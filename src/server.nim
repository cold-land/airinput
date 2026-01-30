import mummy, mummy/routers, std/logging, std/times, std/net, std/os, std/locks, std/sets

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

proc websocketHandler(
  websocket: WebSocket,
  event: WebSocketEvent,
  message: Message
) =
  case event:
  of OpenEvent:
    echo "WebSocket connected"
    {.gcsafe.}:
      withLock clientsLock:
        clients.incl(websocket)
  of MessageEvent:
    echo "Message received"
    {.gcsafe.}:
      withLock clientsLock:
        for client in clients:
          client.send(message.data)
  of ErrorEvent:
    discard
  of CloseEvent:
    echo "WebSocket disconnected"
    {.gcsafe.}:
      withLock clientsLock:
        clients.excl(websocket)

proc startServer*(startPort: int = 5001) =
  var router: Router
  router.get("/", mobileHandler)
  router.get("/pc", pcHandler)
  router.get("/ws", upgradeHandler)

  var server: Server = nil
  var actualPort = -1

  for port in startPort .. (startPort + 99):
    try:
      let testSocket = newSocket()
      testSocket.bindAddr(Port(port), "0.0.0.0")
      testSocket.close()
      server = newServer(router, websocketHandler)
      actualPort = port
      break
    except:
      echo "Port " & $port & " is busy, trying next..."
      continue

  if actualPort == -1:
    echo "Cannot find available port"
    quit(1)

  echo "Server started on port " & $actualPort
  echo "Mobile: http://localhost:" & $actualPort & "/"
  echo "PC: http://localhost:" & $actualPort & "/pc"
  echo "WebSocket: ws://localhost:" & $actualPort & "/ws"
  server.serve(Port(actualPort))