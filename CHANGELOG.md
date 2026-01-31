# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.0.0.9] - 2026-01-31
- 完善项目文档体系，更新所有模块函数列表文档
- 更新 HELP.txt 添加完整的命令行选项说明
- 转换 CHANGELOG.txt 为标准 Markdown 格式 CHANGELOG.md
- 创建 src/network.txt 和 src/config.txt 模块文档
- 同步更新 src/cmd.txt, src/server.txt, src/logger.txt, src/lock.txt 文档内容

## [0.0.0.8] - 2026-01-31
- 添加网络配置模块 (network.nim)，支持自动检测和用户选择网络接口
- 添加配置文件管理模块 (config.nim)，支持键值对配置文件格式
- 重构命令行参数处理，支持 --config-file, --generate-config, --check-config, --show-config, --list-interfaces
- 重构日志系统，支持配置文件驱动的日志配置
- 重构启动流程，支持守护进程模式和交互模式
- 重构WebSocket服务器，支持自定义网络接口和服务器配置
- 创建完整的项目文档 (FUNCTION_LIST.md)，包含所有函数说明和调用关系

## [0.0.0.7] - 2026-01-31
- 优化服务器启动信息显示，优先显示真实IP地址而不是0.0.0.0

## [0.0.0.6] - 2026-01-30
- 终于弄好了websocket服务啊，还加了两个测试网页。能通信啦

## [0.0.0.5] - 2026-01-30
- 使用 POSIX flock 文件锁实现单实例运行检测
- 添加交互式菜单支持（杀旧启新/保旧退出/两个都结束）
- 添加 -D 参数支持守护进程模式
- 实现跨平台日志目录（Linux/macOS/Windows）
- 日志格式从 Time 改为 DateTime（ISO 8601 标准）

## [0.0.0.4] - 2026-01-30
- 添加自定义日志函数 logFlow
- 优化日志格式，使用紧凑的时间:级别格式

## [0.0.0.3] - 2026-01-30
- 添加 --debug 选项
- 实现系统日志功能

## [0.0.0.2] - 2026-01-30
- 添加 --help 选项
- 创建命令行参数解析模块

## [0.0.0.1] - 2026-01-30
- 添加 --version 选项
- 初始化项目