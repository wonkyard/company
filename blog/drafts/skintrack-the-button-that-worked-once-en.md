<!--
WONKYARD devlog — skintrack, Part 2 of 2 (English; dev.to / HN / Reddit)
Title candidates:
1. The button that worked once: a modal leak in a hand-rolled SPA router
2. Building skintrack, Part 2: a daily-ritual loop, a pig-currency, and a hidden dev mode
3. My in-app router navigated without popstate — so my modals never closed
4. A daily cap is not monetization, it's the mechanic: skintrack Part 2
5. closeAllModals(): what I learned wiring teardown into a 150-line router

Part 1 link: (placeholder — link to "Four bugs stacked on top of each other")

Images: the Founder will add app screenshots. Replace the (screenshot-placeholder: …) lines.
Do not describe screenshots that don't exist yet.
-->

# The button that worked once: a modal leak in a hand-rolled SPA router

> Part 2 of building skintrack, a personal skin-tracking Android app. This one is about a bug where the capture button worked exactly once per install, then went dead — and about turning the app from "a tool I run when I remember" into a once-a-day loop with a daily cap, a pig-mascot credit, and a hidden developer mode.

← Part 1: *Four bugs stacked on top of each other: getting a skin-analysis API working on Android* (placeholder link)

Part 1 got a real skin-analysis call working end to end on the phone. Part 2 is the product direction: I wanted skintrack to feel like a daily habit, not a utility. Along the way I hit a bug that's a good cautionary tale about hand-rolled single-page-app routers.

## The bug: works once, then the button is dead

The Founder (me, wearing the tester hat) installed a fresh APK, took one selfie, got a result. Then tapped "카메라로 촬영" for a second analysis and… nothing. No error, no picker, no log. The button just didn't do anything.

Reinstall, and it works once again. Then dead again.

The app is Capacitor wrapping a framework-free `core/` with plain vanilla-JS screens (Part 1 explains why). That includes a ~150-line router in `src/main.js`. Navigation looks like this:

```js
window.addEventListener('popstate', (e) => {
  const s = e.state || { route: 'home', params: {} };
  render(s.route, s.params);
});
```

and `nav.go()` / `nav.replace()` push a history entry and then call `render()` directly.

Here's the modal primitive I added in v0.4a for the photo-zoom lightbox and the first-run capture guide. Its teardown was wired to `popstate`:

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

See the problem? `nav.go()` navigates with `history.pushState` + a direct `render()` call. **No `popstate` event fires** on a `pushState`. So the only thing that closed a modal on navigation was the hardware back button — which also emits `popstate`.

The exact path that matched the bug report: finish an analysis → you're on the result screen → tap the photo to zoom (opens the lightbox overlay) → tap the "홈" tab (calls `nav.go('home')`, no popstate) → the lightbox overlay is still mounted, `position: fixed`, full viewport, on top of Home. Every tap after that lands on the invisible backdrop. Tapping roughly where the close button used to be dismisses it and the app "recovers" — which is why it felt intermittent rather than broken.

## The fix: the router owns modal teardown

The tempting fix is to sprinkle `close()` calls into every screen's navigation handlers. That's the "convenient right now" fix and it rots — every new screen is a chance to forget one.

Instead, the modal module keeps a registry and exports a bulk close:

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

Every navigation path in this app funnels through one function — `render()` — so that's the single call site:

```js
async function render(route, params) {
  // Every navigation funnels through here — tab tap, nav.go, nav.replace,
  // popstate. Tear down any open modal so a full-viewport overlay can't stay
  // glued over the screen we're navigating to.
  closeAllModals();
  // ...
}
```

Then hardware-back should close the modal instead of popping the screen under it:

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

`close()` stays idempotent and de-registers itself, so double-closes and the leftover `popstate` backstop don't fight each other. I also added a `busy` re-entrancy guard around `capture()` cleared in a `finally` — that doesn't fix the root cause, but a wedged native picker is a second way to get a dead-looking button.

The lesson: if you hand-roll a router, every "on navigation" side effect has to hang off the *one thing that's actually true on every navigation*. `popstate` is not that thing when you also use `pushState` + manual render. The test suite had 92 passing tests and none of them caught this, because they all drove `core/` and never exercised the router. The new `modal.test.js` calls the router helpers directly: open two modals, navigate, assert zero overlays remain.

(screenshot-placeholder: the lightbox open over the result screen)

## The mechanic: one scan a day

A skin tracker's real loop is *one check a day, watch the trend*. Scanning five times in an afternoon tells you nothing — skin doesn't change that fast, and the API's score noise would swamp the signal. So a daily cap isn't just about cost or monetization. It's the correct cadence for the thing.

New pure module, `core/entitlements.js` — same shape as the rest of `core/`, all side effects through an injected `prefs` and an injected `now` clock, zero platform imports:

```js
export const ENTITLEMENT_CONFIG = {
  freeScansPerDay: 1,
  extraScanCost: { SD: 1, HD: 2 }, // 콜라겐 per extra same-day scan
  starterCollagen: 3,
};
```

- One free analysis per local calendar day.
- Extra same-day scans cost "콜라겐" (collagen) — a pig-mascot credit, 🐷, 1 for a standard scan, 2 for HD.
- A fresh install is seeded with 3 콜라겐.
- The "충전" (top-up) button is there but deliberately disabled — it's the seam a future watch-an-ad or purchase flow plugs into. `grantCollagen(n)` is the function it'll call.

Two rules that matter:

**Reset on local midnight, not UTC.** The obvious way to get "today" is `new Date().toISOString().slice(0, 10)`. That's UTC. For a user in KST (UTC+9) that rolls over at 9am local — so your "daily" scan resets in the middle of breakfast, and a scan at 11pm and one at 1am count as the same day when they shouldn't. The date key has to come from local components:

```js
export function localDateKey(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}
```

**Consume on success only.** The credit is deducted *after* a scan comes back with real scores — never before. If the API rejects the photo for a face that's too small or bad lighting, that costs nothing. Charging someone for a failed selfie is the kind of thing that makes people uninstall. Mock/demo scans (the offline sample replay, on by default so the app runs with no API key) are never gated and never charged.

The decision logic is a pure function over a resolved snapshot, shared between the async `canScan()` and a synchronous `checkScanAllowed()` that the analyze screen calls mid-flow, so the two can't drift:

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

When you're out, the analyze screen shows a calm gate card — "오늘 무료 분석을 다 썼어요" with a "홈으로" button — not the red error card. Being rate-limited by design shouldn't look like something broke.

(screenshot-placeholder: the "done for today" home state with the collagen balance)

## The hidden developer mode

The Settings screen was getting cluttered with things a normal user should never see: the API-key card, a mock-analysis toggle, and now debug switches for credits. I didn't want to build a separate build flavor for that.

So: tap the version number 5 times within 2 seconds and a "개발자" section appears. The key card, the mock toggle, an "unlimited scans" switch, and collagen debug buttons ("+10", "reset to 3") all move into it. The everyday Settings screen drops to three sections.

The one guard that matters:

```js
export function shouldShowKeyCard(devMode, hasKey) {
  return !!devMode || !hasKey;
}
```

If there's no key saved, the key card shows regardless of dev mode. Otherwise a user who cleared their key would be locked out of the one screen where they can add it back, with no way to reach it. "Hide the advanced stuff" must never become "trap the user."

## What's next

v0.4b-2 is queued: score gauges (a fill bar behind each concern number, a circular ring for the overall score), a daily-ritual home that leads with "오늘의 피부 체크" and a streak count ("🔥 3일 연속"), a softer visual pass, and an ad-slot placeholder component that renders literally nothing in production but reserves the DOM node so a later insertion doesn't reflow the layout. The streak logic goes in a pure `core/streak.js` — consecutive local days with at least one session, a day counts once, a gap breaks it.

Honest status as I write this: the capture fix is merged to `main` (`c2a6c4e`) and the APK is built by CI, but the on-device confirmation from the Founder — install fresh, analyze, zoom the photo, tab to Home, tap capture, three times — is still pending. The unit tests say it's fixed (116/116). The phone hasn't voted yet.
