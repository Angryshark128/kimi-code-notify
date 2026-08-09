#!/bin/bash
# kimi-code-notify 安装脚本
# 将「任务结果通知」hooks（后台任务 5 条 + 对话回合 3 条）写入 ~/.kimi-code/config.toml（幂等，可重复执行）
# 用法:
#   ./install.sh       安装 / 更新
#   ./install.sh -u    卸载（移除本脚本管理的 hooks 块）
set -euo pipefail

CONFIG_DIR="${KIMI_CODE_HOME:-$HOME/.kimi-code}"
CONFIG="$CONFIG_DIR/config.toml"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NOTIFY_SCRIPT="$SCRIPT_DIR/notify.sh"
MARKER_BEGIN="# kimi-code-notify hooks: begin"
MARKER_END="# kimi-code-notify hooks: end"

if [ ! -f "$CONFIG" ]; then
  echo "错误：找不到 ${CONFIG}（先运行一次 kimi code 生成默认配置）" >&2
  exit 1
fi

# 移除旧的标记块（幂等）
remove_block() {
  if grep -qF "$MARKER_BEGIN" "$CONFIG"; then
    awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
      $0 == b { skip = 1; next }
      skip && $0 == e { skip = 0; next }
      !skip { print }
    ' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
    echo "已移除旧的 kimi-code-notify hooks 块"
  fi
}

if [ "${1:-}" = "-u" ] || [ "${1:-}" = "--uninstall" ]; then
  remove_block
  echo "已卸载 kimi-code-notify hooks"
  exit 0
fi

cp "$CONFIG" "$CONFIG.kimi-notify.bak"
echo "已备份: $CONFIG.kimi-notify.bak"

remove_block

# 生成 hooks 块；quoted heredoc 保留 \\. 转义，@SCRIPT@ 写入前替换为脚本绝对路径
HOOKS="$(cat <<'EOF'
# kimi-code-notify hooks: begin
# 任务结果 → 系统通知 + 提示音 + 状态图标（由 install.sh 生成，请勿手改；卸载执行 ./install.sh -u）
# 后台任务终态（Notification 事件）
[[hooks]]
event = "Notification"
matcher = "task\\.completed"
command = "@SCRIPT@ 任务完成 Glass"

[[hooks]]
event = "Notification"
matcher = "task\\.failed"
command = "@SCRIPT@ 任务失败 Sosumi"

[[hooks]]
event = "Notification"
matcher = "task\\.timed_out"
command = "@SCRIPT@ 任务超时 Funk"

[[hooks]]
event = "Notification"
matcher = "task\\.killed"
command = "@SCRIPT@ 任务被终止 Basso"

[[hooks]]
event = "Notification"
matcher = "task\\.lost"
command = "@SCRIPT@ 任务丢失 Ping"

# 对话回合终态（Stop / StopFailure / Interrupt 事件）
[[hooks]]
event = "Stop"
command = "@SCRIPT@ 对话完成 Glass"

[[hooks]]
event = "StopFailure"
matcher = "*"
command = "@SCRIPT@ 对话失败 Basso"

[[hooks]]
event = "Interrupt"
command = "@SCRIPT@ 对话已中断 Ping"
# kimi-code-notify hooks: end
EOF
)"
HOOKS="${HOOKS//@SCRIPT@/$NOTIFY_SCRIPT}"

printf '\n%s\n' "$HOOKS" >> "$CONFIG"
echo "已写入 ${CONFIG}（共 8 条 hooks，新会话 / /reload 生效）"
echo "提示：tui.toml 的桌面通知改动在会话内执行 /reload-tui 即可生效"
