import ploverqueue, logparser
from dictionarytree import getTree
from strutils import repeat
from os import sleep

proc fseek(f: File, offset: clong, whence: int): int {.importc: "fseek", header: "<stdio.h>", tags: [].} 
proc allign(s: any, i: int, r=' '): string = $s & r.repeat(max(i - ($s).len, 0))

var
  tree  = getTree()
  queue = initLogQueue()
  file  = logPath.open()
  line  = ""

discard file.fseek(0, 2)
while true:
  if file.readLine line:
    let stroke = line.parse
    case stroke.kind
    of lAddition:
      var entry = queue.addStrokeStatic(tree, stroke)
      for f in entry.dictionaryEntries:
        if f.wasted > 0:
          echo f.wasted.allign 4, f.entry.originalTranslation.allign 20, f.entry.bestStroke
    of lDeletion: queue.removeStroke
    of lStroke, lError: discard
  else:
    sleep 100
file.close()
