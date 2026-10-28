#!/usr/bin/env bash
# playbook memory/*.md(프로젝트 무관 교훈)를 대상 프로젝트의 Claude 자동 메모리에 넣는다.
#   install-memory.sh ~/IdeaProjects/my-project
# 메모리 위치는 ~/.claude/projects/<저장소 루트 경로의 영숫자 외 문자를 '-' 로>/memory/ 이다.
# 워크트리에서 돌려도 본 저장소 루트 기준으로 계산한다(Claude Code 와 같은 규칙).
# 이미 같은 이름의 파일이 있으면 덮지 않는다. MEMORY.md 색인에는 없는 줄만 덧붙인다.
set -euo pipefail

PB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="${1:-}"
[[ -n "$target" && -d "$target" ]] || { echo "usage: install-memory.sh <프로젝트-경로>" >&2; exit 2; }

root="$(cd "$target" && pwd)"
if common="$(git -C "$root" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; then
  root="$(dirname "$common")"
fi
encoded="$(printf '%s' "$root" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g')"
memdir="$HOME/.claude/projects/$encoded/memory"
mkdir -p "$memdir"
index="$memdir/MEMORY.md"
[[ -f "$index" ]] || printf '# Memory Index\n\n' > "$index"

added=0
for src in "$PB"/memory/*.md; do
  name="$(basename "$src")"
  [[ "$name" == "INDEX.md" ]] && continue
  if [[ -e "$memdir/$name" ]]; then
    echo "= 있음(건너뜀): $name"
  else
    cp "$src" "$memdir/$name"
    echo "✔ 추가: $name"
    added=$((added + 1))
  fi
  line="$(grep -F "($name)" "$PB/memory/INDEX.md" || true)"
  if [[ -n "$line" ]] && ! grep -qF "($name)" "$index"; then
    printf '%s\n' "$line" >> "$index"
  fi
done
echo "메모리: $memdir (새로 ${added}개)"
