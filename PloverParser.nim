import inlinejson, streams, critbits, strutils, os, logparser, lexbase, tables
import algorithm, future

var 


  dictPath = when defined windows:
                r"C:\Users\Cyril\AppData\Local\plover\plover\main.json"
             else:
                r"/home/cyril/.local/share/plover/dict.json"
  dparser = parseFile(dictPath)
  rootObject = newJsonObject(dparser)
  # table = newTable[string, string]()
  t = CritBitTree[string]()
for key, value in rootObject:
  let translation = value.content.toLower
  if not t.hasKey(translation) or t[translation].len > key.len:
    t[translation] = key
var 
  s = newFileStream(logPath)
  lParser: LogParser
  entries: seq[(int, string, string)] = @[]
lParser.open s
echo "Num  Translation    Shortest Used          Shortest Dict"
echo ""
for a, b in lParser.parse:
  var
    dictStroke = ""
    dictLen: int
    wastedStrokes = 0
    minLen = int.high
    minStroke = ""
  try:
    dictStroke = t[a]
    dictLen = dictStroke.find("/")
  except:
    dictLen = int.high
  for stroke in b.strokes:
    let strokeCount = stroke.stroke.find("/")
    wastedStrokes += max(strokeCount - dictLen, 0) * stroke.times.len
    if strokeCount < minLen:
      minLen = strokeCount
      minStroke = stroke.stroke
  if minLen > dictLen:
    entries.add((wastedStrokes, a, minStroke & " ".repeat(max(20-minStroke.len, 0)) & "   " & dictStroke))
entries.sort((x, y) => system.cmp[int](x[0], y[0]), Descending)
for i in 0..<30:
  let 
   (count, translation, strokes) = entries[i]
   countString = $count
  echo countString, " ".repeat(max(5-countString.len, 0)), translation, " ".repeat(max(15-translation.len, 0)), strokes
  # if b.errorCount >= 10:
  #   echo a, ": "
  #   echo "  usages: ", b.usages
  #   echo "  errors: ", b.errorCount
  #   for error in b.errors:
  #     echo "  ", error.stroke, " ".repeat(max(30 - error.stroke.len, 0)), error.times.len
  #     for time in error.times:
  #       echo "    ", time.format "yyyy-MM-dd HH:mm:ss"#"h:mm:ss d/M/yy"
# echo t["sun"]
# for input in stdin.lines:
#   for x, y in t.pairsWithPrefix(input):
#     echo x, " ", y

