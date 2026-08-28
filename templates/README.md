# templates/

Skeletons that `repo-manager` copies into a new project repo at split time. Nothing here runs
in the company repo itself.

## project-repo/

The starting team and operating manual for a single spun-off product repo
(`github.com/wonkyard/<slug>`). `repo-manager` copies the whole tree into
`projects/<project_id>/`, substitutes the `<repo-slug>` and `<project_id>` placeholders, and
pushes it as the repo's first team commit.

```
project-repo/
  CLAUDE.md                        mini operating manual for the product team
  .claude/agents/
    project-lead.md      sonnet    decides the next priority, writes the backlog
    project-eng.md       sonnet    implements one backlog item at a time, owns tests
    product-ops.md       haiku     deps / competitor / monetization scan, recommend-only
    daily-reporter.md    haiku     compiles "what this repo did" on demand, logs to company DB
    release-check.md     sonnet    pre-push PASS/BLOCK gate on the diff
```

### Placeholders

Every templated file uses two literal placeholder strings that `repo-manager` replaces:

- `<repo-slug>` — the human-readable repo name, e.g. `ai-morningcut-shorts`
- `<project_id>` — the pipeline id, e.g. `IDEA-20260827-1524`

### Shared state

When a project repo's working copy sits inside a company-repo checkout, its agents reach the
shared DB at `../../state/company.db` — `daily-reporter` writes roll-up rows to
`project_reports`, others write `status_log` rows. When the repo is cloned standalone, agents
skip the DB and only write local reports.
