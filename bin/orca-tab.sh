#!/usr/bin/env bash
# HTML 등 산출물을 orca 브라우저 탭으로 연다. macOS `open` 은 쓰지 않는다
# (orca 밖 기본 브라우저로 열려 맥락에서 떨어지고, orca 가 기본 브라우저면 탭이 중복된다).
#   orca-tab.sh briefing/day-05-report.html
# 같은 URL 탭이 이미 있으면 새로 만들지 않는다. --focus 는 붙이지 않는다(직전 페이지 복제 실측).
# 내용을 고친 뒤 다시 보려면: orca reload --page <browserPageId>
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/orca-common.sh"

file="${1:-}"
[[ -n "$file" && -f "$file" ]] || { echo "usage: orca-tab.sh <파일>" >&2; exit 2; }

abs="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
url="file://$abs"

tabs_json="$(orca_json tab list --worktree "$ORCA_WORKTREE")" || exit 1
existing="$(URL="$url" python3 -c '
import json, os, sys
tabs = json.load(sys.stdin)["result"].get("tabs", [])
hits = [t for t in tabs if t.get("url") == os.environ["URL"]]
print(hits[0].get("browserPageId", "?") if hits else "")
' <<<"$tabs_json")"

if [[ -n "$existing" ]]; then
  echo "이미 열림: $url (page $existing) — 갱신은 orca reload --page $existing"
  exit 0
fi

created="$(orca_json tab create --worktree "$ORCA_WORKTREE" --url "$url")" || exit 1
page="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["result"].get("browserPageId", "?"))' <<<"$created")"
echo "열림: $url (page $page)"
