---
name: git-identity-noreply
description: git 신원·자격증명 위생 — 전역 신원은 hong3807 noreply 고정(실이메일 쓰면 squash 병합 시 커밋이 두 명으로 집계), 자격증명은 gitconfig에 두지 않고 keyring/osxkeychain 사용
metadata:
  node_type: memory
  type: feedback
  modified: 2026-09-22T00:48:29.159Z
---

# git 신원 · 자격증명 위생

> 2026-08-11 확정. 2026-09-22 `github-pat-rotation-20260811` 을 이 파일로 병합했다(같은 날·같은 세션 산물·같은 주제).

## ① 전역 git 신원 = noreply 고정

전역 git 신원은 **`<이름> <<숫자ID>+<로그인>@users.noreply.github.com>`** 로 고정한다 (2026-08-11 확정).
실이메일로 되돌리지 않는다.

**Why:** `~/.gitconfig` 에 실이메일이 박혀 있었는데 이 주소가 GitHub 계정에
등록돼 있지 않았다. GitHub API 로 실측하니 `.author.login` 이 `null` — GitHub 이 주인을 모르는 이메일이었다.
저장소가 **squash merge** 라 병합할 때마다 GitHub 이 ① squash 커밋 author 를 PR 작성자 신원(noreply)으로 덮고
② 원래 author 가 달라 `Co-authored-by: TaeHong <실이메일>` 를 자동으로 붙여 → 커밋마다
계정명 + 표시이름 두 명이 동시 작업자로 표시됐다.

**Claude 설정 문제가 아니었다.** `attribution: {commit:"", pr:""}` · `includeCoAuthoredBy: false` 는 정상이었고
로컬 커밋 트레일러 0건, squash 커밋에만 1건씩. 원인을 Claude 쪽에서 찾으면 헛수고한다.

**How to apply:**
- 커밋 작성자가 둘로 보인다는 얘기가 나오면 **`gh api repos/{o}/{r}/commits/{sha} --jq .author.login` 이 null 인지부터** 본다.
  null 이면 이메일 미등록이 원인(트레일러 뒤지는 건 그다음).
- noreply 는 GitHub 계정 신원 자체라 매핑 보장 · squash 시 author 일치로 `Co-authored-by` 자체가 안 생김 · 실이메일 미노출.
- 과거 커밋(이 저장소 85건)은 옛 이메일로 남음. 히스토리 재작성은 안 함.

## ② 자격증명은 gitconfig 에 두지 않는다

**자격증명을 `~/.gitconfig` 에 넣지 않는다.** `gh auth login` 의 keyring 또는
`git config --global credential.helper osxkeychain` 을 쓴다.

**Why — 2026-08-11 사례(종결):** `~/.gitconfig` 에 `user.password = ghp_…`(GitHub classic PAT)이 평문 저장돼
있었다. `git` 은 `user.password` 를 인증에 안 쓴다(실제 인증은 `gh` keyring OAuth `gho_…`, scopes gist·read:org·repo·workflow)
— **기능적으로 무용지물인데 노출만** 되고 있었다. `GET https://api.github.com/user` 로 실측하니 **401 Bad credentials**
— 이미 폐기·만료된 죽은 문자열이라 GitHub 토큰 목록에도 없었다. 파일과 백업본(`~/.gitconfig.bak-20260811`)에서
제거 후 `chmod 600`. **조치 불필요로 종결.**

**How to apply:**
- 설정 파일을 백업할 때 **복사본에도 비밀값이 딸려간다** — 백업본도 함께 정리한다(백업 먼저 뜨고 원본 지우면 비밀값이 백업에 남는다).
- 토큰이 GitHub 목록에 안 보인다고 안심하지 않는다. 목록은 값으로 대조 불가 →
  **`curl -H "Authorization: Bearer <T>" https://api.github.com/user` 상태코드로 판정**한다.
  200 이면 살아 있고 `login`(소유 계정)·`x-oauth-scopes`(권한) 확인, 401 이면 죽은 것.
- ⚠️ 이 유효성 확인은 **Claude 가 대신 못 한다** — 자격증명을 네트워크로 보내는 호출이라 하네스가 차단한다.
  태홍님께 `!` 접두사로 직접 실행하시도록 명령을 드린다.

관련: [[weekly-report-execution]]
