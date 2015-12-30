import tables, PloverQueue
from hashes import hash
from strutils import count, repeat
from times import format

proc allign(s: any, i: int): string = $s & " ".repeat(max(i - ($s).len, 0))

echo "Saved Translation         Original Stroke     Dictionary Stroke   Time Stamp"
for entry in getEntries():
  for e in entry.dictionaryEntries:
    echo e.strokes.allign 6, e.translation.allign 20, e.originalStroke.allign 20, e.dictionaryStroke.allign 20, entry.time.format("yyyy-MM-dd HH:mm:ss")
