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
  LogQueueGroup* = ref object
    entry*: LogEntry
    strokes*: int
    dictionaryPrefixes*: seq[(int, string, Node[string])]
    dictionaryEntries*: seq[(int, string, string)]

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
  if not dictionaryTree.hasKey(translation) or (dictionaryTree[translation].count('/') >= stroke.count('/')) or (dictionaryTree[translation].count('/') >= stroke.count('/')  and dictionaryTree[translation].len > stroke.len):
    dictionaryTree[translation] = stroke

proc getNextNode[T](n: Node[T], key: string): Node[T] =
  result = n
  while result != nil and result.byte < key.len and not result.isLeaf:
    let 
     ch = key[result.byte]
     dir = (1 + (ch.ord or result.otherBits.ord)) shr 8
    result = result.child[dir]
proc finishNodes[T](stroke: string, e: seq[(int, string, Node[T])]): seq[(int, string, string)] =
  result = @[]
  for entry in e:
    var 
      (baseStrokes, key, it) = entry
      strokes = baseStrokes + stroke.count('/')
    while it != nil:
      if it.isLeaf:
        let wasted = strokes - it.val.count('/') - 1
        if key == it.key and wasted > 0:
          result.add((wasted, it.val, it.key))
        break
      else:
        let dir = (('\0'.ord or it.otherBits.ord) + 1) shr 8
        it = it.child[dir]
proc updateGroups(postFix: string, stroke: string, p: seq[(int, string, Node[string])]): (seq[(int, string, string)], seq[(int, string, Node[string])]) =
  result[0] = @[]
  result[1] = @[]
  for a in p:
    let 
      (strokeBase, startKey, startNode) = a
      searchKey = if startKey != nil: startKey & " " & postFix else: postFix
      node = getNextNode(startNode,  searchKey)
      strokes = strokeBase + stroke.count('/') + 1
    if node.isLeaf:
      let wasted = strokes - node.val.count('/') - 1
      if node.key == searchKey and wasted > 0:
        result[0].add((wasted, node.val, node.key))
    else:
      result[1].add((strokes, searchKey, node))

proc initQueue*[T](initialSize=4): Queue[T] =
  ## creates a new queue. `initialSize` needs to be a power of 2.
  assert isPowerOfTwo(initialSize)
  result.mask = initialSize-1
  newSeq(result.data, initialSize)
proc initLogQueue*(): LogQueue =
  result.queue = initQueue[LogQueueGroup]()
proc initLogQueueGroup*(c: CritBitTree, p: seq[(int, string, Node[string])], i: LogEntry): LogQueueGroup =
  result = LogQueueGroup(entry: i)
  var p = p
  p.add((0, nil,  c.root))
  (result.dictionaryEntries, result.dictionaryPrefixes) = updateGroups(i.translation, i.stroke, p)


const maxStrokes = 10
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


proc printQueue(q: LogQueue) =
    echo  " count", q.queue.count, " cap", q.queue.cap,  " mask", q.queue.mask, " rd", q.queue.rd, " wr", q.queue.wr

proc peak*(q: var LogQueue): var LogQueueGroup =
    let i = (q.queue.wr - 1 + q.queue.mask ) mod q.queue.mask
    q.queue.data[i]
proc dequeue*(q: var LogQueue): LogQueueGroup =
  result = q.queue.dequeue()
proc addStroke*(q: var LogQueue, c: CritBitTree[string], i: LogEntry) =
  var 
    entry: LogQueueGroup
    prefixes = if q.queue.count > 0:
                 q.peak.dictionaryPrefixes
               else:
                 @[]

  entry = initLogQueueGroup(c, prefixes, i)

  add(q.queue, entry)
  
proc removeStroke*(q: var LogQueue, c: CritBitTree): LogQueueGroup=
  if q.queue.count == 0: return
  dec q.queue.count
  q.queue.wr = (q.queue.wr - 1 + q.queue.mask) mod q.queue.mask
  result = q.queue.data[q.queue.wr]

iterator getEntries*(): LogQueueGroup =
    var
      s = newFileStream(logPath)
      parser: BaseLexer
      inputs = initLogQueue()
      i = 0
    parser.open s
    for a in parser.parse:
      case a.kind
      of lAddition:
        inputs.addStroke(dictionaryTree, a)
        if inputs.queue.count >= maxStrokes:
          var result = inputs.dequeue()
          result.dictionaryEntries.add finishNodes(result.entry.stroke, result.dictionaryPrefixes)
          yield result
      of lDeletion:
        discard inputs.removeStroke dictionaryTree
      else: break
