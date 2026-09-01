<!--
WONKYARD devlog part 4 (velog, English). Korean companion version comes later from blog-translator.

Title candidates:
1. Someone else installed my extension and the terminal wouldn't start
2. "could not start the terminal: posix_spawnp failed" — the first bug report from a stranger
3. Agentyard v1.0.1 shipped to real registries, then a friend's Mac broke it (devlog part 4)
4. My VS Code extension assumed a perfect environment. The first outside user didn't have one.
5. The shebang, the GUI PATH, and node-pty: why my extension couldn't find `claude` on someone else's machine

Part 3: https://velog.io/@hyeokkiyaa/AI-직원들-채용해서-회사-하나-만들어봤다-3-패널에-Claude-Code를-심다가-Windows-RCE를-잡고-v1.0.0을-출시하기까지
Part 2: (placeholder)
Part 1: (placeholder)

Images: blog/drafts/images/  — founder adds screenshots, placeholders below.
-->

# Someone else installed my extension and the terminal wouldn't start

> Part 4 of the WONKYARD devlog. Agentyard actually went public this time — VS Code Marketplace and Open VSX, small honest numbers, a couple of strangers. Then a friend of mine installed it on a Mac, opened the panel terminal, and got one bare red line: `could not start the terminal: posix_spawnp failed.` This post is that bug, why it happens, and the v1.0.2 I'm designing to stop assuming everyone has my exact setup.

## Last time

[Part 3](https://velog.io/@hyeokkiyaa/AI-%EC%A7%81%EC%9B%90%EB%93%A4-%EC%B1%84%EC%9A%A9%ED%95%B4%EC%84%9C-%ED%9A%8C%EC%82%AC-%ED%95%98%EB%82%98-%EB%A7%8C%EB%93%A4%EC%96%B4%EB%B4%A4%EB%8B%A4-3-%ED%8C%A8%EB%84%90%EC%97%90-Claude-Code%EB%A5%BC-%EC%8B%AC%EB%8B%A4%EA%B0%80-Windows-RCE%EB%A5%BC-%EC%9E%A1%EA%B3%A0-v1.0.0%EC%9D%84-%EC%B6%9C%EC%8B%9C%ED%95%98%EA%B8%B0%EA%B9%8C%EC%A7%80) added a Run panel to Agentyard so I could drive Claude Code from inside the pixel-office view, hit a Windows command-injection RCE on the way (`.cmd` launchers get interpreted by `cmd.exe`, and there is no safe way to pass arguments through `cmd.exe`), killed some zombie agent sprites, and tagged v1.0.0.

I ended Part 3 saying Part 4 would probably be "the company refactoring itself" — the pipeline changes for how split-out repos get built. That's still coming. But something more interesting happened first: the extension left my laptop.

## v1.0.1 shipped — to actual registries, to actual strangers

I published v1.0.1 to both:

- **VS Code Marketplace** (`wonkyard.agentyard`) — as I write this, about 36 downloads, 3 installs, one 5-star rating.
- **Open VSX** (`wonkyard/agentyard`) — about 298 downloads.

(v1.0.0 from Part 3 was only ever a git tag and a local `.vsix`. It never got published. 1.0.1 is the first version that exists on either registry.)

These are small numbers and I'm not pretending otherwise. The point is the "3 installs" and the one rating are *not me*. For the first time, people I've never talked to are running this thing on machines I've never seen. That changes what a bug means.

(screenshot-placeholder: Marketplace listing for wonkyard.agentyard showing v1.0.1 and the rating)

### What was in v1.0.1

Three changes, all fallout from actually using the thing:

**Stale "working" agents self-clear.** The office has a board layer driven by `state/company.db` — a `status_log` table where each department writes `working` when it starts and `idle` when it finishes. If a session dies without writing that final `idle` row, the sprite sits at its desk forever. I saw `research` and `portfolio-manager` still "working" from a run two days earlier. Fix: in `webview/js/model.js`, if the newest `status_log` row for a department is `working` but its timestamp is older than `agentyard.staleWorkingHours` (default 3h), *render* it as `idle`. Render-side only — the database is never touched, and it's disabled in demo mode because the demo fixture ships frozen timestamps on purpose.

**Ctrl+Shift+Enter is a soft newline** in the Run-view terminal, so you can type a multi-line prompt. Plain Enter still submits. It's handled in the same custom key handler that the copy/paste work went into, and it uses `term.paste('\n')` — bracketed-paste framing that the `claude` CLI treats as literal input, so the newline lands in the buffer without submitting.

**The office finally lights up the build annex.** When a project gets split into its own repo, its build is run by a `repo-team-runner` — an in-process subagent of the company session. The office used to draw that as a lone wandering runner sprite while the project's actual annex team (`project-lead` / `project-eng` / `release-check`) sat there empty. It looked like the team was slacking and one contractor was doing everything.

The reason cwd-matching couldn't fix this is a bit subtle: the runner is a subagent of the *company* session, so every Claude Code hook event it emits carries `cwd = <company repo root>`. It `cd`s into the project repo inside each individual Bash command, but the session cwd the hook reports never changes. So there was nothing to match against.

The fix: the runner now `echo`s an `[agentyard] build <id>` marker once at the start. That lands in the hook event's tool-input summary, and Agentyard parses it (`buildTargetFromText`) and matches it against the project id, the repo slug, or the local-path basename. The old cwd-inside and lone-runner heuristics stay as fallbacks.

(screenshot-placeholder: office view with an annex team lit up "working" and a "building..." sign)

## The release is only half-wired

Honest admission: v1.0.1 went out as a manual `publish` command from my laptop, with my marketplace credentials sitting in my shell. There is no GitHub Release for it. I *did* write a tag-triggered release workflow — push `vX.Y.Z`, it packages the `.vsix`, runs the sanity checks, publishes to both registries, attaches the artifact to a Release — but I wrote it *after* cutting the v1.0.1 tag, so it never fired. The automation exists on a branch and has never actually run. That's a job for next time.

## Then a friend installed it

He installed v1.0.1 from the Marketplace, opened the Agentyard panel, switched to the terminal, and got exactly this, in red, with nothing else:

```
could not start the terminal: posix_spawnp failed.
```

That string is Agentyard printing `e.message` straight from a caught exception:

```js
try {
  pty = nodePty.spawn(target.file, target.args, { name: 'xterm-256color', cwd: root, env: process.env, ... });
} catch (e) {
  this._say('\r\n\x1b[31mcould not start the terminal: ' + e.message + '\x1b[0m\r\n');
  return;
}
```

### Working backwards from the error

`posix_spawnp` is a POSIX call, so he's on macOS or Linux (not Windows). And to even reach that `catch`, the code before it had to have *found* `claude`: the resolver only returns a path when a real file exists on `PATH`. If it hadn't found anything, he'd have gotten a different, friendlier message about setting `agentyard.claudePath`.

So: the `claude` file exists, and node-pty still can't exec it.

The most likely cause is the classic "VS Code extension can't find my tools" problem, one layer deeper. VS Code launched from the Dock or Finder doesn't inherit your login shell's `PATH` — it gets a minimal one like `/usr/bin:/bin:/usr/sbin:/sbin`. The npm-global `claude` is a script starting with `#!/usr/bin/env node`. node-pty execs it **without a shell**, so the kernel's shebang handling kicks in and tries to locate `node` — on that minimal PATH, where there is no `node`. The spawn fails with ENOENT, but it's the *interpreter* that's missing, not `claude` itself. Hence the confusing "I use claude every day and it's right there" report.

### What it really exposed

The bug is fixable. The embarrassing part is what it revealed about the extension's assumptions. Agentyard assumes a fully set-up environment:

- A spawn failure prints the raw error string with no suggested next step.
- An empty agent roster just shows an empty office with no explanation of what an agent file even is.
- There is zero onboarding. First launch drops you into the same view as launch #500.

It works great on the one machine it was built on. That's not the same as working.

## v1.0.2 — designed, not built yet

Here's the plan (spec is written; the agentyard repo's own team builds it, I don't hand-edit it here):

1. **PATH augmentation** before the lookup — prepend the usual install locations (`~/.local/bin`, `/opt/homebrew/bin`, `/usr/local/bin`, the nvm/volta/fnm/asdf shim dirs, the native install path). Existing behaviour stays; this only adds candidates when the normal lookup misses.
2. **If the resolved `claude` is a shebang script, run it with VS Code's own bundled Node** — `process.execPath` plus `ELECTRON_RUN_AS_NODE=1` — instead of depending on a separate `node` being on PATH. This is the actual fix for my friend's Mac.
3. **A friendly spawn-failure message** with "Open Settings" and "Run Diagnostics" buttons instead of the raw exception text.
4. **An empty-state card** when there are no agent files, explaining what they are and offering to create starter ones.
5. **A one-time 3-step onboarding wizard** inside the panel: detect Claude → create starter agent `.md` files (non-destructively — skip any that exist) → done. It sets a flag and never nags again; you can re-open it from a command.
6. **An always-visible "?" help panel** rendered from bundled markdown, so it works offline and is easy to maintain.
7. **An `Agentyard: Diagnostics` command** that dumps platform, the resolved `claude` path, node-pty load state, roster counts, and current settings — so the next bug report from a stranger comes with the information I had to interrogate out of this one.

## What's next

- Build v1.0.2 through the agentyard repo team.
- Finish wiring the release automation so a tag actually publishes and cuts a GitHub Release.
- Longer-term v0.5+ ideas still on the list: hover tooltips on the sprites, gate history on the company board, camera pan/zoom, a project-reports ticker.

The lesson from this one is cheap to state and annoying to live: the first time someone else runs your thing, you find out which "it works" was actually "it works here."
