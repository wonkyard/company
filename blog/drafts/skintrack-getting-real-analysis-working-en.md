<!--
WONKYARD devlog — skintrack, Part 1 of 2 (English; dev.to / HN / Reddit)
Title candidates:
1. Four bugs stacked on top of each other: getting a skin-analysis API working on Android
2. I got free API units, so I actually built the skincare tracker — Part 1: making the analysis work
3. A 400 that lied to me: debugging a Capacitor + YouCam skin-analysis app
4. Building skintrack, Part 1: from "file_size is required" to real scores on device

Images: the Founder will add app screenshots. Replace the (이미지-자리표시자: …) lines below.
Do not describe screenshots that don't exist yet.
-->

# Four bugs stacked on top of each other: getting a skin-analysis API working on Android

> I've wanted a "take a selfie, track your skin over time" app for a while. Perfect Corp offered free units of their YouCam AI Skin Analysis API, so I finally built it. Part 1 is the unglamorous part: a real analysis call kept failing, and it turned out to be four separate bugs stacked on top of each other. Part 2 is the product direction.

## Disclosure first

Perfect Corp reached out and provided free API units for this project (roughly 500, enough for maybe 80–125 skin scans). That's the entire reason this got built now instead of "someday." It did not influence any product decision, and this is not a review of their API. I'm disclosing it because it's the honest thing to do and because the unit budget shows up later in the story — I couldn't just spam test calls.

With that out of the way: I got the units, so let me actually try building this.

## What the app is

It's a personal Android app. Sideloaded to my own phone, no store release. You take a selfie, it runs skin analysis, it stores the per-metric scores locally, and it shows you the trend over time — so you can tell whether a routine change is actually doing anything.

(이미지-자리표시자: app home screen — "take a selfie" / recent result)

The original design (from the day before I started) was a buildless web app with an optional serverless proxy to hide the API key. Then I reframed it as a native Android app and most of that complexity evaporated. Native HTTP has no browser origin, so CORS never applies and the proxy tier is just gone. The app calls the server-to-server endpoint directly with a `Bearer` key.

I settled on **Capacitor wrapped around a framework-free `core/`**:

- `core/` — pure ES modules, zero Capacitor imports. All the API logic, the metric config, the trend math. Platform capabilities (HTTP, storage, camera, secrets) are injected.
- `platform/` — the Capacitor adapters that provide those capabilities.
- `src/screens/` — plain vanilla-JS views.

Rejected: native Kotlin (zero reuse with a future web version), Flutter/React Native (toolchain-rot risk, full rewrite), a plain PWA (WebView origin brings CORS and the proxy back). The point of the split is that `core/` runs unchanged under Node for tests today and could run in a browser later.

**v0.1** was a skeleton: the full API adapter coded to the V2 spec, a settings screen to paste a key (encrypted with the Android Keystore), and a mock adapter that's on by default so the app runs with no key and spends nothing. 50/50 tests passing.

**v0.2** was the part where v0.1 met an actual phone and lost. My "no bundler" trick — copy Capacitor plugin files into `www/vendor/` and wire them with an import map — works in a desktop browser and **breaks in the Android WebView**, because the plugin dist files do their own nested lazy `import()`. First real tap on "take a selfie":

```
failed to fetch dynamically imported module .../vendor/@capacitor/...
```

Real analysis with a saved key: nothing happened, no error shown, because the HTTP path went through the same broken module load and there was no error surface. Mock worked only because it touches neither `@capacitor/*` nor the network.

So I dropped the buildless dogma and adopted Vite — the standard Capacitor build. `core/` stayed framework-free; only the packaging changed. v0.2 also added camera vs gallery as two separate actions, made every error visible on screen, and added a Diagnostics screen (copyable, key redacted). 66/66 tests.

That got me to a build where I could finally run a real, unit-spending analysis. Which is where it got interesting.

## The debugging saga: four bugs, one symptom

I installed the build, picked a real photo, hit analyze. It failed in 766 ms at the very first network call:

```
POST https://yce-api-01.makeupar.com/s2s/v2.0/file → 400
{"status":400,"error":"file_size is required but wasn't included in your request.","error_code":"InvalidParameters"}
```

The thing is, the code *does* send `file_size`. I checked. `_buildFileBody()` produces exactly:

```json
{"files":[{"content_type":"image/jpeg","file_name":"selfie.jpg","file_size":131072}]}
```

So I took the API key and ran the same `/file` endpoint from a plain `curl` — the `/file` call only registers metadata, it doesn't spend a unit, so this was a free probe. From curl, that exact body returns **HTTP 200**. The request shape was right. The app was mangling it somewhere between `core` and the wire.

### Bug 1 — Android's native HTTP doesn't send a pre-stringified JSON string

`core` builds the body and does `JSON.stringify(...)`, so the platform layer receives a *string* with `Content-Type: application/json`. On the web / in Node that's exactly correct. But Android's `CapacitorHttp` serializes JS objects itself, and it does not faithfully transmit a raw pre-stringified string for `application/json` — it re-encodes or drops it. The server then sees no readable fields and names the first required one: `file_size`. The 400 was real; it was just pointing at a symptom three layers away from the cause.

The fix stays in the transport adapter — `core` keeps emitting a spec-correct string that fetch and Node handle unchanged:

```js
const ct = (headers['Content-Type'] ?? headers['content-type'] ?? '').toLowerCase();
if (typeof body === 'string' && ct.includes('json')) {
  // core emits a JSON *string* (correct for fetch / Node). Android CapacitorHttp
  // does not transmit a pre-stringified application/json string faithfully — it
  // serialises JS objects itself and drops/re-encodes a raw string, so YouCam
  // sees no fields and returns 400 "file_size is required". Parse it back here.
  try { options.data = JSON.parse(body); } catch { options.data = body; }
} else {
  options.data = body;
}
```

Every test suite passed 66/66 through all of this, because they all inject a fake HTTP client at the `core` seam and never exercise `platform/http-capacitor.js`. That was the real gap — nothing tested the transport adapter. I refactored it to take an injected transport so it's testable without a device, and added a test that a JSON-string body arrives at the fake transport as an *object* with a numeric `files[0].file_size`.

### Bug 2 — the response envelope, and a poll loop that always timed out

With the request fixed, the next problem was reading the response. The real `POST /file` 200 body looks like this:

```json
{
  "status": 200,
  "data": {
    "files": [
      {
        "file_id": "2cnJM/o4Ex…",
        "requests": [
          { "method": "PUT", "url": "https://…s3-accelerate.amazonaws.com/…", "headers": { "Content-Length": "131072", "Content-Type": "image/jpeg" } }
        ]
      }
    ]
  }
}
```

Two things the code got wrong:

1. Everything is wrapped in `{status, data: {…}}`. The reader was looking at `body.result` and `body.files`, so it fell through to `body` itself and got nothing.
2. The upload URL is nested at `files[0].requests[0].url`, not `files[0].url`. Same for the method and the presigned headers (which the S3 signature covers, so the `PUT` has to forward them verbatim or it 403s).

The worse instance of the same envelope bug was in the poll loop. The poll response carries the real state in `data.task_status` (`"running"` / `"success"` / `"error"`). The code was reading the top-level `status` field — which is the HTTP-ish `200` — so it never matched `"success"` or `"error"` and **the poll loop ran to its 120-second hard timeout on every single analysis**.

Fix was one small helper applied in every reader:

```js
function unwrap(body) {
  return body?.data ?? body?.result ?? body ?? {};
}
```

plus tolerant field fallbacks so the mock and the old fixtures still parse.

### Bug 3 — `format: "json"` returns the scores inline, not as a file

The adapter was written to the ZIP-mode flow: poll until done, then `GET` a separate `score_info.json`, then parse a flat `{concern_id: {raw_score}}` object. But with `format: "json"` the scores come back **inline in the poll response** under `data.results.output[]` — an array of `{ type, ui_score, raw_score, mask_urls }`. There is no second file to fetch. So I deleted the extra download for the json path and built the result straight from the inline array, keyed by metric id. (I kept the `score_info.json` reader as a fallback, because the mock adapter and the sample fixture use that shape.)

### Bug 4 — one wrong action name 400s the entire task

The task request sends `dst_actions` — the list of skin concerns to score. My `metrics.config.js` shipped 15 ids, some of them guesses. One of them was `dark_circle`. The SD tier's actual action is `dark_circle_v2` (`dark_circle` without the suffix is the... it's just not a valid SD action). And an unknown action doesn't get skipped — it returns `InvalidParameters` and **fails the whole `POST /task/skin-analysis` call**. SD and HD action names also can't be mixed in one request.

I found this one by pulling the authoritative SD action list out of the Perfect Corp docs and diffing it against what the code sent. The valid SD list, for the record:

```
wrinkle, acne, pore, texture, moisture, firmness, redness, oiliness, radiance,
age_spot, dark_circle_v2, eye_bag, droopy_upper_eyelid, droopy_lower_eyelid,
tear_trough, skin_type
```

## How the working structure caught bug 4

Quick aside on process, because it's the whole reason bug 4 didn't ship.

skintrack has its own repo with its own small team (`project-lead` → `project-eng` → `release-check`). The company session designs and reviews; the repo team builds on a branch. I've written about the "you built a department and then did the work yourself" failure mode before — this is the fix for it, applied here.

So the flow for the API fixes was: I wrote a fix brief (the four bugs, the curl findings, the maintainable fix direction for each), handed it to the repo team on a `v0.3-fixes` branch, and reviewed what came back.

Round 1 came back with bugs 1–3 fixed correctly, 80/80 tests, clean build, self-review PASS. But the `dst_actions` list it produced still had `dark_circle` in it and had dropped three valid actions (`firmness`, `droopy_upper_eyelid`, `droopy_lower_eyelid`) for no reason. That's a **FAIL at review** — one wrong string that 400s every real task. I wrote up exactly what was wrong, sent it back, and round 2 fixed just that: the 14-id list that's the intersection of the official SD actions and skintrack's own metrics, the dead `dark_circle` metric row removed, `dark_circle_v2` relabelled so it's the single "dark circle" metric. 81/81. Merged.

The retry cap is two build rounds per spec. It didn't need the second one for anything else.

## It works now

After the merge I ran one real end-to-end analysis on the phone: `/file` → S3 `PUT` → create task → poll → inline scores. Real skin scores, on device, from a selfie.

(이미지-자리표시자: result screen — per-metric scores + overall)

Steps 3–5 were coded against the docs, not probed with curl (creating a task spends a unit, and my budget is ~80–125 total), so the first real run was also the verification. It held up.

## First dogfooding round (v0.4a)

Then I actually used it for a few days, and a fresh batch of problems showed up. None of them were "the analysis is wrong" — they were all "this is annoying to live with."

**Raw floats everywhere.** The result screen showed `모공 50.28319990634918` — the raw `raw_score` straight from the API. The response actually carries both `raw_score` (float) and `ui_score` (a calibrated 0–100 integer meant for display, e.g. raw 57.33 → ui 68). I switched `session.scores` to store `ui_score` (falling back to `Math.round(raw_score)`), kept the untouched payload in `session.raw` so nothing's lost, and added `Math.round()` at render time so the float sessions already in the DB display cleanly with no migration.

(이미지-자리표시자: the raw-float bug — "모공 50.28319990634918")

**A ~5-second freeze after a camera shot, before the loading screen.** All the heavy pixel work — decode, full-res canvas draw, a pixel scan to estimate face width, JPEG re-encode — ran synchronously on the main thread *before* the app navigated anywhere. A fresh camera photo is much bigger than a typical gallery pick, so it was worse for camera shots. I restructured the capture flow: open the native picker, stash the raw image, navigate immediately so the progress bar is on screen, then do the conditioning work as the first phase of the loading screen.

**Occasional silent capture failures.** Same root cause. On a lower-RAM device, `canvas.toBlob` can return `null` (out of memory) with a big camera image, then `blob.arrayBuffer()` throws, and the error landed in a tiny status div that's easy to miss. Now conditioning failures throw a typed `CaptureError` and land on the full error card with a "view diagnostics" button, plus a diagnostics step that records the image dimensions and timing so the next occurrence is debuggable from a screenshot.

**No guidance when a selfie gets rejected.** I took a side-profile photo and the analysis rejected it with no explanation of what to do. So v0.4a added a capture guide modal (front-facing, fill the frame, good light, hair back) — shown once on first run, reachable any time from the home screen, and linked from the face/lighting error cards.

Also a small one: the result photo is now tap-to-zoom (a lightbox), and the app stores a slightly larger image (~720px) for that, still local-only and still wiped by "delete all data."

## Next time

The analysis works and the app is usable. Part 2 is the direction I'm taking it as a *product*: a deliberate one-scan-a-day loop (which is also just the right cadence for a skin tracker), a cute "collagen" credit as the currency for a future top-up flow, a hidden developer mode, and where ads or affiliate links could sit without making the app worse. That's Part 2.
