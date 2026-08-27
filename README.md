# 에이전트 개발 운영 매뉴얼 (Portable Playbook)

Claude Code 를 주 실행자로, codex·antigravity 를 교차 리뷰어로, orca 를 작업 표면으로,
ECC 플러그인을 에이전트 공급원으로 쓰는 개발 방식을 **기술 스택과 무관하게** 정리한 것.

한 프로젝트에서 21일 · 32세션 · 30보고서를 돌리며 **실제 실패로 얻은 규칙만** 담았고,
각 규칙에 **왜 생겼는지**를 함께 적었다.

## 파일

```
playbook.html                                  ← 매뉴얼 본문 (단일 HTML, 외부 리소스 없음)
templates/
├── CLAUDE.md                                  ← 규칙. 「작업 원칙」 절만 채우면 된다
├── MEMORY.md                                  ← 상태 (6개 절 골격)
├── gitignore-starter                          ← 시크릿 패턴 우선
├── .claude/skills/day-report/SKILL.md         ← 보고서 형식 스킬
└── sessions/day-NN-start-prompt.md            ← 핸드오프 프롬프트
```

## 설치 (다른 컴퓨터에서)

```bash
git clone https://github.com/hong3807/playbook.git ~/IdeaProjects/dev-playbook
```

## 새 프로젝트에 얹기

```bash
PB=~/IdeaProjects/dev-playbook
cd <새-프로젝트>

cp "$PB/templates/CLAUDE.md" .
cp "$PB/templates/MEMORY.md" .
cp "$PB/templates/gitignore-starter" .gitignore     # 기존 것이 있으면 병합
mkdir -p plan sessions briefing .claude/skills
cp -R "$PB/templates/.claude/skills/day-report" .claude/skills/

# 환경 점검 — ECC 이중 설치 확인 (0 이어야 한다)
ls ~/.claude/agents/ 2>/dev/null | wc -l
```

그다음 `CLAUDE.md` 맨 아래 **「작업 원칙」 절만** 프로젝트에 맞게 채운다.
그 위쪽(세션 프로토콜 · 날짜 규칙 · 개발 방법론)은 손대지 않는다.

## 매뉴얼 열기

```bash
orca tab create --worktree active --url "file://$HOME/IdeaProjects/dev-playbook/playbook.html" --json
```

## 어디부터 시작할까

전부 한 번에 지키려 하지 말 것. **§02 문서 3층 구조**와 **§03 세션 프로토콜**부터.
그 둘만으로도 세션이 끊겨도 일이 이어진다. 나머지는 필요해질 때 켠다.
