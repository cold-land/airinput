import std/logging, std/times, std/strformat, std/os
import config

# 获取跨平台日志目录
proc getLogDir(): string =
  when defined(windows):
    result = getEnv("LOCALAPPDATA", getEnv("APPDATA"))
    result = result / "airinput" / "logs"
  elif defined(macosx):
    result = getHomeDir() / "Library" / "Logs" / "airinput"
  else:
    result = getHomeDir() / ".local" / "share" / "airinput" / "logs"
  
  createDir(result)

# 初始化日志系统
proc initLogger*(debugMode: bool = false, daemonMode: bool = false, loggingConfig: LoggingConfig = nil) =
  let useConfig = loggingConfig != nil
  
  if daemonMode:
    # 守护进程模式：日志写入文件
    let logFile = if useConfig and loggingConfig.logFile != "": 
                     loggingConfig.logFile 
                   else: 
                     getLogDir() / "airinput.log"
    
    var fileLogger = newFileLogger(
      logFile,
      fmtStr = "[$datetime:$levelid]",
      levelThreshold = if debugMode or (useConfig and loggingConfig.logLevel == "debug"): lvlDebug 
                      elif useConfig and loggingConfig.logLevel == "warn": lvlWarn
                      elif useConfig and loggingConfig.logLevel == "error": lvlError
                      else: lvlInfo
    )
    addHandler(fileLogger)
  else:
    # 前端模式：日志输出到控制台
    var consoleLogger = newConsoleLogger(fmtStr = "[$datetime:$levelid]")
    addHandler(consoleLogger)
  
  let logLevel = if debugMode: lvlDebug
                elif useConfig:
                  case loggingConfig.logLevel:
                  of "debug": lvlDebug
                  of "warn": lvlWarn
                  of "error": lvlError
                  else: lvlInfo
                else: lvlInfo
  
  setLogFilter(logLevel)

# 信息流向日志
# 格式: [日期T时间:级别][来源]→[目标]内容
proc logFlow*(level: string, source: string, target: string, content: string) =
  let timeStr = now().format("yyyy-MM-dd'T'HH:mm:ss")
  let logLine = &"[{timeStr}:{level}][{source}]→[{target}]{content}"
  
  # 根据级别选择 logging 模块的日志级别
  let logLevel = case level
    of "D": lvlDebug
    of "I": lvlInfo
    of "W": lvlWarn
    of "E": lvlError
    else: lvlInfo
  
  logging.log(logLevel, logLine)