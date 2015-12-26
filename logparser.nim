import strutils, lexbase, streams, sets, tables, times
type 
  Translation* = object
    strokes*: seq[Stroke]
    usages*: int
  Stroke* = object
    times*: seq[TimeInfo]
    stroke*: string #seq[int, 22]
proc newTranslation(): Translation =
  result = Translation()
  result.usages = 0
  result.strokes = newSeq[Stroke]()
proc newStroke(s: var string, t: TimeInfo): Stroke =
  result = Stroke()
  result.stroke = s
  result.times = @[t]

proc updateStroke(t: var Translation, stroke: var string, time: TimeInfo) =
  for s in t.strokes.mitems():
    if s.stroke == stroke:
      s.times.add(time)
      return
  t.strokes.add newStroke(stroke, time)
proc parse(parser: var BaseLexer): TableRef[string, Translation] =
  var 
    i: int
    stroke = ""
    translation = ""
    lastTranslation = ""
    backup = ""
    pbackup = ""
    timeString = newString 23
    strokeLength = 0
    time: TimeInfo
    id = 'T'
    line: string
  result = newTable[string, Translation]()
  i = parser.lineStart

  while parser.buf[i] != '\0':
    pbackup = timeString
    backup = timeString
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
    of 'S', '*':
      while parser.buf[i] notin {'\c', '\l'}: inc i
      case parser.buf[i]
      of '\c': i = parser.handleCR i
      of '\l': i = parser.handleLF i
      else: return
      if id == '*': continue
    else:
      echo "IDERROR: ", parser.buf[i]
    while parser.buf[i] notin {'\c', '\l'}:
      translation.add parser.buf[i]
      inc i
    case parser.buf[i]
    of '\c': i = parser.handleCR i
    of '\l': i = parser.handleLF i
    else: return

    translation.setLen translation.len - 1
    if id == 'T':
      result.mgetOrPut(translation, newTranslation()).updateStroke(stroke, time)
    elif result.hasKey lastTranslation:
      inc result[lastTranslation].usages

    lastTranslation = translation
    strokeLength = 0
    translation.setLen 0
    stroke.setLen 0




var 
  logPath = when defined windows:
              r"C:\Users\Cyril\AppData\Local\plover\plover\plover.log"
            else:
              r"/home/cyril/.local/share/plover/plover.log"

  s = newFileStream(logPath)
  parser: BaseLexer
parser.open s
for a, b in parser.parse:
  echo a, ": ", b.usages
  for stroke in b.strokes:
    echo "  ", stroke.stroke
    for time in stroke.times:
      echo "      ", time.format "h:MM:ss d/m/yy"


