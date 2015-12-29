import inlinejson, streams, critbits, strutils, os, logparser, lexbase, tables, PloverQueue
import algorithm, future


  # table = newTable[string, string]()
var 
  s = newFileStream(logPath)
  lParser: LogParser
  entries: seq[(int, string, string)] = @[]
  result = newTable[string, Translation]()

for entry in getEntries():
  discard
  # if entry.dictionaryEntries.len > 1:
  #   let e = entry.entries[entry.entries.high]
  #   echo e.stroke, "  ", e.translation
  #   for entry in entry.dictionaryEntries:
  #     let (stroke, translation) = entry
  #     echo "  ", stroke, "  ",  translation
  #   echo ""
  
  # let 
  #   e = entry.entries[entry.entries.high]
  #   (stroke, translation, time) = (e.stroke, e.translation, e.time)
  # if stroke.find('/') > 0:
  #   echo stroke, "  ", translation
  #   for item in entry.dictionaryEntries:
  #       let (ds, dt) = item
  #       echo "   ", ds, " ", dt
  # var translationTracker = result.mgetOrPut(translation, newTranslation())
  # translationTracker.updateStroke(stroke, time)
  # inc translationTracker.usages

# echo "Num  Translation    Shortest Used          Shortest Dict"
# echo ""
# for a, b in result:
  # var
  #   dictStroke = ""
  #   dictLen: int
  #   wastedStrokes = 0
  #   minLen = int.high
  #   minStroke = ""
  # try:
  #   dictLen = dictStroke.find("/")
  # except:
  #   dictLen = int.high
  # for stroke in b.strokes:
  #   let strokeCount = stroke.stroke.find("/")
  #   wastedStrokes += max(strokeCount - dictLen, 0) * stroke.times.len
  #   if strokeCount < minLen:
  #     minLen = strokeCount
  #     minStroke = stroke.stroke
  # if minLen > dictLen:
  #   entries.add((wastedStrokes, a, minStroke & " ".repeat(max(20-minStroke.len, 0)) & "   " & dictStroke))
# entries.sort((x, y) => system.cmp[int](x[0], y[0]), Descending)
# for i in 0..<30:
  # let 
  #   (wasted, translation, strokes) = entries[i]
  #   wastedString = $wasted
  # echo wastedString, " ".repeat(max(5-wastedString.len, 0)), translation, " ".repeat(max(15-translation.len, 0)), strokes

# # # for input in stdin.lines:
# # #   for x, y in dictionaryTree.pairsWithPrefix(input):
# # #     echo x, " ", y

