import pythonpathlib, parsecfg, streams

proc printf(formatstr: cstring) {.header: "<stdio.h>", importc: "printf", varargs.}
proc getenv(name: cstring): cstring {.header: "<stdio.h>", importc: "getenv", varargs.}
{.experimental.}
# proc getConfig() =
# proc readConfig() =
#   var
#     base = Path($getenv("HOME"))
#     configPath = when defined windows:
#                   base / "AppData" / "Local" / "plover" / "plover" / "plover.cfg"
#                 elif defined mac:
#                   base / "Library" / "Application Support" / "plover" / "plover.cfg"
#                 else:
#                   base / ".config" / "plover" / "plover.cfg"
#   echo base
#   echo configPath
#   var
#     path = configPath.asPosix
#     f = path.newFileStream fmRead
#   echo path
#   if f != nil:
#     var p: CfgParser
#     open(p, f, path)
#     while true:
#       var e = next(p)
#       case e.kind
#       of cfgEof:
#         echo("EOF!")
#         break
#       of cfgSectionStart:   ## a ``[section]`` has been parsed
#         echo("new section: " & e.section)
#       of cfgKeyValuePair:
#         echo("key-value-pair: " & e.key & ": " & e.value)
#       of cfgOption:
#         echo("command: " & e.key & ": " & e.value)
#       of cfgError:
#         echo(e.msg)
#     close(p)
#   else:
#     echo("cannot open: " & path)


# readConfig()
