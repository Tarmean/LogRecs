import tables, PloverQueue
from hashes import hash
from strutils import count, repeat
from times import format
import algorithm, future

proc allign(s: any, i: int): string = $s & " ".repeat(max(i - ($s).len, 0))

echo "Saved Translation         Original Stroke     Dictionary Stroke"
var t = initTable[string, (int,DictionaryEntry)]()
for entry in getEntries():
  for e in entry.dictionaryEntries:
      inc(t.mgetOrPut(e.translation, (0,e))[0], e.strokes)
var s = newSeq[(int, DictionaryEntry)]()
for a, b in t:
    s.add b
s.sort((x, y) => system.cmp[int](x[0], y[0]), Descending)
var i = 0
for a in s:
   let (c, e) = a
   echo c.allign 6, e.translation.allign 20, e.originalStroke.allign 20, e.dictionaryStroke.allign 20
   inc i
   if i > 30: break
