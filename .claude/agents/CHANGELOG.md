# Changelog

All notable additions to the WONKYARD org structure are logged here — think of it as the company's growth log, not just a code changelog. Useful both for tracking what changed and as raw material for devlog posts.

Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## 2026-08-29

### Added
- **`research-desk` department.** The editorial desk for a new content line
  (`IDEA-20260829-1822`): curate recent HCI research (CHI/UIST/CSCW/DIS, arXiv cs.HC) into
  general-public "news cards" under the positioning *"the research backstory behind the AI
  news."* Cleared Gate 1 (PROCEED) and Gate 2 (BUILD — scoped as "run the 3-week instrumented
  concierge experiment," no software build). The desk does the daily one-paper pick and the
  weekly metrics rollup against the kill/pivot thresholds; the Founder reads the paper (ACM DL
  access) and produces the card in Claude Design. Picks are logged to an append-only ledger and
  archived by `cards/<YYYY>/<MM>/`. Model: `sonnet` (curation + audience judgment). A real
  automation build is gated behind month-2–3 growth thresholds.

## 2026-08-28

### Added
- **`agentyard` department.** Owns "Agentyard", a pixel-art, game-tycoon-style view of the
  whole company the Founder built for their own use: departments from `.claude/agents/*.md`,
  project repo teams, and every agent's working/idle/blocked status from `state/company.db`.
  Personal tool — skips Gate 1/2 — built as a VS Code extension that shows up as a bottom-panel
  tab (Webview + canvas + bundled sql.js), also runnable standalone for local iteration, headed
  for the Marketplace. Project `TOOL-20260828-1008`, repo `github.com/wonkyard/agentyard`.
- **`projects.local_path` column** (+ `schema.sql`). Split project repos now have a defined
  local home at `~/projects/wonkyard/<slug>` — deliberately outside the cloud-synced company
  repo so `node_modules`/build output never sync. `repo-manager` moves the working copy there
  and records the absolute path; `portfolio-manager` reads `local_path` and `cd`s there instead
  of assuming `projects/<project_id>/`. Backfilled for `ai-coding-content-kit` and
  `ai-morningcut`, which had been pushed to GitHub but left with no local copy at all.

- **Per-project repo teams.** Every project split into its own `wonkyard/<slug>` repo now gets
  a small self-contained team, not just `product-ops`: `project-lead` (decides the next
  priority), `project-eng` (implements one backlog item at a time), `product-ops` (unchanged),
  `daily-reporter` (compiles a status report on demand), and a copied `release-check`. Stored
  as a skeleton in `templates/project-repo/` and templated in by `repo-manager` at split time.
- `daily-reporter` — the reporting desk for a project repo. When the company asks "what did
  this project do today / this week," it reads git history + agent reports + open TODOs, writes
  `reports/daily/<date>.md`, and logs a one-line summary to the company DB.
- `project_reports` table in `state/company.db` (+ `schema.sql`): one-line daily/weekly
  roll-ups from each repo's `daily-reporter`, so the company answers "what did every project do
  today" with a single query.
- `repo_url` column on `projects` — the dedicated repo URL, set by `repo-manager` after a split.
- `portfolio-manager` gained a "daily roll-up" mode: run every repo's `daily-reporter` via
  scoped headless sessions, then read all summaries back from `project_reports` in one query.
- GitHub CLI (`gh`) installed on the Founder's machine so `repo-manager` can actually create
  repos. Still needs a one-time `gh auth login`.

### Notes
- `product-ops.md` moved out of the company's own `.claude/agents/` into
  `templates/project-repo/.claude/agents/` — it was never meant to run against the company
  repo, only inside product repos.
- The per-repo team is deliberately smaller than the company (5 agents vs 14): enough to keep
  one product moving and reporting, not a second full pipeline.

## 2026-08-27

### Added
- Initial pipeline: 7 core departments (`research`, `venture-lab`, `engineering`, `security-reliability`, `growth`, `customer-success`, `operations`), orchestrated via `CLAUDE.md`.
- Shared state store (`state/company.db`, SQLite) with `projects`, `gate_decisions`, and `status_log` tables, so every department reports its stage/status to one place.
- Considered a pixel-office style visualization to watch subagents work in real time (later built in-house as `agentyard`).
- `release-check` — a pre-push gatekeeper subagent that reviews diffs (secrets, debug leftovers, unintended files, scope creep) before any `git push`.
- `blog-writer` — drafts English devlog posts (for dev.to / HN / Reddit) from recent `reports/` and git history. Draft-only, never publishes.
- `blog-translator` — localizes `blog-writer`'s English drafts into Korean for velog. Draft-only, never publishes.
- Converted all subagent prompt files (`.claude/agents/*.md`) and `CLAUDE.md` from Korean to English, to make the GitHub repo (`wonkyard/company`) readable for an international audience.

### Notes
- Reasoning for the language switch: the repo itself is the content — non-Korean readers need to be able to read the department prompts, not just the blog posts about them.
- Growth/Customer Success departments are still untested in a live pipeline run as of this entry.

<!--
Template for future entries:

## YYYY-MM-DD

### Added
- <new department / subagent / capability>

### Changed
- <modified behavior of an existing department>

### Notes
- <why this was added, what problem it solved, anything worth remembering for a future blog post>
-->
