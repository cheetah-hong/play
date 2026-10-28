# 이식용 메모리 색인

`bin/install-memory.sh <프로젝트>` 가 아래 줄을 대상 프로젝트 `MEMORY.md` 에 덧붙인다(없는 것만).
전부 **프로젝트 무관 교훈**이다. 프로젝트 고유 기억은 각 프로젝트에서 새로 쌓는다.

- [★커밋은 검수·허락 후에만](no-commit-until-review.md) — 작업 중 커밋 금지. 끝나면 검수 → 허락 → 커밋. push 전 git fetch 로 원격 최신·충돌 확인
- [★「최종」과 「중간」 구별](interim-vs-final-report-labeling.md) — 잘라 받은 리포트를 "최종"이라 부르지 않는다("중간"으로). 태홍님은 최종으로 믿으신다
- [서브에이전트 생사 판정](subagent-liveness-judgment.md) — ListAgents 이탈=사망 아님. 3회 재요청이 먼저("문제없으면 없다고 보내라" 포함)
- [★교차 반증이 독립 수렴을 뒤집는다](cross-refutation-overturns-convergence.md) — 독립 수렴도 틀릴 수 있다. 심각도는 수렴수 아니라 재현가능성으로
- [★에이전트 가시성 오케스트레이션](agent-visibility-orchestration.md) — codex 는 orca terminal TUI(read-only)로 띄워 사람이 보게. Bash 백그라운드 금지. 실행은 $PLAYBOOK_HOME/bin/codex-review.sh
- [★orca 하위 워크트리 위임 절차](orca-child-worktree-delegation.md) — 크로스repo 부모 lineage 금지→홈은 같은 repo+코드는 별도 git워크트리. 신뢰프롬프트 기본 No(Up→Yes)·멀티라인은 파일참조 한줄
- [git 신원·자격증명 위생](git-identity-noreply.md) — 전역 신원 noreply 고정(실이메일이면 squash 시 두 명). 자격증명은 gitconfig 아닌 keyring/osxkeychain
- [★ECC 이중 설치와 접두사](ecc-double-install-prefix.md) — 사본+플러그인 이중설치면 스킬 예산 초과. 사본 걷으면 everything-claude-code: 접두사가 정본
