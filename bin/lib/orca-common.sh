# orca 래퍼 공통 함수 — bin/*.sh 가 source 한다.
# 'active' 선택자는 **현재 디렉터리가 속한 orca 워크트리**로 해석된다. orca 밖에서 돌리면
# selector_not_found 로 실패하므로 ORCA_WORKTREE=path:<절대경로> 등으로 대상을 지정할 수 있다.
ORCA_WORKTREE="${ORCA_WORKTREE:-active}"

# orca 명령을 --json 으로 실행하고, ok:false 면 오류 메시지를 stderr 로 내고 실패한다.
# 성공 시 JSON 을 stdout 으로 낸다.
orca_json() {
  local out
  out="$(orca "$@" --json 2>&1)" || true
  if ! python3 -c 'import json,sys; sys.exit(0 if json.loads(sys.argv[1]).get("ok") else 1)' "$out" 2>/dev/null; then
    printf 'orca %s 실패: %s\n' "$1 $2" \
      "$(python3 -c 'import json,sys
try: e=json.loads(sys.argv[1]).get("error",{}); print(e.get("code",""), "—", e.get("message",""))
except ValueError: print(sys.argv[1][:300])' "$out")" >&2
    return 1
  fi
  printf '%s\n' "$out"
}
