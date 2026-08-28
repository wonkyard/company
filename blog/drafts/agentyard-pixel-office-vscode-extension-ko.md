<!--
제목 후보:
1. AI 회사를 만들긴 했는데 눈에 안 보여서, 픽셀 사무실을 하나 지었습니다 (Claude Code 실험기 2편)
2. Agentyard: VS Code 패널에서 Claude Code 서브에이전트가 일하는 걸 구경하는 픽셀 사무실 (devlog 2편)
3. SQLite 폴링에서 Claude Code 훅으로 — 진짜로 살아 움직이는 에이전트 사무실 만들기
-->

# AI 회사를 만들긴 했는데, 눈에 안 보여서 픽셀 사무실을 지었습니다

> WONKYARD devlog 2편입니다. 1편에서 만든 에이전트 회사를 Agentyard로 옮겼습니다. 각 부서를 방으로, 각 에이전트를 스프라이트로 그려서 놀고 있을 땐 방 안을 돌아다니고, 일할 땐 책상에 앉아 타이핑하는 VS Code 익스텐션입니다. 이 글은 그걸 만든 과정입니다. 아키텍처를 어떻게 잡았는지, 그리고 패키징한 익스텐션에서만 튀어나온 Windows 버그들 이야기입니다.

## 지난 이야기

[1편](https://velog.io/@hyeokkiyaa/AI-%EC%A7%81%EC%9B%90%EB%93%A4-%EC%B1%84%EC%9A%A9%ED%95%B4%EC%84%9C-%ED%9A%8C%EC%82%AC-%ED%95%98%EB%82%98-%EB%A7%8C%EB%93%A4%EC%96%B4%EB%B4%A4%EB%8B%A4-Claude-Code-Subagent-%EC%8B%A4%ED%97%98%EA%B8%B0)에서 Claude Code 서브에이전트로 작은 회사를 하나 차렸습니다. 7개 부서를 `.claude/agents/*.md` 파일로 두고, `CLAUDE.md`가 오케스트레이터 역할을 하고, 단계 사이마다 품질 게이트가 있고, `state/company.db`라는 SQLite DB가 어떤 프로젝트가 어느 단계에 있고 각 부서가 마지막으로 뭘 했는지를 기록합니다.

돌아가긴 합니다. 아이디어를 넣으면 게이트 판정이 나오고 리포트가 쌓입니다. 그런데 전부 텍스트입니다. 한 번 실행을 걸어두고 커피 한 잔 내리고 돌아오면, 무슨 일이 있었는지 알아내려고 마크다운 벽을 읽어야 했습니다. 저는 이걸 *구경하고* 싶었습니다. 모바일 타이쿤 게임처럼 위에서 내려다보는 사무실 뷰를 띄워놓고, 패널을 힐끗 보면 누가 바쁜지 바로 보이는 그런 것 말입니다.

그래서 만들었습니다. 이름은 Agentyard입니다.

## 뭘 만들었나

VS Code 익스텐션입니다. 설치하면 아래쪽 패널에 Terminal, Output 옆으로 **Agentyard** 탭이 생깁니다. 클릭하면 사무실이 나옵니다. 부서마다 방이 하나씩 있고, 벽에는 에이전트 이름이 적힌 간판과 모델을 나타내는 색 띠(sonnet은 청록색, haiku는 노란색)가 붙어 있고, 방마다 작은 스프라이트가 한 명씩 있습니다. 놀고 있는 에이전트는 3프레임 걷기 애니메이션으로 방을 한 바퀴 돌다가 벽에서 방향을 틉니다. 일하는 에이전트는 책상에 앉아 모니터를 켜놓고, 말풍선에 지금 뭘 하는지 띄웁니다. 막힌 에이전트는 자리에서 일어나 빨간 `!`를 튕깁니다.

별도 저장소로 분리된 프로젝트들은 벽돌로 지은 별관 건물로 그려지고, 그 안에 자기네 작은 팀이 들어 있습니다.

네트워크도, API 키도, 텔레메트리도 없습니다. 로컬 파일을 읽을 뿐입니다.

## 만들면서 내린 선택들

**웹앱이 아니라 익스텐션.** 회사는 이미 VS Code로 열어둔 저장소 안에 있습니다. 데이터가 바로 거기 있습니다. 웹뷰 패널로 만들면 배포할 것도 없고, 항상 제가 작업하는 자리에 있습니다.

**웹뷰 + HTML5 canvas, 스프라이트는 코드로.** 게임 엔진도, 아트 에셋도 없습니다. 모든 스프라이트는 고정된 16색 팔레트에 정수 `fillRect` 호출로 그립니다. "책상"은 사각형 네 개입니다. 이렇게 하면 번들이 작게 유지되고, 숫자만 고치면 스프라이트를 바꿀 수 있습니다.

**sql.js (WASM)를 벤더링.** 회사 상태는 SQLite 파일입니다. 네이티브 `better-sqlite3` 의존성은 쓰고 싶지 않았습니다. 컴파일 단계가 붙고, 플랫폼별 바이너리가 필요하고, 언젠가 macOS 쓰는 사람이 마켓플레이스에서 설치하는 순간 골치 아파집니다. 그래서 [sql.js](https://github.com/sql-js/sql.js)의 WASM 빌드를 `webview/vendor/`에 그대로 복사해 넣고, CDN에서는 절대 가져오지 않습니다. 버전 올릴 때 `npm run vendor`로 다시 복사합니다.

**아래쪽 패널 탭, 알아서 뜸.** `viewsContainers.panel` contribution에 `WebviewViewProvider`를 붙이고 `onStartupFinished`로 활성화합니다. 실행할 커맨드가 없습니다. 탭을 숨기면 뷰가 파괴되기 때문에 웹뷰는 상태를 갖지 않고, 다시 보이게 될 때마다 익스텐션이 `postMessage`로 스냅샷을 새로 밀어 넣습니다.

**같은 웹뷰가 일반 브라우저에서도 돈다.** `npm run dev`를 하면 의존성 없는 정적 서버가 뜨는데, 익스텐션이 로드하는 것과 완전히 똑같은 `webview/` 폴더를 가짜 데모 데이터와 함께 서빙합니다. VS Code에 종속된 부분은 전부 `adapter.js` 하나 뒤에 몰아뒀습니다. 이게 반복 개발 속도에 크게 도움이 됐는데, 나중에 보니 한동안 버그를 하나 가려주기도 했습니다.

## 이걸 가능하게 만든 회사 쪽 배관 작업

회사 저장소에서 먼저 바꿔야 할 게 두 가지 있었습니다.

익스텐션은 `repo-manager` 에이전트를 통해 자기 저장소(`wonkyard/agentyard`)를 받았습니다. 프로젝트가 출시되면 분리해주는 그 에이전트와 같은 놈입니다. 회사 저장소에는 제품 소스 코드를 두지 않습니다. 리포트만 남습니다.

더 중요한 건 이겁니다. 프로젝트 작업본은 이제 `~/projects/wonkyard/<slug>`에, 회사 저장소 **바깥**에 일부러 둡니다. 회사 저장소는 OneDrive로 동기화되는 폴더 안에 있습니다. 동기화 폴더 안에 `node_modules/`나 `.vsix` 빌드 결과물이 들어 있으면, OneDrive가 파일 쓰기와 싸우고 `npm install` 할 때마다 작은 파일 4,000개를 동기화하는 참사가 벌어집니다. `projects` 테이블에 `local_path` 컬럼을 추가해서, 에이전트가 각 저장소가 디스크 어디에 있는지 `projects/<id>/`로 가정하지 않고 실제 위치를 알도록 했습니다.

## Windows / 패키징 삽질기

여기가 실제로 제 시간을 잡아먹은 부분입니다.

### `printf: missing unicode digit for \U`

Git Bash에서 설치/리로드 흐름을 스크립트로 짜다가, Windows 경로를 출력하는 줄을 하나 넣었습니다. Bash의 `printf`는 `\U`를 유니코드 이스케이프의 시작으로 취급하는데, `C:\Users\...`에 정확히 그게 들어 있습니다:

```
printf: missing unicode digit for \U
```

`\Users`의 `\U`가 먹혀버립니다. 해결책은 시시합니다. `%s`를 쓰고 경로를 인자로 넘기거나, 아예 Windows 경로를 `printf`에 통과시키지 않으면 됩니다. 그런데 이런 건 스크립트를 5분씩 노려보면서 "여기 뭐가 씌었나" 싶게 만드는 종류의 버그입니다.

### 패키징한 익스텐션이 "loading Agentyard…"에서 영원히 멈춤

이건 진짜 고약했는데, **패키징한 익스텐션에서만 재현됐기** 때문입니다. 브라우저에서 `npm run dev`: 정상. 소스에서 F5: 정상. `vsce package` → `.vsix` 설치 → 패널이 로딩 화면에 멈춰서 영영 렌더링이 안 됩니다.

원인은 웹뷰의 Content-Security-Policy였습니다. 개발 모드엔 CSP가 없습니다. 패키징한 웹뷰엔 있고, 제 것은 이렇게 생겼는데 한 줄이 빠져 있었습니다:

```js
const csp = [
  "default-src 'none'",
  `img-src ${webview.cspSource} data:`,
  `style-src ${webview.cspSource} 'unsafe-inline'`,
  `font-src ${webview.cspSource}`,
  // sql.js fetches its .wasm at runtime; without connect-src the webview
  // hangs forever on "loading Agentyard…" because the DB never loads.
  `connect-src ${webview.cspSource}`,
  `script-src 'nonce-${n}' 'wasm-unsafe-eval'`,
].join('; ');
```

sql.js는 초기화할 때 자기 `.wasm` 파일을 `fetch()`합니다. CSP에 `connect-src`가 없으면 그 fetch가 차단되고, Promise는 영영 resolve되지 않고, DB 로딩이 그냥... 멈춥니다. 패널엔 에러도 안 뜹니다. 제가 에러를 렌더링하고 있지 않았으니까요.

해결은 두 가지였습니다. `connect-src ${webview.cspSource}`를 추가한 것. 그리고 진짜 교훈은 이겁니다. 데이터 로딩이 실패하면 로딩 화면에 머무르지 말고, 웹뷰가 **실제 에러 텍스트를 canvas에 그리도록** 하는 것. "fetch of sql-wasm.wasm was blocked"라는 문구 하나만 보였어도 디버깅 세션 전체를 아낄 수 있었습니다.

### 흐릿한 글씨

화면이 픽셀 아트라서, 본능적으로 canvas에 `image-rendering: pixelated`를 걸고 업스케일하게 뒀습니다. 스프라이트엔 문제없습니다. 그런데 9px 라벨은 *박살*납니다. 벽 간판의 부서 이름이 죽처럼 뭉개졌는데, canvas가 소수 배율로 CSS 스케일링되고 있었기 때문입니다.

해결: 씬을 논리 크기의 2배로 canvas 백킹 스토어에 렌더링한 다음, 브라우저가 canvas 엘리먼트를 패널 폭에 맞게 *축소*하도록 둡니다.

```js
// Supersample: render the scene at SS× the logical size and let the browser
// scale the canvas element down to the panel width. This is what keeps small
// text readable — a 1× canvas scaled by CSS turns 9px labels to mush.
const SS = 2;
```

스프라이트는 여전히 정수 사각형이라 2배 해상도에서도 선명하게 유지됩니다. 글씨는 축소가 확대와 달리 텍스트에 관대하기 때문에 선명하게 유지됩니다. 지금 그 CSS 주석에는 "여기 `image-rendering: pixelated` 다시 넣지 말 것"이라는 큼직한 경고가 붙어 있습니다.

### 늘 내는 Windows 세금

git의 CRLF/LF 노이즈, OneDrive가 옛날 `projects/<id>` 폴더에 잠금을 걸고 있어서 그 폴더를 가리키는 에디터 탭을 닫기 전까지 `mv`가 실패한 것. 대단한 건 없고, 그냥 Windows에서 이걸 하면 붙는 마찰입니다.

## 진짜로 *살아 움직이게* 만들기

프로젝트의 방향을 바꾼 깨달음이 여기 있습니다. Agentyard v0.2는 `status_log` 테이블을 읽었습니다. 모든 부서가 작업을 시작하고 끝낼 때 기록하는 그 테이블입니다. 이건 *저한테는* 됩니다. 제 회사가 그 테이블에 쓰니까요.

그런데 다른 사람이 익스텐션을 설치하면, 그 테이블은 존재하지 않습니다. 사무실이 그냥 얼어붙어 있게 됩니다. 아무것도 안 움직이는 픽셀 사무실은 도구가 아니라 스크린샷입니다.

그래서 v0.3에서는 라이브 레이어를 **Claude Code 훅**으로 바꿨습니다. 익스텐션에 아주 작은 훅 스크립트가 딸려 옵니다. 라이브 모드를 켜면, 그 스크립트가 `~/.claude/settings.json`에 라이프사이클 이벤트를 커버하는 `hooks` 블록을 병합합니다:

```js
const HOOK_EVENTS = [
  'SessionStart', 'SessionEnd', 'UserPromptSubmit',
  'PreToolUse', 'PostToolUse', 'PostToolUseFailure',
  'PermissionRequest', 'SubagentStart', 'SubagentStop',
  'Stop', 'Notification',
];
```

각 이벤트가 스크립트를 실행하고, 스크립트는 `~/.claude/agentyard/events-<session>.jsonl`에 압축된 JSON 한 줄을 덧붙이고 종료합니다. HTTP 서버도, 포트도 없습니다. 익스텐션은 `FileSystemWatcher`로 그 파일들을 tail 하는데, 각 파일에서 이미 몇 바이트를 소비했는지 기억해서 새로 추가된 꼬리 부분만 파싱합니다.

작은 상태 머신이 그 이벤트 스트림을 에이전트별 상태로 바꿉니다. `PreToolUse`/`PostToolUse` 뒤로 30초쯤 아무것도 없으면 → idle. `PermissionRequest`나 실패한 툴 → blocked. `SubagentStart`/`SubagentStop`은 서브에이전트의 `agent_id`와 `agent_type`을 주는데, 이거면 각 서브에이전트를 자기 방에 자기 스프라이트로 그리기에 충분합니다. 툴 이벤트는 `tool_name`과, 입력을 한 줄로 정리한 요약을 실어 나릅니다. 그래서 말풍선이 그냥 "working"이 아니라 `Edit: webview/js/render.js`라고 말할 수 있습니다.

훅 스크립트는 일부러 편집증적으로 만들었습니다. 의존성 제로, 이상한 입력에도 절대 throw하지 않음, 디스크에 닿기 전에 자격 증명처럼 보이는 건 정규식 세트로 전부 마스킹, 네트워크 호출은 절대 안 함.

**남의 `settings.json`을 조용히 건드리는 건 할 짓이 아닙니다.** 그래서 라이브 모드는 옵트인입니다. "Turn on live mode" 커맨드는 병합하려는 JSON diff를 그대로 보여주고, 확인을 요청하고, 먼저 `settings.json.agentyard-backup`을 쓰고, 비파괴적으로 병합합니다. 기존 훅은 그대로 둡니다. Agentyard가 넣은 항목은 전부 커맨드 문자열에 `agentyard-hook.mjs`가 들어 있는 걸로 태깅되기 때문에, "Turn off live mode"는 정확히 우리 것만 걷어내고 나머지는 그대로 둡니다. 그리고 `settings.json`을 깔끔하게 파싱할 수 없으면, 다른 키를 날릴 위험을 감수하느니 그냥 중단합니다.

`state/company.db`가 사라진 건 아닙니다. 이제는 선택적인 세 번째 레이어가 되어서, WONKYARD식 파이프라인을 돌리는 사람에게 회사 보드와 게이트 히스토리를 위에 얹어줍니다.

## 지금 상태

v0.3, 설치 가능한 `.vsix`, 패널 탭, 훅에서 오는 라이브 방들. 큰 팬아웃(서브에이전트 수백 개)이 발생하면 방마다 스프라이트 수에 상한을 두고 "+N more"를 붙여서 패널이 읽을 만하게 유지됩니다. 훅도 없고 DB도 없으면, 번들된 가짜 데모 데이터로 폴백하면서 "DEMO DATA" 배지를 답니다. 그래서 갓 설치한 상태에서도 움직이는 사무실이 보입니다.

마켓플레이스 퍼블리시 전에 아직 할 일: 저장소 히스토리에서 제 프로젝트 ID와 이메일 지우기, 아이콘 다듬기, 그리고 실제로 `vsce publish` 계정 만들기.

## 3편 예고

계속 하고 싶어지는 게 하나 있습니다. 패널 안에 입력창을 두고 거기서 Claude Code 자체를 실행해서, 답변을 리포트 피드로 스트리밍해서 받는 것. 그러면 사무실 뷰를 떠나지 않고도 일감을 조금 던져놓고 결과를 읽을 수 있습니다. 그게 3편입니다.
