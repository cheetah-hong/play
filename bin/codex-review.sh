#!/usr/bin/env bash
# codex 1차 코드리뷰를 orca 터미널(대화형 TUI, read-only)로 띄우고 회수한다.
# 사람이 orca 화면에서 리뷰 진행을 직접 볼 수 있게 하는 것이 목적이다 — Bash 백그라운드 금지.
#
#   codex-review.sh prepare <base> [outdir]   diff(미커밋·미추적 포함)·프롬프트를 절대경로 파일로 만든다
#   codex-review.sh start   <prompt-file> [title]   터미널을 띄우고 프롬프트를 보낸다 → handle 출력
#   codex-review.sh status  <handle>   RUNNING | APPROVAL | STALLED | CAPACITY | UPDATE | BOOTING | IDLE
#   codex-review.sh wait    <handle> [timeout-sec]   RUNNING 이 끝날 때까지 폴링 (기본 3600초)
#   codex-review.sh approve <handle>   승인 모달에 'p'(Yes, don't ask) — 엔터 없이 단일 핫키
#   codex-review.sh read    <handle> [limit]   누적 출력(스피너 잔상 정리)
#   codex-review.sh close   <handle>
#
# 환경변수: REVIEW_MODEL · REVIEW_EFFORT 로 모델을 바꿀 수 있다 (기본값은 아래 고정).
set -euo pipefail

PB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PB/bin/lib/orca-common.sh"
REVIEW_MODEL="${REVIEW_MODEL:-gpt-5.6-sol}"
REVIEW_EFFORT="${REVIEW_EFFORT:-high}"
READY_TIMEOUT_SEC=120
POLL_SEC=20
IDLE_CONFIRM=3       # 연속 IDLE 표본 수 — 이만큼 이어져야 완료로 본다
IDLE_GAP_SEC=5

# 화면 판정 문자열 (codex-cli 0.160.0 · 2026-10-28 실측). codex 업데이트로 문구가 바뀌면 여기만 고친다.
READY_MARK='Context [0-9]+% used'          # 하단 상태줄 — 이게 떠야 입력을 받는다
RUNNING_MARK='esc to interrupt'
APPROVAL_MARK="Would you like to run|don't ask"
UPDATE_MARK='Update available|Skip until next version'
CAPACITY_MARK='at capacity'
STALL_MARK='No agents completed yet|Finished waiting'

die() { printf 'codex-review: %s\n' "$*" >&2; exit 1; }
usage() { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

# orca --json 응답에서 화면 텍스트만 꺼낸다 (키 이름이 버전마다 조금씩 달라 넓게 줍는다).
screen_text() {
  orca terminal read --terminal "$1" --screen --json 2>/dev/null | python3 -c '
import json, sys
def walk(node):
    if isinstance(node, dict):
        for key, value in node.items():
            if key in ("tail", "text", "screen", "lines", "output", "content") and isinstance(value, (str, list)):
                yield "\n".join(map(str, value)) if isinstance(value, list) else value
            else:
                yield from walk(value)
    elif isinstance(node, list):
        for item in node:
            yield from walk(item)
try:
    print("\n".join(walk(json.load(sys.stdin))))
except ValueError:
    pass
'
}

state_of() {
  local text
  text="$(screen_text "$1")"
  if   grep -Eq "$UPDATE_MARK"   <<<"$text"; then echo UPDATE
  elif grep -Eq "$APPROVAL_MARK" <<<"$text"; then echo APPROVAL
  elif grep -Eq "$RUNNING_MARK"  <<<"$text"; then
    if grep -Eq "$STALL_MARK" <<<"$text"; then echo STALLED; else echo RUNNING; fi
  elif grep -Eq "$CAPACITY_MARK" <<<"$text"; then echo CAPACITY
  elif grep -Eq "$READY_MARK"    <<<"$text"; then echo IDLE
  else echo BOOTING; fi
}

cmd_prepare() {
  local base="${1:-}" outdir="${2:-}"
  [[ -n "$base" ]] || die "prepare <base> — 비교 기준 브랜치/커밋이 필요하다"
  git rev-parse --verify --quiet "$base" >/dev/null || die "기준 '$base' 를 찾을 수 없다"
  local repo stamp
  repo="$(git rev-parse --show-toplevel)"
  stamp="$(date +%Y%m%d-%H%M%S)"
  outdir="${outdir:-${TMPDIR:-/tmp}/codex-review-$(basename "$repo")-$stamp}"
  mkdir -p "$outdir"
  outdir="$(cd "$outdir" && pwd)"

  # 커밋 전 검수 규칙상 변경은 워킹트리에 있다 → base...HEAD 가 아니라 base 대 워킹트리로 뜬다.
  git -C "$repo" diff "$base" > "$outdir/review.diff"
  git -C "$repo" ls-files --others --exclude-standard | while IFS= read -r path; do
    git -C "$repo" diff --no-index -- /dev/null "$path" >> "$outdir/review.diff" || true
  done
  { git -C "$repo" diff --name-only "$base"; git -C "$repo" ls-files --others --exclude-standard; } \
    | sort -u > "$outdir/files.txt"
  [[ -s "$outdir/review.diff" ]] || die "기준 '$base' 대비 변경이 없다"

  local ci="(CI 결과 미제공 — 필요하면 CI_RESULT_FILE=<파일> 로 넘긴다. read-only 샌드박스는 네트워크가 막혀 codex 가 gh 로 조회하지 못한다)"
  [[ -n "${CI_RESULT_FILE:-}" ]] && ci="$(cat "$CI_RESULT_FILE")"
  REPO="$repo" BASE="$base" HEAD_SHA="$(git -C "$repo" rev-parse --short HEAD)" \
  DIFF="$outdir/review.diff" FILES="$outdir/files.txt" CI="$ci" \
    python3 -c '
import os, sys
text = open(sys.argv[1], encoding="utf-8").read()
for key, env in (("REPO_DIR", "REPO"), ("BASE", "BASE"), ("HEAD", "HEAD_SHA"),
                 ("DIFF_FILE", "DIFF"), ("FILES_FILE", "FILES"), ("CI_RESULT", "CI")):
    text = text.replace("{{%s}}" % key, os.environ[env])
sys.stdout.write(text)
' "$PB/prompts/codex-review.md" > "$outdir/prompt.md"
  printf 'diff   : %s (%s 파일)\nprompt : %s\n다음   : %s start %s\n' \
    "$outdir/review.diff" "$(wc -l < "$outdir/files.txt" | tr -d ' ')" "$outdir/prompt.md" "$0" "$outdir/prompt.md"
}

cmd_start() {
  local prompt="${1:-}" title="${2:-codex-review}"
  [[ "$prompt" == /* && -f "$prompt" ]] || die "start <절대경로-프롬프트파일> — codex 가 파일을 직접 읽으므로 절대경로여야 한다"
  local launch handle
  # check_for_update_on_startup=false: 업데이트 모달이 뜨면 입력이 그 모달로 빨려 들어간다.
  #   (예전 규칙의 env CODEX_DISABLE_UPDATE_CHECK=1 은 0.160.0 바이너리에 없는 이름이라 효과가 없다 — 2026-10-28 실측)
  # --sandbox read-only: orca 앱 기본 인자(agentDefaultArgs.codex)가 YOLO 라 반드시 명시한다.
  #   명시하면 /status 에 "Permissions: Read Only" 로 뜬다(실측). 리뷰어에게 쓰기 권한을 주지 않는다.
  launch="codex --sandbox read-only -m $REVIEW_MODEL -c model_reasoning_effort=$REVIEW_EFFORT -c check_for_update_on_startup=false"
  handle="$(orca_json terminal create --worktree "$ORCA_WORKTREE" --title "$title" --command "$launch" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["terminal"]["handle"])')" \
    || die "terminal create 실패 — orca 앱이 켜져 있고 orca 워크트리 안(또는 ORCA_WORKTREE 지정)인지 확인"

  local waited=0 state
  while :; do
    state="$(state_of "$handle")"
    [[ "$state" == IDLE ]] && break
    # 그래도 업데이트 모달이 뜨면 ESC(= skip) 한 번. 숫자+엔터는 agent_prompt_blocked 로 거부된다.
    [[ "$state" == UPDATE ]] && orca terminal send --terminal "$handle" --text $'\x1b' >/dev/null
    (( waited >= READY_TIMEOUT_SEC )) && die "codex 가 ${READY_TIMEOUT_SEC}초 안에 준비되지 않음 (state=$state, handle=$handle)"
    sleep 3; waited=$((waited + 3))
  done

  # 여러 줄을 --text 로 밀면 개행이 조기 제출을 일으켜 거부된다 → 파일 참조 한 줄로 보낸다.
  orca_json terminal send --terminal "$handle" --enter \
    --text "다음 절대경로 파일을 읽고 그 지시를 그대로 수행하라: $prompt" >/dev/null \
    || die "프롬프트 전송 실패 (agent_prompt_blocked 면 모달 상태 — status 로 확인)"
  # 세션이 바뀌어도 회수할 수 있게 프롬프트 옆에 핸들을 남긴다.
  echo "$handle" > "$(dirname "$prompt")/codex_handle"
  echo "$handle"
}

cmd_wait() {
  local handle="${1:?handle}" timeout="${2:-3600}" waited=0 state idle_streak=0 delay
  while :; do
    state="$(state_of "$handle")"
    # codex 가 도구(파일 읽기 등)를 쓰는 순간엔 'esc to interrupt' 가 잠깐 사라진다 →
    # 한 번의 IDLE 은 완료가 아니다. IDLE_CONFIRM 번 연속(IDLE_GAP_SEC 간격)일 때만 DONE (2026-10-28 실측 오판).
    if [[ "$state" == IDLE ]]; then
      idle_streak=$((idle_streak + 1))
      (( idle_streak >= IDLE_CONFIRM )) && { echo "DONE"; return 0; }
    else
      idle_streak=0
    fi
    case "$state" in
      APPROVAL) echo "APPROVAL — '$0 approve $handle' 로 접두 허용"; return 3 ;;
      STALLED)  echo "STALLED — 먼저 기다린다. 끝내 안 되면 '중간 보고'를 요청한다(최종이라 부르지 말 것)"; return 4 ;;
      CAPACITY) echo "CAPACITY — 모델 혼잡. close 후 잠시 뒤 재시도하거나 REVIEW_MODEL=<다른 모델> 로 다시 start (모델 변경은 로그에 명시)"; return 6 ;;
    esac
    (( waited >= timeout )) && { echo "TIMEOUT ($state)"; return 5; }
    delay="$POLL_SEC"; (( idle_streak > 0 )) && delay="$IDLE_GAP_SEC"
    sleep "$delay"; waited=$((waited + delay))
  done
}

cmd_read() {
  local handle="${1:?handle}" limit="${2:-400}"
  orca terminal read --terminal "$handle" --limit "$limit" --json | python3 -c '
import json, re, sys
data = json.load(sys.stdin)
result = data.get("result", data)
result = result.get("terminal", result)
tail = result.get("tail") or result.get("lines") or result.get("text") or ""
text = "\n".join(map(str, tail)) if isinstance(tail, list) else str(tail)
text = re.sub(r"(Working[^\n]*\n)+", "", text)
print(re.sub(r"[ \t]{2,}", " ", text))
'
}

main() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    prepare) cmd_prepare "$@" ;;
    start)   cmd_start "$@" ;;
    status)  state_of "${1:?handle}" ;;
    wait)    cmd_wait "$@" ;;
    approve) orca terminal send --terminal "${1:?handle}" --text "p" ;;   # --enter 붙이면 agent_prompt_blocked
    read)    cmd_read "$@" ;;
    close)   orca terminal close --terminal "${1:?handle}" ;;
    *)       usage ;;
  esac
}

main "$@"
