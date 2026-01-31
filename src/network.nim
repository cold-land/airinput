import std/net, std/strutils, std/osproc
import config

# ========================================
# 网络检测模块
# ========================================

type
  NetworkInterface* = ref object
    name*: string           # 接口名 (eth0, wlan0, virbr0)
    ipAddresses*: seq[string] # IPv4地址列表
    isLoopback*: bool        # 是否为回环接口

# 获取默认网络接口
proc getDefaultNetworkInterface*(): NetworkInterface =
  # 尝试获取真实的本地IP地址
  when defined(linux):
    try:
      let cmdResult = execProcess("hostname -I 2>/dev/null").strip()
      if cmdResult != "" and cmdResult != "127.0.0.1":
        let ip = cmdResult.split()[0]
        return NetworkInterface(
          name: "default",
          ipAddresses: @[ip],
          isLoopback: false
        )
    except:
      discard
  
  # 默认回退
  return NetworkInterface(
    name: "0.0.0.0",
    ipAddresses: @["所有地址"],
    isLoopback: false
  )

# 获取所有网络接口（简化实现）
proc getNetworkInterfaces*(): seq[NetworkInterface] =
  result = @[]
  
  let defaultInterface = getDefaultNetworkInterface()
  result.add(defaultInterface)

# 过滤掉不需要的接口
proc filterInterfaces*(interfaces: seq[NetworkInterface]): seq[NetworkInterface] =
  result = @[]
  
  for iface in interfaces:
    # 过滤掉回环接口
    if iface.isLoopback:
      continue
    
    # 过滤掉没有IP地址的接口
    if iface.ipAddresses.len == 0:
      continue
    
    # 过滤掉本地链路地址
    var validIPs = newSeq[string]()
    for ip in iface.ipAddresses:
      let isLocal = ip.startsWith("127.") or ip.startsWith("169.254.") or ip == "0.0.0.0"
      if not isLocal:
        validIPs.add(ip)
    
    if validIPs.len > 0:
      result.add(NetworkInterface(
        name: iface.name,
        ipAddresses: validIPs,
        isLoopback: false
      ))

# 显示网络接口列表
proc displayNetworkInterfaces*(interfaces: seq[NetworkInterface]) =
  if interfaces.len == 0:
    echo "未找到可用的网络接口"
    return
  
  echo "检测到多个网络接口："
  for i in 0..<interfaces.len:
    let iface = interfaces[i]
    let ipStr = join(iface.ipAddresses, ", ")
    echo "[" & $(i+1) & "] " & iface.name & " - " & ipStr
  echo "请选择要绑定的网络接口 (1-" & $(interfaces.len) & "): "

# 用户选择网络接口
proc letUserSelectInterface*(interfaces: seq[NetworkInterface]): NetworkInterface =
  if interfaces.len == 0:
    echo "错误：没有可用的网络接口"
    return NetworkInterface(name: "0.0.0.0", ipAddresses: @["0.0.0.0"], isLoopback: false)
  
  let maxAttempts = 3
  
  for attempt in 1..maxAttempts:
    try:
      displayNetworkInterfaces(interfaces)
      let answer = stdin.readLine().strip()
      let choice = parseInt(answer)
      
      if choice >= 1 and choice <= interfaces.len:
        return interfaces[choice - 1]
      else:
        echo "无效选项，请输入 1-" & $(interfaces.len) & " 之间的数字"
    except CatchableError:
      echo "输入无效，请输入数字"
    
    if attempt < maxAttempts:
      echo "剩余尝试次数: " & $(maxAttempts - attempt)
  
  echo "尝试次数过多，将使用第一个网络接口"
  return interfaces[0]

# 检查网络配置（交互模式）
proc checkNetworkConfiguration*(): NetworkInterface =
  let interfaces = getNetworkInterfaces()
  let filteredInterfaces = filterInterfaces(interfaces)
  
  if filteredInterfaces.len == 0:
    echo "错误：没有找到可用的网络接口"
    quit(1)
  elif filteredInterfaces.len == 1:
    let iface = filteredInterfaces[0]
    let ipStr = join(iface.ipAddresses, ", ")
    echo "只有一个网络接口可用: " & iface.name & " - " & ipStr
    return filteredInterfaces[0]
  else:
    return letUserSelectInterface(filteredInterfaces)

# 解析网络配置（支持配置文件）
proc resolveNetworkConfiguration*(daemonMode: bool, config: AirInputConfig): NetworkInterface =
  if daemonMode:
    # 守护进程模式：使用配置文件
    if config.network.bindAll:
      return NetworkInterface(name: "0.0.0.0", ipAddresses: @["所有地址"], isLoopback: false)
    elif config.network.bindAddress != "":
      return NetworkInterface(
        name: config.network.bindAddress,
        ipAddresses: @[config.network.bindAddress],
        isLoopback: false
      )
    else:
      # 配置文件没有指定，默认绑定所有接口
      return NetworkInterface(name: "0.0.0.0", ipAddresses: @["所有地址"], isLoopback: false)
  else:
    # 交互模式：用户选择
    return checkNetworkConfiguration()