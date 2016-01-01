import critbits, inlinejson
from times import TimeInfo
from strutils import count
from LogParser import LogEntry

type
  Node = critbits.Node[TreeEntry]
  DictionaryTree* = CritBitTree[TreeEntry]
  TreeEntry* = ref object # Entry in the critbit tree, maps from canonical translation to everything needed
    dictStrokes*: seq[string]
    bestStroke*: string
    bestStrokeCount: int
    originalTranslation*: string
    active*: bool
    usedStrokes*: ref seq[Stroke]
    wasted*: int
  Stroke* = object
    stroke*: string
    times*: seq[TimeInfo]
  DictionaryEntry = object
    originalStroke: string
    translation: string
    strokes: int
    node: Node
  DictionaryEntryGroup* = object
    time*: TimeInfo
    dictionaryPrefixes*: seq[DictionaryEntry]

iterator pairs*(t: DictionaryTree): (string,TreeEntry) =
  echo isNil t.root
  for a, b in critbits.pairs(t):
    yield (a,b)
proc initTreeEntry(originalTranslation: string): TreeEntry =
  result = TreeEntry(originalTranslation: originalTranslation)
  result.dictStrokes = @[]
proc initStroke(s: string, t: TimeInfo): Stroke =
  Stroke(stroke: s, times: @[t])

proc getTree*(dictPath: string =
                 when defined windows:
                   r"C:\Users\Cyril\AppData\Local\plover\plover\main.json"
                 else:
                   r"/home/cyril/.local/share/plover/dict.json"
            ): CritBitTree[TreeEntry]=

  result = CritBitTree[TreeEntry]()
  var
    dparser = parseFile(dictPath)
    rootObject = newJsonObject(dparser)
  for key, value in rootObject:
    let 
      (stroke, translation) = (key, value.content)
      canonicalizedTranslation = translation

    var entry: TreeEntry
    let
      newStrokeCount = stroke.count('/') + 1
    if result.hasKey(canonicalizedTranslation):
      entry = result[canonicalizedTranslation]
      let 
        oldStrokeCount =  entry.bestStrokeCount
        isStrokeBetter =  newStrokeCount < oldStrokeCount or
                          (
                            newStrokeCount == oldStrokeCount and
                            entry.bestStroke.len > stroke.len
                          )
      if isStrokeBetter:
        entry.bestStroke = stroke
        entry.bestStrokeCount = newStrokeCount
    else:
      entry = initTreeEntry(translation)
      result[canonicalizedTranslation] = entry
      entry.bestStroke = stroke
      entry.bestStrokeCount = newStrokeCount
    entry.dictStrokes.add stroke

proc addStroke(n: Node, wasted: int, originalStroke: string, t: TimeInfo) =
  inc n.val.wasted, wasted
  if not isNil n.val.usedStrokes:
    for stroke in n.val.usedStrokes[].mitems:
      if stroke.stroke == originalStroke:
        stroke.times.add t
        return
  else:
    n.val.usedStrokes = new seq[Stroke]
    n.val.active = true
    n.val.usedStrokes[] = @[]
  n.val.usedStrokes[].add initStroke(originalStroke, t)

proc getNextNode(entry: DictionaryEntry): Node =
  result = entry.node
  let key = entry.translation
  while result != nil and result.byte < key.len and not result.isLeaf:
    let 
     ch = key[result.byte]
     dir = (1 + (ch.ord or result.otherBits.ord)) shr 8
    result = result.child[dir]

proc addEntry(r: var seq[DictionaryEntry], d: DictionaryEntry, t: TimeInfo) =
  var 
     node = getNextNode(d)
     d = d
  if isNil node:
    discard
  elif node.isLeaf:
    let
      nodeStroke = node.val.bestStroke
      wasted = d.strokes - nodeStroke.count('/') - 1
    if node.key == d.translation and wasted > 0:
      node.addStroke wasted, d.originalStroke, t
  else:
    d.node = node
    r.add d

proc initDictionaryEntry(strokes: int, stroke, translation: string, node: Node): DictionaryEntry =
  DictionaryEntry(strokes: strokes, originalStroke: stroke, translation: translation, node: node)

proc getEntry*(d: DictionaryEntry, i: LogEntry): DictionaryEntry =
  let
    strokes = d.strokes + i.stroke.count('/') + 1
    translation = d.translation & " " & i.translation
    stroke = d.originalStroke & " " & i.stroke
    node = d.node
  initDictionaryEntry(strokes, stroke, translation, node)
proc getEntry*(n: Node, i: LogEntry): DictionaryEntry =
  let
    strokes = i.stroke.count('/') + 1
    translation = i.translation
    stroke = i.stroke
    node = n
  initDictionaryEntry(strokes, stroke, translation, node)


proc getNextGroup*(root: Node, p: seq[DictionaryEntry], i: LogEntry): DictionaryEntryGroup =
  result = DictionaryEntryGroup(time: i.time)
  result.dictionaryPrefixes = @[]
  for a in p:
    result.dictionaryPrefixes.addEntry a.getEntry(i), i.time
  result.dictionaryPrefixes.addEntry root.getEntry(i), i.time

proc finishNodes*(e: DictionaryEntryGroup) =
  for entry in e.dictionaryPrefixes:
    var it = entry.node
    while it != nil:
      if it.isLeaf:
        let 
          nodeStroke = it.val.bestStroke
          wasted = entry.strokes - nodeStroke.count('/') - 1
        if entry.translation == it.key and wasted > 0:
          it.addStroke wasted, entry.originalStroke, e.time
        break
      else:
        let dir = (('\0'.ord or it.otherBits.ord) + 1) shr 8
        it = it.child[dir]
