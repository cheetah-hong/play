---
name: ecc-double-install-prefix
description: "ECC를 install.sh 사본 + 플러그인으로 이중 설치하면 확장 목록이 두 벌 실리고 스킬 예산이 넘친다. 사본을 걷으면 짧은 이름이 사라지고 everything-claude-code: 접두사가 정본이 된다"
metadata: 
  node_type: memory
  type: project
  modified: 2026-08-14T02:14:01.583Z
---

`everything-claude-code`(ECC)를 **두 방식으로 동시에 설치**해 두고 있었다 (2026-08-14 `/doctor` 로 발견).

- ① `install.sh` 가 `~/.claude/{agents,commands,skills}` 로 파일 복사
- ② `/plugin` 으로 플러그인 설치 (`~/.claude/plugins/cache/…/1.10.0`)

`cmp`·`diff -rq` 로 대조한 결과 **에이전트 42/42 · 명령 70/70 · 스킬 43/43 이 바이트 단위 동일**,
커스터마이즈 0건이었다. 둘은 **이름이 달라** Claude Code 가 별개 항목으로 보고 **양쪽 다 목록에 싣는다**.

**왜 문제인가** — 토큰(6,142 est.)보다 **스킬 목록 예산**이 핵심이다.
스킬 목록에는 컨텍스트 창의 약 1%(1M 창에서 ≈10,000 토큰)라는 별도 한도가 있고,
중복 때문에 **11,372 토큰으로 114% 초과** 상태였다. 넘치면 설명문이 잘려 **스킬 라우팅이 망가진다.**
사본 43개를 걷어 94%로 복귀시켰다.

**짧은 이름은 사본에서만 나온다** — 이게 판정 근거였다.
플러그인에만 있고 사본이 없는 스킬 125개(`deep-research`, `git-workflow` 등)는
**접두사형으로만** 목록에 뜬다. 즉 `java-reviewer` 같은 짧은 이름은 `~/.claude/` 사본이 만든 것이고,
사본을 지우면 **`everything-claude-code:java-reviewer` 가 정본**이 된다.
`Agent(subagent_type: "java-reviewer")` 는 더 이상 해석되지 않는다.

**적용 범위** — `~/.claude/` 라 **이 맥의 모든 프로젝트**에 즉시 적용된다.
반면 그 결과를 반영하는 CLAUDE.md 수정은 **저장소·브랜치별**이라 따로 손대야 한다.
2026-08-14 전수 스캔 결과 낡은 이름을 가진 문서는 weekly-report 계열뿐이었다
(housedeal 35세션의 `/verify` 는 API 경로 오탐, ECC 원본 저장소는 자기 설명이라 손대지 않음).

**되돌리기**: `~/.claude/_doctor-removed/{agents,skills}` 에 격리해 뒀다(삭제 아님).
`~/.claude/_doctor-backup-20260814.tar.gz` 도 있다.

같은 날 함께 처리한 것 — `~/.claude/rules/{common,web}` 과 `rules/README.md` 에
`paths:` 프론트매터가 없어 **모든 프로젝트에 항상 로드**되고 있었다(java·kotlin·ts·dart 는 이미 있었다).
web 7개에 `paths:` 를 달고 README 를 `.txt` 로 바꿔 4,605 est. 토큰을 걷어냈다.

관련: [[agent-visibility-orchestration]] · [[complementary-review-lenses]]
