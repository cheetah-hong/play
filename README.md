# 에이전트 개발 하네스 (Portable Playbook)

Claude Code 를 주 실행자로, codex 를 교차 리뷰어로, orca 를 작업 표면으로, ECC 플러그인을
에이전트 공급원으로 쓰는 개발 방식을 **다른 컴퓨터에서 그대로 재현**하기 위한 저장소.

> **원칙: 규칙은 문장이 아니라 실행되는 것으로 옮긴다.**
> 「orca 브라우저로 띄울 것」이 아니라 `bin/orca-tab.sh <파일>`, 「codex 로 read-only 리뷰」가 아니라
> `bin/codex-review.sh start <프롬프트>`. 문장은 해석이 갈리지만 스크립트는 같은 결과를 낸다.
> 그리고 `doctor.sh` 가 「이 컴퓨터가 원본과 같은가」를 PASS/FAIL 로 판정한다.

## 1. 새 컴퓨터에 설치 (3단계)

```bash
# ① 받기 — 경로는 어디든 되지만 bootstrap 이 그 경로를 settings.json 에 PLAYBOOK_HOME 으로 박는다
git clone https://github.com/hong3807/playbook.git ~/IdeaProjects/dev-playbook
cd ~/IdeaProjects/dev-playbook

# ② 설치 — 먼저 --dry-run 으로 무엇이 바뀌는지 본다. 덮는 파일은 전부 *.bak-playbook-<시각> 백업
./bootstrap.sh --dry-run
./bootstrap.sh

# ③ Claude Code 재시작 후 판정 — FAIL 0 이어야 한다
./doctor.sh
```

**선행 조건** (bootstrap 이 없으면 멈추고 설치 방법을 알려 준다): `git` `jq` `python3` `gh`(로그인) `claude` `codex`(로그인) `orca`(앱 실행 중)

**bootstrap 이 하는 일**

| 대상 | 방식 | 내용 |
|---|---|---|
| ECC 플러그인 | 없으면 `claude plugin marketplace add` + `install` | 리뷰·빌드 에이전트 공급원 |
| `~/.claude/settings.json` | **키만 깊은 병합**(jq) — 통째로 덮지 않는다 | 작성자 표기 차단 · 모델/effort · 플러그인 · tui · teammate · `env.PLAYBOOK_HOME` |
| `~/.claude/CLAUDE.md` | 다르면 백업 후 교체 | 호칭 · 존댓말 · `[HH:MM]` · 커밋/PR 표기 금지 |
| `~/.codex/AGENTS.md` | 다르면 백업 후 교체 | codex 쪽 호칭 · 타임스탬프 |
| `~/.codex/config.toml` | top-level `model`·`model_reasoning_effort` 만 교체 | 섹션([...])은 건드리지 않는다 |

**일부러 옮기지 않는 것**
- `~/.claude/settings.json` 의 `hooks` — **orca 앱이 시작할 때 스스로 다시 쓴다**(`: orca-agent-hook-form=1` 표식). 복사하면 버전이 어긋난다
- `autoMode.environment` — 이 머신의 자격증명 파일 경로 목록이 들어 있다
- `~/.codex/auth.json`, `.env`, 각종 키 · `history.jsonl` 등 기록 파일(토큰이 섞여 있을 수 있다)
- orca 앱 설정 — CLI 로 바꿀 수 없다. 아래 「수동 확인」 참조

## 2. 새 프로젝트에 얹기

```bash
PB="$PLAYBOOK_HOME"            # bootstrap 후 Claude 세션 안에서는 이 변수가 잡혀 있다
cd <새-프로젝트>

cp "$PB/templates/CLAUDE.md" .
cp "$PB/templates/MEMORY.md" .
cp "$PB/templates/gitignore-starter" .gitignore     # 기존 것이 있으면 병합
mkdir -p plan sessions briefing .claude/skills
cp -R "$PB/templates/.claude/skills/day-report" .claude/skills/

# 프로젝트 무관 교훈 메모리 8개를 이 프로젝트의 Claude 자동 메모리에 넣는다 (있는 것은 안 덮음)
"$PB/bin/install-memory.sh" .
```

그다음 `CLAUDE.md` 맨 아래 **「작업 원칙」 절만** 프로젝트에 맞게 채운다. 위쪽은 손대지 않는다.

## 3. 매일 쓰는 명령

| 할 일 | 명령 |
|---|---|
| 세션 착수/완료 표시 | `"$PLAYBOOK_HOME/bin/orca-status.sh" in-progress "Day 05 착수 — <요약>"` |
| 보고서 HTML 띄우기 | `"$PLAYBOOK_HOME/bin/orca-tab.sh" briefing/day-05-report.html` |
| codex 1차 리뷰 | `prepare main` → `start <prompt.md>` → `wait` → `read` → `close` (`templates/CLAUDE.md` 「codex 1차 리뷰」 절) |
| 에이전트 프롬프트 문구 | `prompts/agent-phrases.md` 블록을 그대로 붙인다 |
| 환경 점검 | `"$PLAYBOOK_HOME/doctor.sh"` |

orca 래퍼는 **현재 디렉터리가 속한 orca 워크트리**를 대상으로 한다. orca 밖에서 돌리면
`selector_not_found` — `ORCA_WORKTREE=path:<워크트리 절대경로>` 를 앞에 붙인다.

## 4. 파일

```
bootstrap.sh                 설치 (멱등 · --dry-run)
doctor.sh                    판정 (FAIL=규칙 깨짐 · WARN=원본과 다름)
global/claude/               ~/.claude 로 가는 것 (CLAUDE.md · settings.fragment.json)
global/codex/                ~/.codex 로 가는 것 (AGENTS.md · config.fragment.toml)
bin/codex-review.sh          codex TUI 리뷰 (read-only·모델 고정·업데이트 모달 차단·완료 판정)
bin/orca-status.sh           orca 보드 상태 갱신
bin/orca-tab.sh              orca 브라우저 탭 열기 (중복 방지)
bin/install-memory.sh        교훈 메모리 이식
bin/lib/                     공통 함수 (orca 오류를 삼키지 않고 드러낸다 · TOML 병합)
prompts/codex-review.md      codex 1차 리뷰 프롬프트 (2026-09-22 제약 포함 · prepare 가 채운다)
prompts/agent-phrases.md     서브에이전트 3조항 · 2차 리뷰 · 반증 · 재요청 · 중간 보고 문구
memory/                      프로젝트 무관 교훈 8개 + 색인
templates/                   프로젝트용 CLAUDE.md · MEMORY.md · 세션 시작 프롬프트 · day-report 스킬
playbook.html                사람이 읽는 배경 매뉴얼 (2026-08 판 — 명령은 위 스크립트가 정본)
```

## 5. 수동 확인 (스크립트로 못 하는 것)

- **orca 앱 설정 → 에이전트 기본 인자**: 원본은 codex 기본 인자가 `--dangerously-bypass-approvals-and-sandbox`(YOLO)다.
  `codex-review.sh` 는 `--sandbox read-only` 를 명시해 이를 이긴다(`/status` → `Permissions: Read Only` 실측).
  그러나 `orca agent launch` · `orca worktree create --agent codex` 로 띄우면 YOLO 가 된다 — 리뷰에는 쓰지 않는다.
- **orca 스킬**(orca-cli · orchestration · computer-use): `orca skills install` 로 받는다.
- **codex 첫 기동의 폴더 신뢰 프롬프트**: 경로마다 한 번 승인한다.

## 6. 검증 이력

- 2026-10-28 원본 Mac: `doctor.sh` FAIL 0 · `bootstrap.sh --dry-run` 변경 = `env.PLAYBOOK_HOME` 추가뿐 ·
  `codex-review.sh` start→wait→read→close 스모크 통과(업데이트 모달 0회 · read-only 확인) ·
  `orca-tab.sh` 열기·중복 방지·워크트리 밖 오류 표시 · `install-memory.sh` 워크트리→본 저장소 경로·멱등
- 같은 날 이 저장소 자체를 `codex-review.sh` 로 1차 리뷰(도그푸딩). 그 과정에서 **wait 조기 DONE**(도구 실행 순간
  `esc to interrupt` 가 사라짐)을 발견해 연속 3회 IDLE 확인으로 고쳤다
- 이식하며 뒤집힌 옛 규칙: `env CODEX_DISABLE_UPDATE_CHECK=1` 은 codex 0.160.0 에서 무효(바이너리에 없는 이름) →
  `-c check_for_update_on_startup=false`
- 검증 버전: Claude Code 2.1.312 · codex-cli 0.160.0 · orca 1.4.229 · ECC 1.10.0 (`doctor.sh` 상단 상수)
