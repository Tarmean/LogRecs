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
    lAddition, ## Type some stuff
    lDeletion,      ## Remove the typed stuff
    lStroke,   ## Internal state for '*Translation' entries, doesn't output but modifies the next 'Translation'
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
  result = LogEntry(time: t)
  result.kind = lDeletion
proc newLogEntry(kind: LogKind, stroke, translation: string, time: TimeInfo): LogEntry =
  result             = LogEntry(time: time)
  result.kind        = kind
  result.stroke      = stroke
  result.translation = translation

proc newTranslation*(): Translation =
  result = Translation()
  result.usages = 0
  result.wastedStrokes = 0
  # result.strokes = newSeq[Stroke]()
  # result.errors = newSeq[Stroke]()
proc newStroke(s: string, t: TimeInfo): Stroke =
  result = Stroke()
  result.stroke = s
  result.times = @[t]

# proc updateStroke*(t: var Translation, stroke, wasted) =
#   # for v in t.strokes.mitems():
#   #   if v.stroke == stroke:
#   #     v.times.add time
#   #     return
#   t.strokes.add newStroke(stroke, time)
# proc updateError(t: var Translation, stroke: string, time: TimeInfo) =
#   for v in t.errors.mitems():
#     if v.stroke == stroke:
#       v.times.add time
#       return
#   t.errors.add newStroke(stroke, time)

iterator parse*(parser: var BaseLexer): LogEntry =
  var 
    time: TimeInfo                  # (parsed) time of the current entry
    id:   LogKind                   # type of the current entry
    stroke       = ""               # buffer for the current stroke
    translation  = ""               # buffer for the current translation
    timeString   = newString 23     # buffer for the date and time fields
    strokeLength = 0                # length of the current stroke, i.e. number of /'s +1
    i            = parser.lineStart # position in the lexer buffer
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
        result = newLogEntry(id, stroke, translation, time)

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

      # if id == 'T':
      #   if inputStack.len > 0:
      #     var transRef: Translation = result.mgetOrPut(inputStack[0][1], newTranslation())
      #     inc transRef.errorCount, errorStack.len
      #     for error in errorStack:
      #       transRef.updateError(error[0], error[1])

      #     transRef.updateStroke(inputStack[0][0], inputStack[0][2])
      #     inc transRef.usages
      #     errorStack.setLen 0
      #     inputStack.setLen inputStack.len - 1

      #   
      #   inputStack.add((stroke, translation, time))


proc parseLine(line: string): LogEntry =
  let time = line[0..<23].parse "yyyy-MM-dd HH:mm:ss"
  case line[24]
  of 'S': return LogEntry(kind: lStroke, time: time)
  of '*': return LogEntry(kind: lDeletion, time: time)
  of 'T':
    var
      strokes = ""
      translation = ""
    result = LogEntry(time: time)
  else: return LogEntry(kind: lError, time: time)




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

# for entry in inputs:
#   echo ""
#   for modifications in entry:
#     let (s, t, d) = modifications
#     echo s, " ", t
  # if b.errorCount >= 10:
  #   echo a, ": "
  #   echo "  usages: ", b.usages
  #   echo "  errors: ", b.errorCount
  #   for error in b.errors:
  #     echo "  ", error.stroke, " ".repeat(max(30 - error.stroke.len, 0)), error.times.len
  #     for time in error.times:
  #       echo "    ", time.format "yyyy-MM-dd HH:mm:ss"#"h:mm:ss d/M/yy"


