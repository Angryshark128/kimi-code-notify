#!/bin/bash
# kimi-code-notify —— 任务结束的系统通知 + 提示音（macOS）+ Bark（iOS 推送）
# 用法: notify.sh <消息> [音效] [标题]
#   消息: 通知正文，默认 "任务完成"
#   音效: Glass / Sosumi / Funk / Basso / Ping / Purr ...（macOS 内置音效，不带 .aiff）
#   标题: 默认 "Kimi Code"
# 状态: 按消息自动匹配 emoji（✅完成 ⏰超时 ❌失败 ⛔被终止 ✋中断 ❓丢失）
# 兼容: 无 osascript 的环境自动降级（声音 / 纯文本）
#
# Bark 推送（可选）：读取 ~/.config/kimi-code-notify/bark.env 中的 BARK_URL / BARK_KEY，
# 未配置则静默跳过，不影响系统通知。示例：
#   BARK_URL=https://api.day.app        # 官方服务；自建服务填你的地址
#   BARK_KEY=xxxxxxxxxxxxxxxxxxxx       # 手机 Bark App 里的设备 key
#
# 当作为 kimi hook 命令被调用时（stdin 收到 JSON），自动提取 session_title
# 作为通知标题；手动运行（终端交互）则不受影响。

set -uo pipefail

MESSAGE="${1:-任务完成}"
SOUND="${2:-Glass}"
TITLE="${3:-Kimi Code}"

# 从 hook stdin 读取 JSON，用会话名覆盖标题（仅 hook 调用时生效）
if [ ! -t 0 ]; then
  SNAP="$(cat 2>/dev/null || true)"
  if [ -n "$SNAP" ]; then
    SESSION_TITLE="$(printf '%s' "$SNAP" | python3 -c 'import sys,json
try:
    d=json.load(sys.stdin)
    print((d.get("session_title") or "").strip())
except Exception:
    print("")' 2>/dev/null)"
    [ -n "$SESSION_TITLE" ] && TITLE="$SESSION_TITLE"
  fi
fi

# 状态 emoji：系统通知与 Bark 标题均带状态
case "$MESSAGE" in
  *超时*)                    EMOJI="⏰" ;;
  *被终止*)                  EMOJI="⛔" ;;
  *中断*)                    EMOJI="✋" ;;
  *丢失*)                    EMOJI="❓" ;;
  *失败*)                    EMOJI="❌" ;;
  *完成*|*成功*|*completed*) EMOJI="✅" ;;
  *)                         EMOJI="" ;;
esac
# Bark 标题 = emoji + 会话名；系统通知标题保持纯会话名，emoji 前缀消息
BARK_TITLE="$TITLE"
[ -n "$EMOJI" ] && BARK_TITLE="$EMOJI $BARK_TITLE"

# ---- Bark iOS 推送（可选）----
# 配置: ~/.config/kimi-code-notify/bark.env 中设 BARK_URL / BARK_KEY；未配置则跳过。
# 放在系统通知之前，避免 osascript 提前 exit 导致推送丢失。
BARK_ENV="${BARK_ENV_FILE:-$HOME/.config/kimi-code-notify/bark.env}"
if [ -f "$BARK_ENV" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$BARK_ENV" 2>/dev/null || true
  set +a
fi
if [ -n "${BARK_KEY:-}" ]; then
  BARK_URL="${BARK_URL:-https://api.day.app}"
  # 来源标识（subtitle）：默认取系统电脑名，可用 bark.env 中的 BARK_SOURCE 覆盖
  BARK_SOURCE="${BARK_SOURCE:-$(scutil --get ComputerName 2>/dev/null || hostname -s)}"
  JSON="$(python3 -c 'import sys,json
print(json.dumps({"title": sys.argv[1], "subtitle": sys.argv[2], "body": sys.argv[3], "group": "kimi-code", "sound": "default"}))' "$BARK_TITLE" "来自 $BARK_SOURCE" "$MESSAGE" 2>/dev/null)"
  if [ -n "$JSON" ]; then
    curl -s -m 8 -X POST "${BARK_URL%/}/$BARK_KEY" \
      -H 'Content-Type: application/json' -d "$JSON" >/dev/null 2>&1
  fi
fi

# 系统通知横幅 + 声音（osascript 主路径；terminal-notifier 在部分 macOS 上会挂起且通知被系统丢弃，弃用）
# emoji 前缀用于区分状态：✅任务完成 ⏰任务超时 ❌任务失败 ...
if command -v osascript >/dev/null 2>&1; then
  if osascript -e "display notification \"$EMOJI $MESSAGE\" with title \"$TITLE\" sound name \"$SOUND\"" 2>/dev/null; then
    exit 0
  fi
  afplay "/System/Library/Sounds/$SOUND.aiff" 2>/dev/null && exit 0
fi

# 最后兜底：纯文本输出
echo "[kimi-code-notify] $EMOJI $MESSAGE ($SOUND)" >&2
