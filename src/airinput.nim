import cmd, logger, lock
import std/logging

# 主程序入口
when isMainModule:
  # 确保单实例运行
  if not ensureSingleInstance():
    quit(1)
  
  # 处理命令行参数
  let cmdResult = handleCmdLine()
  
  # 如果是守护进程模式，先守护进程化
  if cmdResult.daemonMode:
    if not daemonize():
      echo "守护进程化失败"
      quit(1)
  
  # 初始化日志
  initLogger(cmdResult.debugMode, cmdResult.daemonMode)
  
  # 主逻辑
  logging.info("程序已启动")
  logging.debug("调试模式已启用")
  
  # 测试信息流向日志
  logFlow("D", "手机端", "服务端", "收到文本消息")
  logFlow("D", "服务端", "PC", "发送消息")
  
  echo("Hello, World!")