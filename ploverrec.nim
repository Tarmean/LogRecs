{.experimental.}
import tables, os, json
import algorithm, future
import queues
from strutils import spaces
from streams import FileStream, newFileStream, readLine

type
  Stroke = string
  Translation = string

  LogType = enum
    Input, Deletion, Output

  LogEntry = object
    stroke: string
    case kind: LogType
        of Deletion, Output: translation: string
        of Input: discard

  LogQueue = ref Queue[LogEntry]

  StrokeUsageCounter = ref object
    counter: CountTableRef[Stroke]
    totalCount: int
  TranslationTracker = TableRef[Translation, StrokeUsageCounter]
  TranslationList = ref seq[(Translation, StrokeUsageCounter)]



var
  logPath = expandFilename "C:\\Users/Cyril/appdata/local/plover/plover/plover.log"

proc newStrokeUsageCounter(): StrokeUsageCounter =
  result = StrokeUsageCounter()
  result.counter = newCountTable[Stroke]()
  result.totalCount = 0

proc newTranslationTracker(): TranslationTracker =
  newTable[Translation, StrokeUsageCounter]

proc newTranslationList(): TranslationList =
  newSeq[(Translation, StrokeUsageCounter)]


proc parseLogLine(line: var string): (bool, Stroke, Translation) =
  # skip date and time stamp
  let entryType = line[24]
  # if the entry isn't a Translation it can be skipped
  if entryType != 'T':
    return (false, "", "")
  
  # stroke is delimited by a pair of 's, seek the second one
  var 
    index, skip, currentStart: int
    stroke = ""
    mult = false
  if line[37] == 'u':
    skip = 4
    index = 39
    currentStart = 39
  else:
    skip = 3
    index = 38
    currentStart = 38

  while index < line.len and line[index] != ':':
    inc index
    if line[index] == ',':
      if stroke.len > 0:
        mult = true
      stroke.add(line[currentStart..index-2] & "/")
      currentStart = index + skip
      inc index
  stroke = stroke[0..<stroke.len-1]
  # if mult:
  #   echo stroke, "    ", line[index+2..<line.len-1]

  # the translation starts 6 characters after the closing 1 and ends 1 character before the end of the line
  return (true, stroke, line[index+2..<line.len-1])

proc update(tracker: var TranslationTracker, stroke: Stroke, translation: Translation) =
  if not tracker.hasKey translation:
    var counter =  newStrokeUsageCounter()
    tracker.add(translation, counter)

  inc tracker[translation].totalCount
  inc tracker[translation].counter, stroke
    
proc parseLogFile(stream: FileStream): TranslationTracker =
  result = newTranslationTracker()

  var line = newString 0
  while stream.readLine line:
    let (success, stroke, translation) =  parseLogLine line
    if success:
      result.update(stroke, translation)

proc toSortedSeq(table: TranslationTracker): TranslationList =
  result = newTranslationList()
  for translation, strokeUsageCounter in table:
    strokeUsageCounter.counter.sort
    result.add((translation, strokeUsageCounter))

  result.sort((x,y) => cmp(x[1].totalCount, y[1].totalCount), Descending)

    
proc echoPretty(translationTracker: TranslationTracker) =
  let sorted = toSortedSeq translationTracker
  var i = 0
  for entry in sorted:
    let 
      (translation, strokeUsage) = entry
      totalCount = $strokeUsage.totalCount
    echo totalCount, spaces(max(0, 7 - totalCount.len)), translation
    echo ""
    for stroke, count in strokeUsage.counter:
      let scount = $count
      echo scount, spaces(max(0, 7 - scount.len)), stroke
    inc i
    if i > 1000:
      break
    echo "\n--------------"

proc process(path: string) =
  var stream = newFileStream(path, fmRead)
  if stream == nil:
    raise newException(IOError, "cannot read from file: " & path) 

  var translationTracker = parseLogFile(stream)
  echoPretty translationTracker


process logPath


