#!/bin/bash
# ============================================================
#  DSH Web 一键启动（DeepSeek Harness 浏览器端）
#  使用 ~/.dsh 全局配置，监听 127.0.0.1:3080
#  双击本文件即可运行；关闭终端窗口即停止服务。
#  （同机备份：/Users/limeng/启动-DSH-Web.command）
# ============================================================
set -e
cd "$HOME"

# 1) 优先用 npx 缓存里的 dsh（本机已装 0.1.0-rc.6）
DSH_BIN="/Users/limeng/.npm/_npx/1e7f6d9597241db0/node_modules/.bin/dsh"
if [ -x "$DSH_BIN" ]; then
  echo "==> 使用 dsh: $DSH_BIN"
  exec "$DSH_BIN" web --host 127.0.0.1 --port 3080
fi

# 2) 回退：PATH 中的 dsh
if command -v dsh >/dev/null 2>&1; then
  echo "==> 使用 PATH 中的 dsh"
  exec dsh web --host 127.0.0.1 --port 3080
fi

# 3) 最后回退：npx 拉取
echo "==> 未找到 dsh，尝试 npx 安装..."
exec npx --yes dsh web --host 127.0.0.1 --port 3080
