import strutils, lexbase, streams, sets, tables, times
type 
  Translation* = object
    strokes*: seq[Stroke]
    misStrokes*: int
  Stroke* = object
    times*: seq[TimeInfo]
    stroke*: string #seq[int, 22]
proc newTranslation(): Translation =
  result = Translation()
  result.misStrokes = 0
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
proc parse(l: var BaseLexer): TableRef[string, Translation] =
  var 
    i: int
    stroke = ""
    translation = ""
    lastTranslation = ""
    timeString = newString 23
    strokeLength = 0
    time: TimeInfo
    id = 'T'
    line: string
  result = newTable[string, Translation]()
  i = l.lineStart

  block outer:
    while true:
      for j in 0..<23:
        timeString[j] = l.buf[i]
        inc i
      # echo timeString
      try: time = timeString.parse "yyyy-MM-dd HH:mm:ss"
      except:
        return
      inc i
      id = l.buf[i]
      # echo "ID, ", id
      case id
      of 'T':
        inc i, 13
        while true:
          inc strokeLength
          while l.buf[i] != '\'':
            inc i
          inc i
          while l.buf[i] != '\'':
            stroke.add l.buf[i]
            inc i
          inc i, if strokeLength == 1: 2 else: 1
          if l.buf[i] == ')':
            inc i, 4
            break
          else:
            stroke.add '/'
      of 'S', '*':
        while l.buf[i] notin {'\c', '\L', '\0'}: inc i
        case l.buf[i]
        of '\c': i = l.handleCR i
        of '\L': i = l.handleLF i
        of '\0': return
        else:
          echo "S*ERROR"
          echo l.buf[i]
          echo stroke, "/",  translation
          echo time
          echo id
          inc i
          return
        if id == '*': continue
      else:
        echo "IDERROR: ", l.buf[i]
      while l.buf[i] notin {'\c', '\L', '\0'}:
        translation.add l.buf[i]
        inc i
      case l.buf[i]
      of '\c': i = l.handleCR i
      of '\L': i = l.handleLF i
      of '\0': return
      else:
        echo "NL ERROR"
        echo l.buf[i]
        echo stroke, "/",  translation
        echo time
        echo id
        return
      translation.setLen translation.len - 1
      if id == 'T':
        result.mgetOrPut(translation, newTranslation()).updateStroke(stroke, time)
      elif result.hasKey lastTranslation:
        inc result[lastTranslation].misStrokes

      lastTranslation = translation
      strokeLength = 0
      translation.setLen 0
      stroke.setLen 0





  # while not (l.buf[i] in {'\c', '\L', EndOfFile}):
  #   for j in 0..<23:
  #     timeString[j] = l.buf[i + j]
  #   time = timeString.parse "yyyy-MM-dd HH:mm:ss"
  #   echo time
  #   inc i, 24
  #   case l.buf[i]
  #   of '*', 'S':
  #     while l.buf[i] != '\L':
  #       inc i
  #     inc i, 25
  #   else: discard
  #   while true:
  #     echo l.buf[i]
  #     while not (l.buf[i] != '\''):
  #       stroke.add l.buf[i]
  #       echo l.buf[i]
  #       inc i
  #     if l.buf[i] == ')':
  #       inc i, 4
  #       break
  #     else:
  #       stroke.add '/'
  #       while l.buf[i] != '\'':
  #         inc i
  #       inc i
  #   while l.buf[i] == ')':
  #     translation.add l.buf[i]
  #     inc i
  #   echo stroke, " ", translation

# echo parse("2015-12-06 16:34:39,089 ", "yyyy-MM-dd HH:mm:ss")

var 
  s = newFileStream(r"C:\Users\Cyril\AppData\Local\plover\plover\plover.log")
  l: BaseLexer
l.open s
let 
  r = l.parse
for k, v in r:
  if v.misStrokes > 1: echo k, " ", v.misStrokes
  for stroke in v.strokes:
    echo "     ", stroke.stroke


