import strutils, lexbase, streams, sets, tables, times
type 
  LogParser* = BaseLexer
  Translation* = ref TranslationObj
  TranslationObj = object
    strokes*: string
    usages*: int
    wastedStrokes*: int
  Stroke* = ref StrokeObj
  StrokeObj* = object
    times*: seq[TimeInfo]
    stroke*: string
  
  LogKind* = enum
    lAddition,
    lDeletion,
    lStroke,
    lError
  LogEntry* = object
    case kind*: LogKind
    of lAddition:
      translation*: string
      stroke*: string
    of lDeletion, lStroke, lError: discard
    time*: TimeInfo

proc openLog*(path: string): LogParser =
  let s = newFileStream(path)
  result = LogParser()
  result.open s

proc newDeletionEntry(t: TimeInfo): LogEntry =
  result = LogEntry(time: t, kind: lDeletion)
proc newStrokeEntry(t: TimeInfo): LogEntry =
  result = LogEntry(time: t, kind: lStroke)
proc newErrorEntry(t: TimeInfo): LogEntry =
  result = LogEntry(time: t, kind: lError)
proc newLogEntry(stroke, translation: string, time: TimeInfo): LogEntry =
  result             = LogEntry(time: time)
  result.kind        = lAddition
  result.stroke      = stroke
  result.translation = translation

proc newTranslation*(): Translation =
  result = Translation()
  result.usages = 0
  result.wastedStrokes = 0

iterator parse*(parser: var BaseLexer): LogEntry =
  var 
    stroke       = ""               # buffer for the current stroke
    translation  = ""               # buffer for the current translation
    timeString   = newString 23     # buffer for the date and time fields
    strokeLength = 0                # length of the current stroke, i.e. number of /'s +1
    i            = parser.lineStart # position in the lexer buffer
    time:   TimeInfo                # (parsed) time of the current entry
    id:     LogKind                 # type of the current entry
    result: LogEntry

  block outer:
    while parser.buf[i] != '\0': # if the EOF isn't after an eol character the log is broken
      for j in 0..<23: # the date and time fields combined are 23 characters long
        timeString[j] = parser.buf[i]
        inc i
      time = timeString.parse "yyyy-MM-dd HH:mm:ss"
      inc i # skip the space
      id = case parser.buf[i] # 24th character or the line can be used to id the type
           of 'T': lAddition  # add a stroke and update possible dictionary entries
           of '*': lDeletion  # remove the last stroke, either because of multi stroke words or '*'
           of 'S': lStroke    # all this info is also in the next T so ignore these
           else: lError       # broken log file or parser, gives up
      case id
      of lAddition:
        inc i, 13 # skip to the stroke start
        while true:
          inc strokeLength
          while parser.buf[i] != '\'': # parse until start of delimiter
            inc i
          inc i
          while parser.buf[i] != '\'': # copy until the end delimiter
            stroke.add parser.buf[i]
            inc i
          inc i, if strokeLength == 1: 2 else: 1 # interestingly enough there is only a final ',' if this is a one-stroke-translation
                                                 # and by interestingly I mean super dumb and annoying
          if parser.buf[i] != ')':
            stroke.add '/'
          else: # stroke ended, copy translation until line end
            inc i, 4
            while parser.buf[i] notin {'\c', '\l'}:
              translation.add parser.buf[i]
              inc i
            translation.setLen translation.len - 1 # also captured the last ), no good way around this because there might be unescaped )'s
            case parser.buf[i]
            of '\c': i = parser.handleCR i
            of '\l': i = parser.handleLF i
            else: break outer
            break
        result = newLogEntry(stroke, translation, time)

      of lDeletion: # two options, multi stroke or * deletion. If it is a deletion the state is Deleting
        while parser.buf[i] notin {'\c', '\l'}: inc i
        case parser.buf[i]
        of '\c': i = parser.handleCR i
        of '\l': i = parser.handleLF i
        else: break outer
        result = newDeletionEntry(time)

      of lStroke:
        while parser.buf[i] notin {'\c', '\l'}: inc i
        case parser.buf[i]
        of '\c': i = parser.handleCR i
        of '\l': i = parser.handleLF i
        else: break outer
        continue
      of lError: break outer

      # at this point the line is parsed and everything is ready to return:
      yield result

      strokeLength = 0
      translation.setLen 0
      stroke.setLen 0

proc parseLine*(line: string): LogEntry =
  if line == "*": return LogEntry(kind: lDeletion, time: getTime().getLocalTime())
  return LogEntry(kind: lAddition, stroke: "", translation: line, time: getTime().getLocalTime())

proc parse*(line: string): LogEntry =
  var
    stroke       = ""
    time         = line[0..<23].parse "yyyy-MM-dd HH:mm:ss"
    i            = 37
  case line[24] # 24th character of the line can be used to id the type
  of 'T':
    var nextDist = 2
    while true:
      while line[i] != '\'':
        inc i
      inc i
      while line[i] != '\'':
        stroke.add line[i]
        inc i
      inc i, nextDist # only trailing "," if it is a one stroke word
      if line[i] == ')':
        break
      nextDist = 1
      stroke.add '/'
    return newLogEntry(stroke, line[i+4..line.high-1], time)
  of '*':
    return newDeletionEntry(time)
  of 'S':
    return newStrokeEntry(time)
  else:
    return newErrorEntry(time)



var 
  logPath* = when defined windows:
              r"C:\Users\Cyril\AppData\Local\plover\plover\plover.log"
            else:
              r"/home/cyril/.local/share/plover/plover.log"
when isMainModule:
  var
    s = newFileStream(logPath)
    parser: BaseLexer
    inputs = newSeq[seq[(string, string, TimeInfo)]]()
  parser.open s
  for a in parser.parse:
    case a.kind
    of lAddition:
      echo a.stroke, " ", a.translation
      inputs.add(@[(a.stroke, a.translation, a.time)])
    of lDeletion:
      echo "*"
      if inputs.len > 0:
        inputs[inputs.high].setLen inputs[inputs.high].len - 1
        if inputs[inputs.high].len == 0:
          inputs.setLen inputs.len - 1
    else: break
