<!--
WONKYARD devlog 4편 (velog, 한국어)
제목 후보:
1. AI 직원들 채용해서 회사 하나 만들어봤다 (4) — 남이 설치했더니 터미널이 안 켜졌습니다
2. AI 직원들 채용해서 회사 하나 만들어봤다 (4) — "posix_spawnp failed", 낯선 사람이 보낸 첫 버그 리포트
3. AI 직원들 채용해서 회사 하나 만들어봤다 (4) — 내 익스텐션은 완벽한 환경을 가정했고, 첫 외부 사용자는 그렇지 않았습니다
4. AI 직원들 채용해서 회사 하나 만들어봤다 (4) — shebang, GUI PATH, node-pty: 남의 맥에서 claude를 못 찾은 이유

3편: https://velog.io/@hyeokkiyaa/AI-직원들-채용해서-회사-하나-만들어봤다-3-패널에-Claude-Code를-심다가-Windows-RCE를-잡고-v1.0.0을-출시하기까지

이미지: blog/drafts/images/ — 스크린샷은 Founder가 추가, 아래 자리표시자 참고.
-->

# 남이 설치했더니 터미널이 안 켜졌습니다

> WONKYARD devlog 4편입니다. 이번엔 Agentyard가 진짜로 공개됐습니다 — VS Code 마켓플레이스와 Open VSX, 소박하고 정직한 숫자, 그리고 처음 보는 사용자 몇 명. 그러다 친구 한 명이 맥에 설치하고 패널 터미널을 열었더니 빨간 글씨 한 줄만 떴습니다: `could not start the terminal: posix_spawnp failed.` 이번 글은 그 버그, 왜 그런지, 그리고 "모두가 내 환경이랑 똑같겠지"라는 가정을 걷어내려고 설계 중인 v1.0.2 이야기입니다.

## 지난 이야기

[3편](https://velog.io/@hyeokkiyaa/AI-%EC%A7%81%EC%9B%90%EB%93%A4-%EC%B1%84%EC%9A%A9%ED%95%B4%EC%84%9C-%ED%9A%8C%EC%82%AC-%ED%95%98%EB%82%98-%EB%A7%8C%EB%93%A4%EC%96%B4%EB%B4%A4%EB%8B%A4-3-%ED%8C%A8%EB%84%90%EC%97%90-Claude-Code%EB%A5%BC-%EC%8B%AC%EB%8B%A4%EA%B0%80-Windows-RCE%EB%A5%BC-%EC%9E%A1%EA%B3%A0-v1.0.0%EC%9D%84-%EC%B6%9C%EC%8B%9C%ED%95%98%EA%B8%B0%EA%B9%8C%EC%A7%80)에서는 픽셀 사무실 뷰를 떠나지 않고 Claude Code를 돌리려고 Run 패널을 붙였습니다. 그 과정에서 Windows 커맨드 인젝션 RCE를 만났고(`.cmd` 런처가 `cmd.exe`를 거쳐 해석되는데, `cmd.exe`로 인자를 안전하게 넘기는 방법은 존재하지 않습니다), 죽지 않는 좀비 에이전트 스프라이트를 정리했고, v1.0.0 태그를 달았습니다.

3편은 4편이 아마 "회사가 자기 자신을 리팩터링하는" 이야기 — 분리된 저장소를 빌드하는 파이프라인 변경 — 가 될 거라고 하며 끝났습니다. 그건 여전히 예정돼 있습니다. 그런데 그것보다 더 흥미로운 일이 먼저 일어났습니다: 익스텐션이 제 노트북을 떠났습니다.

## v1.0.1 배포 — 진짜 레지스트리에, 진짜 낯선 사람들에게

v1.0.1을 두 곳 모두에 배포했습니다:

- **VS Code 마켓플레이스** (`wonkyard.agentyard`) — 이 글을 쓰는 시점에 다운로드 약 36, 설치 3, 별 5개 평점 1개.
- **Open VSX** (`wonkyard/agentyard`) — 다운로드 약 298.

(3편의 v1.0.0은 git 태그와 로컬 `.vsix`뿐이었습니다. 배포된 적이 없습니다. 1.0.1이 두 레지스트리 중 어디든 실제로 존재하는 첫 버전입니다.)

작은 숫자고, 아닌 척하지 않겠습니다. 요점은 이 "설치 3"과 평점 1개가 *제가 아니라는* 것입니다. 처음으로, 한 번도 얘기해본 적 없는 사람들이 제가 본 적 없는 컴퓨터에서 이걸 돌리고 있습니다. 그러면 버그의 의미가 달라집니다.

(screenshot-placeholder: v1.0.1과 평점이 보이는 wonkyard.agentyard 마켓플레이스 리스팅)

### v1.0.1에 들어간 것

세 가지 변경, 전부 실제로 써보다가 나온 것들입니다:

**멈춰 있는 "working" 에이전트가 스스로 풀립니다.** 사무실에는 `state/company.db`로 굴러가는 보드 레이어가 있습니다 — `status_log` 테이블에 각 부서가 시작할 때 `working`, 끝날 때 `idle`을 씁니다. 세션이 마지막 `idle` 행을 못 쓰고 죽으면 그 스프라이트는 책상에 영원히 앉아 있습니다. 이틀 전 실행에서 `research`와 `portfolio-manager`가 아직 "working"인 걸 봤습니다. 해결: `webview/js/model.js`에서, 어떤 부서의 가장 최근 `status_log` 행이 `working`인데 타임스탬프가 `agentyard.staleWorkingHours`(기본 3시간)보다 오래됐으면 `idle`로 *렌더링*합니다. 렌더 단계에서만 — DB는 건드리지 않고, 데모 모드에서는 끕니다(데모 픽스처는 일부러 고정된 타임스탬프로 배포되니까).

**Run 뷰 터미널에서 Ctrl+Shift+Enter는 소프트 개행**이라 여러 줄 프롬프트를 입력할 수 있습니다. 그냥 Enter는 여전히 제출입니다. 복붙 작업이 들어갔던 그 커스텀 키 핸들러에서 같이 처리하고, `term.paste('\n')`을 씁니다 — `claude` CLI가 리터럴 입력으로 취급하는 bracketed-paste 프레이밍이라, 개행이 제출 없이 버퍼에 들어갑니다.

**드디어 사무실이 빌드 별관에 불을 켭니다.** 프로젝트가 자기 저장소로 분리되면 그 빌드는 `repo-team-runner`가 돌립니다 — 회사 세션의 인프로세스 서브에이전트입니다. 사무실은 이걸 떠돌이 러너 스프라이트 하나로 그렸고, 정작 그 프로젝트의 별관 팀(`project-lead` / `project-eng` / `release-check`)은 텅 빈 채였습니다. 팀은 노는데 계약직 한 명이 다 하는 것처럼 보였죠.

cwd 매칭으로 이걸 못 고친 이유는 조금 미묘합니다: 러너는 *회사* 세션의 서브에이전트라, 그놈이 뱉는 모든 Claude Code 훅 이벤트는 `cwd = <회사 저장소 루트>`를 달고 옵니다. 개별 Bash 커맨드 안에서 프로젝트 저장소로 `cd`는 하지만, 훅이 보고하는 세션 cwd는 안 바뀝니다. 매칭할 게 없었던 겁니다.

해결: 러너가 시작할 때 `[agentyard] build <id>` 마커를 한 번 `echo`합니다. 그게 훅 이벤트의 tool-input 요약에 들어가고, Agentyard가 파싱해서(`buildTargetFromText`) 프로젝트 id, 저장소 slug, 또는 local-path 베이스네임과 매칭합니다. 예전 cwd-inside와 lone-runner 휴리스틱은 폴백으로 남겨뒀습니다.

(screenshot-placeholder: 별관 팀이 "working"으로 불이 켜지고 "building..." 간판이 걸린 사무실 뷰)

## 배포는 아직 절반만 배선돼 있습니다

솔직히 말하면: v1.0.1은 제 노트북에서 마켓플레이스 자격증명을 셸에 띄운 채로 수동 `publish` 커맨드로 나갔습니다. 이것에 대한 GitHub Release는 없습니다. 태그로 트리거되는 릴리스 워크플로는 *만들어뒀습니다* — `vX.Y.Z`를 push하면 `.vsix`를 패키징하고, 새너티 체크를 돌리고, 두 레지스트리에 배포하고, 아티팩트를 Release에 첨부합니다 — 그런데 v1.0.1 태그를 자른 *다음에* 썼기 때문에 한 번도 안 돌았습니다. 자동화는 브랜치에 존재하고, 실제로 실행된 적은 없습니다. 다음번 숙제입니다.

## 그러다 친구가 설치했습니다

마켓플레이스에서 v1.0.1을 설치하고, Agentyard 패널을 열고, 터미널로 전환했더니, 정확히 이게, 빨간 글씨로, 다른 건 아무것도 없이 떴습니다:

```
could not start the terminal: posix_spawnp failed.
```

이 문자열은 Agentyard가 잡은 예외에서 `e.message`를 그대로 찍는 겁니다:

```js
try {
  pty = nodePty.spawn(target.file, target.args, { name: 'xterm-256color', cwd: root, env: process.env, ... });
} catch (e) {
  this._say('\r\n\x1b[31mcould not start the terminal: ' + e.message + '\x1b[0m\r\n');
  return;
}
```

### 에러에서 거꾸로 짚어보기

`posix_spawnp`는 POSIX 콜이니 그는 macOS나 Linux입니다(Windows 아님). 그리고 저 `catch`에 도달하려면, 그 앞의 코드가 `claude`를 *찾았어야* 합니다: 리졸버는 실제 파일이 `PATH`에 존재할 때만 경로를 반환합니다. 아무것도 못 찾았다면 `agentyard.claudePath`를 설정하라는 다른, 더 친절한 메시지를 받았을 겁니다.

정리하면: `claude` 파일은 존재하는데, node-pty가 그걸 exec하지 못합니다.

가장 유력한 원인은 고전적인 "VS Code 익스텐션이 내 도구를 못 찾는" 문제인데, 한 겹 더 깊은 버전입니다. Dock이나 Finder에서 실행한 VS Code는 로그인 셸의 `PATH`를 상속받지 않습니다 — `/usr/bin:/bin:/usr/sbin:/sbin` 같은 최소한의 것만 받습니다. npm-global로 깔린 `claude`는 `#!/usr/bin/env node`로 시작하는 스크립트입니다. node-pty는 이걸 **셸 없이** exec하니까, 커널의 shebang 처리가 발동해서 `node`를 찾으려 합니다 — 그 최소 PATH에서, `node`가 없는 곳에서요. spawn은 ENOENT로 실패하는데, 없는 건 `claude` 자체가 아니라 *인터프리터*입니다. 그래서 "나 claude 매일 쓰는데 바로 저기 있잖아"라는 헷갈리는 리포트가 나옵니다.

### 이게 진짜로 드러낸 것

버그는 고칠 수 있습니다. 창피한 부분은 이게 익스텐션의 가정에 대해 드러낸 것입니다. Agentyard는 완벽하게 세팅된 환경을 가정합니다:

- spawn 실패는 다음에 뭘 하라는 안내 없이 날것의 에러 문자열을 찍습니다.
- 에이전트 명단이 비어 있으면 에이전트 파일이 뭔지 설명도 없이 그냥 빈 사무실만 보여줍니다.
- 온보딩이 전혀 없습니다. 첫 실행이 500번째 실행과 똑같은 화면입니다.

빌드된 그 한 대의 컴퓨터에서는 아주 잘 됩니다. 그건 "된다"와 같은 게 아닙니다.

## v1.0.2 — 설계는 했고, 아직 빌드는 안 했습니다

계획은 이렇습니다(스펙은 작성됨; agentyard 저장소 자체 팀이 빌드하고, 여기서 제가 직접 편집하지 않습니다):

1. **조회 전에 PATH 보강** — 흔한 설치 위치를 앞에 붙입니다(`~/.local/bin`, `/opt/homebrew/bin`, `/usr/local/bin`, nvm/volta/fnm/asdf shim 디렉터리, 네이티브 설치 경로). 기존 동작은 그대로, 일반 조회가 실패할 때만 후보를 추가합니다.
2. **리졸브된 `claude`가 shebang 스크립트면, VS Code 자체 번들 Node로 실행** — `process.execPath` + `ELECTRON_RUN_AS_NODE=1` — 별도 `node`가 PATH에 있는 것에 의존하지 않습니다. 이게 친구 맥의 실제 해결책입니다.
3. **친절한 spawn 실패 메시지** — 날것의 예외 텍스트 대신 "Open Settings"와 "Run Diagnostics" 버튼.
4. **빈 상태 카드** — 에이전트 파일이 없을 때, 그게 뭔지 설명하고 스타터 파일을 만들어주겠다고 제안.
5. **패널 안의 1회성 3단계 온보딩 마법사** — Claude 감지 → 스타터 에이전트 `.md` 파일 생성(비파괴적으로 — 있는 건 건너뜀) → 완료. 플래그를 세우고 다시는 안 조릅니다. 커맨드로 다시 열 수 있습니다.
6. **항상 보이는 "?" 도움말 패널** — 번들된 마크다운으로 렌더링해서 오프라인에서도 되고 유지보수도 쉽게.
7. **`Agentyard: Diagnostics` 커맨드** — 플랫폼, 리졸브된 `claude` 경로, node-pty 로드 상태, 명단 카운트, 현재 설정을 덤프합니다 — 다음번 낯선 사람의 버그 리포트가 이번에 제가 캐물어서 알아내야 했던 정보를 처음부터 달고 오도록.

## 다음

- agentyard 저장소 팀을 통해 v1.0.2 빌드.
- 태그 하나로 실제 배포되고 GitHub Release까지 잘리도록 릴리스 자동화 배선 마무리.
- 좀 더 장기의 v0.5+ 아이디어는 여전히 리스트에 있습니다: 스프라이트 호버 툴팁, 회사 보드의 게이트 히스토리, 카메라 팬/줌, 프로젝트 리포트 티커.

이번 편의 교훈은 말하긴 쉽고 겪긴 짜증납니다: 남이 처음으로 당신 물건을 돌려보는 순간, 어떤 "된다"가 사실은 "여기서만 된다"였는지 알게 됩니다.
