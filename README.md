# kimi-code-notify

Kimi Code 任务结束时弹系统通知 + 提示音，并区分**成功 / 失败 / 超时 / 终止 / 丢失**。macOS 原生实现（`osascript`），无需安装任何第三方依赖。

> 触发时机：Kimi Code 的**后台任务**（`Bash` / `Agent` 的 `run_in_background=true`）到达终态时。

## 特性

- ✅ 成功 / 失败 / 超时 / 被终止 / 丢失 用**不同提示音**区分
- ✅ macOS 通知中心横幅弹窗（屏幕右上角），即使终端不在前台也会弹
- ✅ 幂等安装 / 一键卸载，自动备份 `config.toml`
- ✅ 无 `osascript` 的环境（如 SSH）自动降级为只播声音 / 纯文本输出

## 快速开始

```bash
git clone <your-repo-url> ~/Project/kimi-code-notify
cd ~/Project/kimi-code-notify
./install.sh        # 写入 hooks 到 ~/.kimi-code/config.toml（自动备份）
```

然后**重启 kimi code 会话**（hooks 在会话启动时加载），之后后台任务结束时就会有通知+声音。

### 先手动试一次

```bash
./notify.sh "测试通知" Glass
```

应立即弹出横幅并播放 `Glass` 音效。若没有：

- 检查 macOS 通知权限：`系统设置 → 通知` → 找到对应的 App（Terminal / iTerm 等）→ 允许横幅通知
- 检查系统音量 / 勿扰模式

## 卸载

```bash
./install.sh -u     # 移除本脚本管理的 hooks 块（保留其余配置）
```

## 工作原理

Kimi Code 的 [Hooks 机制](https://www.kimi.com/code/docs/en/kimi-code-cli/customization/hooks.html)：

- `install.sh` 在 `~/.kimi-code/config.toml` 追加 `[[hooks]]` 规则，监听 `Notification` 事件，用 `matcher` 正则按通知类型区分结果；
- 触发时调用 `notify.sh <消息> <音效>`，脚本通过 `osascript display notification ... sound name ...` 弹横幅并播放提示音；
- 标记块 `# kimi-code-notify hooks: begin / end` 之间的内容由脚本管理，重复安装不会叠加。

## 通知类型（已验证）

从本地 CLI 二进制提取并对照文档确认的后台任务通知类型：

| 类型 | 含义 | 默认音效 |
|---|---|---|
| `task.completed` | 任务成功完成 | `Glass` |
| `task.failed` | 任务失败 | `Sosumi` |
| `task.timed_out` | 任务超时 | `Funk` |
| `task.killed` | 任务被终止（TaskStop 等） | `Basso` |
| `task.lost` | 任务丢失（进程失联） | `Ping` |

非终态通知类型：`task.created`（任务开始）、`task.progress`（进度更新），`install.sh` 未为其配置规则。

macOS 内置音效：`Basso` `Blow` `Bottle` `Frog` `Funk` `Glass` `Hero` `Morse` `Ping` `Pop` `Purr` `Sosumi` `Submarine` `Tink`。

## 定制

- **改消息 / 音效**：编辑 `install.sh` 中 hooks 块的 `command = "@SCRIPT@ ..."` 行，重新运行 `./install.sh`（幂等覆盖）；
- **其他事件**：参考官方 Hooks 文档事件表，例如
  - `Interrupt`（用户 Esc 中断当前回合）
  - `StopFailure`（回合因错误失败）
  - `SessionEnd`（会话关闭）
  - `SubagentStop`（子代理完成）

  可仿照格式自行追加，例如会话结束提醒：

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

修改后在会话内执行 `/reload-tui` 立即生效。`config.toml` 的 hooks 改动需新会话生效。

## 目录结构

```
kimi-code-notify/
├── notify.sh      # 通知+声音脚本：notify.sh <消息> [音效] [标题]
├── install.sh     # 安装/更新/卸载 hooks（-u 卸载）
└── README.md
```

## 常见问题

- **没声音 / 没弹窗**：先 `./notify.sh 测试 Glass` 手动验证 → 查通知权限、系统音量、勿扰。
- **配置了但没反应**：hooks 是**会话启动时**读取的，必须重启会话（或开新会话）；`kimi -p` 单次模式同理。
- **通知重复**：内置桌面通知与本 hooks 各弹一次，将 `tui.toml` 的 `notifications.enabled` 设为 `false` 只留本方案即可。
- **ssh 远程终端**：`osascript` 不可用，会降级为只播 `afplay` 声音；远程主机若无声卡则仅文本输出。
