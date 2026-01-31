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

# 获取持有锁文件的进程 PID
proc getLockHolderPid(): Pid =
  try:
    let lockFile = getLockFilePath()
    # 获取锁文件的 inode
    var fileStat: Stat
    if stat(lockFile.cstring, fileStat) != 0:
      return 0
    
    let lockInode = fileStat.st_ino
    
    # 读取 /proc/locks
    if not fileExists("/proc/locks"):
      return 0
    
    let locksContent = readFile("/proc/locks")
    for line in locksContent.splitLines():
      # /proc/locks 格式示例：
      # 1: POSIX  ADVISORY  READ  pid:12345  08:02:123456 0 EOF
      # 2: flock  ADVISORY  WRITE pid:12345  08:02:123456 0 EOF
      # 3: FLOCK  ADVISORY  WRITE 12345  00:2b:66730 0 EOF
      if "flock" in line.toLowerAscii() and "ADVISORY" in line:
        let parts = line.splitWhitespace()
        if parts.len >= 5:
          # 查找 pid:xxxxx 部分 或直接的 PID
          var pidStr = ""
          for part in parts:
            if part.startsWith("pid:"):
              pidStr = part[4..^1]
              break
          
          # 如果没有找到 pid: 格式，尝试直接解析 PID
          if pidStr == "":
            # 在 /proc/locks 中，PID 通常在第五个位置
            # 格式: 162: FLOCK  ADVISORY  WRITE 907323 00:2b:66730 0 EOF
            # parts = ["162:", "FLOCK", "ADVISORY", "WRITE", "907323", "00:2b:66730", "0", "EOF"]
            if parts.len >= 5:
              let possiblePid = parts[4]
              try:
                let _ = parseInt(possiblePid)
                pidStr = possiblePid
              except:
                discard
          
          if pidStr != "":
            let pid = parseInt(pidStr)
            
            # 验证这个进程是否确实持有我们的锁文件
            # 检查 /proc/PID/fd 中的文件描述符
            let fdDir = "/proc/" & $pid & "/fd"
            if dirExists(fdDir):
              for fdFile in walkDir(fdDir):
                var fdStat: Stat
                if stat(fdFile.path.cstring, fdStat) == 0:
                  if fdStat.st_ino == lockInode:
                    return pid.Pid
    return 0
  except:
    return 0

# 清理锁
proc cleanupLock() {.noconv.} =
  shouldExit = true
  if lockFd >= 0:
    discard close(lockFd)
    lockFd = -1
  quit(0)

# 确保单实例运行
proc ensureSingleInstance*(): bool =
  let lockFile = getLockFilePath()
  
  # 打开锁文件（如果不存在则创建）
  lockFd = open(lockFile.cstring, O_RDWR or O_CREAT, 0o600)
  if lockFd < 0:
    echo "无法创建锁文件: " & lockFile
    return false
  
  # 尝试获取排他锁（非阻塞）
  if flock(lockFd, LOCK_EX or LOCK_NB) == 0:
    # 成功获取锁，程序可以运行
    # 注册 Ctrl+C 处理，确保退出时清理锁
    setControlCHook(cleanupLock)
    return true
  else:
    # 锁已被占用，说明有其他实例在运行
    echo "检测到已有 AirInput 实例在运行"
    echo "请选择操作："
    echo "  1. 杀旧启新 - 终止旧实例并启动新实例"
    echo "  2. 保旧退出 - 保留旧实例，退出当前启动"
    echo "  3. 结束全部 - 终止旧实例并退出当前启动"
    stdout.write("请输入选项 (1/2/3): ")
    
    let answer = stdin.readLine().strip()
    
    if answer == "1":
      # 杀旧启新：终止持有锁的进程
      let oldPid = getLockHolderPid()
      if oldPid > 0:
        echo "正在终止旧实例 (PID: " & $oldPid & ")..."
        if killProcess(oldPid, graceful = true):
          echo "旧实例已终止"
          # 等待锁文件被释放
          for i in 0..<10:
            sleep(200)
            let currentPid = getLockHolderPid()
            if currentPid == 0:
              break
          # 关闭当前文件描述符，重新打开
          discard close(lockFd)
          lockFd = open(lockFile.cstring, O_RDWR or O_CREAT, 0o600)
          if lockFd >= 0:
            # 重新尝试获取锁
            if flock(lockFd, LOCK_EX or LOCK_NB) == 0:
              setControlCHook(cleanupLock)
              echo "新实例已启动"
              return true
      
      echo "错误：无法终止旧实例或获取锁"
      return false
    elif answer == "2":
      # 保旧退出
      echo "程序退出"
      discard close(lockFd)
      lockFd = -1
      return false
    elif answer == "3":
      # 两个都结束：终止旧实例并退出当前启动
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
    else:
      # 无效输入
      echo "无效选项，程序退出"
      discard close(lockFd)
      lockFd = -1
      return false