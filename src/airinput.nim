import cmd, logger
import std/logging

# 主程序入口
when isMainModule:
  # 处理命令行参数
  handleCmdLine()
  
  # 初始化日志
  initLogger()
  
  # 主逻辑
  logging.debug ("程序已启动")
  echo("Hello, World!")