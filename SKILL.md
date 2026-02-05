---
name: webhook-skills
description: "Do notification tasks by sending a webhook via curl, with auto-saved URL in webhook-url.txt (next to SKILL.md). Supports Feishu (飞书), DingTalk (钉钉), Bark, and generic webhooks. Each time: if webhook-url.txt is missing/empty, ask the user for the webhook URL, save it, then notify. Works across Windows/macOS/Linux."
---

# Webhook Skills

这个 skill 的作用：**发通知**。

主要支持：

- 飞书（群机器人 webhook）
- 钉钉（群机器人 webhook）
- Bark（手机推送）
- 以及你自己的普通 webhook（自建服务、任意 HTTP 接口）

核心思路很简单：每次要通知时，先找 `webhook-url.txt` 里有没有 URL，有就直接发；没有就问你要一个 URL，保存起来，再发。

## 阶段 1：拿到 webhook url（每次都先检查一下）

默认配置文件：`./webhook-url.txt`（和 `SKILL.md` 放在同一个目录；项目里默认不带这个文件，第一次保存 url 才会创建）

每次要发通知之前，都先做这件事：

1) 先看 `./webhook-url.txt` 里有没有内容
2) 如果有内容：直接用它当 webhook url
3) 如果没内容（空文件/没创建）：就 **在对话里问用户要一个 webhook url**

你可以这么问（照抄就行）：

> 你把要接收通知的 webhook 地址发我一下（必须以 http:// 或 https:// 开头）。我拿到后会自动保存到 `webhook-url.txt`，下次就不用再问了。

用户把 url 发你之后：

- 简单检查一下：是不是 `http://` 或 `https://` 开头
- 然后把它写进 `./webhook-url.txt`（没有这个文件就新建；只写一行就行，不要写别的）
- 或者更省事：第一次发送时直接带上 `--url` / `-Url` 参数，脚本会自动把 url 写进 `webhook-url.txt`

### `webhook-url.txt` 应该写什么（按你用的平台）

你最终就是把“机器人给你的那个 webhook 地址”原样贴进去。

- 飞书：一般长这样（示例）  
  `https://open.feishu.cn/open-apis/bot/v2/hook/xxxxxx`
- 钉钉：一般长这样（示例）  
  `https://oapi.dingtalk.com/robot/send?access_token=xxxxxx`
- Bark：建议写“前半段”（示例）  
  `https://api.day.app/你的key/Codex`  
  说明：后面的“消息正文”会由脚本自动拼到 URL 最后面，所以你这里不用手动写正文。

## 阶段 2：调用（每次要通知就跑）

目标：发出一次 webhook 请求，告诉对方“成功/失败 + 简短说明”。

最稳的方式：先把要通知的那段话写进一个文件，然后跑脚本发送（脚本内部就是 `curl`，只是帮你自动适配飞书/钉钉/Bark/普通 webhook 的格式）。

### macOS / Linux（bash）

```bash
printf '%s\n' "我做完了：xxx" > /tmp/codex-summary.txt
bash scripts/webhook_notify.sh --summary-file /tmp/codex-summary.txt --status success --event agent.done
```

如果你是第一次用、`webhook-url.txt` 还没保存过 URL：把用户给你的 URL 直接带上（脚本会自动写入 `webhook-url.txt`，下次就不用再传了）：

```bash
bash scripts/webhook_notify.sh --summary-file /tmp/codex-summary.txt --status success --event agent.done --url "https://example.com/your-webhook"
```

### Windows（PowerShell）

> 脚本里用的是 `curl.exe`，不怕 PowerShell 的别名坑。

```powershell
"我做完了：xxx" | Set-Content -Encoding UTF8 -Path C:\Temp\codex-summary.txt
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\webhook_notify.ps1 -SummaryFile "C:\Temp\codex-summary.txt" -Status success -Event agent.done
```

第一次用还没保存 URL 的话，也可以这样（会自动写入 `webhook-url.txt`）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\webhook_notify.ps1 -SummaryFile "C:\Temp\codex-summary.txt" -Status success -Event agent.done -Url "https://example.com/your-webhook"
```

### 可选：如果你的 webhook 需要 token

如果你用的是“自建 webhook”，而且它需要 token（通行证），就设置环境变量 `WEBHOOK_TOKEN`：

- macOS / Linux：`export WEBHOOK_TOKEN="xxx"`
- Windows：`$env:WEBHOOK_TOKEN="xxx"`

## 你的服务会收到什么（payload）

不同平台收到的东西不一样（不用深究，脚本会自动处理）：

- 飞书/钉钉：群里会收到一条“文本消息”（内容就是你的总结，前面会带上成功/失败 + 事件名）
- Bark：手机会收到一条推送（内容同上）
- 普通 webhook（你自己的接口）：会发一个 `POST`，body 是纯文本；同时带两个头：  
  `X-Webhook-Event` 和 `X-Webhook-Status`

如果你用的是“自建 webhook”，但你希望它收到的是 **JSON**（不是纯文本），你把你想要的 JSON 格式发我，我再把“通用 webhook”这条发送方式升级成 JSON 版。

## 让它在“对话结束”时通知

当你准备输出最终总结回复之前：

1) 先把你要发出去的总结写到一个临时文件（比如 `/tmp/codex-summary.txt` 或 `C:\\Temp\\codex-summary.txt`）
2) 跑上面的通知命令（bash / PowerShell 脚本）发 webhook
3) 再把同样的总结回复给用户

如果 webhook 发送失败：不要卡死流程，照样把主要工作总结回复出去，同时把失败原因简单写进总结里。
