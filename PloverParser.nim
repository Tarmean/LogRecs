import tables, PloverQueue
from hashes import hash
from strutils import count, repeat
from times import format

proc allign(s: any, i: int): string = result = $s & " ".repeat(max(i - ($s).len, 0))

var 
  result = initTable[string, DictionaryEntry]()
echo "Saved Translation         Original Stroke     Dictionary Stroke   Time Stamp"
for entry in getEntries():
  for e in entry.dictionaryEntries:
    echo e.strokes.allign 6, e.translation.allign 20, e.originalStroke.allign 20, e.dictionaryStroke.allign 20, entry.time.format("yyyy-MM-dd HH:mm:ss")
    # result(e, e.strokes)
    # if e.translation != e.originalStroke: echo wasted.allign 4, translation.allign 20, stroke.allign 20, entry.entry.time.format"yyyy-MM-dd HH:mm:ss"
    #
# result.sort
# var i = 0
# for a, b in result:
#   echo b.allign 4, a.translation.allign 10, a.originalStroke.allign 10, a.dictionaryStroke.allign 10
#   inc i
#   if i > 30: break
    # var tracker = result.mgetOrPut(translation, newTranslation())

    # inc tracker.wastedStrokes, (entry.entry.stroke.count('/') - stroke.count('/'))
    # inc tracker.usages
    # tracker.updateStroke(stroke, entry.entry.time)
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

# echo "Num  Translation    Shortest"
# echo ""
# for a, b in result:
#   var
#     dictStroke = ""
#     dictLen: int
#     wastedStrokes = 0
#     minLen = int.high
#     minStroke = ""
#   try:
#     dictLen = dictStroke.count("/")
#   except:
#     dictLen = int.high
#   for stroke in b.strokes:
#     let strokeCount = stroke.stroke.count("/")
#     wastedStrokes += max(strokeCount - dictLen, 0) * stroke.times.len
#     if strokeCount < minLen:
#       minLen = strokeCount
#       minStroke = stroke.stroke
#   if minLen > dictLen:
#     entries.add((wastedStrokes, a, minStroke & " ".repeat(max(20-minStroke.len, 0)) & "   " & dictStroke))
# entries.sort((x, y) => system.cmp[int](x[0], y[0]), Descending)
# for i in 0..<30:
#   let 
#     (wasted, translation, strokes) = entries[i]
#     wastedString = $wasted
#   echo wastedString, " ".repeat(max(5-wastedString.len, 0)), translation, " ".repeat(max(15-translation.len, 0)), strokes

# # # for input in stdin.lines:
# # #   for x, y in dictionaryTree.pairsWithPrefix(input):
# # #     echo x, " ", y

