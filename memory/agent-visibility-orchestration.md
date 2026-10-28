---
name: agent-visibility-orchestration
description: 외부 CLI 에이전트(codex 등)는 orca terminal 로 띄워 태홍님이 직접 보게 한다. Bash 백그라운드 금지
metadata: 
  node_type: memory
  type: feedback
  modified: 2026-09-08T00:15:07.170Z
---

태홍님 지시 (2026-08-04, Day 02) — **에이전트를 사람이 못 보는 곳에서 돌리지 말 것.**

> "다른 에이전트들은 다 보이는데 리뷰 맡긴 sol 콘솔은 왜 못 봐? orca에서 해당 기능도 이용할 수 있지 않니?"
> "`--command "codex"` 이 부분 메모리에 오케스트레이션 부분에 넣어서 터미널로 각 에이전트들을 띄워서
> 내 눈으로 직접 볼 수 있게 진행하도록 해줘."

**Why**: Claude Code 서브에이전트(`Agent` 툴)는 하네스가 UI 에 띄워 주지만, `codex` 를 Bash
백그라운드로 돌리면 출력이 파일에만 쌓여 **태홍님 화면에서 완전히 안 보인다.** Day 01 에
`CLAUDE.md` 에 "codex 는 Bash 직접, orca terminal 경유 불필요"라고 적어 뒀던 게 원인이고,
그 판단은 **가시성을 고려하지 않은 것**이라 Day 02 에 번복했다. 10분 넘게 도는 리뷰를
사람이 들여다볼 수 없으면 진행 상황도, 이상 징후도 알 수 없다.

**How to apply** — ★ `exec` 가 아니라 **대화형 TUI** 로 띄운다

```bash
# ① TUI 로 띄운다 (인자 없는 `codex` = 대화형. `codex exec` 는 headless 라 원시 로그만 쏟아진다)
#    ★ --sandbox read-only 를 반드시 붙인다 (아래 참조)
#    ★ -c check_for_update_on_startup=false 로 업데이트 모달을 끈다 (2026-10-28 정정 — 아래 참조)
#    ★ -m gpt-5.6-sol -c model_reasoning_effort=high 로 모델을 명시한다 (안 주면 기본 luna)
H=$(orca terminal create --worktree active --title "codex-review-1" \
    --command "codex --sandbox read-only -m gpt-5.6-sol -c model_reasoning_effort=high -c check_for_update_on_startup=false" --json \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["terminal"]["handle"])')

# ② 프롬프트를 밀어 넣는다 (idle 확인 후) — ★ 여러 줄을 --text 로 직접 밀지 말 것: 개행이 조기 제출을 일으켜
#    agent_prompt_blocked/부분 제출이 된다. 프롬프트는 절대경로 파일에 쓰고 「파일 참조 한 줄」만 보낸다
orca terminal send --terminal "$H" --text "다음 절대경로 파일을 읽고 그 지시를 그대로 수행하라: /abs/prompt.md" --enter

# ④ 읽는다 (스크롤백이 길면 커서로 잘라 읽는다)
orca terminal read --terminal "$H" --cursor <N> --limit <M>
```

- **★ `--sandbox read-only` 를 빠뜨리지 말 것 (2026-08-06 실측).** `--command "codex"` 만 주면
  orca 가 **`codex '--dangerously-bypass-approvals-and-sandbox'`(YOLO 모드)** 로 띄운다.
  화면에 `permissions: YOLO mode` 로 표시된다. Day 01 에 리뷰어가 `src/test` 에 프로브를 심어
  커버리지를 8.35%p 부풀린 전례가 있어 **리뷰어에게 쓰기 권한을 주면 안 된다.**
- **★ 업데이트 프롬프트에 "2"(Skip) 를 보내는 건 이제 안 먹는다 (2026-09-07 #117 실측).**
  codex 첫 기동 시 "✨ Update available! 1. Update now(runs brew upgrade) 2. Skip …" 이 뜨는데,
  orca 가 이 "brew upgrade" 승인 프롬프트에 대한 에이전트 입력을 **`agent_prompt_blocked`** 로
  거부한다. 그러면 codex 가 `model: loading` 에서 **영영 멈춘다**(60초+ 대기해도 그대로).
  → 종전 메모의 "`--text 2` 로 Skip" 은 더 이상 신뢰 못 한다. **`CODEX_DISABLE_UPDATE_CHECK=1`
  을 create 명령의 `env …` 접두로 박아 프롬프트 자체를 안 뜨게 한다.** 그러면 바로 로딩 완료.
- **★★ 2026-10-28 정정 — `CODEX_DISABLE_UPDATE_CHECK=1` 은 codex-cli 0.160.0 에서 효과가 없다.**
  playbook 스모크 테스트에서 이 env 를 줘도 `Update available · 0.160.0 → 0.165.0` 모달이 떴고,
  바이너리 문자열에 이 이름 자체가 없다. 실제 설정 키는 **`check_for_update_on_startup`** →
  `-c check_for_update_on_startup=false` 를 붙이자 모달 0회로 바로 입력 대기가 됐다(실측).
  그래도 뜨면 **ESC(`--text $'\x1b'`) 한 번** = skip (accepted:true 실측). 실행 스크립트: playbook `bin/codex-review.sh`.
- **orca 앱 기본 인자 `agentDefaultArgs.codex` 가 `--dangerously-bypass-approvals-and-sandbox`(YOLO)다** — `--sandbox read-only` 를
  명시하면 그게 이긴다(`/status` → `Permissions: Read Only` 실측). `orca agent launch`/`worktree create --agent codex` 로 띄우면 YOLO 가 된다.
- **★ JSON 키는 `terminalId` 가 아니라 `handle`** (`term_…` 형식). `terminalId` 로 파싱하면 KeyError.
- **read-only 샌드박스에서 pytest 승인 프롬프트가 뜨면 `--text "2"`(접두 허용)로 풀어 준다
  (2026-09-07 #117 실측).** codex 가 표적 테스트를 돌리려는데 샌드박스가 임시 캡처 파일 생성을
  막아 "Would you like to run … pytest …? 1.Yes 2.Yes,don't ask 3.No" 가 뜬다. pytest 는
  `src/test` 를 수정하지 않고(임시파일만) **G1 동결 해시 대조가 최종 방어선**이라 허용해도 안전하다.
  막힌 채 두는 것은 진전이 아니다.
- **`codex exec` 를 쓰지 말 것.** Day 02 에 `exec` 로 띄웠더니 태홍님이 "다른 claude 에이전트는
  각자 터미널에서 프롬프팅한 것처럼 나오는데 이건 실시간 로그만 나온다"고 지적했다.
  `codex [PROMPT]` (서브커맨드 없음) 가 대화형 CLI 다 — `codex --help` 첫 줄에 명시돼 있다.
- `--title` 로 무슨 작업인지 탭에 드러낸다. 여러 개 띄우면 각각 구분되게 이름을 준다
- 응답에 `"surface": "visible"` 이 오면 UI 에 실제로 떴다는 뜻이다
- 부수 효과: 포그라운드 10분 한도(Day 01 SIGTERM 사고)도 함께 해소된다

**완료 판정 — `wait --condition tui-idle` 을 믿지 말 것 (2026-08-06 실측)**
중간 유휴 상태에 걸려 **조기 반환**한다(작업 시작 몇 초 만에 돌아왔다).
화면 tail 에서 **`esc to interrupt` 가 사라졌는지**로 판정하라. 출력에 스피너 잔상
(`Working…` 반복)이 섞이므로 `tr -s ' '` + 정규식으로 걷어내고 읽는다.

**read-only 샌드박스는 네트워크도 막는다** — codex 가 `gh` 로 CI 결과를 조회하려다 멈춘다.
**CI 결과는 프롬프트에 직접 넣어 줄 것.**

**★ "모든 셸 명령 금지"로 지시하지 말 것 (2026-09-02 #150 실측)** — codex 는 파일을 셸(cat/sed
등)로 읽는다. pytest 를 막으려고 "어떤 셸 명령도 실행 말라"고 했더니 **파일 읽기조차 못 해
"판정 불가"** 를 반환했다. 정확히 쓸 것: "read-only 조회(cat/sed/grep)는 하되 **pytest 등
테스트·쓰기 명령만** 하지 말라." (샌드박스 임시디렉터리 제약으로 pytest 는 어차피 `No usable
temporary directory` 로 실패한다 — 테스트 결과는 로컬에서 돌려 프롬프트에 넣어 줄 것.)

**★ 승인 위젯·입력 차단 (`agent_prompt_blocked`) 다루기 (2026-09-02 #150 · 2026-09-08 #163 실측)** —
codex 가 명령 승인 프롬프트("Would you like to run… 1.Yes 2.Yes,don't ask(p) 3.No(esc)")를 띄우거나
부팅 중이면 orca 의 `orca terminal send --text …` 가 **`agent_prompt_blocked`** 로 거부된다. 대응:
- **전송은 idle 일 때만** — tail 이 `Ask Codex to do anything` 이고 `esc to interrupt` 가 없을 때.
  `tab to queue message`/`Starting MCP servers` 면 아직 준비 안 됨.
- **★★ 승인 모달은 「단일 핫키 + `--enter` 없이」로만 답해진다 (2026-09-08 #163 실측·#153 교차확인).**
  모달은 화면에 찍힌 핫키(`y`=Yes 1회 · `p`=Yes·don't-ask · `esc`=No)만 받는다.
  `orca terminal send --terminal "$H" --text "p"` (★ `--enter` 붙이지 말 것) → `accepted:true` 로 통과.
  ⚠️ **`--text "2" --enter`(숫자+엔터)나 여러 글자+엔터는 `agent_prompt_blocked` 를 낸다** — 모달에
  라인 입력이 안 되기 때문이다. 종전 메모의 「`--text "2"` 로 승인」은 **핫키(`p`/`y`)를 `--enter` 없이**
  로 읽을 것. (git·pytest 조회 승인 모두 `p` 로 접두 허용하면 이후 재프롬프트가 없다.)
- 승인이 아니라 **취소**하려면 ESC = `--interrupt`(또는 `--text $'\x1b'`) 한 번("Conversation
  interrupted") — 단, interrupt 후에도 그 상태가 다시 `agent_prompt_blocked` 라 텍스트 재주입이 막힌다.
  그럴 땐 `orca terminal close` 후 새 터미널로 깨끗이 다시 띄우는 편이 빠르다.
- ⚠️ **모달을 피하는 게 상책** — 리뷰 프롬프트에 **diff·소스를 절대경로 파일로 직접 주면** codex 가
  git 을 안 불러 승인 모달 자체가 안 뜬다(#163 실측: 절대경로 diff 를 주자 git 모달 없이 완주).
- ⚠️ **ESC·Enter 를 반복해서 밀어넣지 말 것** — 세션이 리셋돼 컨텍스트가 0% 로 날아가고
  그때까지의 분석을 통째로 잃는다(#150 에 실제로 겪음). 막히면 차라리 `orca terminal close`
  후 새 터미널로 깨끗하게 다시 띄운다.

**codex 신뢰성 — ⚠️ 부분 해소 (2026-08-14 갱신)**: `codex exec` 는 Day 01·02 모두
`collab: Wait` + `agent thread limit reached` 로 정체했고, TUI 는 Day 02~11 정체 없이 완주했다.
**리뷰는 여전히 TUI 로 돌린다.**

**그러나 Day 12(2026-08-14)에 TUI 도 정체했다.** codex 가 스킬을 통해 **하위 에이전트**를
띄웠는데(`/root/comment_contract_review` 등) 그것들이 안 끝나
`Finished waiting` / `No agents completed yet` 을 15분 넘게 반복했다.
**「TUI 는 안 정체한다」는 종전 기술은 틀렸다.**

- 정체 신호: `Finished waiting` · `No agents completed yet` 반복
- 대응: **먼저 기다린다.** 그래도 안 되면 「지금까지 확인한 것을 **중간 보고**로 달라」고 요청한다.
  ★ **「최종 리포트」라고 요청하지 말 것** — [[interim-vs-final-report-labeling]]
- 잘라서 받은 것은 **중간본**이며 게이트 통과로 치지 않는다. codex 는 자기 기준 커밋을
  스스로 밝히므로(「HEAD=x 기준, 이후 커밋 미반영」) 그걸 그대로 기록한다
- 잘라 받아도 **내용은 값졌다** — Day 12 에 BLOCKER 1(원천이 비어도 「거래 0건」으로 적재) +
  MAJOR 6 을 냈고, 그중 둘은 다른 리뷰어와 **독립 수렴**했다

**Claude Code `Agent` 서브에이전트는 그대로 둔다** — 하네스가 이미 UI 에 표시한다.
문제는 하네스 밖에서 도는 프로세스였다.

## HTML·파일을 띄울 때도 orca 안에서 (태홍님 지시 2026-08-04)

> "html 띄워주는 것도 orca 브라우저 탭으로 생성한다고 기억시켜줘"

macOS `open <file>` 을 쓰면 orca **밖의** 기본 브라우저로 열려 작업 맥락에서 떨어져 나간다.
Day 완료 보고서(`briefing/day-XX-report.html`)처럼 태홍님이 바로 보셔야 하는 산출물은
**orca 브라우저 탭**으로 띄운다.

```bash
orca tab create --worktree active --url "file:///절대/경로/briefing/day-XX-report.html" --json
```

- 절대 경로 + `file://` 스킴. 상대 경로는 안 먹는다
- **`--focus` 를 붙이면 실패하는 경우가 있다** (2026-08-05 실측: `ok:false` 를 반환하고
  새 URL 대신 **직전 페이지가 복제**됐다). `--focus` 없이 만들면 정상 동작하고 새 탭이
  알아서 활성화된다. **붙이지 말 것**
- `orca tab list --worktree active` 로 **반드시 확인**. 중복이 생겼으면 `orca tab close --page <id>`
- 응답의 `browserPageId` 를 잡아 두면 `orca reload`·`orca screenshot` 으로 갱신·캡처까지 된다
- 파일을 **편집기**로 열 때는 `orca file open <path>`, diff 는 `orca file diff`

**주의**: `open` 을 쓰면 orca 브라우저가 기본 브라우저인 환경에서는 탭이 **중복 생성**된다
(2026-08-04 실제로 2개가 겹쳤다). `orca tab create` 로 통일한다.

**일반화한 원칙**: 사람이 지켜봐야 할 장시간 작업을 사람이 못 보는 곳에서 돌리지 않는다.
산출물도 사람이 있는 곳(orca) 안에서 띄운다.
`run_in_background` Bash 는 짧고 결과만 필요한 것에만 쓴다.

관련: [[complementary-review-lenses]] · [[weekly-report-execution]]
