import std/parseopt
import config
import network

# 命令行参数结果
type
  CmdResult* = ref object
    debugMode*: bool
    daemonMode*: bool
    configFile*: string
    generateConfig*: string
    checkConfig*: bool
    showConfig*: bool
    listInterfaces*: bool

# 处理命令行参数
proc handleCmdLine*(): CmdResult =
  result = CmdResult(
    debugMode: false,
    daemonMode: false,
    configFile: "",
    generateConfig: "",
    checkConfig: false,
    showConfig: false,
    listInterfaces: false
  )
  
  # 使用 staticRead 在编译时读取帮助文件
  const helpText = staticRead("../resources/HELP.txt")
  
  # Nim 官方标准做法：Nimble 自动注入版本号
  const NimblePkgVersion {.strdefine.} = "Unknown"
  
  var
    showVersion = false
    showHelp = false
  
  for kind, key, val in getopt():
    case kind
    of cmdEnd: break
    of cmdLongOption:
      if key == "version":
        showVersion = true
      elif key == "help":
        showHelp = true
      elif key == "debug":
        result.debugMode = true
      elif key == "config":
        result.configFile = val
      elif key == "generate-config":
        result.generateConfig = if val != "": val else: "airinput.conf"
      elif key == "check-config":
        result.checkConfig = true
      elif key == "show-config":
        result.showConfig = true
      elif key == "list-interfaces":
        result.listInterfaces = true
    of cmdShortOption:
      if key == "D":
        result.daemonMode = true
    of cmdArgument:
      discard
  
  if showVersion:
    echo "AirInput version ", NimblePkgVersion
    quit(0)
  
  if showHelp:
    echo helpText
    quit(0)
  
  # 处理特殊命令
  if result.generateConfig != "":
    if generateDefaultConfig(result.generateConfig):
      quit(0)
    else:
      quit(1)
  
  if result.listInterfaces:
    let interfaces = getNetworkInterfaces()
    let filteredInterfaces = filterInterfaces(interfaces)
    displayNetworkInterfaces(filteredInterfaces)
    quit(0)