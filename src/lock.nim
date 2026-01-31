import std/os, std/posix, std/strutils

# 声明 flock 函数（从 sys/file.h 导入）
proc flock(fd: cint, operation: cint): cint {.importc, header: "<sys/file.h>".}

# flock 操作常量
const
  LOCK_SH = 1.cint  # 共享锁
  LOCK_EX = 2.cint  # 排他锁
  LOCK_NB = 4.cint  # 非阻塞
  LOCK_UN = 8.cint  # 释放锁

const LOCK_FILE = "airinput.lock"

# 全局变量保存文件描述符
var lockFd: cint = -1

# 退出标志
var shouldExit = false

# 获取跨平台锁文件路径
proc getLockFilePath(): string =
  getTempDir() / LOCK_FILE

# 守护进程化
proc daemonize*(): bool =
  # 第一次 fork
  if fork() != 0:
    quit(0)
  
  # 创建新会话
  if setsid() < 0:
    return false
  
  # 第二次 fork
  if fork() != 0:
    quit(0)
  
  # 重定向标准输入/输出/错误
  let nullFile = open("/dev/null", O_RDWR)
  if nullFile >= 0:
    discard dup2(nullFile, STDIN_FILENO)
    discard dup2(nullFile, STDOUT_FILENO)
    discard dup2(nullFile, STDERR_FILENO)
    discard close(nullFile)
  
  return true

# 检查进程是否存活
proc isProcessAlive(pid: Pid): bool =
  if pid <= 0:
    return false
  # 使用 kill(pid, 0) 检查进程是否存在，但不发送信号
  return kill(pid, 0) == 0

# 终止进程
proc killProcess(pid: Pid, graceful: bool = true): bool =
  if not isProcessAlive(pid):
    return true
  
  if graceful:
    # 优雅关闭：发送 SIGTERM (15)
    discard kill(pid, SIGTERM)
    # 等待 5 秒让进程清理
    for i in 0..<5:
      sleep(1000)
      if not isProcessAlive(pid):
        return true
  
  # 如果进程仍然存活，强制终止：发送 SIGKILL (9)
  if isProcessAlive(pid):
    discard kill(pid, SIGKILL)
    sleep(500)
  
  return not isProcessAlive(pid)

# 获取锁文件的 inode 号码
proc getLockFileInode(lockFile: string): uint =
  var fileStat: Stat
  if stat(lockFile.cstring, fileStat) != 0:
    return 0
  return fileStat.st_ino

# 从单行锁信息中提取 PID
proc extractPidFromLockLine(line: string): int =
  let parts = line.splitWhitespace()
  if parts.len < 5:
    return 0
  
  # 查找 pid:xxxxx 格式
  for part in parts:
    if part.startsWith("pid:"):
      try:
        return parseInt(part[4..^1])
      except:
        discard
  
  # 尝试直接解析第五个位置的 PID
  try:
    let possiblePid = parts[4]
    discard parseInt(possiblePid)  # 验证是否为数字
    return parseInt(possiblePid)
  except:
    return 0

# 从 /proc/locks 中解析所有可能的 PID
proc parsePidsFromProcLocks(): seq[int] =
  result = @[]
  if not fileExists("/proc/locks"):
    return result
  
  let locksContent = readFile("/proc/locks")
  for line in locksContent.splitLines():
    if "flock" in line.toLowerAscii() and "ADVISORY" in line:
      let pid = extractPidFromLockLine(line)
      if pid > 0:
        result.add(pid)

# 验证指定 PID 是否持有锁文件
proc isPidHoldingLockFile(pid: int, lockInode: uint): bool =
  let fdDir = "/proc/" & $pid & "/fd"
  if not dirExists(fdDir):
    return false
  
  for fdFile in walkDir(fdDir):
    var fdStat: Stat
    if stat(fdFile.path.cstring, fdStat) == 0:
      if fdStat.st_ino == lockInode:
        return true
  return false

# 清理锁
proc cleanupLock() {.noconv.} =
  shouldExit = true
  if lockFd >= 0:
    discard close(lockFd)
    lockFd = -1
  quit(0)

# 获取持有锁文件的进程 PID
proc getLockHolderPid(): Pid =
  try:
    let lockFile = getLockFilePath()
    let lockInode = getLockFileInode(lockFile)
    if lockInode == 0:
      return 0
    
    let pids = parsePidsFromProcLocks()
    for pid in pids:
      if isPidHoldingLockFile(pid, lockInode):
        return pid.Pid
    return 0
  except:
    return 0

# 显示菜单并获取用户选择
proc getUserChoice(): string =
  echo "请选择操作："
  echo "  1. 杀旧启新 - 终止旧实例并启动新实例"
  echo "  2. 保旧退出 - 保留旧实例，退出当前启动"
  echo "  3. 结束全部 - 终止旧实例并退出当前启动"
  stdout.write("请输入选项 (1/2/3): ")
  return stdin.readLine().strip()

# 保旧退出
proc exitCleanly(): bool =
  echo "程序退出"
  discard close(lockFd)
  lockFd = -1
  return false

# 结束全部
proc killAllAndExit(lockFile: string): bool =
  let oldPid = getLockHolderPid()
  if oldPid > 0:
    echo "正在终止旧实例 (PID: " & $oldPid & ")..."
    if killProcess(oldPid, graceful = true):
      echo "旧实例已终止"
    else:
      echo "警告：终止旧实例失败"
  else:
    echo "警告：无法找到旧实例的 PID"
  
  echo "程序退出"
  discard close(lockFd)
  lockFd = -1
  return false

# 无效选择退出
proc exitWithInvalidChoice(): bool =
  echo "无效选项，程序退出"
  discard close(lockFd)
  lockFd = -1
  return false

# 等待锁文件释放
proc waitForLockRelease(maxAttempts: int = 10, interval: int = 200): bool =
  for i in 0..<maxAttempts:
    sleep(interval)
    if getLockHolderPid() == 0:
      return true
  return false

# 重新尝试获取锁
proc retryAcquireLock(lockFile: string): bool =
  discard close(lockFd)
  lockFd = open(lockFile.cstring, O_RDWR or O_CREAT, 0o600)
  if lockFd >= 0 and flock(lockFd, LOCK_EX or LOCK_NB) == 0:
    setControlCHook(cleanupLock)
    return true
  return false

# 执行"杀旧启新"逻辑
proc killOldAndStartNew(lockFile: string): bool =
  let oldPid = getLockHolderPid()
  if oldPid > 0 and killProcess(oldPid, graceful = true):
    echo "旧实例已终止"
    if waitForLockRelease() and retryAcquireLock(lockFile):
      echo "新实例已启动"
      return true
  echo "错误：无法终止旧实例或获取锁"
  return false

# 处理锁被占用的情况
proc handleLockConflict(lockFile: string): bool =
  echo "检测到已有 AirInput 实例在运行"
  let choice = getUserChoice()
  
  case choice:
  of "1": return killOldAndStartNew(lockFile)
  of "2": return exitCleanly()
  of "3": return killAllAndExit(lockFile)
  else: return exitWithInvalidChoice()

# 尝试获取文件锁
proc tryAcquireLock(lockFile: string): bool =
  lockFd = open(lockFile.cstring, O_RDWR or O_CREAT, 0o600)
  if lockFd < 0:
    echo "无法创建锁文件: " & lockFile
    return false
  
  if flock(lockFd, LOCK_EX or LOCK_NB) == 0:
    setControlCHook(cleanupLock)
    return true
  return false

# 确保单实例运行
proc ensureSingleInstance*(): bool =
  let lockFile = getLockFilePath()
  
  if tryAcquireLock(lockFile):
    return true
  
  return handleLockConflict(lockFile)