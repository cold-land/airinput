# AirInput 项目 - 函数列表
========================================

## 模块概览
**总计函数数量：38个**
- src/airinput.nim: 0个（主程序入口）
- src/network.nim: 7个（网络检测模块）
- src/config.nim: 8个（配置文件管理）
- src/server.nim: 14个（WebSocket服务器）
- src/logger.nim: 3个（日志系统）
- src/cmd.nim: 1个（命令行处理）
- src/lock.nim: 5个（进程锁和守护进程）

========================================
# 详细函数列表

## src/airinput.nim - 主程序入口
（无自定义函数）
**作用**：主程序入口点，包含完整的程序启动和初始化逻辑

## src/network.nim - 网络检测模块

**NetworkInterface*(name: string, ipAddresses: seq[string], isLoopback: bool)**
**作用**：网络接口对象，存储接口名称、IP地址和回环状态

**getDefaultNetworkInterface*(): NetworkInterface**
**作用**：获取默认网络接口，优先获取真实本地IP，回退到0.0.0.0

**getNetworkInterfaces*(): seq[NetworkInterface]**
**作用**：获取所有网络接口列表（简化实现，只包含默认接口）

**filterInterfaces*(interfaces: seq[NetworkInterface]): seq[NetworkInterface]**
**作用**：过滤网络接口，排除回环、无效IP和本地链路地址

**displayNetworkInterfaces*(interfaces: seq[NetworkInterface])**
**作用**：显示网络接口列表供用户选择

**letUserSelectInterface*(interfaces: seq[NetworkInterface]): NetworkInterface**
**作用**：交互式选择网络接口，支持重试机制

**checkNetworkConfiguration*(): NetworkInterface**
**作用**：检查网络配置（交互模式），自动或用户选择接口

**resolveNetworkConfiguration*(daemonMode: bool, config: AirInputConfig): NetworkInterface**
**作用**：解析网络配置，支持守护进程和交互模式

## src/config.nim - 配置文件管理

**NetworkConfig*(bindAddress: string, bindPort: int, bindAll: bool)**
**作用**：网络配置对象

**ServerConfig*(maxConnections: int, timeout: int, bindPort: int)**
**作用**：服务器配置对象

**LoggingConfig*(logLevel: string, logFile: string)**
**作用**：日志配置对象

**AirInputConfig*(network: NetworkConfig, server: ServerConfig, logging: LoggingConfig, configFile: string)**
**作用**：完整的应用配置对象

**findConfigFile(): string**
**作用**：查找配置文件路径（当前目录→用户配置→系统配置）

**getDefaultConfig*(): AirInputConfig**
**作用**：获取默认配置对象

**generateDefaultConfigContent*(): string**
**作用**：生成默认配置文件内容

**generateDefaultConfig*(outputPath: string): bool**
**作用**：生成默认配置文件到指定路径

**parseConfigFile*(configPath: string): AirInputConfig**
**作用**：解析键值对格式的配置文件

**loadConfiguration*(configPath: string = ""): AirInputConfig**
**作用**：加载配置文件，支持自动查找和显式指定

**validateConfig*(config: AirInputConfig): tuple[valid: bool, errors: seq[string]]**
**作用**：验证配置文件有效性

**displayConfig*(config: AirInputConfig)**
**作用**：显示当前配置信息

## src/server.nim - WebSocket服务器

**readHtmlFile(filename: string): string**
**作用**：读取HTML文件内容，出错时返回错误页面

**mobileHandler(request: Request)**
**作用**：处理移动端页面的HTTP请求

**pcHandler(request: Request)**
**作用**：处理PC端页面的HTTP请求

**upgradeHandler(request: Request)**
**作用**：处理WebSocket升级请求

**broadcastMessage(message: string)**
**作用**：向所有客户端广播消息

**handleWebSocketOpen(websocket: WebSocket)**
**作用**：处理WebSocket连接打开事件，添加客户端到列表

**handleWebSocketMessage(websocket: WebSocket, message: Message)**
**作用**：处理WebSocket消息事件，记录并广播消息

**handleWebSocketError(websocket: WebSocket)**
**作用**：处理WebSocket错误事件

**handleWebSocketClose(websocket: WebSocket)**
**作用**：处理WebSocket关闭事件，从列表移除客户端

**websocketHandler(websocket: WebSocket, event: WebSocketEvent, message: Message)**
**作用**：WebSocket事件分发器，根据事件类型调用对应处理函数

**createRouter(): Router**
**作用**：创建HTTP路由配置

**isPortAvailable(port: int): bool**
**作用**：检查端口是否可用（默认0.0.0.0.0）

**isPortAvailable(port: int, bindAddress: string = "0.0.0.0.0"): bool**
**作用**：检查指定地址的端口是否可用

**findAvailablePort(startPort: int): int**
**作用**：在默认地址上查找可用端口（5001-5100范围）

**findAvailablePort(startPort: int, bindAddress: string = "0.0.0.0.0"): int**
**作用**：在指定地址上查找可用端口

**logServerInfo(port: int, networkInterface: NetworkInterface)**
**作用**：记录服务器启动信息（新版本，显示真实IP地址）

**startServer*(networkInterface: NetworkInterface, serverConfig: ServerConfig)**
**作用**：启动WebSocket服务器，支持自定义网络接口和服务器配置

## src/logger.nim - 日志系统

**getLogDir(): string**
**作用**：获取跨平台日志目录路径

**initLogger*(debugMode: bool = false, daemonMode: bool = false, loggingConfig: LoggingConfig = nil)**
**作用**：初始化日志系统，支持配置文件驱动

**logFlow*(level: string, source: string, target: string, content: string)**
**作用**：记录信息流向日志，格式：[时间:级别][来源]→[目标]内容

## src/cmd.nim - 命令行参数处理

**CmdResult*(debugMode: bool, daemonMode: bool, configFile: string, generateConfig: string, checkConfig: bool, showConfig: bool, listInterfaces: bool)**
**作用**：命令行参数结果对象，包含所有命令行选项

**handleCmdLine*(): CmdResult**
**作用**：处理命令行参数，支持版本、帮助、调试、守护进程、配置文件等选项

## src/lock.nim - 进程锁和守护进程

**flock(fd: cint, operation: cint): cint**
**作用**：文件锁定系统调用（从sys/file.h导入）

**daemonize*(): bool**
**作用**：将程序转换为守护进程，使用双重fork技术

**isProcessAlive(pid: Pid): bool**
**作用**：检查指定PID的进程是否存活

**killProcess(pid: Pid, graceful: bool = true): bool**
**作用**：终止指定PID的进程，支持优雅关闭和强制终止

**getLockFilePath(): string**
**作用**：获取跨平台锁文件路径

**getLockFileInode(lockFile: string): uint**
**作用**：获取锁文件的inode号码

**extractPidFromLockLine(line: string): int**
**作用**：从单行锁信息中提取PID

**parsePidsFromProcLocks(): seq[int]**
**作用**：从/proc/locks中解析所有可能的PID

**isPidHoldingLockFile(pid: int, lockInode: uint): bool**
**作用**：验证指定PID是否持有锁文件

**getLockHolderPid(): Pid**
**作用**：获取持有锁文件的进程PID

**cleanupLock()**
**作用**：清理锁文件并退出程序

**getUserChoice(): string**
**作用**：显示菜单并获取用户选择

**exitCleanly(): bool**
**作用**：保旧退出（保留旧实例，退出当前启动）

**killAllAndExit(lockFile: string): bool**
**作用**：结束全部（终止旧实例并退出当前启动）

**exitWithInvalidChoice(): bool**
**作用**：无效选择退出（用户输入无效选项）

**waitForLockRelease(maxAttempts: int = 10, interval: int = 200): bool**
**作用**：等待锁文件释放

**retryAcquireLock(lockFile: string): bool**
**作用**：重新尝试获取锁

**killOldAndStartNew(lockFile: string): bool**
**作用**：执行"杀旧启新"逻辑

**handleLockConflict(lockFile: string): bool**
**作用**：处理锁被占用的情况，包括用户交互和进程管理

**tryAcquireLock(lockFile: string): bool**
**作用**：尝试获取文件锁

**ensureSingleInstance*(): bool**
**作用**：确保程序单实例运行，包含锁获取和冲突处理

========================================
## 函数调用关系
========================================

**主启动流程**：
1. `handleCmdLine*()` → 2. `loadConfiguration()` → 3. `initLogger*()` → 4. `ensureSingleInstance*()` → 5. `resolveNetworkConfiguration()` → 6. `startServer*()`

**网络配置流程**：
- 守护进程模式：`resolveNetworkConfiguration()` → 使用配置文件设置
- 交互模式：`resolveNetworkConfiguration()` → `checkNetworkConfiguration()` → 用户选择接口

**WebSocket服务器流程**：
- `websocketHandler()` → 事件分发到各处理函数
- 连接/关闭事件：记录日志并管理客户端列表
- 消息事件：记录日志并广播给所有客户端

**锁管理流程**：
- `ensureSingleInstance()` → `tryAcquireLock()` → `handleLockConflict() → 各种处理函数

========================================
## 函数使用场景
========================================

**高频核心函数**（每次启动必调用）：
- `handleCmdLine*()` - 处理命令行参数
- `initLogger*()` - 初始化日志系统
- `ensureSingleInstance*()` - 确保单实例运行
- `startServer*()` - 启动WebSocket服务器

**配置相关函数**：
- `loadConfiguration()` - 配置文件加载
- `resolveNetworkConfiguration()` - 网络配置解析
- `getDefaultNetworkInterface()` - 获取网络信息

**事件处理函数**（实时运行时频繁调用）：
- `websocketHandler()` - WebSocket事件分发
- `broadcastMessage()` - 消息广播
- `logFlow()` - 信息流跟踪

**守护进程和进程管理**：
- `daemonize*()` - 守护进程化
- `killProcess()` - 进程终止
- 各种锁管理函数

这个函数列表为AirInput项目提供了完整的函数概览，帮助理解项目架构和函数调用关系。项目采用模块化设计，每个模块职责明确，函数粒度合理，适合Nim语言新手学习。