#!/usr/bin/env bash
# 이 컴퓨터의 하네스가 playbook 원본과 같은지 판정한다. 아무것도 바꾸지 않는다.
#   FAIL = 규칙이 깨진다(작성자 표기 누출·이중 설치 등) → exit 1
#   WARN = 동작은 하나 원본과 다르다(버전·기본값)
set -uo pipefail

PB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
CODEX_DIR="$HOME/.codex"
SETTINGS="$CLAUDE_DIR/settings.json"
FRAGMENT="$PB/global/claude/settings.fragment.json"

# 원본 Mac 에서 검증된 버전 (2026-10-28). 다르면 WARN — 동작 차이가 생기면 여기부터 의심한다.
EXPECTED_CLAUDE="2.1.312"
EXPECTED_CODEX="0.160.0"
EXPECTED_ORCA="1.4.229"
EXPECTED_ECC="1.10.0"

fails=0; warns=0
pass() { printf '  ✅ %s\n' "$*"; }
warn() { printf '  ⚠️  %s\n' "$*"; warns=$((warns + 1)); }
fail() { printf '  ❌ %s\n' "$*"; fails=$((fails + 1)); }
section() { printf '\n## %s\n' "$*"; }

check_commands() {
  section "필수 명령"
  local cmd
  for cmd in git jq python3 gh claude codex orca; do
    if command -v "$cmd" >/dev/null 2>&1; then pass "$cmd"; else fail "$cmd 없음"; fi
  done
}

check_version() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == *"$expected"* ]]; then pass "$name $expected"
  else warn "$name 버전 다름 — 원본 $expected · 현재 ${actual:-없음}"; fi
}

check_versions() {
  section "버전"
  check_version "claude" "$EXPECTED_CLAUDE" "$(claude --version 2>/dev/null | head -1)"
  check_version "codex"  "$EXPECTED_CODEX"  "$(codex --version 2>/dev/null | head -1)"
  check_version "orca"   "$EXPECTED_ORCA"   "$(orca --version 2>/dev/null | head -1)"
  local ecc
  ecc="$(ls "$CLAUDE_DIR/plugins/cache/everything-claude-code/everything-claude-code" 2>/dev/null | sort -V | tail -1)"
  check_version "ECC 플러그인" "$EXPECTED_ECC" "$ecc"
}

check_claude_settings() {
  section "Claude 설정 (~/.claude/settings.json)"
  [[ -f "$SETTINGS" ]] || { fail "settings.json 없음 — ./bootstrap.sh"; return; }

  if jq -e '.attribution.commit == "" and .attribution.pr == "" and .includeCoAuthoredBy == false' \
      "$SETTINGS" >/dev/null; then
    pass "커밋·PR 작성자 표기 차단"
  else
    fail "작성자 표기 차단 꺼짐 — Co-Authored-By 가 커밋에 붙는다"
  fi

  if jq -e '.enabledPlugins["everything-claude-code@everything-claude-code"] == true' "$SETTINGS" >/dev/null; then
    pass "ECC 플러그인 활성"
  else
    fail "ECC 플러그인 비활성 — 리뷰 에이전트(everything-claude-code:*)가 없다"
  fi

  local key expected actual
  for key in model effortLevel tui teammateMode permissions.defaultMode env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS; do
    expected="$(jq -c ".${key}" "$FRAGMENT")"
    actual="$(jq -c ".${key}" "$SETTINGS")"
    if [[ "$expected" == "$actual" ]]; then pass "$key = $actual"
    else warn "$key — 원본 $expected · 현재 $actual"; fi
  done

  local home
  home="$(jq -r '.env.PLAYBOOK_HOME // empty' "$SETTINGS")"
  if [[ -z "$home" && -n "${PLAYBOOK_HOME:-}" ]]; then
    warn "settings.json 에 env.PLAYBOOK_HOME 없음 — 현재 셸 값($PLAYBOOK_HOME)으로 대신 검사. ./bootstrap.sh 로 박을 것"
    home="$PLAYBOOK_HOME"
  fi
  if [[ -n "$home" && -x "$home/bin/codex-review.sh" ]]; then pass "PLAYBOOK_HOME = $home"
  else fail "env.PLAYBOOK_HOME 미설정/잘못됨 — CLAUDE.md 의 \$PLAYBOOK_HOME/bin 호출이 깨진다 (./bootstrap.sh)"; fi

  if jq -e '[.hooks // {} | .. | .command? // empty | select(test("orca/agent-hooks"))] | length > 0' \
      "$SETTINGS" >/dev/null 2>&1; then
    pass "orca 에이전트 훅 등록됨"
  else
    warn "orca 훅 없음 — orca 앱이 Claude 상태를 못 본다. orca 에서 Claude 연동을 켤 것"
  fi
}

check_same_file() {
  local label="$1" src="$2" dst="$3"
  if [[ ! -f "$dst" ]]; then fail "$label 없음 ($dst)"
  elif cmp -s "$src" "$dst"; then pass "$label 원본과 동일"
  else warn "$label 원본과 다름 — diff \"$src\" \"$dst\""; fi
}

check_instructions() {
  section "전역 지침"
  check_same_file "~/.claude/CLAUDE.md" "$PB/global/claude/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
  check_same_file "~/.codex/AGENTS.md"  "$PB/global/codex/AGENTS.md"  "$CODEX_DIR/AGENTS.md"

  local count=0
  [[ -d "$CLAUDE_DIR/agents" ]] && count="$(find "$CLAUDE_DIR/agents" -maxdepth 1 -type f | wc -l | tr -d ' ')"
  if [[ "$count" == "0" ]]; then pass "~/.claude/agents 사본 0개 (ECC 이중 설치 아님)"
  else fail "~/.claude/agents 사본 ${count}개 — 에이전트 이름 해석이 흔들리고 스킬 예산이 넘친다"; fi
}

check_codex() {
  section "codex"
  local key want have
  for key in model model_reasoning_effort; do
    want="$(grep -E "^${key} *=" "$PB/global/codex/config.fragment.toml" | head -1)"
    have="$(grep -E "^${key} *=" "$CODEX_DIR/config.toml" 2>/dev/null | head -1)"
    if [[ "$want" == "$have" ]]; then pass "$have"; else warn "원본 [$want] · 현재 [${have:-없음}]"; fi
  done
  if [[ -f "$CODEX_DIR/auth.json" ]]; then pass "codex 로그인 파일 있음"
  else fail "codex 미로그인 — codex login"; fi
  pass "리뷰 모델(고정) = $(grep -E '^REVIEW_MODEL=' "$PB/bin/codex-review.sh" | grep -oE ':-[^}]+' | cut -c3-)"
}

check_orca_runtime() {
  section "orca 런타임"
  if orca terminal list --json >/dev/null 2>&1; then pass "orca CLI ↔ 앱 연결"
  else warn "orca 앱 응답 없음 — 앱을 켠 상태에서 다시 실행 (orca 안 터미널에서 돌리는 게 정확)"; fi
}

check_git_identity() {
  section "git 신원 · GitHub"
  local email
  email="$(git config --global user.email 2>/dev/null)"
  if [[ "$email" == *"@users.noreply.github.com" ]]; then pass "user.email = $email"
  else warn "user.email 이 noreply 아님(${email:-없음}) — squash 병합 시 작성자가 둘로 집계된다"; fi
  if git config --global --get user.password >/dev/null 2>&1; then
    fail "~/.gitconfig 에 user.password 평문 — 제거할 것(git 은 쓰지도 않는다)"
  fi
  if gh auth status >/dev/null 2>&1; then pass "gh 로그인"; else fail "gh 미로그인 — gh auth login"; fi
}

main() {
  printf '# playbook doctor — %s\n' "$(date '+%Y-%m-%d %H:%M')"
  check_commands
  check_versions
  check_claude_settings
  check_instructions
  check_codex
  check_orca_runtime
  check_git_identity
  printf '\n결과: FAIL %d · WARN %d → %s\n' "$fails" "$warns" "$([[ $fails -eq 0 ]] && echo PASS || echo FAIL)"
  [[ $fails -eq 0 ]]
}

main "$@"
