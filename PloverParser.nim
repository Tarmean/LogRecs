import inlinejson, streams, critbits, strutils, os

var 


  dictPath = when defined windows:
                r"/home/cyril/.local/share/plover/dict.json"
             else:
                r"C:\Users\Cyril\AppData\Local\plover\plover\main.json"
  parser = parseFile(dictPath)
  rootObject = newJsonObject(parser)
  # table = newTable[string, string]()
  t = CritBitTree[string]()
for key, value in rootObject:
  let translation = value.content.toLower
  if not t.hasKey(translation) or t[translation].len > key.len:
    t[translation] = key
  
echo t["sun"]
for input in stdin.lines:
  for x, y in t.pairsWithPrefix(input):
    echo x, " ", y
