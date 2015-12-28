import times, sequtils, logparser, streams, lexbase
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
    queue: Queue[seq[LogEntry]]
    strokeCount: int

proc initQueue*[T](initialSize=4): Queue[T] =
  ## creates a new queue. `initialSize` needs to be a power of 2.
  assert isPowerOfTwo(initialSize)
  result.mask = initialSize-1
  newSeq(result.data, initialSize)
proc newLogQueue(): LogQueue =
  result.queue = initQueue[seq[LogEntry]]()
  result.strokeCount = 0

const maxStrokes = 20

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
proc add[T](q: var Queue[T], i: T) =
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
proc peak(q: var LogQueue): var seq[LogEntry] = q.queue.data[q.queue.rd]
proc addStroke(q: var LogQueue, i: LogEntry) =
  add(q.queue, @[i])
  inc q.strokeCount
proc continueStroke(q: var LogQueue, i: LogEntry) =
  q.peak.add i
  inc q.strokeCount
proc removeStroke(q: var LogQueue): LogEntry =
  if q.queue.count == 0: return
  var e = q.peak
  result = e[e.high]
  e.setLen e.high
  if q.queue.data[q.queue.wr].len == 0:
    discard q.queue.dequeue()
proc dequeue(q: var LogQueue): seq[LogEntry] =
  result = q.queue.dequeue
  dec q.strokeCount, result.len


# proc continue[T](q: var, i: T): LogEntry = 
#   q.strokes[q.strokes.high].add i
#   inc q.count
#   if q.count > maxStrokes:
#     discard

# proc quickPrint(q: LogQueue) =
#   for multiStrokeWord in q.queue:
#     var 
#       output = ""
#     for stroke in multiStrokeWord:
#       output.add stroke.stroke & "|" & stroke.translation
#     echo output


var
  s = newFileStream(logPath)
  parser: BaseLexer
  inputs = newLogQueue()
parser.open s
for a in parser.parse:
  echo ""
  case a.kind
  of lInitialStroke:
    inputs.addStroke a
  of lModification:
    inputs.continueStroke a
  of lDeletion:
    # echo inputs
    discard inputs.removeStroke
  else: break
  if inputs.strokeCount >= maxStrokes:
    echo inputs.dequeue
  # quickPrint inputs

