# AirInput 学习笔记

## 项目初始化 + Git 初始化

```bash
#初始化 Nim 语言项目
nimble init


# Git 初始化
git init
git config --global user.name "Shaowei"
git config --global user.email "ccshaowei@gmail.com"
git add .
git commit -m "first commit"
git branch -M main

ssh -T git@github.com  # 验证连接

# 关联 GitHub 远程仓库并推送
git remote add origin git@github.com:cold-land/airinput.git
git push -u origin main
```

