#!/usr/bin/env sh
set -eu

summary_file=""
status="success"
event="agent.done"
url="${WEBHOOK_URL:-}"
url_from_cli="0"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
skill_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
config_path="${WEBHOOK_SKILLS_CONFIG:-$skill_root/webhook-url.txt}"

while [ $# -gt 0 ]; do
  case "$1" in
    --summary-file)
      summary_file="${2:-}"
      shift 2
      ;;
    --status)
      status="${2:-}"
      shift 2
      ;;
    --event)
      event="${2:-}"
      shift 2
      ;;
    --url)
      url="${2:-}"
      url_from_cli="1"
      shift 2
      ;;
    --help|-h)
      echo "用法：bash scripts/webhook_notify.sh --summary-file /tmp/codex-summary.txt [--status success|error] [--event agent.done] [--url https://...]" >&2
      exit 0
      ;;
    *)
      echo "参数不认识：$1" >&2
      exit 2
      ;;
  esac
done

if [ "$summary_file" = "" ]; then
  echo "缺少 --summary-file" >&2
  exit 2
fi

if [ ! -f "$summary_file" ]; then
  echo "找不到 summary 文件：$summary_file" >&2
  exit 2
fi

if [ "$url" = "" ]; then
  if [ ! -f "$config_path" ]; then
    echo "没有 webhook url：请先写入 $config_path（或用 --url / WEBHOOK_URL）" >&2
    exit 2
  fi
  url="$(tr -d '\r\n' < "$config_path")"
fi

url="$(printf '%s' "$url" | tr -d '\r\n')"
if [ "$url" = "" ]; then
  echo "webhook-url.txt 里是空的：请先把 webhook url 写到 $config_path（只写一行），或者用 --url / WEBHOOK_URL 临时指定。" >&2
  exit 2
fi

case "$url" in
  http://*|https://*)
    ;;
  *)
    echo "webhook url 必须以 http:// 或 https:// 开头：$url" >&2
    exit 2
    ;;
esac

# 如果是通过 --url / WEBHOOK_URL 传进来的，并且本地文件还是空的，就顺手保存一下（下次就不用再传了）
if [ -f "$config_path" ]; then
  saved_url="$(tr -d '\r\n' < "$config_path")"
else
  saved_url=""
fi
if [ "$saved_url" = "" ] && { [ "$url_from_cli" = "1" ] || [ "${WEBHOOK_URL:-}" != "" ]; }; then
  mkdir -p "$(dirname "$config_path")"
  printf '%s' "$url" > "$config_path"
fi

provider="generic"
case "$url" in
  *oapi.dingtalk.com*robot/send*|*dingtalk.com*robot/send*)
    provider="dingtalk"
    ;;
  *open.feishu.cn*open-apis/bot/*hook*|*feishu.cn*open-apis/bot/*hook*)
    provider="feishu"
    ;;
  *api.day.app*|*day.app*)
    provider="bark"
    ;;
esac

need_python3() {
  if command -v python3 >/dev/null 2>&1; then
    return 0
  fi
  echo "需要 python3（用来生成飞书/钉钉 JSON 或 Bark URL 编码），但当前环境找不到 python3" >&2
  exit 2
}

if [ "$provider" = "feishu" ]; then
  need_python3
  json_body="$(python3 - "$status" "$event" "$summary_file" <<'PY'
import json
import sys

status, event, summary_file = sys.argv[1:4]
status_label = {"success": "成功", "error": "失败"}.get(status, status)
summary = open(summary_file, "r", encoding="utf-8", errors="replace").read().rstrip("\n")
text = f"[{status_label}] {event}\n{summary}".strip()
print(json.dumps({"msg_type": "text", "content": {"text": text}}, ensure_ascii=False))
PY
)"

  if [ "${WEBHOOK_TOKEN:-}" != "" ]; then
    curl -fsS -o /dev/null -X POST "$url" \
      -H "Content-Type: application/json; charset=utf-8" \
      -H "Authorization: Bearer $WEBHOOK_TOKEN" \
      --data-binary "$json_body"
  else
    curl -fsS -o /dev/null -X POST "$url" \
      -H "Content-Type: application/json; charset=utf-8" \
      --data-binary "$json_body"
  fi
elif [ "$provider" = "dingtalk" ]; then
  need_python3
  json_body="$(python3 - "$status" "$event" "$summary_file" <<'PY'
import json
import sys

status, event, summary_file = sys.argv[1:4]
status_label = {"success": "成功", "error": "失败"}.get(status, status)
summary = open(summary_file, "r", encoding="utf-8", errors="replace").read().rstrip("\n")
text = f"[{status_label}] {event}\n{summary}".strip()
print(json.dumps({"msgtype": "text", "text": {"content": text}}, ensure_ascii=False))
PY
)"

  if [ "${WEBHOOK_TOKEN:-}" != "" ]; then
    curl -fsS -o /dev/null -X POST "$url" \
      -H "Content-Type: application/json; charset=utf-8" \
      -H "Authorization: Bearer $WEBHOOK_TOKEN" \
      --data-binary "$json_body"
  else
    curl -fsS -o /dev/null -X POST "$url" \
      -H "Content-Type: application/json; charset=utf-8" \
      --data-binary "$json_body"
  fi
elif [ "$provider" = "bark" ]; then
  need_python3
  encoded_text="$(python3 - "$status" "$event" "$summary_file" <<'PY'
import sys
from urllib.parse import quote

status, event, summary_file = sys.argv[1:4]
status_label = {"success": "成功", "error": "失败"}.get(status, status)
summary = open(summary_file, "r", encoding="utf-8", errors="replace").read().rstrip("\n")
text = f"[{status_label}] {event}\n{summary}".strip()
print(quote(text, safe=""))
PY
)"

  base="$url"
  query=""
  case "$base" in
    *\?*)
      query="?${base#*\?}"
      base="${base%%\?*}"
      ;;
  esac
  base="${base%/}"
  final_url="$base/$encoded_text$query"

  if [ "${WEBHOOK_TOKEN:-}" != "" ]; then
    curl -fsS -o /dev/null "$final_url" \
      -H "Authorization: Bearer $WEBHOOK_TOKEN"
  else
    curl -fsS -o /dev/null "$final_url"
  fi
else
  # 通用 webhook：发纯文本 + 两个头（event/status）
  if [ "${WEBHOOK_TOKEN:-}" != "" ]; then
    curl -fsS -o /dev/null -X POST "$url" \
      -H "Content-Type: text/plain; charset=utf-8" \
      -H "X-Webhook-Event: $event" \
      -H "X-Webhook-Status: $status" \
      -H "Authorization: Bearer $WEBHOOK_TOKEN" \
      --data-binary "@$summary_file"
  else
    curl -fsS -o /dev/null -X POST "$url" \
      -H "Content-Type: text/plain; charset=utf-8" \
      -H "X-Webhook-Event: $event" \
      -H "X-Webhook-Status: $status" \
      --data-binary "@$summary_file"
  fi
fi

echo "已发送"
