---
name: cross-refutation-overturns-convergence
description: 두 리뷰어가 독립 수렴해도 틀릴 수 있다 — 2단계 교차 반증을 생략하지 말 것
metadata: 
  node_type: memory
  type: feedback
  modified: 2026-08-14T09:09:42.764Z
---

리뷰 3단계 프로토콜에서 **1단계 독립 수렴을 "즉시 수정" 근거로만 쓰지 말고, BLOCKER·MAJOR 는 반드시 2단계 교차 반증을 거칠 것.**

Day 13(2026-08-14) 실증: codex 가 BLOCKER, python-reviewer 가 MAJOR 로 **독립 수렴**한 「R-ONE 페이징이 부분 수신을 exit 0 으로 흘린다」가 2단계에서 **기각**됐다. security-reviewer 가 실데이터로 반증 — R-ONE 응답이 **오름차순(과거→최신)**이라 페이지 절단이 일어나면 최신월이 페이지1 에 없고, 따라서 신선도·완전성 게이트에 반드시 걸린다(end-to-end `exit 5`, 적재기 미호출 확인). 같은 라운드에서 아키텍처 지적도 `plan/daily-plan.md` 문서 근거로 기각됐다.

반대 방향도 같은 날 나왔다 — **진짜 BLOCKER 는 codex 혼자** 찾았다(매매·전세 합집합 완전성이 통과해 UPSERT 가 기존 전세 지수를 NULL 로 덮음). 수렴하지 않은 단독 발견이라고 심각도를 낮추면 안 된다.

**Why:** 수렴은 "둘 다 같은 코드를 같은 방식으로 읽었다"는 뜻이기도 하다. 원천의 실제 동작(정렬 순서 등)을 확인하지 않으면 둘이 같이 틀린다. 반대로 단독 발견은 그 리뷰어만 본 각도라는 뜻이지 약한 증거가 아니다.

**How to apply:** 심각도는 수렴 개수가 아니라 **재현 가능성**으로 정한다. 지적을 받으면 판정 전에 직접 재현해 보고, 재현되면 수렴 여부와 무관하게 고친다. 재현이 안 되거나 판단이 섞인 항목만 2단계 반증에 건다. 반증 프롬프트는 "확인" 이 아니라 **"반박해보라, 확신이 없으면 반박 성공으로 간주하라"** 여야 한다.

관련: [[complementary-review-lenses]] · [[interim-vs-final-report-labeling]]
