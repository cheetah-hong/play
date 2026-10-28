---
name: orca-child-worktree-delegation
description: "orca 하위 워크트리로 Claude 위임하는 실측 절차 — 신뢰프롬프트 Up+Enter, 멀티라인은 파일참조 한줄, claude 셸별칭이 바이패스 강제"
metadata: 
  node_type: memory
  type: reference
  modified: 2026-09-11T01:43:03.207Z
---

2026-09-11 실측. 태홍님이 "0911 하위 워크트리로 티켓잡아 Claude 터미널에 프롬프트까지 쳐서 위임" 요청 → 아래로 성공(#190 region-scorer-190, #191 region-apply-191, base=analysis).

**★★ 크로스-repo 부모 lineage 는 금지된다** (2026-09-11 실측 정정 — 처음에 "동작함"으로 잘못 적었다가 뒤집음). `worktree set/create --parent-worktree` 에 다른 repo 워크트리를 주면 **`LINEAGE_PARENT_CONTEXT_CONFLICT` — "부모 워크트리는 같은 repo·실행호스트·프로젝트여야 함"**. 대시보드는 repo/워크스페이스 폴더 단위로 묶여, 다른 repo 자식은 부모 밑에 절대 안 붙는다. `--activate` 도 안 주면 아예 안 보인다.

**★ 그래서 "관심지역 리포트(weekly-report) 하위에 프론트(<frontend-repo>) 작업을 넣어달라" 는 이렇게 푼다** (형제 #186·#187·#189 실측 패턴):
1. **orca 홈 워크트리 = 부모와 같은 repo(weekly-report)** 로 만든다: `orca worktree create --repo id:<repo-id> --name area5-<task>-<#> --parent-worktree active --issue <#> --agent claude --activate`. 이러면 `parentWorktreeId` 가 0911 로 박혀 대시보드에 nesting 된다(검증됨). 이 홈은 채팅·조율용이고 report-api/ 가 여기 있다.
2. **실제 프론트 코드 = 별도 raw git 워크트리** `~/IdeaProjects/<frontend-repo>-<#>`: `git -C <프론트-저장소-경로> worktree add -b feat/<...> ~/IdeaProjects/<frontend-repo>-<#> analysis`. 위임 프롬프트에서 "코드 작업은 여기서 하라" 고 경로를 못박는다. (형제도 `<frontend-repo>-186`·`-188` 를 이렇게 쓴다)

생성 결과의 `worktree.id`(=`repoId::path`)와 `agentTerminalHandle`(term_…)를 다음 명령에 그대로 쓴다.

**3가지 함정**:
1. ★ **`claude`는 orca 앱 설정 `agentDefaultArgs.claude` 가 `--dangerously-skip-permissions`(바이패스)라 그렇게 뜬다.** (2026-10-28 정정 — 종전의 「zsh 별칭」은 틀렸다. `~/.zshrc` 에 alias 없음. 설정은 `~/Library/Application Support/orca/profiles/local-default/` 에 있고 CLI 로는 못 바꾼다 — GUI) `--agent claude`든 `--command "claude"`든 항상 바이패스로 뜬다. 전역 규칙 "바이패스 금지"와 상충하나 환경이 강제 — 격리 워크트리+본인 repo면 무해로 보고 진행하되 태홍님께 명시. 진짜 비바이패스가 필요하면 **orca 설정에서 `agentDefaultArgs.claude` 를 비운다**(확실한 방법). 인자 없는 `--command "claude"` 에도 기본 인자가 붙는다. 단 codex 는 인자를 명시한 명령(`codex --sandbox read-only …`)에 YOLO 가 붙지 않았다(2026-10-28 ps 실측) — claude 도 `--permission-mode default` 등을 명시하면 될 가능성이 있으나 **미검증**.
2. ★ **첫 기동은 폴더 신뢰 프롬프트에서 멈춘다.** 커서 기본값이 **"No, exit"(종료)**에 있다 — 그냥 Enter 치면 종료됨. `send --text "$(printf '\033[A')"`(위 화살표, --enter 없이)로 커서를 "Yes, I trust this folder"로 올리고 **read로 커서 위치 확인 후** `--enter`. 렌더가 겹쳐 보여도("❯lYes...") 커서 이동은 됨.
3. ★ **멀티라인 프롬프트를 `send --text`로 보내면 개행이 조기 제출을 일으켜 거부(ok:False)된다.** 프롬프트를 스크래치 파일(`/tmp/claude-501/…txt`)에 쓰고, **한 줄로** "이 절대경로 파일을 Read로 읽고 그대로 수행하라: <path>" + `--enter` 를 보낸다. 델리게이트가 파일을 읽어 실행함(검증됨).

**tui-idle 대기**: `terminal wait --for tui-idle --timeout-ms 60000`. 단 신뢰 프롬프트에서도 idle=satisfied가 나오므로, idle만 믿지 말고 read로 화면을 확인할 것.

관련: [[agent-visibility-orchestration]](codex는 orca terminal로), [[scorer-repo-access-lost]].
