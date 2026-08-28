# WONKYARD

An AI company simulation running on Claude Code subagents. Drop an idea, and it flows through a pipeline —
market research, market-test simulation, engineering, security review, growth, customer success, and
operations — with human-approved Gates in between. Separate tracks handle personal tooling, GitHub repo
separation per product, and portfolio-wide maintenance.

> Make weird things work.

## Folder structure

```
wonkyard/
├── CLAUDE.md
├── CHANGELOG.md
├── .claude/
│   └── agents/
│       ├── research.md              (haiku)
│       ├── venture-lab.md           (sonnet)
│       ├── engineering.md           (sonnet)
│       ├── security-reliability.md  (sonnet)
│       ├── release-check.md         (sonnet)
│       ├── growth.md                (sonnet)
│       ├── customer-success.md      (haiku)
│       ├── operations.md            (sonnet)
│       ├── blog-writer.md           (sonnet)
│       ├── blog-translator.md       (sonnet)
│       ├── personal-tools.md        (sonnet)
│       ├── repo-manager.md          (haiku)
│       ├── product-ops.md           (haiku — templated into each spun-off product repo)
│       └── portfolio-manager.md     (haiku)
├── docs/
│   └── *.md                          planning notes, also raw material for blog-writer
└── state/
    ├── schema.sql
    └── README.md
```

## Setup

1. Copy this whole structure into your project folder (`.claude` is hidden — VS Code shows it fine).
2. Initialize the DB:
   ```bash
   cd wonkyard
   sqlite3 state/company.db < state/schema.sql
   ```
3. Run `claude` here and log in with a Claude subscription account (no API key needed).
4. Confirm `gh auth status` is logged in — `repo-manager` and `portfolio-manager` depend on it.
5. Ask "list available subagents" to confirm all department agents are recognized.
6. Drop an idea:
   ```
   New idea: <your idea>
   ```
   or, for something that isn't a revenue idea:
   ```
   Build me a personal tool: <description>
   ```

## Pipeline

```
IDEA
 -> research              "Is this a real problem?"                    [haiku]
 -> Gate 1 (PROCEED/KILL)
 -> venture-lab           fake door / concierge MVP simulation         [sonnet]
 -> Gate 2 (BUILD/PIVOT/KILL)
 -> engineering           PRD -> architecture -> implementation -> tests [sonnet]
 -> security-reliability  Release Gate (PASS/FAIL)                     [sonnet]
 -> release-check         pre-push diff review (PASS/BLOCK)            [sonnet]
 -> repo-manager          split into its own GitHub repo, templates product-ops in [haiku]
 -> growth + customer-success  (ongoing, post-launch)                  [sonnet / haiku]
 -> operations            unit economics -> SCALE/KILL                 [sonnet]
```

## Alternate track: Personal Tools

```
Founder request -> personal-tools (skips Gate 1/2, TOOL- prefixed IDs) [sonnet]
                -> release-check
                -> repo-manager (optional, if it should live in its own repo)
```

## Portfolio-wide maintenance

`portfolio-manager` (company repo, haiku) surveys every repo under the `wonkyard` GitHub org and can wake up
a specific repo's own `product-ops` (haiku) team when it needs attention.

## License

TBD.