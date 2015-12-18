import json, os, streams

let dictPath = r"C:\Users\Cyril\AppData\Local\plover\plover\main.json"
proc parse(path: string) =
    var stream = newFileStream(path, fmRead)
    if stream == nil:
      raise newException(IOError, "cannot read from file: " & path)

    var p: JsonParser
    p.open(stream, path)
    defer: p.close()
    p.next() #error->object start
    p.next() #object start-> string
    while p.kind != jsonObjectEnd and p.kind != jsonEOF:
      echo p.a
      echo str p
      p.next()
parse dictPath
