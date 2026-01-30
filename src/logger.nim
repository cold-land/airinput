import std/logging

# 初始化日志系统
proc initLogger*(debugMode: bool = true) =
  var consoleLogger = newConsoleLogger(fmtStr = "[$time] $levelname: ")
  addHandler(consoleLogger)
  
  if debugMode:
    setLogFilter(lvlDebug)
  else:
    setLogFilter(lvlInfo)