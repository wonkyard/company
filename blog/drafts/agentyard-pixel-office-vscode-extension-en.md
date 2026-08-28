<!--
Title candidates:
1. My AI company worked but I couldn't see it, so I built a pixel office for it
2. Agentyard: watching Claude Code subagents work in a tycoon-style pixel office (devlog part 2)
3. From SQLite polling to Claude Code hooks: making an agent office that's actually live
4. Windows packaging war stories from a pixel-art VS Code extension
5. I drew my whole agent company as a game-dev-tycoon office in the VS Code panel
-->

# My AI company worked, but I couldn't see it — so I built a pixel office for it

> Part 2 of the WONKYARD devlog. I turned the agent company from part 1 into Agentyard: a VS Code extension that draws every department as a room and every agent as a sprite that walks around when idle and sits typing when working. This post is the build — the architecture choices, and a pile of Windows/packaging bugs that only showed up in the packaged extension.

## Recap

In [part 1](https://velog.io/@hyeokkiyaa/AI-%EC%A7%81%EC%9B%90%EB%93%A4-%EC%B1%84%EC%9A%A9%ED%95%B4%EC%84%9C-%ED%9A%8C%EC%82%AC-%ED%95%98%EB%82%98-%EB%A7%8C%EB%93%A4%EC%96%B4%EB%B4%A4%EB%8B%A4-Claude-Code-Subagent-%EC%8B%A4%ED%97%98%EA%B8%B0) I set up a little company out of Claude Code subagents: seven departments as `.claude/agents/*.md` files, a `CLAUDE.md` that acts as the orchestrator, quality gates between stages, and a SQLite database at `state/company.db` tracking which project is at which stage and what each department last did.

It works. Ideas go in, gate decisions come out, reports get written. But it's all text. I'd kick off a run, go make coffee, come back, and read a wall of markdown to figure out what happened. I wanted to *watch* it — a top-down, mobile-tycoon-game view of the office where I can glance at the panel and see who's busy.

So I built that. It's called Agentyard.

## What it is

A VS Code extension. Install it and an **Agentyard** tab shows up in the bottom panel, next to Terminal and Output. Click it and there's an office: one room per department, a wall sign with the agent's name and a colored stripe for its model (teal for sonnet, yellow for haiku), and a little sprite in each room. Idle agents walk a loop around the room with a 3-frame walk cycle and turn at the walls. Working agents sit at the desk, monitor glowing, with a thought bubble showing what they're doing. Blocked agents stand up and bounce a red `!`.

Projects that got split into their own repos get drawn as separate brick annex buildings with their own little team inside.

No network, no API keys, no telemetry. It reads local files.

## Build choices

**Extension, not a web app.** The company lives in a repo I already have open in VS Code. The data is right there. A webview panel means zero deployment and it's always where I'm working.

**Webview + HTML5 canvas, procedural sprites.** No game engine, no art assets. Every sprite is drawn with integer `fillRect` calls against a fixed ~16-color palette. A "desk" is four rectangles. This keeps the bundle tiny and means I can tweak a sprite by editing numbers.

**sql.js (WASM), vendored.** The company state is a SQLite file. I did not want a native `better-sqlite3` dependency — that's a compile step, a per-platform binary, and a support headache the day someone on macOS installs it from the Marketplace. So it's [sql.js](https://github.com/sql-js/sql.js), the WASM build, copied straight into `webview/vendor/` and never fetched from a CDN. `npm run vendor` re-copies it after a version bump.

**Bottom-panel tab, appears on its own.** This is a `viewsContainers.panel` contribution plus a `WebviewViewProvider`, activated `onStartupFinished`. No command to run. The view gets destroyed when you hide the tab, so the webview is stateless and the extension re-pushes a snapshot via `postMessage` every time it becomes visible.

**Same webview runs in a plain browser.** `npm run dev` starts a zero-dependency static server that serves the exact same `webview/` folder the extension loads, with synthetic demo data. All the VS Code-specific bits sit behind one `adapter.js`. This mattered a lot for iteration speed — and, as it turned out, it also hid a bug for a while.

## Company plumbing that made this sane

Two things in the company repo had to change first.

The extension got its own repo (`wonkyard/agentyard`) via the `repo-manager` agent, which is the same thing that splits any project out once it ships. The company repo keeps no product source code — only the reports.

More importantly: project working copies now live at `~/projects/wonkyard/<slug>`, deliberately **outside** the company repo. The company repo is in a OneDrive-synced folder. Having `node_modules/` and `.vsix` build output inside a synced folder is a recipe for OneDrive fighting your file writes and syncing 4,000 tiny files every `npm install`. I added a `local_path` column to the `projects` table so the agents know where each repo actually lives on disk instead of assuming `projects/<id>/`.

## The Windows / packaging war stories

This is the part that actually cost me time.

### `printf: missing unicode digit for \U`

While scripting the install/reload flow in Git Bash, I had a line that printed a Windows path. Bash's `printf` treats `\U` as the start of a Unicode escape, and `C:\Users\...` contains exactly that:

```
printf: missing unicode digit for \U
```

The `\U` in `\Users` gets eaten. The fix is boring — use `%s` and pass the path as an argument, or just don't run Windows paths through `printf` — but it's the kind of thing that makes you stare at a script for five minutes wondering what's haunted.

### The packaged extension hung forever on "loading Agentyard…"

This one was genuinely nasty because it **only reproduced in the packaged extension**. `npm run dev` in a browser: fine. F5 from source: fine. `vsce package` → install the `.vsix` → the panel sits on the loading screen and never renders.

The cause: the webview Content-Security-Policy. In dev there's no CSP. In the packaged webview there is, and mine looked like this — with one line missing:

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

sql.js `fetch()`es its `.wasm` file at init. With no `connect-src` in the CSP, that fetch is blocked, the promise never resolves, and the DB load just... hangs. No error in the panel, because I wasn't rendering one.

Two fixes. Add `connect-src ${webview.cspSource}`. And — the real lesson — make the webview **draw the actual error text on the canvas** when data loading fails, instead of sitting on a loading screen. A visible "fetch of sql-wasm.wasm was blocked" would have saved me the whole debugging session.

### Blurry text

The scene is pixel-art, so my instinct was `image-rendering: pixelated` on the canvas and let it upscale. That's fine for sprites. It *shreds* 9px labels — the department names on the wall signs turned to mush, because the canvas was being CSS-scaled by a fractional factor.

Fix: render the scene at 2× the logical size into the canvas backing store, then let the browser scale the canvas element *down* to the panel width.

```js
// Supersample: render the scene at SS× the logical size and let the browser
// scale the canvas element down to the panel width. This is what keeps small
// text readable — a 1× canvas scaled by CSS turns 9px labels to mush.
const SS = 2;
```

Sprites stay crisp because they're still integer rectangles, just at 2× resolution. Text stays crisp because downscaling is kind to it in a way upscaling never is. The CSS comment now has a big "do NOT put `image-rendering: pixelated` back here" warning on it.

### The usual Windows tax

CRLF/LF noise in git, OneDrive holding a lock on the old `projects/<id>` folder so `mv` failed until I closed the editor tab pointing at it. Nothing profound, just the friction of doing this on Windows.

## Making it actually *live*

Here's the realization that reshaped the project. Agentyard v0.2 read the `status_log` table — the one every department writes to when it starts and finishes. That works for *me*, because my company writes to that table.

For anyone else who installs the extension, that table doesn't exist. The office would just be frozen. A pixel office where nothing moves is a screenshot, not a tool.

So v0.3 switched the live layer to **Claude Code hooks**. The extension ships a tiny hook script. When you turn on live mode, it merges a `hooks` block into your `~/.claude/settings.json` covering the lifecycle events:

```js
const HOOK_EVENTS = [
  'SessionStart', 'SessionEnd', 'UserPromptSubmit',
  'PreToolUse', 'PostToolUse', 'PostToolUseFailure',
  'PermissionRequest', 'SubagentStart', 'SubagentStop',
  'Stop', 'Notification',
];
```

Each event fires the script, which appends one compact JSON line to `~/.claude/agentyard/events-<session>.jsonl` and exits. No HTTP server, no port. The extension tails those files with a `FileSystemWatcher`, remembering how many bytes of each it has already consumed so it only parses the new tail.

A small state machine turns that event stream into per-agent status. `PreToolUse`/`PostToolUse` with no follow-up for ~30s → idle. `PermissionRequest` or a failed tool → blocked. `SubagentStart`/`SubagentStop` give you the subagent's `agent_id` and `agent_type`, which is enough to draw each subagent as its own sprite in its own room. The tool events carry `tool_name` and a scrubbed one-line summary of the input, so the thought bubble can say `Edit: webview/js/render.js` instead of just "working".

The hook script is deliberately paranoid: zero dependencies, never throws on bad input, runs a set of regexes to redact anything that looks like a credential before it can touch disk, and never makes a network call.

**Editing someone's `settings.json` is not something you do silently.** So live mode is opt-in. The "Turn on live mode" command shows the exact JSON diff it's about to merge, asks you to confirm, writes a `settings.json.agentyard-backup` first, and merges non-destructively — your existing hooks are kept. Every Agentyard entry is tagged by its command string containing `agentyard-hook.mjs`, so "Turn off live mode" strips exactly ours and leaves everything else. And if it can't cleanly parse your `settings.json`, it bails out rather than risk dropping your other keys.

`state/company.db` didn't go away — it's now an optional third layer that adds the company board and gate history on top, for people running a WONKYARD-style pipeline.

## Where it is now

v0.3, an installable `.vsix`, panel tab, live rooms from hooks. Big fan-outs (hundreds of subagents) get a per-room sprite cap with a "+N more" so the panel stays readable. With no hooks and no DB, it falls back to bundled synthetic demo data with a "DEMO DATA" badge, so a fresh install still shows a moving office.

Still on the list before a Marketplace publish: scrubbing my own project IDs and email out of the repo history, icon polish, and actually setting up a `vsce publish` account.

## Part 3

The thing I keep wanting: an input box in the panel that runs Claude Code itself and streams the answer back as a report feed — so I can dispatch a bit of work and read the result without leaving the office view. That's part 3.
