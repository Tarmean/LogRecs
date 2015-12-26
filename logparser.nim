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
  StrokeObj = object
    times*: seq[TimeInfo]
    stroke*: string
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
proc parse*(parser: var BaseLexer): TableRef[string, Translation] =
  var 
    i: int
    stroke = ""
    translation = ""
    timeString = newString 23
    strokeLength = 0
    time: TimeInfo
    id = 'T'

    inputStack = newSeq[(string, string, TimeInfo)]()
    errorStack = newSeq[(string, TimeInfo)]()
  i = parser.lineStart
  result = newTable[string, Translation]()

  while parser.buf[i] != '\0':
    for j in 0..<23:
      timeString[j] = parser.buf[i]
      inc i
    time = timeString.parse "yyyy-MM-dd HH:mm:ss"
    inc i
    id = parser.buf[i]
    case id
    of 'T':
      inc i, 13
      while true:
        inc strokeLength
        while parser.buf[i] != '\'':
          inc i
        inc i
        while parser.buf[i] != '\'':
          stroke.add parser.buf[i]
          inc i
        inc i, if strokeLength == 1: 2 else: 1
        if parser.buf[i] == ')':
          inc i, 4
          break
        else:
          stroke.add '/'
    of 'S':
      if parser.buf[i + 7] == '*' and inputStack.len > 0:
        # errorStack.setLen max(errorStack.len - 1, 0)
        if errorStack.len == 0:
          errorStack.add((inputStack[0][0], time))
        inputStack.setLen max(inputStack.len - 1, 0)
      while parser.buf[i] notin {'\c', '\l'}: inc i
      case parser.buf[i]
      of '\c': i = parser.handleCR i
      of '\l': i = parser.handleLF i
      else: return
      continue
    of '*':
      while parser.buf[i] notin {'\c', '\l'}: inc i
      case parser.buf[i]
      of '\c': i = parser.handleCR i
      of '\l': i = parser.handleLF i
      else: return
      continue
    else: return
    while parser.buf[i] notin {'\c', '\l'}:
      translation.add parser.buf[i]
      inc i
    case parser.buf[i]
    of '\c': i = parser.handleCR i
    of '\l': i = parser.handleLF i
    else: return

    if id == 'T':
      if inputStack.len > 0:
        var transRef: Translation = result.mgetOrPut(inputStack[0][1], newTranslation())
        inc transRef.errorCount, errorStack.len
        for error in errorStack:
          transRef.updateError(error[0], error[1])

        transRef.updateStroke(inputStack[0][0], inputStack[0][2])
        inc transRef.usages
        errorStack.setLen 0
        inputStack.setLen inputStack.len - 1

      translation.setLen(translation.len - 1)
      inputStack.add((stroke, translation, time))


    strokeLength = 0
    translation.setLen 0
    stroke.setLen 0




var 
  logPath* = when defined windows:
              r"C:\Users\Cyril\AppData\Local\plover\plover\plover.log"
            else:
              r"/home/cyril/.local/share/plover/plover.log"

  # s = newFileStream(logPath)
  # parser: BaseLexer
# parser.open s
# for a, b in parser.parse:
  # if b.errorCount >= 10:
  #   echo a, ": "
  #   echo "  usages: ", b.usages
  #   echo "  errors: ", b.errorCount
  #   for error in b.errors:
  #     echo "  ", error.stroke, " ".repeat(max(30 - error.stroke.len, 0)), error.times.len
  #     for time in error.times:
  #       echo "    ", time.format "yyyy-MM-dd HH:mm:ss"#"h:mm:ss d/M/yy"


