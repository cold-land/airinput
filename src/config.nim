import std/os, std/times, std/strutils, std/net, std/json

# ========================================
# 配置文件模块
# ========================================

type
  NetworkConfig* = ref object
    bindAddress*: string
    bindPort*: int
    bindAll*: bool

  ServerConfig* = ref object
    maxConnections*: int
    timeout*: int
    bindPort*: int

  LoggingConfig* = ref object
    logLevel*: string
    logFile*: string

  AirInputConfig* = ref object
    network*: NetworkConfig
    server*: ServerConfig
    logging*: LoggingConfig
    configFile*: string

# 查找配置文件
proc findConfigFile(): string =
  # 1. 当前目录
  if fileExists("airinput.conf"):
    return "airinput.conf"
  
  # 2. 用户配置目录
  when defined(linux):
    let userConfig = getHomeDir() / ".config/airinput/airinput.conf"
  elif defined(macosx):
    let userConfig = getHomeDir() / "Library/Preferences/airinput/airinput.conf"
  else: # Windows
    let userConfig = getEnv("APPDATA", "") / "airinput/airinput.conf"
  
  if fileExists(userConfig):
    return userConfig
  
  # 3. 系统配置目录
  when defined(linux):
    let systemConfig = "/etc/airinput/airinput.conf"
  elif defined(macosx):
    let systemConfig = "/Library/Preferences/airinput/airinput.conf"
  else: # Windows
    let systemConfig = getEnv("PROGRAMDATA", "") / "airinput/airinput.conf"
  
  if fileExists(systemConfig):
    return systemConfig
  
  return ""

# 获取默认配置
proc getDefaultConfig*(): AirInputConfig =
  let now = now().format("yyyy-mm-dd")
  
  result = AirInputConfig(
    network: NetworkConfig(
      bindAddress: "",
      bindPort: 5001,
      bindAll: true
    ),
    server: ServerConfig(
      maxConnections: 100,
      timeout: 30000,
      bindPort: 5001
    ),
    logging: LoggingConfig(
      logLevel: "info",
      logFile: "/var/log/airinput.log"
    ),
    configFile: ""
  )

# 生成默认配置文件内容
proc generateDefaultConfigContent*(): string =
  result = """
# AirInput 配置文件

[network]
bind_address = ""
bind_all = true

[server]
bind_port = 5001
max_connections = 100
timeout = 30000

[logging]
log_level = info
log_file = /var/log/airinput.log
"""

# 生成默认配置文件
proc generateDefaultConfig*(outputPath: string): bool =
  try:
    let dir = parentDir(outputPath)
    if dir != "" and not dirExists(dir):
      createDir(dir)
    
    let content = generateDefaultConfigContent()
    writeFile(outputPath, content)
    echo "默认配置文件已生成: " & outputPath
    return true
  except CatchableError as e:
    echo "生成配置文件失败: " & e.msg
    return false

# 简化配置文件解析（键值对格式）
proc parseConfigFile*(configPath: string): AirInputConfig =
  if not fileExists(configPath):
    return getDefaultConfig()
  
  try:
    result = getDefaultConfig()
    result.configFile = configPath
    
    let lines = readFile(configPath).splitLines()
    var currentSection = ""
    
    for line in lines:
      let trimmed = line.strip()
      if trimmed == "" or trimmed.startsWith("#"):
        continue
      
      if trimmed.startsWith("[") and trimmed.endswith("]"):
        currentSection = trimmed[1..^2]
        continue
      
      if "=" in trimmed:
        let parts = trimmed.split("=", 1)
        if parts.len == 2:
          let key = parts[0].strip()
          let value = parts[1].strip()
          
          case currentSection:
          of "network":
            if key == "bind_address":
              result.network.bindAddress = value
            elif key == "bind_all":
              result.network.bindAll = parseBool(value)
          of "server":
            if key == "max_connections":
              result.server.maxConnections = parseInt(value)
            elif key == "timeout":
              result.server.timeout = parseInt(value)
            elif key == "bind_port":
              result.server.bindPort = parseInt(value)
          of "logging":
            if key == "log_level":
              result.logging.logLevel = value.replace("\"", "")
            elif key == "log_file":
              result.logging.logFile = value.replace("\"", "")
    
  except CatchableError as e:
    return getDefaultConfig()

# 加载配置文件
proc loadConfiguration*(configPath: string = ""): AirInputConfig =
  if configPath != "":
    # 显式指定的配置文件
    if not fileExists(configPath):
      return getDefaultConfig()
    return parseConfigFile(configPath)
  else:
    # 自动查找配置文件（静默）
    let actualConfigPath = findConfigFile()
    if actualConfigPath == "":
      return getDefaultConfig()
    return parseConfigFile(actualConfigPath)

# 验证配置文件
proc validateConfig*(config: AirInputConfig): tuple[valid: bool, errors: seq[string]] =
  result.valid = true
  result.errors = @[]
  
  # 验证端口范围
  if config.network.bindPort < 1 or config.network.bindPort > 65535:
    result.valid = false
    result.errors.add("端口号必须在 1-65535 范围内")
  
  # 验证端口范围
  if config.network.bindPort < 5000 or config.network.bindPort > 5100:
    result.errors.add("建议使用 5001-5100 范围的端口")
  
  # 验证最大连接数
  if config.server.maxConnections < 1:
    result.valid = false
    result.errors.add("最大连接数必须大于 0")
  
  # 验证超时时间
  if config.server.timeout < 1000:
    result.errors.add("超时时间建议不少于 1000 毫秒")
  
  # 验证日志级别
  let validLogLevels = @["debug", "info", "warn", "error"]
  if config.logging.logLevel notin validLogLevels:
    result.valid = false
    result.errors.add("日志级别必须是: debug, info, warn, error 之一")
  
  # 验证绑定地址
  if not config.network.bindAll and config.network.bindAddress != "":
    # 简单的IP格式验证
    let parts = config.network.bindAddress.split('.')
    if parts.len != 4:
      result.valid = false
      result.errors.add("无效的IP地址格式: " & config.network.bindAddress)
    else:
      for part in parts:
        try:
          let num = parseInt(part)
          if num < 0 or num > 255:
            result.valid = false
            result.errors.add("无效的IP地址格式: " & config.network.bindAddress)
            break
        except:
          result.valid = false
          result.errors.add("无效的IP地址格式: " & config.network.bindAddress)
          break

# 显示当前配置
proc displayConfig*(config: AirInputConfig) =
  echo "当前配置："
  echo "  配置文件: " & (if config.configFile != "": config.configFile else: "默认配置")
  echo "  "
  echo "  [网络配置]"
  echo "    绑定地址: " & (if config.network.bindAll: "所有接口 (0.0.0.0)" 
                                elif config.network.bindAddress != "": config.network.bindAddress 
                                else: "自动检测")
  echo "    绑定端口: " & $config.network.bindPort
  echo "    绑定所有接口: " & $config.network.bindAll
  echo "  "
  echo "  [服务器配置]"
  echo "    最大连接数: " & $config.server.maxConnections
  echo "    超时时间: " & $config.server.timeout & " 毫秒"
  echo "  "
  echo "  [日志配置]"
  echo "    日志级别: " & config.logging.logLevel
  echo "    日志文件: " & config.logging.logFile