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
    dictionaryPrefixes*: seq[(string, CritBits.Node[string])]
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

proc getNextNode[T](n: Node[T], key: string): Node[T] =
  result = n
  while result != nil and result.byte < key.len and not result.isLeaf:
    let 
     ch = key[result.byte]
     dir = (1 + (ch.ord or result.otherBits.ord)) shr 8
    result = result.child[dir]
proc finishNodes[T](stroke: string, e: seq[(string, Node[T])]): seq[(string, string)] =
  result = @[]
  for entry in e:
    var (key, it) = entry
    while it != nil:
      if it.isLeaf:
        # echo "check: ", key, " ", it.key
        if key == it.key and stroke != it.val:
          result.add((it.val, it.key))
        break
      else:
        let dir = (('\0'.ord or it.otherBits.ord) + 1) shr 8
        it = it.child[dir]
proc updateGroups(post: string, stroke: string, p: seq[(string, Node[string])]): (seq[(string, string)], seq[(string, Node[string])]) =
  result[0] = @[]
  result[1] = @[]
  for a in p:
    let 
      (startKey, startNode) = a
      searchKey = if startKey != nil: startKey & " " & post else: post
      node = getNextNode(startNode,  searchKey)
    if node.isLeaf:
      if node.key == post and stroke != node.val:
        result[0].add((node.val, node.key))
    else:
      result[1].add((searchKey, node))

proc initQueue*[T](initialSize=4): Queue[T] =
  ## creates a new queue. `initialSize` needs to be a power of 2.
  assert isPowerOfTwo(initialSize)
  result.mask = initialSize-1
  newSeq(result.data, initialSize)
proc initLogQueue*(): LogQueue =
  result.queue = initQueue[LogQueueGroup]()
  result.strokeCount = 0
proc initLogQueueGroup*(c: CritBitTree, p: seq[(string, Node[string])], i: LogEntry): LogQueueGroup =
  result = LogQueueGroup()
  result.entries = @[i]
  var p = p
  p.add((nil, c.root))
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
    # var i = 0
    # for entry in q.queue:
    #     let 
    #      a = entry.entries[entry.entries.high]
    #      b = q.queue.data[i].entries[q.queue.data[i].entries.high]
    #     echo i, ":   ", a.translation, " ", a.stroke, "  |  ", b.translation ,b.stroke
    #     inc i
    # echo ""

proc peak*(q: var LogQueue): var LogQueueGroup =
    let i = (q.queue.wr - 1 + q.queue.mask ) mod q.queue.mask
    q.queue.data[i]
proc dequeue*(q: var LogQueue): LogQueueGroup =
  result = q.queue.dequeue()
  dec q.strokeCount, result.entries.len
proc addStroke*(q: var LogQueue, c: CritBitTree[string], i: LogEntry) =
  var 
    entry: LogQueueGroup
    prefixes = if q.queue.count > 0:
                 q.peak.dictionaryPrefixes
               else:
                 @[]

  entry = initLogQueueGroup(c, prefixes, i)

  add(q.queue, entry)
  inc q.strokeCount
proc continueStroke*(q: var LogQueue, i: LogEntry, c: CritBitTree) =
  q.peak.entries.add i
  # let i = (q.queue.wr - 2 + q.queue.mask ) mod q.queue.mask
  #     prevs = q.queue.data[i]
  # echo "cont", q.peak.entries
  inc q.strokeCount
  
  var lastPrefixes: seq[(string, Node[string])]
  if q.queue.count > 1:
    lastPrefixes = q.queue.data[(q.queue.wr - 1 + q.queue.mask) mod q.queue.mask].dictionaryPrefixes
  else:
    lastPrefixes = @[]
  lastPrefixes.add ((nil, c.root))
  (q.peak.dictionaryEntries,q.peak.dictionaryPrefixes) = updateGroups(i.translation, i.stroke, lastPrefixes)
proc removeStroke*(q: var LogQueue, c: CritBitTree): LogEntry =
  if q.strokeCount == 0: return
  var e:  seq[LogEntry]
  e.shallowCopy q.peak.entries
  result = e[e.high]
  dec q.strokeCount
  e.setLen e.high
  if e.len == 0:
    dec q.queue.count
    q.queue.wr = (q.queue.wr - 1 + q.queue.mask) mod q.queue.mask
  else:
    var lastPrefixes: seq[(string, Node[string])]
    if q.queue.count > 1:
      lastPrefixes = q.queue.data[(q.queue.wr - 1 + q.queue.mask) mod q.queue.mask].dictionaryPrefixes
    else:
      lastPrefixes = @[]
    lastPrefixes.add ((nil, c.root))
    (q.peak.dictionaryEntries, q.peak.dictionaryPrefixes) = updateGroups(result.translation,  result.stroke, lastPrefixes)


iterator getEntries*(): LogQueueGroup =
    var
      s = newFileStream(logPath)
      parser: BaseLexer
      inputs = initLogQueue()
      i = 0
    parser.open s
    for a in parser.parse:
      case a.kind
      of lInitialStroke:
        inputs.addStroke(dictionaryTree, a)

        if inputs.strokeCount >= maxStrokes:
          var 
            bla = inputs.dequeue()
          if bla.dictionaryEntries.len > 0:
            let entry = bla.entries[bla.entries.high]
            bla.dictionaryEntries.add finishNodes(entry.stroke, bla.dictionaryPrefixes)
            if bla.entries.len > 0:
              var printed = false
              for e in bla.dictionaryEntries:
                let (dictStroke, dictTranslation) = e
                if entry.translation != dictTranslation:
                  if not printed:
                    echo entry.stroke, " ", entry.translation, " ", entry.time.format("yyyy-MM-dd HH:mm:ss")
                    printed = true
                  echo "    ",  dictTranslation, "  |  ", entry.stroke, "->", dictStroke
              if printed: echo ""
            else:
              echo repr bla
          yield bla
      of lModification:
        inputs.continueStroke a, dictionaryTree
      of lDeletion:
        discard inputs.removeStroke dictionaryTree
      else: break

      if a.kind != lDeletion:
        echo a.kind, " ", a.stroke, " ", a.translation, " ", a.time.format("yyyy-MM-dd HH:mm:ss")
      else: echo  a.kind, " ", a.time
      printQueue inputs
      echo "in logical order: ", inputs.strokeCount
      for entry in inputs.queue:
          echo " ", entry.entries, " ", entry.dictionaryPrefixes.len, " ", entry.dictionaryEntries.len
          for match in entry.dictionaryEntries:
              let (stroke, translation) = match
              echo "      ", stroke, " ",  translation
      
      echo ""
      inc i
      if i > 30: break
      
      
      # echo "in memory order:"
      # echo  " count", inputs.queue.count, " cap", inputs.queue.cap,  " mask", inputs.queue.mask, " rd", inputs.queue.rd, " wr", inputs.queue.wr
      # for j in 0..inputs.queue.mask:
      #     if inputs.queue.data[j] != nil:
      #         echo " ",inputs.queue.data[j].entries
      #     else:
      #         echo " nil"

        # let 
        #  entry = bla.entries[bla.entries.high]
        #  (logstroke, logtranslation) = (entry.stroke, entry.translation)
        # var printed = false
        # for entry in bla.dictionaryEntries:
        #   let (stroke, translation) = entry
        #   if logstroke.count('/') > stroke.count('/'):
        #     if not printed:
        #       echo logstroke, " ", logtranslation
        #       echo bla.entries
        #       printed = true
        #     echo "    ", stroke, " ", translation
