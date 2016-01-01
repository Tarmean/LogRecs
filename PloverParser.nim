import dictionarytree, os, strutils, critbits, times, algorithm, future
var
  tree = getTree()
  entries = newSeq[TreeEntry]()

for line in stdin.lines:
  entries.setLen(0)
  let stopTime = cpuTime()

  for entry in tree.valuesWithPrefix line:
    entries.add entry
  entries.sort((x, y) => cmp[int](x.originalTranslation.len, y.originalTranslation.len))
  let delta = cpuTime() - stopTime

  for entry in entries:
    echo entry.originalTranslation, " ".repeat(max(0, 30-entry.originalTranslation.len)), entry.bestStroke
  echo delta.formatFloat(format=ffDecimal, precision=10)

