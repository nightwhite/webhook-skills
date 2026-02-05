# webhook-skills

这个项目是一个 **通知用的 skill**：你把“我做完了 / 我失败了”这句话交给它，它就会发到你指定的平台。

目前支持：

- 飞书群机器人 webhook
- 钉钉群机器人 webhook
- Bark（手机推送）
- 以及你自建的普通 webhook（任意 HTTP 接口）

## 它怎么记住你的 webhook 地址？

它会在项目根目录用一个文件记住地址：`webhook-url.txt`

- 这个文件 **默认不存在**（方便部署时用“有没有这个文件”判断是否配置过）
- 第一次你给它一个 URL，它会 **自动保存** 到 `webhook-url.txt`
- 这个文件已经被 `.gitignore` 忽略了，不会被提交到仓库

## 最常用的用法（推荐）

### macOS / Linux

1) 把要通知的文字写进一个文件（随便放哪都行）：

```bash
printf '%s\n' "我做完了：xxx" > /tmp/codex-summary.txt
```

2) 第一次发通知（顺便把 URL 存下来）：

```bash
bash scripts/webhook_notify.sh --summary-file /tmp/codex-summary.txt --status success --event agent.done --url "你的webhook地址"
```

后面再发就不用带 `--url` 了：

```bash
bash scripts/webhook_notify.sh --summary-file /tmp/codex-summary.txt --status success --event agent.done
```

### Windows（PowerShell）

1) 写入通知内容：

```powershell
"我做完了：xxx" | Set-Content -Encoding UTF8 -Path C:\Temp\codex-summary.txt
```

2) 第一次发通知（顺便把 URL 存下来）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\webhook_notify.ps1 -SummaryFile "C:\Temp\codex-summary.txt" -Status success -Event agent.done -Url "你的webhook地址"
```

后面再发就不用带 `-Url` 了：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\webhook_notify.ps1 -SummaryFile "C:\Temp\codex-summary.txt" -Status success -Event agent.done
```

## 参数是啥意思？

- `--summary-file` / `-SummaryFile`：你要通知的文字在哪个文件里
- `--status` / `-Status`：成功还是失败（`success` 或 `error`）
- `--event` / `-Event`：你随便起个“事件名”，方便你自己区分（比如 `agent.done`、`deploy.done`）
- `--url` / `-Url`：第一次用的时候把 webhook 地址带上（脚本会自动写进 `webhook-url.txt`）

## 不同平台会发成什么样？

脚本会“看 URL 长什么样”自动判断：

- 飞书：发送飞书机器人需要的 JSON 文本消息
- 钉钉：发送钉钉机器人需要的 JSON 文本消息
- Bark：把消息内容拼到 URL 里做一次请求（就是 Bark 的常规用法）
- 普通 webhook：`POST` 一段纯文本，同时带两个头：
  - `X-Webhook-Event`（事件名）
  - `X-Webhook-Status`（success/error）

## 可选：你的自建 webhook 需要 token（通行证）

你可以设置一个“环境变量” `WEBHOOK_TOKEN`（就是在系统里临时存一段字符串），脚本会自动加请求头：

`Authorization: Bearer 你的token`

- macOS / Linux：

```bash
export WEBHOOK_TOKEN="xxx"
```

- Windows（PowerShell）：

```powershell
$env:WEBHOOK_TOKEN="xxx"
```

## 常见问题

1) **`webhook-url.txt` 没有/是空的怎么办？**  
第一次发送时带上 `--url` / `-Url` 就行，它会自动保存。

2) **飞书/钉钉机器人开了“签名/加签”怎么办？**  
现在脚本没做加签。如果你必须用签名，我可以按你那边的规则把签名也补上。
