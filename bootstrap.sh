#!/usr/bin/env bash
# playbook 하네스를 이 컴퓨터에 설치한다. 여러 번 돌려도 안전하다(멱등).
#   ./bootstrap.sh            설치
#   ./bootstrap.sh --dry-run  무엇을 바꿀지만 출력
# 덮어쓰는 파일은 모두 <파일>.bak-playbook-<시각> 으로 먼저 백업한다.
set -euo pipefail

PB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

CLAUDE_DIR="$HOME/.claude"
CODEX_DIR="$HOME/.codex"
ECC_MARKETPLACE_URL="https://github.com/affaan-m/everything-claude-code.git"
ECC_PLUGIN="everything-claude-code@everything-claude-code"

log()  { printf '[%s] %s\n' "$(date +%H:%M)" "$*"; }
run()  { if ((DRY_RUN)); then log "DRY: $*"; else "$@"; fi; }
need() { command -v "$1" >/dev/null 2>&1 || { log "❌ 필수 명령 없음: $1 — $2"; exit 1; }; }

backup() {
  [[ -f "$1" ]] && run cp -p "$1" "$1.bak-playbook-$STAMP"
  return 0
}

# src 를 dst 로 설치한다. 내용이 같으면 건너뛴다.
install_file() {
  local src="$1" dst="$2"
  if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
    log "= 동일: $dst"
    return 0
  fi
  backup "$dst"
  run mkdir -p "$(dirname "$dst")"
  run cp "$src" "$dst"
  log "✔ 설치: $dst"
}

# 생성된 내용(tmp)을 dst 와 비교해 다르면 백업 후 교체한다.
replace_if_changed() {
  local tmp="$1" dst="$2"
  if [[ -f "$dst" ]] && cmp -s "$tmp" "$dst"; then
    log "= 동일: $dst"
  elif ((DRY_RUN)); then
    log "DRY: $dst 갱신 예정 — 변경분:"
    diff <(cat "$dst" 2>/dev/null || true) "$tmp" | sed 's/^/    /' || true
  else
    backup "$dst"
    mv "$tmp" "$dst"
    log "✔ 갱신: $dst"
    return 0
  fi
  rm -f "$tmp"
}

check_prerequisites() {
  need git     "Xcode CLT 또는 brew install git"
  need jq      "brew install jq"
  need python3 "brew install python"
  need gh      "brew install gh && gh auth login"
  need claude  "Claude Code 설치"
  need codex   "brew install codex 또는 npm i -g @openai/codex"
  need orca    "orca 앱 설치 후 CLI 활성화"
}

install_ecc_plugin() {
  if claude plugin list 2>/dev/null | grep -q "everything-claude-code"; then
    log "= ECC 플러그인 설치돼 있음"
    return 0
  fi
  run claude plugin marketplace add "$ECC_MARKETPLACE_URL"
  run claude plugin install "$ECC_PLUGIN"
}

# settings.json 은 통째로 덮지 않는다 — fragment 의 키만 깊은 병합한다.
# orca 가 등록한 hooks 등 이 머신 고유 키는 그대로 남는다.
# env.PLAYBOOK_HOME 을 이 clone 경로로 박아, 세션 안의 Bash 가 $PLAYBOOK_HOME/bin 을 찾게 한다.
merge_claude_settings() {
  local dst="$CLAUDE_DIR/settings.json" tmp fragment
  tmp="$(mktemp)"
  fragment="$(jq --arg pb "$PB" '.env.PLAYBOOK_HOME = $pb' "$PB/global/claude/settings.fragment.json")"
  if [[ -f "$dst" ]]; then
    jq --argjson frag "$fragment" '. * $frag' "$dst" > "$tmp"
  else
    printf '%s\n' "$fragment" > "$tmp"
  fi
  run mkdir -p "$CLAUDE_DIR"
  replace_if_changed "$tmp" "$dst"
}

warn_ecc_copies() {
  local count
  [[ -d "$CLAUDE_DIR/agents" ]] || return 0   # 폴더가 없으면 사본도 없다 (find 실패로 set -e 종료 방지)
  count="$(find "$CLAUDE_DIR/agents" -maxdepth 1 -type f | wc -l | tr -d ' ')"
  if [[ "$count" != "0" ]]; then
    log "⚠️  ~/.claude/agents 에 사본 ${count}개 — ECC 이중 설치 의심. 자동 삭제하지 않는다."
    log "    확인 후 격리: mkdir -p ~/.claude/_removed && mv ~/.claude/agents ~/.claude/_removed/"
  fi
}

merge_codex_config() {
  local dst="$CODEX_DIR/config.toml" tmp
  tmp="$(mktemp)"
  python3 "$PB/bin/lib/merge_toml_top.py" "$dst" "$PB/global/codex/config.fragment.toml" > "$tmp"
  run mkdir -p "$CODEX_DIR"
  replace_if_changed "$tmp" "$dst"
}

main() {
  log "playbook: $PB"
  ((DRY_RUN)) && log "※ dry-run — 아무것도 바꾸지 않는다"
  check_prerequisites
  install_ecc_plugin
  merge_claude_settings
  install_file "$PB/global/claude/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
  warn_ecc_copies
  install_file "$PB/global/codex/AGENTS.md" "$CODEX_DIR/AGENTS.md"
  merge_codex_config
  ((DRY_RUN)) || chmod +x "$PB"/bin/*.sh "$PB"/doctor.sh
  log "다음: Claude Code 를 재시작한 뒤 $PB/doctor.sh 로 판정"
  log "프로젝트별 메모리 이식: $PB/bin/install-memory.sh <프로젝트-경로>"
}

main "$@"
