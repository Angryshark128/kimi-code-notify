#!/bin/bash
# kimi-code-notify —— 后台任务结束的系统通知 + 提示音（macOS）
# 用法: notify.sh <消息> [音效] [标题]
#   消息: 通知正文，默认 "任务完成"
#   音效: Glass / Sosumi / Funk / Basso / Ping / Purr ...（macOS 内置音效，不带 .aiff）
#   标题: 默认 "Kimi Code"
# 兼容: 无 osascript 的环境（如 SSH）自动降级为只播声音 / 只输出文本

set -uo pipefail

MESSAGE="${1:-任务完成}"
SOUND="${2:-Glass}"
TITLE="${3:-Kimi Code}"

# 首选：系统通知中心横幅 + 声音
if command -v osascript >/dev/null 2>&1; then
  if osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\" sound name \"$SOUND\"" 2>/dev/null; then
    exit 0
  fi
  # 降级：仅播放系统声音
  afplay "/System/Library/Sounds/$SOUND.aiff" 2>/dev/null && exit 0
fi

# 最后兜底：纯文本输出
echo "[kimi-code-notify] $MESSAGE ($SOUND)" >&2
