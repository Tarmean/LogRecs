import strutils, lexbase, streams, sets, tables, times
type 
  LogParser* = BaseLexer
  Translation* = ref TranslationObj
  TranslationObj = object
    strokes*: seq[Stroke]
    usages*: int
    errors*: seq[Stroke]
    errorCount*: int
  Stroke* = ref StrokeObj
  StrokeObj* = object
    times*: seq[TimeInfo]
    stroke*: string
  
  LogState {.pure.} = enum 
    Normal, Correcting, Deleting
  LogKind* = enum
    lInitialStroke, ## First stroke in a word as recognized by Plover
    lModification,  ## Addition to some previous stroke, plover replaced the last output with this one
    lDeletion,      ## Special handeling in case a * was stroked to pop the last stroke
    lStrokeCorrection,   ## Internal state for '*Translation' entries, doesn't output but modifies the next 'Translation'
    lError          ## Something went horribly wrong during parsing or the log file is broken
  LogEntry* = object
    case kind*: LogKind
    of lInitialStroke, lModification:
      translation*: string
      stroke*: string
      time*: TimeInfo
    of lDeletion, lError, lStrokeCorrection: discard


proc newDeletionEntry(): LogEntry =
  result = LogEntry()
  result.kind = lDeletion
proc newLogEntry(kind: LogKind, stroke, translation: string, time: TimeInfo): LogEntry =
  result             = LogEntry()
  result.kind        = kind
  result.stroke      = stroke
  result.translation = translation
  result.time        = time

proc newTranslation(): Translation =
  result = Translation()
  result.usages = 0
  result.strokes = newSeq[Stroke]()
  result.errors = newSeq[Stroke]()
proc newStroke(s: string, t: TimeInfo): Stroke =
  result = Stroke()
  result.stroke = s
  result.times = @[t]

proc updateStroke(t: var Translation, stroke: string, time: TimeInfo) =
  for v in t.strokes.mitems():
    if v.stroke == stroke:
      v.times.add time
      return
  t.strokes.add newStroke(stroke, time)
proc updateError(t: var Translation, stroke: string, time: TimeInfo) =
  for v in t.errors.mitems():
    if v.stroke == stroke:
      v.times.add time
      return
  t.errors.add newStroke(stroke, time)

iterator parse*(parser: var BaseLexer): LogEntry =
  var 
    time: TimeInfo                  # (parsed) time of the current entry
    id:   LogKind                   # type of the current entry
    stroke       = ""               # buffer for the current stroke
    translation  = ""               # buffer for the current translation
    timeString   = newString 23     # buffer for the date and time fields
    state        = LogState.Normal  # internal flag for current state
    strokeLength = 0                # length of the current stroke, i.e. number of /'s +1
    i            = parser.lineStart # position in the lexer buffer

  block outer:
    while parser.buf[i] != '\0': # if the EOF isn't after an eol character the log is broken
      for j in 0..<23: # the date fields combined are 23 characters long
        timeString[j] = parser.buf[i]
        inc i
      time = timeString.parse "yyyy-MM-dd HH:mm:ss"
      inc i # skip the space
      id = case parser.buf[i] # the initial letter kind of tells the log type. Kind of.
           of 'T': lInitialStroke    # the interesting bits
           of '*': lStrokeCorrection # this either means a multi stroke word or * was used, note for next T
           of 'S': lDeletion         # only interesting if the stroke was *, otherwise the line is skipped
           else: lError
      case id
      of lInitialStroke, lModification:
        id = if state == LogState.Correcting:
               lModification
             else:
               lInitialStroke
        state = LogState.Normal
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

      of lDeletion:
        if parser.buf[i + 7] == '*' and parser.buf[i + 8] == ')': # stroke is only '*'
          state = LogState.Deleting
        while parser.buf[i] notin {'\c', '\l'}: inc i
        case parser.buf[i]
        of '\c': i = parser.handleCR i
        of '\l': i = parser.handleLF i
        else: break outer
        if state != LogState.Deleting: continue # skip only if the stroke wasn't '*'

      of lStrokeCorrection: # two options, multi stroke or * deletion. If it is a deletion the state is Deleting
        if state == LogState.Normal: state = LogState.Correcting
        while parser.buf[i] notin {'\c', '\l'}: inc i
        case parser.buf[i]
        of '\c': i = parser.handleCR i
        of '\l': i = parser.handleLF i
        else: break outer
        continue
      else: break outer

      # at this point the line is parsed and everything is ready to return:
      var result: LogEntry
      if state == LogState.Deleting:
        result = newDeletionEntry()
      else:
        result = newLogEntry(id, stroke, translation, time)
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
    of lInitialStroke:
      echo a.stroke, " ", a.translation
      inputs.add(@[(a.stroke, a.translation, a.time)])
    of lModification:
      echo "   ", a.stroke, " ", a.translation
      inputs[inputs.high].add((a.stroke, a.translation, a.time))
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


