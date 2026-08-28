---
name: agentyard
description: The Chief-of-Staff-side SPEC and REVIEW brief for "Agentyard" (github.com/wonkyard/agentyard) — a pixel-art, panel-tab view of the WONKYARD company. This file is the design of record and the 결재/Gate checklist. It is NOT a build agent — do not spawn it to write code. Actual building goes through `portfolio-manager` → the agentyard repo's own `project-lead` / `project-eng` / `release-check`, per the "All work on a split repo goes through its own team" section of CLAUDE.md.
tools: Read
model: sonnet
---

This file is the **spec of record and review brief** for **Agentyard**, WONKYARD's
visualization of the company (a pixel-art view that shows up as a tab in the VS Code bottom
panel). The Founder wanted a clear, glanceable view of who exists, who is busy, and what each
agent is doing — so WONKYARD is building it. Personal tool first, shippable VS Code extension
second (headed for the Marketplace). It skips Gate 1 / Gate 2 (no `research` / `venture-lab`).

**How work happens (do not build Agentyard as a company subagent):**
1. Chief of Staff updates the milestone spec below with what the next version must do.
2. `portfolio-manager` runs the agentyard repo's own team in a headless session inside
   `~/projects/wonkyard/agentyard` to build it.
3. The repo team reports back; Chief of Staff reviews against the "Rules" and the milestone's
   requirements → PASS (report to Founder) or FAIL (write up the fixes, send back, max 2
   rounds). See CLAUDE.md → "All work on a split repo goes through its own team."

Never describe Agentyard by comparison to any other product, and never name another company's
tool in the repo, README, extension description, commit messages, or reports.

Never describe Agentyard by comparison to any other product, and never name another company's
tool in the repo, README, extension description, commit messages, or reports. The framing is
always just: the Founder needed this view and made it.

## Where the code lives

- Repo: `github.com/wonkyard/agentyard`.
- Local working copy: `~/projects/wonkyard/agentyard` — recorded in `state/company.db`
  `projects.local_path`. Work there, not in the company repo.
- The repo carries its own team (`project-lead`, `project-eng`, `product-ops`,
  `daily-reporter`, `release-check`). All building goes through `portfolio-manager` → that
  team; the Chief of Staff only writes the spec and runs the review Gate (see CLAUDE.md).

## What it visualizes

Data all comes from the user's open workspace — no network, no API keys, no per-call cost:

- **Departments** — one per file in `.claude/agents/*.md` (name, `model:`, one-line
  description). Each is a room in the office.
- **Project repo teams** — every project in `state/company.db` with a non-NULL `repo_url` has
  its own team. Each is a separate annex building.
- **Agent status** — see "Data sources" below. Resolves to `working` / `idle` / `blocked`
  plus a short "what it's doing" line.
    - `idle` (or never seen) → the sprite exists but rests / wanders.
    - `working` → sprite at its desk, typing, a work bubble showing the current tool / note.
    - `blocked` → sprite with a red `!` (permission prompt, tool failure).
- **Getting close / clicking an agent** → an info panel: name, model, status, what it's doing,
  relative time.
- **Company board** — projects / stages when a WONKYARD-style `state/company.db` is present.
- When no data is present, the extension shows bundled **synthetic demo data** with a clear
  "DEMO DATA" badge, so a first-time install still shows something.

## Data sources (layered — v0.3 target)

Agentyard must work for *any* Claude Code user, not just WONKYARD. It reads three layers, each
optional, best-effort:

1. **Roster — who exists.** Scan `.claude/agents/*.md` (project), `~/.claude/agents/*.md`
   (user), and enabled plugin `agents/` dirs. Frontmatter: only `name` + `description` are
   guaranteed; `model`, `color`, `tools` are optional. Also fold in Claude Code's built-in
   agent types seen in live events (`Explore`, `Plan`, `general-purpose`, …) and the main
   session itself. The roster is "everyone we could see work," from files *and* from events.
2. **Live activity — what's happening now.** Claude Code **hooks**, configured in
   `.claude/settings.json` (project) or `~/.claude/settings.json` (user). Relevant events:
   `SessionStart` / `SessionEnd`, `UserPromptSubmit`, `PreToolUse` / `PostToolUse` /
   `PostToolUseFailure`, `PermissionRequest`, `Notification`, `SubagentStart` /
   `SubagentStop`, `Stop`, `PreCompact`. Every event carries `session_id`, `transcript_path`,
   `cwd`, `hook_event_name`; tool events add `tool_name` / `tool_input`; **inside a subagent**
   events also carry `agent_id` + `agent_type`, and `SubagentStart/Stop` carry
   `agent_id` + `agent_type` + the subagent's own transcript path. That is enough to draw
   per-agent "swim lanes."
   - Transport: the extension ships a tiny hook script that **appends one JSON line per event**
     to `~/.claude/agentyard/events-<session>.jsonl` (no HTTP server, no port). The extension
     tails those files with a `FileSystemWatcher`. An event with no new tool activity for
     ~30s → that agent goes `idle`; `SubagentStop` / `Stop` → gone.
   - Installing the hook edits the user's `settings.json`, so it is **opt-in**: a "Turn on live
     mode" action in the panel that shows the exact diff and writes it on confirm. Never write
     it silently.
3. **Business state — WONKYARD extra.** If `state/company.db` exists in the workspace, also
   read `projects` / `status_log` / `gate_decisions` for the company board, Gate history, and
   pipeline stage. Via bundled sql.js (WASM), never a system `sqlite3`.

Must degrade cleanly: no hooks installed → roster + demo motion + a hint to enable live mode;
no agents dir → just live sessions; fleet mode (hundreds of subagents) → aggregate/cap the
sprites so the panel stays readable.

## Product shape

## Product shape

- Shows up as a **tab in the VS Code bottom panel** (next to Terminal / Output / Ports), via a
  `viewsContainers.panel` + `WebviewViewProvider` contribution. Not a command-opened editor
  tab. Activates automatically when a workspace is open.
- The same webview HTML/JS also runs standalone in a plain browser for fast iteration
  (`npm run dev`, synthetic data by default; `AGENTYARD_REPO=<root>` for real data). Keep
  VS Code APIs behind a thin adapter.
- Rendering: HTML5 `<canvas>`, vanilla JS or one small vendored MIT helper — no heavy game
  engine. `image-rendering: pixelated`, fixed small palette, consistent tile size.
- Aesthetic: pixel-art, top-down, mobile-tycoon-game feel. Agents visibly move and act —
  walk cycles, sit-and-type when working, wander/rest when idle. Readability first: a glance
  tells you who is busy.
- The webview view is destroyed when its panel tab is hidden — keep it stateless and restore
  from extension-held state via `postMessage` on show; set `retainContextWhenHidden: true` for
  the animation but never rely on it for correctness.
- `state/company.db` is read via bundled **sql.js** (WASM, vendored) — never a system
  `sqlite3`.
- Update on file-change (event JSONL, agents dir, DB) plus a light ~3s tick for animation.
  Never block the editor.
- No telemetry, no network calls, no secrets. The bundled hook script only writes local
  JSONL — it never phones home.

## Milestones (this file is the standing brief — dispatch prompts stay short)

When the Founder asks for the next iteration, the calling prompt should be ~3 sentences:
"do milestone vX per agentyard.md + <2-3 lines of what changed since>". All standing context
lives here, not in the prompt.

- **v0.1** (done) — canvas scene, departments from `.claude/agents/`, annexes, sql.js, demo
  data, `npm run dev` + `npm run sanity`.
- **v0.2** (done, on `main`, `89d63b6`, release-checked) — renamed to Agentyard; bottom-panel
  `WebviewViewProvider` (`agentyard.office`), `onStartupFinished`; living scene (walk cycles,
  typing, blocked flag, furnished rooms, annexes, day tint); icon; `agentyard-0.2.0.vsix`.
- **v0.2.1 / v0.2.2** (done, on `main`) — fixed the packaged webview hanging on
  "loading Agentyard…" (CSP missing `connect-src` for sql.js's wasm); sharp text
  (supersample the scene 2× instead of `image-rendering: pixelated` upscaling).
- **v0.3** (done, on `main`, merge `a15d2a0`, release-checked PASS) — hook-based live
  activity: `hooks/agentyard-hook.mjs` appends Claude Code lifecycle events to
  `~/.claude/agentyard/events-<session>.jsonl`; `shared/hooksConfig.js` does the
  non-destructive `~/.claude/settings.json` merge (opt-in, backup first, "off" removes
  only ours); `webview/js/live.js` is the event → working/idle/blocked state machine;
  live sessions/subagents render as their own rooms with a fleet cap; `state/company.db`
  demoted to an optional board/Gate layer. `agentyard-0.3.0.vsix` built. Palette commands
  `Agentyard: Turn On/Off Live Mode`.
- **v0.4** (next) — **run Claude Code from inside the panel.** An input box + a scrollable
  "run feed" in the panel; the extension spawns `claude -p "<prompt>" --output-format
  stream-json --verbose` as a child process (cwd = workspace root), parses the NDJSON stream,
  and renders it as a feed: the prompt, assistant text, tool calls as compact lines
  (`→ Bash: npm test`), and the final result. Uses the user's existing Claude Code auth —
  **no API key, no metered billing** (this is why it's the CLI and not the Agent SDK).
  Requirements:
  - Config: `agentyard.claudePath` (default `claude`; on Windows also try `claude.cmd`),
    `agentyard.claudeExtraArgs` (string[]), `agentyard.claudePermissionMode`
    (default `default` — do NOT default to `--dangerously-skip-permissions`; headless `-p`
    can't show prompts, so document that tools must be pre-allowed in settings or via
    `--allowedTools`).
  - `--resume <session_id>` to continue the same thread across sends; a "new thread" button.
  - One run at a time; a Cancel button that kills the child process (`tree-kill` behaviour —
    kill the whole group on Windows too).
  - The office scene stays. Header toggle between "office" and "run" views (the panel is small).
  - Browser dev (`npm run dev`) stubs the run feature — show "available inside VS Code".
  - Because the spawned `claude` inherits the installed hooks, its own activity also shows up
    as live rooms in the office view — that synergy is the point; don't fight it.
  - Security: never log the prompt or output anywhere on disk; the child's stdout goes only to
    the webview. No `shell: true` with an unescaped prompt — pass the prompt as a spawn arg.
  - sanity: stream-json parse fixtures, spawn-arg construction (path + resume + permission
    mode + extra args), cancel kills the process.
- **v0.5+** (ideas) — hover tooltip; Gate-history on the board; camera pan/zoom; project-reports
  ticker; Marketplace-publish prep (scrub `TOOL-*` id + Founder email from `.claude/**` and
  git history — currently acceptable only because the repo is private); tighten the `Agent`
  tool's event summary to show only the subagent description, not the full prompt.

## Iteration protocol (keep token use lean)

1. Reuse project id `TOOL-20260828-1008`. Log `status_log` at start/end.
2. Work on a branch off `main`. Keep v0.2's proven browser render path intact — iterations are
   additive.
3. Gate before merge to `main`:
   - **Small / private iteration** → `npm run sanity` ALL PASS + a short self-check (grep for
     secrets, other-product names, absolute paths, committed `node_modules`/`*.vsix`) is
     enough. Skip the full `release-check` agent.
   - **Version bump that will be packaged or published** → full `release-check` agent first.
4. On merge: bump `package.json` version + CHANGELOG, `vsce package`, push `main`.
5. Company repo holds no Agentyard source — only `reports/TOOL-20260828-1008/`. Update that
   report each iteration; never `git push` the company repo from inside this agent.

## Output format

Save to `reports/TOOL-20260828-1008/agentyard.md`:

```
# Agentyard — TOOL-20260828-1008

What: <one-line status of this iteration>
Repo: github.com/wonkyard/agentyard
Run it: <exact commands — dev mode, VS Code F5, and .vsix install>
Status: <in progress / usable / installed / published>

## This iteration
<what got built / changed>

## Next
<what the next slice is>
```

## Rules

- Personal tool → no `research` / `venture-lab`, ever.
- $0: no paid services, no API keys, no cloud. Everything reads local files.
- Cross-platform always — no OS-specific paths, no native compilation.
- No comparison to or mention of other products, anywhere.
- Respect security basics: no hardcoded secrets, no bundled private workspace data.
- Report to the Founder in plain language, action first (see the company CLAUDE.md).
