<!--
WONKYARD devlog (velog, English). Korean companion version comes later from blog-translator.
This is the 가늠 (Ganeum) introduction post — first pipeline product to reach a live demo.

Title candidates:
1. I used my own AI company to build a school competition entry
2. Instead of opening an editor, I handed the competition brief to my AI company
3. Building 가늠: what happens when a gated AI pipeline enters a software competition
4. My AI company caught its own measurement bug before it shipped
5. A school competition opened, so I gave it to the company of agents I built

Earlier parts of this series (agentyard devlog): link generically —
velog @hyeokkiyaa, "AI 직원들 채용해서 회사 하나 만들어봤다" parts 1–4.

Images: blog/drafts/images/ — Founder adds phone screenshots, placeholders below.
-->

# I used my own AI company to build a school competition entry

> A school software competition opened with about 10 weeks on the clock. The normal move is to open an editor and start typing. Instead I dropped the idea into WONKYARD — the company of specialized AI department-agents I've been building in the earlier parts of this series — and let its pipeline build the entry. This is what came out: 가늠 (Ganeum), a browser app that measures your pointing ability with Fitts's law and then resizes a UI to fit it. It's live, and along the way the company caught one of its own bugs.

## The setup

My school opened a "smart software" competition, SW-major division, roughly 10 weeks to submit. I've entered things like this before by just building them. This time I had another option sitting on my disk.

For the last few months I've been building WONKYARD: not a product, a *company*. It's a set of AI department-agents — `research`, `venture-lab`, `engineering`, `security-reliability`, `growth`, `customer-success`, `operations` — with a Chief of Staff agent on top that takes an idea, issues it a project id (this one is `IDEA-20260901-1455`), and routes it through a gated pipeline: research validates it, venture-lab checks market response, then (with my explicit approval, because it costs time) it goes to engineering, then a release gate. Each gate decision comes back to me in one line. The earlier parts of this devlog series are about `agentyard`, the VS Code panel that draws this company as a little pixel office so I can watch which department is "working."

So the question was: do I hand-code the competition entry, or do I make my own company build it and just review the output? I picked the second one.

## The idea I dropped in

The brief I gave the company:

Interfaces are built for the "average hand." Button sizes and spacing get chosen for a median user who doesn't exist. People with tremor, reduced fine motor control, older users, anyone operating one-handed on a train — they mis-tap and get tired, and there's no easy way to see *how far* their pointing differs from the average the UI assumes.

가늠 does three things in the browser:

1. **Measure.** Run the ISO 9241-411 circular tapping task — targets arranged on a circle, tap across the diameter in sequence — and record movement time for every tap.
2. **Results.** Fit Fitts's law to your taps: `MT = a + b · log2(A / W + 1)` (the Shannon form). Show your throughput in bits/second, your accuracy, your consistency.
3. **Adapt.** Take your measured profile and re-lay-out a sample UI — a keypad, a login form, a media toolbar — so the hit targets and spacing match *your* motor ability, not the average.

Constraints, all non-negotiable: no server, no paid API, works offline, nothing leaves the device. Even the optional AI explanation layer has to run as a small model on-device or not at all.

(screenshot-placeholder: measure screen — circular target task on a phone, one target highlighted, faint movement trail)

## What the company actually did

### Research pulled the numbers, and flagged the one it couldn't find

The adaptation model needs population presets — "healthy 20s," "older adult," "tremor" — with real Fitts regression parameters behind them. The research work went to the literature and came back with:

- **Healthy young adults, mouse:** `a ≈ −25 ms`, `b ≈ 224 ms/bit`, throughput ≈ 4.5 bits/s (Hertzum et al. 2010, consistent with the ISO 9241-9 range of 3.7–4.9 bps).
- **Older adults (65+), mouse:** `a ≈ −71 ms`, `b ≈ 333 ms/bit` — a 49% steeper slope — throughput ≈ 3.0 bits/s (Hertzum et al. 2010).
- **Tremor / Parkinson's:** *no citable regression table exists.* The literature (Keates & Trewin 2005 and follow-ups) agrees qualitatively — much longer movement times, more variance, lower error rate because users trade speed for accuracy — but nobody publishes an `a, b` pair in a comparable format.

So the tremor preset ships **labeled as an estimate**: start from the older-adult preset, scale the slope up by 1.2–1.5×, and say so in the UI and the docs. It's a defensible number for a demo, not a measured one. The sources behind all three: Hertzum et al. 2010, Keates & Trewin 2005, Soukoreff & MacKenzie 2004.

### A deeper verification pass caught a real bug

Before the build started, the spec went through a verification pass on a more capable model. It found something already sitting in `main`.

The effective-width calculation — the part that turns your landing scatter into a throughput number — was doing this:

```
deviations: kept.map(t => t.dx)
```

It fed the **raw horizontal error** `dx` of each tap into the effective-width math. That's fine for a one-dimensional left-right tapping task. But the ISO task here is *multidirectional* — 11 targets around a circle, so the approach vector points in every direction. For a vertical movement, `dx` isn't the along-axis error at all; it's the sideways (orthogonal) error. The code was mixing along-axis and across-axis scatter into one number, which poisoned the effective width, which poisoned the throughput, which poisoned the entire adaptation model downstream.

The fix was to project each landing error onto the actual movement direction, in the layer that knows where the previous target was:

```
û = (p_cur − p_prev) / |p_cur − p_prev|
devAxis  =  dx·ûx + dy·ûy
devOrtho = −dx·ûy + dy·ûx
```

`devAxis` is now what the width math consumes; `dx`/`dy` are kept only for the result-card drawing. There's a golden test that fires a synthetic session at a known angle and asserts `devAxis` matches the axis component to 1e-6, and that `dx ≠ devAxis` on a diagonal.

The same pass also caught an over-claim. The adaptation model was described as sizing controls for "predicted error rate ≤ 4%," quietly mixing a 1-D and a 2-D error model. Corrected: it's a **1-D, per-axis** predicted error ≤ 4%, and the "why did this change?" tooltip now shows the 2-D number right next to it (`exp(−(W/2)² / 2σ²)`, about 12% at `W = We`) with the label "a defensible heuristic, not an optimum."

### The build was split into small, gated rounds

Engineering here means the `ganeum` repo's own team — `project-lead`, `project-eng`, `release-check` — running inside the repo. The Chief of Staff writes the spec for a round, the repo team builds it on a work branch, then it comes back to a gate: PASS and it merges, FAIL and it goes back with a written list of what's wrong.

- **Round 1:** skeleton + measurement engine + CI + golden tests.
- **Round 2 (a FAIL):** I opened the deployed build on my phone and the measure screen was stretched vertically, targets clipped, and tapping the highlighted circle mostly missed. Root cause: the canvas computed its layout in one coordinate space and CSS displayed it in another, so hit-testing compared points from two different spaces. The whole round went to fixing that one bug — single source of truth for the canvas size, plus a phone-viewport regression test. After that I deliberately kept rounds smaller.
- **Round 3A:** measure → results → result card, plus the engine-accuracy fixes above, plus the `localStorage` layer.
- **Round 3B-a / 3B-b:** the credit-card screen calibration, the adaptation model core, then the adaptation UI. End of 3B-b, the three-act demo was complete.
- **Round 5-6-a:** the "what is 가늠?" education page and two more sample UIs.

### It's TypeScript with zero runtime dependencies

The stack is TypeScript + Vite, dev dependencies only. The SVG chart, the least-squares regression, the statistics, the inverse-normal approximation, the adaptation sizing math — all hand-written. The reason is a standing rule in the company: build it so it still runs on another machine in a year, not so it passes a demo today. Right now that's ~189 tests, `src/core/` held at 100% line coverage, and a ~44 kB JS bundle (about 17 kB gzipped). The core functions are golden-tested against the ISO spec and the published numbers — Shannon `ID` for a known `A`/`W`, hand-computed regression, hand-computed effective throughput.

(screenshot-placeholder: results screen — SVG scatter plot with the Fitts regression line mid-draw, throughput number counting up)

## Where it is now

It's live: **https://wonkyard.github.io/ganeum/** — GitHub Pages, auto-deploys on merge to `main`.

It's a three-act demo. **Measure**: the ~30-second circular tapping task. **Results**: the regression line draws itself across the scatter plot, the throughput counts up, and a comparison panel overlays the literature preset regression lines (no "you're in the top N%" — there's no dataset to back that, so it isn't claimed). **Adapt**: a morph slider labeled "20s ↔ you ↔ tremor ↔ older" resizes a sample keypad, login form, or media toolbar in real time, snapping to your measured position on the slider. There's an optional credit-card calibration step (hold an ID-1 card to the screen for a px-to-mm ratio) so the adapted sizes can be shown in real millimeters instead of relative multipliers.

And there's a "what is 가늠?" education page — seven sections on Fitts's law, the ISO task, why "average" fails, and the model's limits, with an interactive widget you can drag to watch predicted movement time change.

(screenshot-placeholder: adapt screen — morph slider mid-drag, sample keypad visibly resizing)

(screenshot-placeholder: education page — Fitts's law section with the interactive widget)

## What's next, and what this felt like

Submission is about 8 weeks out. Still on the list: the precise measurement mode (9 conditions instead of 3), left-hand vs right-hand comparison, and the on-device LLM explanation layer — a rule-based explanation already ships as the fallback, so the model is purely additive. Then the accessibility audits, since accessibility is the whole point of the entry.

The strange part has been the role. I didn't write 가늠. I wrote specs, read build reports, and sat at a gate deciding PASS or FAIL. When the verification pass flagged the `dx` bug, my job wasn't to fix it — it was to read the finding, decide it was real, and write the round that addressed it. It's closer to running a small team than to programming, and the thing that made it work wasn't the agents being clever. It was the gates: small scoped rounds, a written spec in, a reviewed diff out, and a hard cap on retries so a bad round can't spiral. The one round that broke that rule — round 2, one bug, whole round — is the one that taught me to keep them small.
