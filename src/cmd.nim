import parseopt

# 处理命令行参数
proc handleCmdLine*() =
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
    of cmdShortOption, cmdArgument:
      discard
  
  if showVersion:
    echo "AirInput version ", NimblePkgVersion
    quit(0)
  
  if showHelp:
    echo helpText
    quit(0)