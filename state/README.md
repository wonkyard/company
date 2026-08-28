# state/ folder

- `company.db` — SQLite DB (created once via `sqlite3 state/company.db < state/schema.sql`)
- `schema.sql` — schema definition for the DB above

## Why this exists

Live coding-event visualizers show what an agent is doing file-by-file in real time. But business-pipeline state — which idea is at which Gate, which department owns which project — needs to be tracked separately for later querying/analysis. This DB does that job, and `agentyard` reads it to draw the company.

## When the Chief of Staff receives a new idea

```bash
sqlite3 state/company.db "INSERT INTO projects (project_id, idea_summary, current_stage, created_at, updated_at) VALUES ('IDEA-20260827-1430', 'Auto-convert long YouTube videos into shorts', 'research', datetime('now'), datetime('now'));"
```

## When a Gate decision is made

```bash
sqlite3 state/company.db "INSERT INTO gate_decisions (project_id, gate, decision, reason, ts) VALUES ('IDEA-20260827-1430', 'gate1', 'PROCEED', 'Found a gap in Korean subtitle editing', datetime('now'));"
sqlite3 state/company.db "UPDATE projects SET current_stage='venture-lab', updated_at=datetime('now') WHERE project_id='IDEA-20260827-1430';"
```

## To see the full company overview (from a terminal)

```bash
sqlite3 -header -column state/company.db "SELECT project_id, idea_summary, current_stage, updated_at FROM projects ORDER BY updated_at DESC;"
```

## To see what each department is doing right now

```bash
sqlite3 -header -column state/company.db "SELECT department, status, note, ts FROM status_log WHERE id IN (SELECT MAX(id) FROM status_log GROUP BY department);"
```

## Tables

- `projects` — one row per idea. `repo_url` is filled by `repo-manager` when the project is
  split into its own GitHub repo (NULL until then).
- `gate_decisions` — every Gate 1 / Gate 2 / Release Gate decision.
- `status_log` — start/finish rows from every department and every project-repo agent.
- `project_reports` — one-line daily/weekly roll-ups written by each project repo's
  `daily-reporter`, so the company can answer "what did each project do today" with one query
  (see `schema.sql` for the exact query).

## Daily roll-up across all project repos

```bash
sqlite3 -header -column state/company.db "SELECT project_id, summary FROM project_reports WHERE report_date = '2026-08-28' ORDER BY project_id;"
```
