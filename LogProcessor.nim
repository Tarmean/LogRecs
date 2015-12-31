import PloverQueue, DictionaryTree, LogParser

const maxStrokes = 10
proc getEntries*(): DictionaryTree =
    result = getTree()
    var
      p = openLog logPath
      q = initLogQueue()
    for entry in p.parse:
      case entry.kind
      of lAddition:
        q.addStroke(result, entry)
        if q.count >= maxStrokes:
          q.dequeue.finishNodes
      of lDeletion:
        q.removeStroke
      else: break

when isMainModule:
  from strutils import repeat
  from times import format
  import future, algorithm
  proc allign(s: any, i: int): string = $s & " ".repeat(max(i - ($s).len, 0))
  var
    btrie = getEntries()
    res = newSeq[TreeEntry]()
  for a, b in btrie:
    if b.active:
      res.add b


  res.sort((x, y) => system.cmp[int](x.wasted, y.wasted), Ascending)
  for b in res:
      echo b.wasted.allign 4, b.bestStroke.allign 8, b.originalTranslation.allign 20
      echo "__  _____    _________"
      for f in b.usedStrokes[]:
        echo "    ", f.stroke
        echo "    -----"
        for t in f.times:
          echo "      ", t.format("yyyy-MM-dd HH:mm:ss")
