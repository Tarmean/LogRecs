import inlinejson, streams, critbits, strutils

var 
  parser = parseFile(r"C:\Users\Cyril\AppData\Local\plover\plover\main.json")
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
