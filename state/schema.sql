-- WONKYARD shared state store schema
-- Usage: sqlite3 state/company.db < state/schema.sql   (run once)

CREATE TABLE IF NOT EXISTS projects (
    project_id     TEXT PRIMARY KEY,       -- e.g. IDEA-20260827-1430
    idea_summary   TEXT NOT NULL,
    created_at     TEXT NOT NULL,
    current_stage  TEXT NOT NULL DEFAULT 'research',
        -- research / venture-lab / engineering / security / growth / customer-success / operations / done / killed
    updated_at     TEXT NOT NULL,
    repo_url       TEXT,                  -- dedicated project repo URL, set by repo-manager after split (NULL until then)
    local_path     TEXT                   -- absolute path to the local working copy of that repo, so agents
                                          -- (portfolio-manager etc.) know where to cd. Convention:
                                          -- ~/projects/wonkyard/<repo-slug>. NULL until split / first clone.
);

-- Migration for a company.db created before these columns existed:
--   sqlite3 state/company.db "ALTER TABLE projects ADD COLUMN repo_url TEXT;"
--   sqlite3 state/company.db "ALTER TABLE projects ADD COLUMN local_path TEXT;"

CREATE TABLE IF NOT EXISTS gate_decisions (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id   TEXT NOT NULL,
    gate         TEXT NOT NULL,            -- gate1 / gate2 / release_gate
    decision     TEXT NOT NULL,            -- PROCEED/KILL/BUILD/PIVOT/PASS/FAIL
    reason       TEXT,
    ts           TEXT NOT NULL,
    FOREIGN KEY (project_id) REFERENCES projects(project_id)
);

CREATE TABLE IF NOT EXISTS status_log (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id   TEXT NOT NULL,
    department   TEXT NOT NULL,
        -- research / venture-lab / engineering / security-reliability / growth / customer-success / operations
    status       TEXT NOT NULL,            -- working / idle / blocked
    note         TEXT,
    ts           TEXT NOT NULL,
    FOREIGN KEY (project_id) REFERENCES projects(project_id)
);

CREATE TABLE IF NOT EXISTS project_reports (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id   TEXT NOT NULL,
    report_date  TEXT NOT NULL,            -- YYYY-MM-DD (or a range label for weekly)
    summary      TEXT NOT NULL,            -- one-line roll-up written by a project repo's daily-reporter
    detail_path  TEXT,                     -- path to the full report inside that project's repo
    ts           TEXT NOT NULL,
    FOREIGN KEY (project_id) REFERENCES projects(project_id)
);

-- Migration for a company.db created before project_reports existed: just re-run this file,
-- or run the CREATE TABLE above once (all statements are IF NOT EXISTS).

-- Reference queries (copy-paste ready)

-- Most recent status per department:
-- SELECT department, status, note, ts FROM status_log
-- WHERE id IN (SELECT MAX(id) FROM status_log GROUP BY department);

-- Project stage overview:
-- SELECT project_id, idea_summary, current_stage, updated_at FROM projects ORDER BY updated_at DESC;

-- Gate history for a specific project:
-- SELECT gate, decision, reason, ts FROM gate_decisions WHERE project_id = 'IDEA-20260827-1430' ORDER BY ts;

-- Daily roll-up across all project repos for one date:
-- SELECT project_id, summary FROM project_reports WHERE report_date = '2026-08-28' ORDER BY project_id;
