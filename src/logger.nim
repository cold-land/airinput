import std/logging, std/times, std/strformat

# 初始化日志系统
proc initLogger*(debugMode: bool = false) =
  var consoleLogger = newConsoleLogger(fmtStr = "[$time:$levelid]")
  addHandler(consoleLogger)
  
  if debugMode:
    setLogFilter(lvlDebug)
  else:
    setLogFilter(lvlInfo)

# 信息流向日志
# 格式: [时间:级别][来源]→[目标]内容
proc logFlow*(level: string, source: string, target: string, content: string) =
  let timeStr = now().format("HH:mm:ss")
  echo &"[{timeStr}:{level}][{source}]→[{target}]{content}"