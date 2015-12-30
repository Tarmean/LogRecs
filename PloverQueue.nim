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
  PrefixKind* = enum
    knPrefix, knEntry, knNone
  DictionaryEntry* = object
    originalStroke*: string
    translation*: string
    strokes*: int
    case kind*: PrefixKind
    of knPrefix:
      node: Node[string]
    of knEntry:
      dictionaryStroke*: string
    of knNone: discard
  LogQueueGroup* = ref object
    strokes*: int
    time: TimeInfo
    dictionaryPrefixes*: seq[DictionaryEntry]
    dictionaryEntries*: seq[DictionaryEntry]
  DictionaryOutput* = object
    time*: TimeInfo
    dictionaryEntries*: seq[DictionaryEntry]

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
proc getEntry(p: DictionaryEntry, i: LogEntry): DictionaryEntry =
  result = DictionaryEntry() # DictionaryEntry contains a TimeInfo object which contains ranges that can't be 0, so the compiler forces it to be set to something immediately
  result.strokes = p.strokes + i.stroke.count('/') + 1
  result.originalStroke = p.originalStroke & " " & i.stroke
  result.translation = p.translation & i.translation

  let node = getNextNode(p.node,  result.translation)
  if isNil node:
    result.kind = knNone
  elif node.isLeaf:
    let wasted = result.strokes - node.val.count('/') - 1
    if node.key == result.translation and wasted > 0:
      result.kind = knEntry
      result.strokes = wasted
      result.dictionaryStroke = node.val
    else: result.kind = knNone
  else:
    result.kind = knPrefix
    result.node = node
proc getEntry(c: CritBitTree, i: LogEntry): DictionaryEntry =
  result = DictionaryEntry()
  result.strokes = i.stroke.count('/') + 1
  result.originalStroke = i.stroke
  result.translation = i.translation

  let node = getNextNode(c.root, result.translation)
  if isNil node:
    result.kind = knNone
  elif node.isLeaf:
    let wasted = result.strokes - node.val.count('/') - 1
    if node.key == result.translation and wasted > 0:
      result.kind = knEntry
      result.strokes = wasted
      result.dictionaryStroke = node.val
    else: result.kind = knNone
  else:
    result.kind = knPrefix
    result.node = node
proc getEntry(strokes: int, originalStroke, dictionaryStroke, translation: string): DictionaryEntry =
  DictionaryEntry(kind: knEntry, strokes: strokes, originalStroke: originalStroke, dictionaryStroke: dictionaryStroke, translation: translation)

proc finishNodes(e: seq[DictionaryEntry]): seq[DictionaryEntry] =
  result = @[]
  for entry in e:
    var it = entry.node
    while it != nil:
      if it.isLeaf:
        let 
          wasted = entry.strokes - it.val.count('/') - 1
        if entry.translation == it.key and wasted > 0:
          result.add getEntry(wasted, entry.originalStroke, it.val, entry.translation)
        break
      else:
        let dir = (('\0'.ord or it.otherBits.ord) + 1) shr 8
        it = it.child[dir]
proc updateGroups(p: seq[DictionaryEntry], c: CritBitTree, i: LogEntry): (seq[DictionaryEntry], seq[DictionaryEntry]) =
  result[0] = @[]
  result[1] = @[]
  for a in p:
    let e = a.getEntry i
    case e.kind
    of knPrefix: result[0].add e
    of knEntry: result[1].add e
    of knNone: continue

proc initQueue*[T](initialSize=4): Queue[T] =
  ## creates a new queue. `initialSize` needs to be a power of 2.
  assert isPowerOfTwo(initialSize)
  result.mask = initialSize-1
  newSeq(result.data, initialSize)
proc initLogQueue*(): LogQueue =
  result.queue = initQueue[LogQueueGroup]()
proc initLogQueueGroup*(c: CritBitTree, p: seq[DictionaryEntry], i: LogEntry): LogQueueGroup =
  result = LogQueueGroup(time: i.time)
  (result.dictionaryPrefixes, result.dictionaryEntries) = updateGroups(p, c, i)
  let e = c.getEntry i
  case e.kind
  of knPrefix: result.dictionaryPrefixes.add e
  of knEntry: result.dictionaryEntries.add e
  of knNone: discard


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

const maxStrokes = 10
iterator getEntries*(): DictionaryOutput =
    var
      s = newFileStream(logPath)
      parser: BaseLexer
      inputs = initLogQueue()
    parser.open s
    for a in parser.parse:
      case a.kind
      of lAddition:
        inputs.addStroke(dictionaryTree, a)
        if inputs.queue.count >= maxStrokes:
          var 
            e = inputs.dequeue()
            result = DictionaryOutput(time: e.time, dictionaryEntries: e.dictionaryEntries)
          result.dictionaryEntries.add finishNodes(e.dictionaryPrefixes)
          yield result
      of lDeletion:
        discard inputs.removeStroke dictionaryTree
      else: break
