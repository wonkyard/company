<!--
WONKYARD devlog — skintrack 2편 (2부작 중 2편, velog, 한국어)
제목 후보:
1. 딱 한 번만 동작하는 버튼: 직접 짠 SPA 라우터의 모달 누수
2. skintrack 2편: 하루 한 번 루프, 돼지 화폐, 그리고 숨은 개발자 모드
3. pushState로 이동했더니 모달이 안 닫혔습니다 — skintrack 2편
4. 하루 1회 제한은 과금이 아니라 앱의 동작 방식입니다 (skintrack 2편)
5. closeAllModals(): 150줄짜리 라우터에 teardown을 붙이며 배운 것

이미지: Founder가 앱 스크린샷을 추가합니다. 아래 (이미지-자리표시자: …) 줄을 교체하세요.
아직 없는 스크린샷을 설명하지 마세요.
-->

# 딱 한 번만 동작하는 버튼: 직접 짠 SPA 라우터의 모달 누수

> 개인용 피부 추적 안드로이드 앱 skintrack을 만드는 이야기, 2편입니다. 이번 글은 설치 직후 딱 한 번만 동작하고 그다음부터 먹통이 되던 촬영 버튼 버그에 대한 것이고, "생각날 때만 켜는 도구"였던 앱을 하루 한 번 도는 루프로 바꾼 이야기입니다 — 하루 1회 제한, 돼지 마스코트 크레딧, 그리고 숨은 개발자 모드.

← 1편: *버그 네 개가 겹쳐 쌓여 있었습니다 — 안드로이드에서 피부 분석 API 붙이기* (링크 자리표시자)

1편에서는 폰 위에서 실제 피부 분석 호출을 엔드-투-엔드로 성공시켰습니다. 2편은 제품 방향에 대한 이야기입니다. 저는 skintrack이 유틸리티가 아니라 매일 하는 습관처럼 느껴지길 바랐습니다. 그 과정에서, 직접 짠 SPA 라우터가 어떻게 사람을 물 수 있는지 잘 보여주는 버그를 만났습니다.

## 버그: 한 번은 되고, 그다음엔 버튼이 죽는다

Founder(테스터 모자를 쓴 저)가 새 APK를 깔고, 셀카를 한 장 찍고, 결과를 받았습니다. 그다음 두 번째 분석을 하려고 "카메라로 촬영"을 눌렀는데… 아무 일도 없었습니다. 에러도, 피커도, 로그도 없이 버튼이 그냥 반응하지 않았습니다.

재설치하면 또 한 번은 됩니다. 그리고 다시 죽습니다.

이 앱은 프레임워크 없는 `core/`를 Capacitor로 감싸고, 화면은 순수 바닐라 JS로 짠 구조입니다(1편에서 이유를 설명했습니다). 여기에 `src/main.js`의 150줄쯤 되는 라우터가 포함돼 있습니다. 화면 이동은 이렇게 생겼습니다:

```js
window.addEventListener('popstate', (e) => {
  const s = e.state || { route: 'home', params: {} };
  render(s.route, s.params);
});
```

그리고 `nav.go()` / `nav.replace()`는 히스토리 항목을 push한 다음 `render()`를 직접 호출합니다.

다음은 v0.4a에서 사진 확대(라이트박스)와 첫 실행 촬영 가이드를 위해 추가한 모달 프리미티브입니다. 이 모달의 teardown은 `popstate`에 걸려 있었습니다:

```js
function close() {
  if (closed) return;
  closed = true;
  document.removeEventListener('keydown', onKeydown, true);
  window.removeEventListener('popstate', close);
  overlay.remove();
  // ...
}
```

문제가 보이시나요? `nav.go()`는 `history.pushState` + `render()` 직접 호출로 화면을 이동합니다. **`pushState`에서는 `popstate` 이벤트가 발생하지 않습니다.** 그러니 화면 이동 시 모달을 닫아주는 건 하드웨어 뒤로 가기 버튼뿐이었습니다 — 그것만 `popstate`를 발생시키니까요.

버그 리포트와 정확히 일치하던 경로는 이렇습니다. 분석을 끝낸다 → 결과 화면에 있다 → 사진을 탭해서 확대한다(라이트박스 오버레이가 열림) → "홈" 탭을 탭한다(`nav.go('home')` 호출, popstate 없음) → 라이트박스 오버레이가 여전히 마운트된 채, `position: fixed`, 뷰포트 전체를 덮고, 홈 위에 올라가 있다. 그 뒤로 모든 탭은 보이지 않는 배경막에 떨어집니다. 예전에 닫기 버튼이 있던 자리쯤을 탭하면 오버레이가 사라지고 앱이 "복구"됩니다 — 그래서 완전히 고장 난 게 아니라 간헐적으로 이상한 것처럼 느껴졌던 겁니다.

## 수정: 모달 teardown은 라우터가 책임진다

솔깃한 수정은 모든 화면의 이동 핸들러에 `close()` 호출을 뿌리는 것입니다. 그게 "지금 당장 편한" 수정이고, 그렇게 하면 썩습니다 — 화면을 새로 추가할 때마다 하나 빠뜨릴 기회가 생기니까요.

대신 모달 모듈이 레지스트리를 들고 있고, 일괄 닫기 함수를 export합니다:

```js
const openModals = new Set();

/** Close every open modal. Iterates a copy — close() mutates the set. */
export function closeAllModals() {
  for (const modal of [...openModals]) modal.close();
}

export function hasOpenModal() {
  return openModals.size > 0;
}
```

이 앱의 모든 화면 이동 경로는 함수 하나 — `render()` — 로 모입니다. 그러니 호출 지점도 딱 하나입니다:

```js
async function render(route, params) {
  // Every navigation funnels through here — tab tap, nav.go, nav.replace,
  // popstate. Tear down any open modal so a full-viewport overlay can't stay
  // glued over the screen we're navigating to.
  closeAllModals();
  // ...
}
```

그리고 하드웨어 뒤로 가기는 아래 화면을 pop하는 대신 모달을 닫아야 합니다:

```js
App.addListener('backButton', () => {
  if (hasOpenModal()) {
    closeAllModals();
    return; // swallow this one press
  }
  if (history.state?.route && history.state.route !== 'home') {
    history.back();
  } else {
    App.exitApp();
  }
});
```

`close()`는 여전히 멱등이고 자기 자신을 레지스트리에서 뺍니다. 그래서 이중 닫기나 남아 있는 `popstate` 백스톱이 서로 싸우지 않습니다. `capture()` 주위에는 `finally`에서 해제되는 `busy` 재진입 가드도 추가했습니다 — 근본 원인을 고치는 건 아니지만, 네이티브 피커가 낀 상태도 버튼이 죽어 보이는 또 다른 경로거든요.

교훈: 라우터를 직접 짠다면, 모든 "화면 이동 시" 사이드 이펙트는 *실제로 모든 화면 이동에서 참인 그 하나*에 걸어야 합니다. `pushState` + 수동 render도 같이 쓴다면 `popstate`는 그 하나가 아닙니다. 테스트 스위트는 92개가 통과하고 있었지만 이 버그를 잡은 건 하나도 없었습니다. 전부 `core/`만 돌리고 라우터는 한 번도 건드리지 않았거든요. 새로 추가한 `modal.test.js`는 라우터 헬퍼를 직접 호출합니다: 모달 두 개를 열고, 화면을 이동하고, 오버레이가 0개 남았는지 확인합니다.

(이미지-자리표시자: 결과 화면 위에 라이트박스가 열려 있는 모습)

## 앱의 동작 방식: 하루 한 번 스캔

피부 트래커의 진짜 루프는 *하루 한 번 확인하고, 추이를 본다*입니다. 오후 한나절에 다섯 번 스캔해봐야 아무것도 알 수 없습니다 — 피부는 그렇게 빨리 변하지 않고, API 점수의 노이즈가 신호를 덮어버립니다. 그러니 하루 1회 제한은 단순히 비용이나 과금 문제가 아닙니다. 이 앱에 맞는 올바른 주기입니다.

새 순수 모듈 `core/entitlements.js` — `core/`의 나머지와 같은 모양입니다. 모든 사이드 이펙트는 주입된 `prefs`와 주입된 `now` 클럭을 거치고, 플랫폼 import는 0개입니다:

```js
export const ENTITLEMENT_CONFIG = {
  freeScansPerDay: 1,
  extraScanCost: { SD: 1, HD: 2 }, // 콜라겐 per extra same-day scan
  starterCollagen: 3,
};
```

- 로컬 달력 기준 하루에 무료 분석 1회.
- 같은 날 추가 스캔은 "콜라겐"을 씁니다 — 돼지 마스코트 크레딧 🐷, 표준 스캔 1개, HD 2개.
- 새로 설치하면 콜라겐 3개가 지급됩니다.
- "충전" 버튼은 있지만 일부러 비활성화해뒀습니다 — 나중에 광고 시청이나 결제 흐름이 끼워질 이음새입니다. 그때 호출할 함수가 `grantCollagen(n)`입니다.

중요한 규칙 두 가지:

**UTC가 아니라 로컬 자정에 리셋한다.** "오늘"을 구하는 뻔한 방법은 `new Date().toISOString().slice(0, 10)`입니다. 그건 UTC입니다. KST(UTC+9) 사용자한테는 이게 로컬 오전 9시에 넘어갑니다 — "하루" 스캔이 아침 먹다 말고 리셋되고, 밤 11시 스캔과 새벽 1시 스캔이 같은 날로 카운트됩니다(사실은 아닌데). 날짜 키는 로컬 구성 요소에서 나와야 합니다:

```js
export function localDateKey(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}
```

**성공했을 때만 차감한다.** 크레딧은 스캔이 실제 점수를 들고 돌아온 *후에만* 차감합니다 — 절대 미리 빼지 않습니다. 얼굴이 너무 작거나 조명이 나빠서 API가 사진을 거부하면, 그건 비용이 0입니다. 실패한 셀카에 요금을 물리는 건 사람들이 앱을 지우게 만드는 종류의 일입니다. 목/데모 스캔(오프라인 샘플 리플레이, API 키 없이도 앱이 돌도록 기본으로 켜져 있음)은 제한도 차감도 없습니다.

판단 로직은 해석된 스냅샷 위에서 도는 순수 함수입니다. 비동기 `canScan()`과, 분석 화면이 흐름 중간에 호출하는 동기 `checkScanAllowed()`가 이 함수를 공유해서, 둘이 어긋날 수 없게 했습니다:

```js
export function evaluateScan(state, tier, config = ENTITLEMENT_CONFIG) {
  const cost = costFor(tier, config);
  if (state.devUnlimited) return { ok: true, reason: 'ok', cost: 0 };
  if ((state.freeScanLeft ?? 0) > 0) return { ok: true, reason: 'ok', cost: 0 };
  const balance = asInt(state.collagen, 0);
  if (balance >= cost) return { ok: true, reason: 'ok', cost };
  if (balance <= 0) return { ok: false, reason: 'no-collagen', cost };
  return { ok: false, reason: 'daily-used-need-collagen', cost };
}
```

다 썼을 때 분석 화면은 빨간 에러 카드가 아니라 차분한 안내 카드를 보여줍니다 — "오늘 무료 분석을 다 썼어요"와 "홈으로" 버튼. 설계상 의도된 제한이 뭔가 고장 난 것처럼 보여선 안 됩니다.

(이미지-자리표시자: 콜라겐 잔량이 보이는 "오늘은 끝" 홈 상태)

## 숨은 개발자 모드

설정 화면이 일반 사용자가 절대 볼 필요 없는 것들로 지저분해지고 있었습니다: API 키 카드, 목 분석 토글, 그리고 이제 크레딧용 디버그 스위치까지. 그렇다고 이것 때문에 별도 빌드 플레이버를 만들고 싶진 않았습니다.

그래서: 2초 안에 버전 번호를 5번 탭하면 "개발자" 섹션이 나타납니다. 키 카드, 목 토글, "무제한 스캔" 스위치, 콜라겐 디버그 버튼("+10", "3으로 리셋")이 전부 이 안으로 들어갑니다. 평소 설정 화면은 섹션 세 개로 줄어듭니다.

중요한 가드 하나:

```js
export function shouldShowKeyCard(devMode, hasKey) {
  return !!devMode || !hasKey;
}
```

저장된 키가 없으면 개발자 모드와 무관하게 키 카드가 보입니다. 안 그러면 키를 지운 사용자가 키를 다시 넣을 수 있는 유일한 화면에서 잠겨버리고, 거기로 갈 방법이 없습니다. "고급 설정 숨기기"가 "사용자 가두기"가 되어선 안 됩니다.

## 다음 편

v0.4b-2가 큐에 있습니다: 점수 게이지(항목별 숫자 뒤의 채움 바, 종합 점수용 원형 링), "오늘의 피부 체크"와 연속 일수("🔥 3일 연속")를 앞세운 매일 루틴형 홈, 더 부드러운 비주얼 손질, 그리고 프로덕션에서는 아무것도 렌더링하지 않지만 나중에 삽입해도 레이아웃이 리플로우되지 않도록 DOM 노드만 잡아두는 광고 슬롯 자리표시자 컴포넌트. 연속 일수 로직은 순수 `core/streak.js`로 들어갑니다 — 세션이 하나 이상 있는 로컬 날짜의 연속, 하루는 한 번만 카운트, 하루라도 비면 끊김.

이 글을 쓰는 시점의 솔직한 상태: 촬영 버그 수정은 `main`에 머지됐고(`c2a6c4e`) APK는 CI가 빌드하지만, Founder의 기기 확인 — 새로 설치, 분석, 사진 확대, 홈 탭으로 이동, 촬영 버튼 탭, 이걸 세 번 — 은 아직 남아 있습니다. 유닛 테스트는 고쳐졌다고 말합니다(116/116). 폰은 아직 투표하지 않았습니다.
