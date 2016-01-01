import queue, DictionaryTree
from times import TimeInfo
import LogParser

type LogQueue* = Queue[DictionaryEntryGroup]

proc initLogQueue*(): LogQueue = initQueue[DictionaryEntryGroup]()
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

proc addStroke*(q: var LogQueue, t: DictionaryTree, i: LogEntry) =
  var 
    prefixes = if q.count > 0:
                 q.peak.dictionaryPrefixes
               else:
                 @[]
  q.add getNextGroup(t.root, prefixes, i)
proc finishStroke*(q: var LogQueue) =
    q.dequeue.finishNodes()

proc removeStroke*(q: var LogQueue) =
  if q.count == 0: return
  discard q.pop

const maxStrokes = 10
proc processEntry*(q: var LogQueue, t: DictionaryTree, entry: LogEntry) {.inline.} =
  case entry.kind
  of lAddition:
    q.addStroke(t, entry)
    if q.count >= maxStrokes:
        q.finishStroke()
  of lDeletion:
    q.removeStroke()
  else: discard

iterator matches*(q: var LogQueue, t: DictionaryTree, i: Logentry): (int, string, TreeEntry) =
  var
    prefixes = if q.count > 0:
                 q.peak.dictionaryPrefixes
               else:
                 @[]
    next: DictionaryEntryGroup
  for output in next.iteratorFinishedNodes(t, prefixes, i):
    yield output
  q.add next
