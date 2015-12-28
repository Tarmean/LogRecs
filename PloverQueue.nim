import times, sequtils, logparser, streams, lexbase, inlinejson, strutils
import CritBits
from math import isPowerOfTwo
type
  Queue[T]= object
    data: seq[T]
    count: int
    cap: int
    mask: int
    rd: int
    wr: int
  LogQueue = object
    queue: Queue[LogQueueGroup]
    strokeCount: int
  LogQueueGroup* = ref object
    entries*: seq[LogEntry]
    dictionaryPrefixes*: seq[(int, CritBits.Node[string])]
    dictionaryEntries*: seq[(string, string)]

var
  dictPath = when defined windows:
                r"C:\Users\Cyril\AppData\Local\plover\plover\main.json"
             else:
                r"/home/cyril/.local/share/plover/dict.json"
  dparser = parseFile(dictPath)
  dictionaryTree = CritBitTree[string]()
  rootObject = newJsonObject(dparser)
for key, value in rootObject:
  let (stroke, translation) = (key, value.content)
  if not dictionaryTree.hasKey(translation) or dictionaryTree[translation].count('/') > stroke.count('/'):
    dictionaryTree[translation] = stroke

proc getNextNode[T](n: Node[T], offset: int, key: string): Node[T] =
  result = n
  while result != nil and result.byte + offset < key.len and not result.isLeaf:
    let 
     ch = key[result.byte + offset]
     dir = (1 + (ch.ord or result.otherBits.ord)) shr 8
    result = result.child[dir]

proc initQueue*[T](initialSize=4): Queue[T] =
  ## creates a new queue. `initialSize` needs to be a power of 2.
  assert isPowerOfTwo(initialSize)
  result.mask = initialSize-1
  newSeq(result.data, initialSize)
proc initLogQueue*(): LogQueue =
  result.queue = initQueue[LogQueueGroup]()
  result.strokeCount = 0
proc initLogQueueGroup*(c: CritBitTree, p: seq[(int, Node[string])], i: LogEntry): LogQueueGroup =
  result = LogQueueGroup()
  result.entries = @[i]
  result.dictionaryEntries = @[]
  result.dictionaryPrefixes = @[]
  let ownNode = getNextNode(c.root, 0, i.translation)
  if ownNode.isLeaf:
    if ownNode.key == i.translation:
      result.dictionaryEntries.add((ownNode.val, ownNode.key))
  else:
    result.dictionaryPrefixes.add((i.translation.len-1, ownNode))
  # for a in p:
  #   let 
  #     (offset, node) = a
  #     multiNode = getNextNode(node, offset, i.translation)
  #   if multiNode.isLeaf:
  #     if multiNode.key == i.translation:
  #       result.dictionaryEntries.add((multiNode.val, multiNode.key))
  #   else:
  #     result.dictionaryPrefixes.add((i.translation.len-1, multiNode))

const maxStrokes = 20
proc `$`*[T](q: Queue[T]): string =
  ## turns a queue into its string representation.
  result = "["
  for x in items(q):
    if result.len > 1: result.add(", ")
    result.add($x)
  result.add("]")
iterator items*[T](q: Queue[T]): T =
  ## yields every element of `q`.
  var i = q.rd
  var c = q.count
  while c > 0:
    dec c
    yield q.data[i]
    i = (i + 1) and q.mask
proc dequeue*[T](q: var Queue[T]): T =
  ## removes and returns the first element of the queue `q`.
  assert q.count > 0
  dec q.count
  result = q.data[q.rd]
  q.rd = (q.rd + 1) and q.mask
proc add*[T](q: var Queue[T], i: T) =
  ## adds an `item` to the end of the queue `q`.
  var cap = q.mask+1
  if q.count >= cap:
    var n: seq[T]
    newSeq(n, cap*2)
    var i = 0
    for x in items(q):
      shallowCopy(n[i], x)
      inc i
    shallowCopy(q.data, n)
    q.mask = cap*2 - 1
    q.wr = q.count
    q.rd = 0
  inc q.count
  q.data[q.wr] = i
  q.wr = (q.wr + 1) and q.mask



proc peak*(q: var LogQueue): var LogQueueGroup = q.queue.data[q.queue.rd]
proc dequeue*(q: var LogQueue): LogQueueGroup =
  result = q.queue.dequeue
  dec q.strokeCount, result.entries.len
proc addStroke*(q: var LogQueue, c: CritBitTree[string], i: LogEntry) =
  var entry: LogQueueGroup
  if q.strokeCount == 0:
    entry = LogQueueGroup(entries: @[i], dictionaryPrefixes: @[], dictionaryEntries: @[])
  else:
    entry = initLogQueueGroup(c, q.peak.dictionaryPrefixes, i)

  add(q.queue, entry)
  inc q.strokeCount
proc continueStroke*(q: var LogQueue, i: LogEntry) =
  q.peak.entries.add i
  inc q.strokeCount
proc removeStroke*(q: var LogQueue): LogEntry =
  if q.strokeCount == 0: return
  var e = q.peak.entries
  result = e[e.high]
  dec q.strokeCount
  e.setLen e.high
  if e.len == 0 and q.strokeCount > 0:
    discard q.dequeue()


iterator getEntries*(): LogQueueGroup =
    var
      s = newFileStream(logPath)
      parser: BaseLexer
      inputs = initLogQueue()
    parser.open s
    for a in parser.parse:
      case a.kind
      of lInitialStroke:
        inputs.addStroke(dictionaryTree, a)
      of lModification:
        inputs.continueStroke a
      of lDeletion:
        discard inputs.removeStroke
      else: break
      if inputs.strokeCount >= maxStrokes:
        let bla = inputs.dequeue()
        yield bla

        let 
         entry = bla.entries[bla.entries.high]
         (logstroke, logtranslation) = (entry.stroke, entry.translation)
        var printed = false
        for entry in bla.dictionaryEntries:
          let (stroke, translation) = entry
          if logstroke.count('/') > stroke.count('/'):
            if not printed:
              echo logstroke, " ", logtranslation
              echo bla.entries
              printed = true
            echo "    ", stroke, " ", translation
