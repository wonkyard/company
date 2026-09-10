<!--
WONKYARD devlog 5편 (velog, 한국어)
제목 후보:
1. AI 직원들 채용해서 회사 하나 만들어봤다 (5) — Codex가 이사를 갔는데, 사무실이 못 따라갔습니다
2. AI 직원들 채용해서 회사 하나 만들어봤다 (5) — 두 번째 AI 직원을 뽑았더니, 사무실이 자기 팀 방도 못 알아봤습니다
3. AI 직원들 채용해서 회사 하나 만들어봤다 (5) — v1.1~v1.5, 그리고 두 번이나 자기 자신을 못 알아본 사무실

4편: https://velog.io/@hyeokkiyaa/AI-직원들-채용해서-회사-하나-만들어봤다-4-남이-설치했더니-터미널이-안-켜졌습니다-Open-VSX-다운로드-약-300번-달성

이미지: blog/drafts/images/ — 스크린샷은 Founder가 추가. 아래 (screenshot-placeholder: ...) 자리마다
실제로 뭘 찍어야 하는지 구체적으로 적어뒀습니다. 캡처 순서 그대로 따라가면 됩니다:
  1. VS Code에서 Agentyard 패널 열기 (Ctrl+Shift+Claude 아이콘, 또는 바닥 패널 탭)
  2. 오피스 뷰에서 Claude Code + Codex 방이 같이 보이는 상태 (둘 다 실행 중이어야 함)
  3. Run 뷰로 전환해서 Claude Code ⇄ Codex 스위처가 보이는 상태
  4. Run 뷰 헤더의 model 드롭다운을 클릭해서 옵션 목록이 열린 상태
  5. VS Code Marketplace 리스팅 페이지 (설치 수 캡처용)
전부 개인 워크스페이스 정보(경로, 프롬프트 내용)는 가리고 캡처할 것.
-->

# Codex가 이사를 갔는데, 사무실이 못 따라갔습니다

> WONKYARD devlog 5편입니다. 지난 편 이후로 Agentyard는 v1.0.2부터 v1.5까지 다섯 번 버전을 올렸습니다. 두 번째 AI 직원(Codex)을 채용했고, 모델을 고르는 드롭다운을 넣었고, 한 에이전트가 막히면 다른 에이전트가 이어받는 기능도 만들었습니다. 그러다 두 번, 이 회사를 지켜보라고 만든 도구가 정작 자기 자신을 못 알아보는 일이 벌어졌습니다. 한 번은 Codex가 파일 저장 방식을 바꿔서, 한 번은 제가 만든 빌드 자동화 도구 자체 때문에요. 이번 편은 그 이야기입니다.

## 지난 이야기

[4편](https://velog.io/@hyeokkiyaa/AI-%EC%A7%81%EC%9B%90%EB%93%A4-%EC%B1%84%EC%9A%A9%ED%95%B4%EC%84%9C-%ED%9A%8C%EC%82%AC-%ED%95%98%EB%82%98-%EB%A7%8C%EB%93%A4%EC%96%B4%EB%B4%A4%EB%8B%A4-4-%EB%82%A8%EC%9D%B4-%EC%84%A4%EC%B9%98%ED%95%B4%EC%9C%A0-%ED%84%B0%EB%AF%B8%EB%84%90%EC%9D%B4-%EC%95%88-%EC%BC%9C%EC%A1%8C%EC%8A%B5%EB%8B%88%EB%8B%A4-Open-VSX-%EB%8B%A4%EC%9A%B4%EB%A1%9C%EB%93%9C-%EC%95%BD-300%EB%B2%88-%EB%8B%AC%EC%84%B1)에서는 마켓플레이스에 올린 v1.0.1을 친구가 설치했다가 `posix_spawnp failed`로 터미널이 죽는 버그를 만났습니다. 원인은 macOS에서 Dock으로 띄운 VS Code가 로그인 셸의 `PATH`를 상속받지 못해 `claude`(npm 글로벌 스크립트)의 shebang이 가리키는 `node`를 못 찾는 것이었고, 고칠 설계까지만 끝내고 편을 마쳤습니다.

그 설계가 **v1.0.2**로 나갔습니다: PATH 보강, shebang 스크립트를 VS Code 내장 Node로 실행, 친절한 spawn 실패 메시지, 빈 상태 카드, 온보딩 마법사, `Agentyard: Diagnostics` 커맨드. 2026-09-03에 태그를 자르고 릴리스 워크플로가 처음으로 실제로 돌아서 Open VSX + GitHub Release까지 자동으로 나갔습니다.

## 먼저, 지난 편 숫자 정정입니다

4편 제목에 "Open VSX 다운로드 약 300번"이라고 썼습니다. 그 뒤로 확인해보니, **그건 대부분 미러/크롤러 트래픽입니다.** Open VSX 다운로드 카운터는 레지스트리를 긁어가는 봇들도 그대로 집계합니다. 진짜 신호는 VS Code Marketplace 쪽 설치 수였고, 그건 4였습니다.

지금 다시 확인해도 VS Code Marketplace는 여전히 설치 4, 리뷰 1개(⭐5)입니다 — v1.1 이후 버전들은 Open VSX + GitHub Release로만 나가고 있고, Marketplace에는 아직 v1.0.1이 최신입니다. `VSCE_PAT`를 리포 시크릿에 넣는 걸 계속 미뤄왔기 때문입니다. 부풀린 숫자로 시작한 편을 정정하는 게 맞는 것 같아서 이번 편 맨 앞에 적어둡니다.

(screenshot-placeholder: VS Code Marketplace `wonkyard.agentyard` 리스팅 페이지, 설치 수와 리뷰가 보이는 상태)

## v1.1 — 두 번째 AI 직원을 뽑았습니다

지금까지 Agentyard는 Claude Code 전용이었습니다. v1.1부터는 아닙니다. 첫 실행 시 피커(`agentyard.agents`)로 Claude Code와 Codex 중 뭘 켤지 고를 수 있고, 둘 다 켜면:

- Run 뷰에 백엔드마다 자기 pty 터미널이 하나씩 붙고, `Claude Code ⇄ Codex` 스위처로 전환합니다. 스위처를 눌러도 세션은 안 죽습니다 — 익스텐션 호스트가 두 터미널을 다 들고 있고, 뷰만 갈아 끼웁니다.
- 새 커맨드 `Agentyard: Set Up Agent Guidelines`가 생겼습니다. Claude Code는 `CLAUDE.md`, Codex는 `AGENTS.md`를 읽는데 둘을 따로 관리하면 금방 벌어집니다. 그래서 `AGENTS.md`를 정본으로 두고, 기존 `CLAUDE.md`가 있으면 세 가지 선택지(따로 유지 / 기존 내용 옮겨 합치기 / `@AGENTS.md`를 가리키는 얇은 포인터로 교체)를 물어보고, 뭘 고르든 원본은 먼저 백업합니다.
- 회사 명단이 `state/company.db` 없이도 돌아가게 됐습니다. `.claude/agents/`만 있는 워크스페이스도 이제 "실데이터 모드"입니다. (이 회사 자신을 위한 도구에서, 다른 사람 워크스페이스에서도 그냥 되게 만드는 일반화입니다.)

(screenshot-placeholder: Run 뷰에서 `Claude Code | Codex` 스위처가 보이는 상태 — 가능하면 둘 다 활성화해서)

## v1.2 — Codex가 사무실에도 나타났습니다

v1.1은 Codex를 Run 뷰에만 넣었습니다. v1.2는 오피스 화면(사무실 픽셀 뷰)에도 Codex를 넣었습니다:

- `~/.codex/sessions/**/rollout-*.jsonl`을 새 `CodexSessionLog`로 tail해서, Claude 세션과 같은 working/idle/gone/blocked 분류기에 합류시킵니다. 키가 겹칠까 봐 `codex:<session_id>` 복합 키를 씁니다.
- 헤드리스 실행(`codex exec … --json`)이 Run 피드에 붙었습니다 — v1.1까지는 "헤드리스는 Claude만" 이었던 제약을 없앤 겁니다.
- 패널 헤더에 동기화 칩이 생겼습니다. `AGENTS.md`/`CLAUDE.md`가 맞는지 `in sync` / `diverged`로 보여주고 클릭하면 바로 맞춰줍니다.

전부 additive라, Claude 하나만 켠 설치는 v1.1과 화면이 바이트 단위로 똑같다는 걸 회귀 테스트로 확인했습니다 — Codex 켠 사람만 새 방이 보입니다.

(screenshot-placeholder: 오피스 뷰에 Claude 방과 Codex 방이 같이 보이는 상태. Codex 특유의 색(`#6ea8fe`)이 다르게 보여야 합니다)

## v1.3, v1.4 — 모델 고르기, 그리고 이어받기

**v1.3**은 작습니다. Run 헤더에 `model: <라벨> ▾` 드롭다운이 생겨서 `--model` 플래그를 매번 기억할 필요 없이 백엔드별로 모델을 고를 수 있습니다. 비워두면 그냥 CLI/설정 기본값이 이깁니다.

**v1.4**가 진짜 원했던 기능이었습니다. 한 에이전트로 작업하다가 한도에 걸리거나 막히면, 다른 에이전트로 넘어가면서 맥락을 들고 가는 것 — "이어받기"입니다. 진짜 컨텍스트 윈도우를 공유할 방법은 없으니, $0으로 되는 현실적인 버전을 만들었습니다:

- 순수 함수 `shared/handoff.js`가 **LLM 호출 없이**, 나가는 쪽 에이전트의 디스크에 남은 트랜스크립트에서 구조화된 다이제스트(목표 / 최근 대화 ~20턴 / 만진 파일 / 실행한 커맨드 / 어디서 멈췄는지)를 뽑아냅니다.
- 그걸 `.agentyard/HANDOFF.md`로 쓰고, Run 뷰를 다른 백엔드로 전환하고, 첫 프롬프트를 미리 채워서 넣습니다 — 받는 쪽 에이전트가 브리핑을 읽고 다시 정리한 뒤 이어가라는 뜻입니다.
- 버튼은 Run 뷰 백엔드-스위처 줄에 `↔ Codex에서 이어받기` 식으로 붙습니다. 오피스 헤더에 새 버튼을 또 만들지 않았습니다.

(screenshot-placeholder: Run 헤더의 model 드롭다운이 열려서 옵션 목록이 보이는 상태)

## 근데 Codex가 사무실에서 사라졌습니다

v1.4.1은 버그 픽스입니다. 2026-09-07, 실제 머신에서 Codex를 켜봤더니 오피스에 Codex 방이 하나도 안 뜨고, Codex→Claude 이어받기도 "최근 Codex 세션 없음"이라고 나왔습니다.

원인을 추적해보니: **Codex CLI(`0.153.4`)가 대화 저장 방식을 바꿨습니다.** v1.2가 tail하던 `~/.codex/sessions/**/rollout-*.jsonl`을 더는 쓰지 않고, `~/.codex/state_5.sqlite`(`threads` 테이블)와 `~/.codex/thread_history_1.sqlite`(`thread_items` / `thread_turns` 테이블)로 옮겨갔습니다. 파일이 사라진 게 아니라, Codex가 조용히 이사를 간 겁니다 — v1.2를 만들 때 진짜 `codex` CLI가 설치돼 있지 않아서 문서상의 동작을 그대로 믿었는데, 그 사이 CLI가 바뀌었습니다.

```
# v1.2가 기대한 것 (더는 안 씀)
~/.codex/sessions/2026/09/01/rollout-xxxx.jsonl

# 실제로 지금 Codex가 쓰는 것
~/.codex/state_5.sqlite          # threads 테이블
~/.codex/thread_history_1.sqlite # thread_items / thread_turns 테이블
```

다행히 회사 DB(`state/company.db`)를 읽으려고 이미 sql.js(WASM)를 번들해뒀던 게 있어서, 그걸 그대로 재사용했습니다. 새 순수 모듈 `shared/codexStore.js`가 SQLite에서 읽은 로우를 기존 `codexSessions.js`가 뱉던 것과 **똑같은 모양**으로 정규화하도록 만들어서, `live.js`나 `handoff.js`(소비하는 쪽)는 한 줄도 안 고쳤습니다. 예전 JSONL 파일은 남겨서 폴백으로 씁니다 — VS Code Codex 확장 같은 다른 클라이언트는 아직 그 형식을 쓸 수도 있으니까요. 같은 세션이 두 소스에 다 있으면 SQLite가 이깁니다.

읽기만 하고 절대 쓰지 않는다는 걸 특히 신경 썼습니다 — `CodexDbReader`는 `.codex` 아래 파일을 메모리 버퍼로 읽어서 `PRAGMA table_info`와 `SELECT`만 실행하고, `.export()`나 WAL 파일 접근 없이 항상 `finally`에서 닫습니다. 남의 CLI가 관리하는 데이터베이스니까요.

## 부작용: 회사를 지켜보는 도구가, 자기 빌드팀은 못 봤습니다

이건 이번 편을 쓰면서 알게 된 재미있는 사실입니다. Agentyard 오피스 뷰는 저장소가 분리된 프로젝트마다 별관 건물을 그리고, 그 안에 `project-lead` / `project-eng` / `release-check` 방을 따로 그립니다. 실제 빌드는 회사 세션의 서브에이전트인 `repo-team-runner`가 그 세 역할을 인프로세스로 순서대로 수행하면서 돌립니다.

그런데 `repo-team-runner`는 자기가 지금 어떤 역할을 수행 중인지와 상관없이 `status_log`에 항상 `repo-team-runner`라는 이름으로만 working/idle을 기록했습니다. 오피스는 방을 부서 이름으로 찾는데, `repo-team-runner`라는 방은 애초에 없습니다. 그러니 실제로는 v1.5를 한창 빌드하고 있어도, 오피스 화면에서는 그 별관의 방들이 전부 조용히 앉아 있는 것처럼 보였습니다. 회사를 지켜보라고 만든 도구가, 자기가 시킨 일을 자기가 못 알아본 겁니다.

고친 방법은 간단합니다: 러너가 각 단계로 들어가고 나올 때마다 `project-lead` / `project-eng` / `release-check` 각자의 이름으로 working/idle 로우를 씁니다. 이제 빌드가 진행되는 동안 그 별관에 실제로 불이 켜집니다.

(screenshot-placeholder: 별관 건물 안에서 project-lead / project-eng / release-check 방이 "working"으로 불 켜진 상태 — 다음 빌드 라운드 실행 중에 캡처)

## v1.5 — 설계는 끝났고, 지금은 승인 대기 중입니다

v1.5는 이번 편에서 가장 큰 조각이고, 아직 완전히 끝나지 않았습니다:

- **부모/자식 에이전트를 실시간으로.** 서브에이전트를 띄우는 에이전트가 있으면, 그 관계(부모 → 자식 → 손자)를 Claude Code와 Codex 양쪽 다 픽셀 뷰에 그립니다.
- **Run 뷰 도킹.** 옵션 패널을 위/아래/좌/우로 옮길 수 있고 접을 수 있습니다. 위치는 저장됩니다.
- **진짜 모델 표시.** 설정에 뭘 넣었든, 실제로 그 에이전트가 쓰고 있는 모델을 보여줍니다.
- 그 밖에 재시작 후 세션 재연결 시 리졸버 버그 수정, 이어받기가 부모 에이전트를 인식하게 하는 것.

빌드는 두 라운드를 다 썼습니다 (레포 팀 작업은 최대 2라운드까지만 재시도하는 규칙이 있습니다). 2라운드에서 자동 테스트(452개 sanity 체크, `killTree` Windows 정리, SQLite/JSONL 우선순위 회귀 포함)는 전부 초록이고, 패키징도 깨끗합니다. 그런데 레포 자체 release-check가 **BLOCK**을 냈습니다 — 이유는 코드 문제가 아니라, 아직 아무도 실제 VS Code 확장 개발 호스트에서 켜보고 진짜 Claude/Codex 부모-자식 세션을 눈으로 확인한 적이 없다는 것입니다. 합성 데이터로 만든 테스트는 다 통과했지만, "실제로 화면에서 보이는지"는 검증되지 않았습니다.

이건 제가 직접 승인해야 하는 부분입니다 — 격리된(제 평소 VS Code 프로필이 아닌) 개발 호스트에서 한 번 켜보고 실제로 그림이 맞는지 확인하는 작업이라, 다음으로 미뤄뒀습니다. 그래서 이번 편은 4편처럼 "설계는 끝났고 아직 안 나갔다"로 끝납니다.

## 다음

- v1.5: 격리 프로필에서 GUI 스모크 테스트 직접 돌리고, 통과하면 병합 + 태그.
- VS Code Marketplace에 `VSCE_PAT`를 걸어서 v1.1~v1.5를 실제로 올리기 — Open VSX에만 나가고 있는 상태를 정리.
- v1.2.1부터 미뤄온 `codex exec` 실제 인자 순서 확인은 v1.4.1에서 이미 끝냈습니다 (`--` 구분자 포함).

이번 편의 교훈: 두 번째 AI 직원을 뽑으면, "다른 직원이 잘 있는지 보는 도구"도 그 직원 사정에 맞춰 다시 짜야 합니다. 상대가 조용히 이사를 갈 수도 있고, 내가 만든 감시 도구가 애초에 내 팀 명단조차 제대로 못 읽고 있었을 수도 있습니다.
