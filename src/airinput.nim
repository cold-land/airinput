import cmd, logger, lock, server, config as cfg, network
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
  
  # 加载配置文件（静默加载默认配置）
  let appConfig = if cmdResult.configFile != "":
                     loadConfiguration(cmdResult.configFile)
                   else:
                     loadConfiguration("")
  
  # 检查配置文件（如果需要）
  if cmdResult.checkConfig:
    let validation = validateConfig(appConfig)
    if validation.valid:
      echo "配置文件验证通过"
      quit(0)
    else:
      echo "配置文件验证失败："
      for error in validation.errors:
        echo "  - " & error
      quit(1)
  
  # 显示配置（如果需要）
  if cmdResult.showConfig:
    displayConfig(appConfig)
    quit(0)
  
  # 初始化日志系统
  initLogger(cmdResult.debugMode, cmdResult.daemonMode, appConfig.logging)
  
  # 确保单实例运行
  if not ensureSingleInstance():
    quit(1)
  
  # 网络配置检查
  let networkInterface = resolveNetworkConfiguration(cmdResult.daemonMode, appConfig)
  
  # 主逻辑
  logging.info("程序已启动")
  logging.debug("调试模式已启用")
  
  # 启动 WebSocket 服务器
  startServer(networkInterface, appConfig.server)