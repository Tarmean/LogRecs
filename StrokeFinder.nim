import DictionaryTree, strutils, parseutils, sets, re

proc translateEntries(t: string): seq[string] =
  var 
    idx = 0
    token = ""
    res = ""
  result = @[]
  while true:
    inc idx, t.parseUntil(token, '{', idx) + 1
    res.add token
    if idx >= t.len: break

    inc idx, t.parseUntil(token, '}', idx) + 1
    res.add token
    if idx >= t.len: break

type
  states = enum
    stForceCap, stForceLower, stSupressSpace, stGlue
  State = set[states]

  TranslationState = object
    state: State
    translation: string
    suffix: string

proc b(t: string, i = 0): seq[TranslationState] =
  result = @[]
  if i >= t.len: return result
  var
    base = ""
    command = ""
    res = ""
    idx = i
  inc idx, t.parseUntil(base, '{', idx) + 1

  inc idx, t.parseUntil(command, '}', idx) + 1
  if command.len > 0:
    if false: discard
    else: result.add (base &'{' & command & '}' & b(t, idx))

  


let 
  prefix  = re"^{\^\w*}$"
  postfix = re"^{\w*\^}$"
  glue = re"^{&\w}$"
  t = r"aaa{a}aa{-|}l"
  q = r"{^ly}"
if t =~ prefix: echo "1"
if q =~ prefix: echo "2"


