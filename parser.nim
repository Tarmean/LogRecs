import
  hashes, strutils, lexbase, streams, unicode, macros

type
  JsonEventKind* = enum  ## enumeration of all events that may occur when parsing
    jsonError,           ## an error occurred during parsing
    jsonEof,             ## end of file reached
    jsonString,          ## a string literal
    jsonInt,             ## an integer literal
    jsonFloat,           ## a float literal
    jsonTrue,            ## the value ``true``
    jsonFalse,           ## the value ``false``
    jsonNull,            ## the value ``null``
    jsonObjectStart,     ## start of an object: the ``{`` token
    jsonObjectEnd,       ## end of an object: the ``}`` token
    jsonArrayStart,      ## start of an array: the ``[`` token
    jsonArrayEnd         ## start of an array: the ``]`` token

  TokKind = enum         # must be synchronized with TJsonEventKind!
    tkError,
    tkEof,
    tkString,
    tkInt,
    tkFloat,
    tkTrue,
    tkFalse,
    tkNull,
    tkCurlyLe,
    tkCurlyRi,
    tkBracketLe,
    tkBracketRi,
    tkColon,
    tkComma

  JsonError* = enum        ## enumeration that lists all errors that can occur
    errNone,               ## no error
    errInvalidToken,       ## invalid token
    errStringExpected,     ## string expected
    errColonExpected,      ## ``:`` expected
    errCommaExpected,      ## ``,`` expected
    errBracketRiExpected,  ## ``]`` expected
    errCurlyRiExpected,    ## ``}`` expected
    errQuoteExpected,      ## ``"`` or ``'`` expected
    errEOC_Expected,       ## ``*/`` expected
    errEofExpected,        ## EOF expected
    errExprExpected        ## expr expected

  ParserState = enum
    stateEof, stateStart, stateObject, stateArray, stateExpectArrayComma,
    stateExpectObjectComma, stateExpectColon, stateExpectValue

  JsonParser* = object of BaseLexer ## the parser object.
    a: string
    tok: TokKind
    kind: JsonEventKind
    err: JsonError
    state: seq[ParserState]
    filename: string

type
  JsonNodeKind* = enum ## possible JSON node types
    JNull,
    JBool,
    JInt,
    JFloat,
    JString,
    JObject,
    JArray
  JsonNodeParent* = enum
    JPArray,
    JPObject


  JsonNode* = ref JsonNodeObj ## JSON node
  JsonNodeObj* {.acyclic.} = object
      case kind*: JsonNodeParent
      of JPArray:
        content*: string
      of JPObject:
        pair*: (string, string)


  JsonParsingError* = object of ValueError ## is raised for a JSON error

proc newJsonNode(s: string): JsonNode =
  new(result)
  result.kind = JPArray
  result.content = s

proc newJsonNode(p: (string, string)): JsonNode =
  new(result)
  result.kind = JPObject
  result.pair = p

iterator parse(p: var JsonParser): JsonNode =
  ## Parses JSON from a JSON Parser `p`.
  case p.tok
  of tkString:
    # we capture 'p.a' here, so we need to give it a fresh buffer afterwards:
    yield newJsonNode(p.a)
    p.a = ""
    discard getTok(p)
  of tkInt:
    yield newJsonNode(p.a)
    discard getTok(p)
  of tkFloat:
    yield newJsonNode(p.a)
    discard getTok(p)
  of tkTrue:
    result = newJsonNode(p.a)
    discard getTok(p)
  of tkFalse:
    result = newJsonNode(p.a)
    discard getTok(p)
  of tkNull:
    result = newJsonNode(p.a)
    discard getTok(p)
  of tkCurlyLe:
    discard getTok(p)
    while p.tok != tkCurlyRi:
      if p.tok != tkString:
        raiseParseErr(p, "string literal as key expected")
      var key = p.a
      discard getTok(p)
      eat(p, tkColon)
      var val = parseJson(p)

      if p.tok != tkComma: break
      discard getTok(p)
    eat(p, tkCurlyRi)
  of tkBracketLe:

    discard getTok(p)
    while p.tok != tkBracketRi:

      if p.tok != tkComma: break
      discard getTok(p)
    eat(p, tkBracketRi)
  of tkError, tkCurlyRi, tkBracketRi, tkColon, tkComma, tkEof:
    raiseParseErr(p, "{")
