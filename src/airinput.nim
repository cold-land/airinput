import cmd, logger, lock, server
import std/logging

# 主程序入口
when isMainModule:
  # 处理命令行参数
  let cmdResult = handleCmdLine()
  
  # 如果是守护进程模式，先守护进程化
  if cmdResult.daemonMode:
    if not daemonize():
      echo "守护进程化失败"
      quit(1)
  
  # 初始化日志
  initLogger(cmdResult.debugMode, cmdResult.daemonMode)
  
  # 确保单实例运行
  if not ensureSingleInstance():
    quit(1)
  
  # 主逻辑
  logging.info("程序已启动")
  logging.debug("调试模式已启用")
  
  # 启动 WebSocket 服务器
  startServer()