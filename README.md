# kimi-code-notify

Kimi Code 任务结束时弹系统通知 + 提示音，覆盖**后台任务**与**对话回合**，用**状态 emoji**（✅ / ⏰ / ❌ 等）区分成功 / 失败 / 中断 / 超时。macOS 原生实现，主路径 `osascript`（系统自带，无额外依赖）。

> 触发时机：
> - **后台任务**（`Bash` / `Agent` 的 `run_in_background=true`）到达终态时（`Notification` 事件）
> - **对话回合**结束时（`Stop` / `StopFailure` / `Interrupt` 事件）

## 特性

- ✅ 横幅消息带**状态 emoji**：✅ 完成 / ❌ 失败 / ⏰ 超时 / ⛔ 被终止 / ❓ 丢失 / ✋ 中断
- ✅ 通知**标题显示当前会话名**（hook 调用时从 stdin JSON 自动提取 `session_title`）
- ✅ 不同状态用**不同提示音**区分（Glass / Sosumi / Funk / Basso / Ping）
- ✅ **Bark（iOS 推送）可选接入**：任务结束同步推送 iPhone，配一次后无感生效，标题同样带状态 emoji + 来源设备标识
- ✅ 系统通知用 macOS 自带 `osascript`，无额外依赖；不可用时只播声音 / 纯文本
- ✅ 幂等安装 / 一键卸载，自动备份 `config.toml`

## 依赖

| 工具 | 用途 | 缺失时 |
|---|---|---|
| `osascript`（macOS 自带） | 弹横幅 + 声音（主路径） | 降级为 afplay / 文本 |

> 注：曾使用 `terminal-notifier` 提供彩色状态图标，但在新版 macOS 上通知会被系统丢弃（日志 `app not found`）且进程挂起不退出，已弃用。状态改用 emoji 区分。

## 快速开始

```bash
git clone <your-repo-url> ~/Project/kimi-code-notify
cd ~/Project/kimi-code-notify
./install.sh        # 写入 8 条 hooks 到 ~/.kimi-code/config.toml（自动备份）
```

然后**重启 kimi code 会话**或执行 `/reload`（hooks 在会话启动/重载时读取），之后任务结束就会有通知+声音。

### 先手动试一次

```bash
./notify.sh "测试通知" Glass
```

应立即弹出横幅并播放 `Glass` 音效（标题为默认 "Kimi Code"；hook 调用时才是会话名）。若没有：

- 检查 macOS 通知权限：`系统设置 → 通知` → 找到对应的 App（终端 / Script Editor 等）→ 允许横幅通知
- 检查系统音量 / 勿扰模式

## Bark 推送（可选）

手机（iPhone）也收一条推送：任务失败 / 超时 / 中断时，即使人不在电脑前也能知道。

1. 手机安装 [Bark App](https://apps.apple.com/app/id1403753865)，打开后复制顶部的**设备 key**；
2. 在本机创建配置文件（脚本自动读取，无需改 hooks）：

   ```bash
   mkdir -p ~/.config/kimi-code-notify
   cat > ~/.config/kimi-code-notify/bark.env <<'EOF'
   BARK_URL=https://api.day.app        # 官方服务；自建服务填你的地址（如 http://host:8080）
   BARK_KEY=你的设备key
   # BARK_SOURCE=我的MacBook   # 可选：来源设备名，默认取系统电脑名
   EOF
   chmod 600 ~/.config/kimi-code-notify/bark.env
   ```

3. 验证：

   ```bash
   ./notify.sh "Bark 测试" Glass
   ```

手机应收到一条推送；系统通知照常弹。**未配置 `bark.env`（或没有 `BARK_KEY`）时脚本静默跳过推送**，不影响原行为。推送带**来源标识**（iOS 通知的副标题行，如「来自 AngryShark's MacBook Pro」），方便区分多台设备 / 多个服务发出的通知。

> 提示：`BARK_URL` 支持官方 `https://api.day.app` 与自建 Bark 服务；推送按 `group=kimi-code` 分组，iOS 通知设置里可单独折叠。

## 卸载

```bash
./install.sh -u     # 移除本脚本管理的 hooks 块（保留其余配置）
```

## 工作原理

Kimi Code 的 [Hooks 机制](https://www.kimi.com/code/docs/en/kimi-code-cli/customization/hooks.html)：

- `install.sh` 在 `~/.kimi-code/config.toml` 追加 `[[hooks]]` 规则，共 8 条，监听 `Notification`（后台任务）与 `Stop` / `StopFailure` / `Interrupt`（对话回合）；
- 触发时调用 `notify.sh <消息> <音效>`，脚本按消息文本匹配状态 emoji，用 macOS 自带 `osascript` 弹横幅并播放提示音（`terminal-notifier` 在新版 macOS 上挂起且通知被丢弃，已弃用）；
- **会话名标题**：hook 的输入数据（含 `session_title`）经 stdin 以 JSON 传给命令，`notify.sh` 自动提取作为通知标题；
- 标记块 `# kimi-code-notify hooks: begin / end` 之间的内容由脚本管理，重复安装不会叠加。

### 状态 emoji 映射

| 消息含 | emoji | 场景 |
|---|---|---|
| `完成` / `成功` | ✅ | 任务完成、对话完成 |
| `超时` | ⏰ | 任务超时 |
| `失败` | ❌ | 任务失败、对话失败 |
| `被终止` | ⛔ | 任务被终止（TaskStop 等） |
| `丢失` | ❓ | 任务丢失（进程失联） |
| `中断` | ✋ | 用户中断对话回合 |

## 通知类型（已验证）

### 后台任务（`Notification` 事件）

| 类型 | 含义 | 默认音效 |
|---|---|---|
| `task.completed` | 任务成功完成 | `Glass` |
| `task.failed` | 任务失败 | `Sosumi` |
| `task.timed_out` | 任务超时 | `Funk` |
| `task.killed` | 任务被终止（TaskStop 等） | `Basso` |
| `task.lost` | 任务丢失（进程失联） | `Ping` |

非终态通知类型：`task.created`（任务开始）、`task.progress`（进度更新），未为其配置规则。

### 对话回合

| 事件 | 含义 | 默认音效 |
|---|---|---|
| `Stop` | 每轮对话正常完成（turn 最后一步） | `Glass` |
| `StopFailure` | 对话因模型/错误失败（含请求超时） | `Basso` |
| `Interrupt` | 用户按 Esc 中断当前回合 | `Ping` |

说明：`StopFailure` 事件携带非空的错误类型作为 matcher 值，因此配置 `matcher = "*"` 以确保匹配；`Stop` / `Interrupt` 不带 matcher 值，无需配置 matcher。

macOS 内置音效：`Basso` `Blow` `Bottle` `Frog` `Funk` `Glass` `Hero` `Morse` `Ping` `Pop` `Purr` `Sosumi` `Submarine` `Tink`。

## 定制

- **改消息 / 音效**：编辑 `install.sh` 中 hooks 块的 `command = "@SCRIPT@ ..."` 行，重新运行 `./install.sh`（幂等覆盖）；
- **改状态 emoji**：编辑 `notify.sh` 中的 `case "$MESSAGE"` 映射；
- **其他事件**：参考官方 Hooks 文档事件表（`SessionEnd`、`SubagentStop` 等），可仿照格式自行追加，例如：

  ```toml
  [[hooks]]
  event = "SessionEnd"
  command = "<repo路径>/notify.sh 会话已结束 Purr"
  ```

## 相关配置

终端 UI 的桌面通知由 `~/.kimi-code/tui.toml` 控制（本仓库的 hooks 与之相互独立，二者都会弹通知时可能出现两条，可按需二选一）：

```toml
[notifications]
enabled = true                       # 是否发送桌面通知
notification_condition = "always"    # "unfocused"(仅终端失焦时) | "always"(总是)
```

修改后在会话内执行 `/reload-tui` 立即生效。`config.toml` 的 hooks 改动需 `/reload` 或新会话生效。

## 目录结构

```
kimi-code-notify/
├── notify.sh      # 通知+声音脚本：notify.sh <消息> [音效] [标题]
├── install.sh     # 安装/更新/卸载 hooks（-u 卸载）
└── README.md
```

## 常见问题

- **没声音 / 没弹窗**：先 `./notify.sh 测试 Glass` 手动验证 → 查通知权限、系统音量、勿扰。
- **横幅不弹但 Bark 收到**：若装了旧版 `terminal-notifier`，它在新版 macOS 上会挂起并卡死脚本（通知同时被系统丢弃）——卸载它即可，本方案只依赖系统自带 `osascript`。
- **配置了但没反应**：hooks 是**会话启动/重载时**读取的，必须 `/reload` 或重启会话（或开新会话）；`kimi -p` 单次模式同理。
- **通知重复**：内置桌面通知与本 hooks 各弹一次，将 `tui.toml` 的 `notifications.enabled` 设为 `false` 只留本方案即可。
- **ssh 远程终端**：`osascript` 不可用，会降级为只播 `afplay` 声音；远程主机若无声卡则仅文本输出。
