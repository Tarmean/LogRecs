import logparser, inlinejson,  Queue,  CritBits
from strutils import count
from lexbase import BaseLexer, open
from times import TimeInfo
from streams import newFileStream

type
  LogQueue = object
    queue: Queue[LogQueueGroup]
  PrefixKind = enum
    knPrefix, knEntry, knNone
  DictionaryEntry* = object     ## Shorter stroke that could replace a set of strokes
    originalStroke*: string     ## Set of strokes actually used
    translation*: string        ## Word or set of words that is soutput
    strokes*: int               ## Number of strokes wasted by using suboptimal stroke
    case kind: PrefixKind
    of knPrefix:
      node: Node[string]
    of knEntry:
      dictionaryStroke*: string ## Shortest equivalent set of strokes in the dictionary
    of knNone: discard
  LogQueueGroup = object
    strokes: int
    time: TimeInfo
    dictionaryPrefixes: seq[DictionaryEntry]
    dictionaryEntries: seq[DictionaryEntry]
  DictionaryOutput* = object ## Representation of set of entries
                             ## Contains a time stamp and all matching dictionary entries
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
  if not dictionaryTree.hasKey(translation) or (dictionaryTree[translation].count('/') > stroke.count('/')) or (dictionaryTree[translation].count('/') == stroke.count('/')  and dictionaryTree[translation].len > stroke.len):
    dictionaryTree[translation] = stroke

proc getNextNode[T](n: Node[T], key: string): Node[T] =
  result = n
  while result != nil and result.byte < key.len and not result.isLeaf:
    let 
     ch = key[result.byte]
     dir = (1 + (ch.ord or result.otherBits.ord)) shr 8
    result = result.child[dir]
proc initDictionaryEntry(n: Node[string], strokes: int, originalStroke, translation: string): DictionaryEntry =
  result = DictionaryEntry(
                           strokes:        strokes,
                           originalStroke: originalStroke,
                           translation:    translation
                          )
  let node = getNextNode(n, translation)
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

proc getEntry(p: DictionaryEntry, i: LogEntry): DictionaryEntry =
  let
    strokes = p.strokes + i.stroke.count('/') + 1
    originalStroke = p.originalStroke & " " & i.stroke
    translation = p.translation & i.translation
  result = initDictionaryEntry(p.node, strokes, originalStroke, translation)
proc getEntry(c: CritBitTree, i: LogEntry): DictionaryEntry =
  let
    strokes = i.stroke.count('/') + 1
  result = initDictionaryEntry(c.root, strokes, i.stroke, i.translation)
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
proc removeStroke*(q: var LogQueue, c: CritBitTree): LogQueueGroup =
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
