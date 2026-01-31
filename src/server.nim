import mummy, mummy/routers, std/logging, std/times, std/net, std/locks, std/sets
import logger, config as cfg, network

# WebSocket 服务器模块

type
  Client = ref object
    websocket: WebSocket
    connectedAt: DateTime
    id: string

var
  clientsLock: Lock
  clients: HashSet[WebSocket]

initLock(clientsLock)

proc readHtmlFile(filename: string): string =
  try:
    result = readFile("resources/web/" & filename)
  except:
    result = "<html><body>Error</body></html>"
    logging.error("Cannot read file: " & filename)

proc mobileHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "text/html"
  request.respond(200, headers, readHtmlFile("mobile/index.html"))

proc pcHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "text/html"
  request.respond(200, headers, readHtmlFile("pc/index.html"))

proc upgradeHandler(request: Request) =
  discard request.upgradeToWebSocket()

# 处理 WebSocket 连接打开事件
proc handleWebSocketOpen(websocket: WebSocket) =
  logging.info("WebSocket connected")
  logFlow("I", "Server", "Client", "WebSocket 连接建立")
  {.gcsafe.}:
    withLock clientsLock:
      clients.incl(websocket)

# 广播消息给所有客户端
proc broadcastMessage(message: string) =
  {.gcsafe.}:
    withLock clientsLock:
      for client in clients:
        client.send(message)

# 处理 WebSocket 消息事件
proc handleWebSocketMessage(websocket: WebSocket, message: Message) =
  logging.info("Message received")
  logFlow("I", "Client", "Server", "收到消息: " & message.data)
  broadcastMessage(message.data)
  logFlow("I", "Server", "All", "广播消息: " & message.data)

# 处理 WebSocket 错误事件
proc handleWebSocketError(websocket: WebSocket) =
  logging.error("WebSocket error")
  logFlow("E", "Client", "Server", "WebSocket 错误")

# 处理 WebSocket 关闭事件
proc handleWebSocketClose(websocket: WebSocket) =
  logging.info("WebSocket disconnected")
  logFlow("I", "Client", "Server", "WebSocket 连接断开")
  {.gcsafe.}:
    withLock clientsLock:
      clients.excl(websocket)

# WebSocket 事件分发器
proc websocketHandler(
  websocket: WebSocket,
  event: WebSocketEvent,
  message: Message
) =
  case event:
  of OpenEvent:
    handleWebSocketOpen(websocket)
  of MessageEvent:
    handleWebSocketMessage(websocket, message)
  of ErrorEvent:
    handleWebSocketError(websocket)
  of CloseEvent:
    handleWebSocketClose(websocket)

# 创建路由配置
proc createRouter(): Router =
  var router: Router
  router.get("/", mobileHandler)
  router.get("/pc", pcHandler)
  router.get("/ws", upgradeHandler)
  result = router

# 检查端口是否可用
proc isPortAvailable(port: int): bool =
  try:
    let testSocket = newSocket()
    testSocket.bindAddr(Port(port), "0.0.0.0")
    testSocket.close()
    return true
  except:
    logging.warn("Port " & $port & " is busy, trying next...")
    return false

# 查找可用端口
proc findAvailablePort(startPort: int): int =
  for port in startPort .. (startPort + 99):
    if isPortAvailable(port):
      return port
  return -1

# 记录服务器启动信息
proc logServerInfo(port: int) =
  logging.info("Server started on port " & $port)
  logging.info("Mobile: http://localhost:" & $port & "/")
  logging.info("PC: http://localhost:" & $port & "/pc")
  logging.info("WebSocket: ws://localhost:" & $port & "/ws")

# 检查端口是否可用
proc isPortAvailable(port: int, bindAddress: string = "0.0.0.0"): bool =
  try:
    let testSocket = newSocket()
    testSocket.bindAddr(Port(port), bindAddress)
    testSocket.close()
    return true
  except:
    logging.warn("Port " & $port & " is busy, trying next...")
    return false

# 查找可用端口
proc findAvailablePort(startPort: int, bindAddress: string = "0.0.0.0"): int =
  for port in startPort .. (startPort + 99):
    if isPortAvailable(port, bindAddress):
      return port
  return -1

# 记录服务器启动信息
proc logServerInfo(port: int, networkInterface: NetworkInterface) =
  let bindAddr = if networkInterface.name == "0.0.0.0": "所有接口" 
                else: networkInterface.ipAddresses[0]
  
  logging.info("Server started on port " & $port)
  logging.info("Bind address: " & bindAddr)
  if networkInterface.name != "0.0.0.0":
    logging.info("Mobile: http://" & networkInterface.ipAddresses[0] & ":" & $port & "/")
    logging.info("PC: http://" & networkInterface.ipAddresses[0] & ":" & $port & "/pc")
    logging.info("WebSocket: ws://" & networkInterface.ipAddresses[0] & ":" & $port & "/ws")
  else:
    logging.info("Mobile: http://localhost:" & $port & "/")
    logging.info("PC: http://localhost:" & $port & "/pc")
    logging.info("WebSocket: ws://localhost:" & $port & "/ws")

# 启动服务器
proc startServer*(networkInterface: NetworkInterface, serverConfig: ServerConfig) =
  let router = createRouter()
  
  # 确定绑定地址
  let bindAddress = if networkInterface.name == "0.0.0.0": "0.0.0.0"
                     else: networkInterface.ipAddresses[0]
  
  # 查找可用端口
  let actualPort = findAvailablePort(serverConfig.bindPort, bindAddress)
  
  if actualPort == -1:
    logging.error("Cannot find available port")
    quit(1)
  
  let server = newServer(router, websocketHandler)
  logServerInfo(actualPort, networkInterface)
  server.serve(Port(actualPort), bindAddress)