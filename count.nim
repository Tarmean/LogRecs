import inlinejson
import strutils
import algorithm, future
let path = when defined windows:
             r"C:\Users\Cyril\AppData\Local\plover\plover\main.json"
           else:
             r"/home/cyril/.local/share/plover/dict.json"

var
  dparser = parseFile(path)
  rootObject = newJsonObject(dparser)
  entries = newSeq[(string, string)]()
for key, value in rootObject:
  entries.add ((value.content, key))

proc allign(s: any, i: int, r=' '): string = $s & r.repeat(max(i - ($s).len, 0))
entries.sort((s, t) => cmp[int](s[0].len, t[0].len), Descending)
var i = 0
for e in entries:
  echo e[0].allign 70, e[1]
  inc i
  if i > 100: break

