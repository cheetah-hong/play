#!/usr/bin/env bash
# 현재 orca 워크트리의 보드 상태·코멘트를 갱신한다 (세션 시작·종료 프로토콜 7항).
#   orca-status.sh in-progress "Day 05 착수 — 인증 필터"
#   orca-status.sh completed   "Day 05 완료 — PR #42"
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/orca-common.sh"

STATUSES="todo in-progress in-review completed"
status="${1:-}" comment="${2:-}"

if [[ -z "$status" || -z "$comment" || " $STATUSES " != *" $status "* ]]; then
  echo "usage: orca-status.sh <${STATUSES// /|}> \"<코멘트>\"" >&2
  exit 2
fi

orca_json worktree set --worktree "$ORCA_WORKTREE" --workspace-status "$status" --comment "$comment" >/dev/null
echo "orca: $status — $comment"
