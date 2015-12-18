import
  hashes, strutils, lexbase, streams, unicode, macros, tables

type
  JsonElementKind = enum
    jsonValue, jsonObject, jsonArray
  JsonContainerLazy = enum
    lazyLoaded, eagerLoaded
  JsonElement = object
    case kind: JsonElementKind
    of jsonValue: content: string
    of jsonObject, jsonArray:
      case lazy: bool
      of true:
        offset: int
        parser: ref JsonParser
      of false: discard

  ParserState = enum
    stateEof, stateStart, stateObject, stateArray, stateExpectArrayComma,
    stateExpectObjectComma, stateExpectColon, stateExpectValue

  TokKind = enum
    tkError,
    tkEof,
    tkValue,
    tkCurlyLe,
    tkCurlyRi,
    tkBracketLe,
    tkBracketRi,
    tkColon,
    tkComma

  JsonParser* = object of BaseLexer ## the parser object.
    a: string
    tok: TokKind
    kind: JsonElementKind
    state: seq[ParserState]
    filename: string

proc newJsonValue(value: string): JsonElement =
  result = JsonElement()
  result.kind = jsonValue
  result.content = value

proc newJsonObject(parser: ref JsonParser): JsonElement =
  result = JsonElement()
  result.kind = jsonObject
  result.lazy = true
  result.parser = parser
  result.offset = parser.bufpos

proc skip(my: var JsonParser) =
  var pos = my.bufpos
  var buf = my.buf
  while true:
    case buf[pos]
    of '/':
      if buf[pos+1] == '/':
        # skip line comment:
        inc(pos, 2)
        while true:
          case buf[pos]
          of '\0':
            break
          of '\c':
            pos = lexbase.handleCR(my, pos)
            buf = my.buf
            break
          of '\L':
            pos = lexbase.handleLF(my, pos)
            buf = my.buf
            break
          else:
            inc(pos)
      elif buf[pos+1] == '*':
        # skip long comment:
        inc(pos, 2)
        while true:
          case buf[pos]
          of '\0':
            # my.err = errEOC_Expected
            break
          of '\c':
            pos = lexbase.handleCR(my, pos)
            buf = my.buf
          of '\L':
            pos = lexbase.handleLF(my, pos)
            buf = my.buf
          of '*':
            inc(pos)
            if buf[pos] == '/':
              inc(pos)
              break
          else:
            inc(pos)
      else:
        break
    of ' ', '\t':
      inc(pos)
    of '\c':
      pos = lexbase.handleCR(my, pos)
      buf = my.buf
    of '\L':
      pos = lexbase.handleLF(my, pos)
      buf = my.buf
    else:
      break
  my.bufpos = pos

proc parseValue(my: var JsonParser): TokKind =
  result = tkValue
  var pos = my.bufpos + 1
  var buf = my.buf
  while true:
    if buf[pos] in {'0'..'9'}:
      add(my.a, buf[pos])
      inc(pos)
    else:
      break
  my.bufpos = pos # store back

proc handleHexChar(c: char, x: var int): bool =
  result = true # Success
  case c
  of '0'..'9': x = (x shl 4) or (ord(c) - ord('0'))
  of 'a'..'f': x = (x shl 4) or (ord(c) - ord('a') + 10)
  of 'A'..'F': x = (x shl 4) or (ord(c) - ord('A') + 10)
  else: result = false # error

proc parseEscapedUTF16(buf: cstring, pos: var int): int =
  result = 0
  #UTF-16 escape is always 4 bytes.
  for _ in 0..3:
    if handleHexChar(buf[pos], result):
      inc(pos)
    else:
      return -1

proc parseString(my: var JsonParser): TokKind =
  result = tkValue
  var pos = my.bufpos + 1
  var buf = my.buf
  while true:
     case buf[pos]
    # of '\0':
    #   # my.err = errQuoteExpected
    #   result = tkError
    #   break
     of '"':
       inc(pos)
       break
     of '\\':
      case buf[pos+1]
      of '\\', '"', '\'', '/':
        add(my.a, buf[pos+1])
        inc(pos, 2)
      of 'b':
        add(my.a, '\b')
        inc(pos, 2)
      of 'f':
        add(my.a, '\f')
        inc(pos, 2)
      of 'n':
        add(my.a, '\L')
        inc(pos, 2)
      of 'r':
        add(my.a, '\C')
        inc(pos, 2)
      of 't':
        add(my.a, '\t')
        inc(pos, 2)
      of 'u':
        inc(pos, 2)
        var r = parseEscapedUTF16(buf, pos)
        if r < 0:
          # my.err = errInvalidToken
          break
        # Deal with surrogates
        if (r and 0xfc00) == 0xd800:
          if buf[pos] & buf[pos+1] != "\\u":
            # my.err = errInvalidToken
            break
          inc(pos, 2)
          var s = parseEscapedUTF16(buf, pos)
          if (s and 0xfc00) == 0xdc00 and s > 0:
            r = 0x10000 + (((r - 0xd800) shl 10) or (s - 0xdc00))
          else:
            # my.err = errInvalidToken
            break
        add(my.a, toUTF8(Rune(r)))
      else:
        # don't bother with the error
        add(my.a, buf[pos])
        inc(pos)
    # of '\c':
    #   pos = lexbase.handleCR(my, pos)
    #   buf = my.buf
    #   add(my.a, '\c')
    # of '\L':
    #   pos = lexbase.handleLF(my, pos)
    #   buf = my.buf
    #   add(my.a, '\L')
     else:
       add(my.a, buf[pos])
       inc(pos)
  my.bufpos = pos # store back


proc getTok(my: var JsonParser): TokKind =
  setLen(my.a, 0)
  skip(my) # skip whitespace, comments
  case my.buf[my.bufpos]
  of '-', '.', '0'..'9':
    result = parseValue(my)
    # if {'.', 'e', 'E'} in my.a:
    #    result = tkFloat
    # else:
    #    result = tkInt
  of '"':
    result = parseString(my)
  of '[':
    inc(my.bufpos)
    result = tkBracketLe
  of '{':
    inc(my.bufpos)
    result = tkCurlyLe
  of ']':
    inc(my.bufpos)
    result = tkBracketRi
  of '}':
    inc(my.bufpos)
    result = tkCurlyRi
  of ',':
    inc(my.bufpos)
    result = tkComma
  of ':':
    inc(my.bufpos)
    result = tkColon
  of '\0':
    result = tkEof
  of 'a'..'z', 'A'..'Z', '_':
    result = parseValue(my)
    # case my.a
    # of "null": result = tkNull
    # of "true": result = tkTrue
    # of "false": result = tkFalse
    # else: result = tkError
  else:
    inc(my.bufpos)
    result = tkError
  my.tok = result
 
iterator pairs(element: JsonElement): (string, JsonElement) =
  let parser = element.parser
  if element.kind == jsonObject:
    var 
      key = ""
      node: JsonElement
    while true:
      var tk = parser[].getTok()
      case tk
      of tkValue:
        key=  parser.a
      else:
        break

      tk = parser[].getTok()
      if tk != tkColon:
        break

      tk = parser[].getTok()
      case tk
      of tkValue:
        node = newJsonValue(parser.a)
        yield (key, node)
      of tkCurlyLe:
        discard
      of tkBracketLe:
        discard
      else:
        break

      tk = parser[].getTok()
      case tk
      of tkComma:
        discard
      else:
        break

       


proc open*(my: var JsonParser, input: Stream, filename: string) =
  ## initializes the parser with an input stream. `Filename` is only used
  ## for nice error messages.
  lexbase.open(my, input)
  my.filename = filename
  my.state = @[stateStart]
  my.kind = jsonValue
  my.a = ""

proc close*(my: var JsonParser) {.inline.} =
  ## closes the parser `my` and its associated input stream.
  lexbase.close(my)

proc parseJson(filestream: Stream, filename: string): ref JsonParser =
  result = new JsonParser
  result[].open(filestream, filename)
  discard getTok(result[]) # read first token

proc parseFile*(filename: string):  ref JsonParser =
  ## Parses `file` into a `JsonNode`.
  var stream = newFileStream(filename, fmRead)
  if stream == nil:
    raise newException(IOError, "cannot read from file: " & filename)
  result = parseJson(stream, filename)

var 
  parser = parseFile(r"C:\Users\Cyril\AppData\Local\plover\plover\main.json")
  rootObject = newJsonObject(parser)
  table = newTable[string, string]()

# echo repr rootObject
for key, value in rootObject:
  table[value.content] = key
  
echo table["sun"]

