#!/usr/bin/env sh
set -eu

if [ "${1:-}" = "" ]; then
  echo "用法：bash scripts/webhook_init.sh \"https://example.com/your-webhook\"" >&2
  exit 2
fi

url="$1"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
skill_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
config_path="${WEBHOOK_SKILLS_CONFIG:-$skill_root/webhook-url.txt}"

config_dir="$(dirname "$config_path")"
mkdir -p "$config_dir"

printf '%s' "$url" > "$config_path"

echo "已写入：$config_path"
