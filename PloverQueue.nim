import queue, DictionaryTree
from times import TimeInfo, format
import LogParser
import critbits

type LogQueue* = Queue[DictionaryEntryGroup]

proc initLogQueue*(): LogQueue = initQueue[DictionaryEntryGroup](16)
proc pop*[T](q: var Queue[T]): T =
  dec q.count
  q.wr = (q.wr - 1 + q.mask) mod q.mask
  result = q.data[q.wr]
proc add*[T](q: var Queue[T], e: T) =
  queue.add q, e
proc dequeue*[T](q: var Queue[T]): T =
  queue.dequeue(q)
proc peak*[T](q: var Queue[T]): var T =
  let i = (q.wr - 1 + q.mask ) mod q.mask
  q.data[i]

const maxStrokes = 10
proc addStroke*(q: var LogQueue, t: DictionaryTree, i: LogEntry) =
  var 
    prefixes = if q.count > 0:
                 q.peak.dictionaryPrefixes
               else:
                 @[]
  var group = getNextGroup(t.root, prefixes, i)
  group.processGroup i.time
  q.add group
  if q.count >= maxStrokes:
      discard q.dequeue()
proc addStrokeStatic*(q: var LogQueue, t: DictionaryTree, i: LogEntry): DictionaryEntryGroup =
  var 
    prefixes = if q.count > 0:
                 q.peak.dictionaryPrefixes
               else:
                 @[]
  var group = getNextGroup(t.root, prefixes, i)
  q.add group
  if q.count >= maxStrokes:
      discard q.dequeue()
  return group

proc removeStroke*(q: var LogQueue) =
  if q.count == 0: return
  discard q.pop

proc processEntry*(q: var LogQueue, t: DictionaryTree, entry: LogEntry) {.inline.} =
  case entry.kind
  of lAddition:
    q.addStroke(t, entry)
    echo "prefix matches"
    for e in q.peak.dictionaryPrefixes:
      echo e.translation
      var skip = e.exactMatch
      for n in e.node.leaves():
        if skip:
          skip = false
          continue
        echo "       ", n.val.originalTranslation, " ", n.val.bestStroke
    echo "exact matches"
    for e in q.peak.dictionaryEntries:
      echo e.entry.originalTranslation, " ", e.wasted, " ", e.entry.wasted
      for s in e.entry.dictStrokes:
        echo "   ", s
    echo "______________________"
    echo ""
    echo ""
    echo ""

  of lDeletion:
    q.removeStroke()
  else: discard
