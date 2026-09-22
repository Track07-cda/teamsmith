# teamsmith

**Give one agent real ownership of a project**: it plans, dispatches, verifies independently, merges and keeps the ledger.

Runs on Pi; the launch/notify seam is an **internal seam (frozen)** — reserved for a possible future non-Pi adapter, with no compatibility promise (ROADMAP M3.0).

In one line: teamsmith turns a single agent session into a **project owner with a crew that can be inspected** —
not "more agents chatting with each other".

## What it actually does

| Capability | Mechanism |
|---|---|
| Dispatch | Task briefs are self-contained (context / deliverables / boundaries / copy-pasteable acceptance commands); `team dispatch` puts a worker agent into its own tmux window and git worktree |
| **Independent verification** | The agent's report is a **claim**; the PM runs the gates on an **independent checkout** (`team review <ID> --dir …`) and that becomes the evidence |
| Ledger | `BOARD.md` (state), `reviews/` (verification evidence), `threads/` (decision trail), `DECISIONS.md` (the "why") |
| Not rigid | The watchdog only wakes the owner when there is pending work; the PM can `standby` deliberately; when capacity is tight, work queues instead of thrashing |
| Boundaries | Cross-project interaction is discussion only (`team meeting`) — never command; git/forge work stays with the PM's own tools |

Design rationale: [references/philosophy.md](skills/teamsmith/references/philosophy.md) (8 principles) and
[references/protocol.md](skills/teamsmith/references/protocol.md) (why each rule exists).

## Included

| Skill | Notes |
|---|---|
| [`teamsmith`](skills/teamsmith/SKILL.md) | See above. Former name: `pi-team` (the `skills/pi-team` compatibility symlink was removed — old absolute paths must be updated) |
| [`teamsmith-init`](skills/teamsmith-init/SKILL.md) | The new-project entry point: settles the setup questions with the user, then runs the one command that writes config, the `docs/team/` skeleton and the protocol section |

This repository's own `docs/team/` **is** its ledger: the board, task briefs, reports, reviews and decisions in it are
the real records of teamsmith being built with teamsmith.

## Install

### Global CLI + project install (recommended)

```bash
npm install -g teamsmith     # the `team` CLI: one npm bin entry, checks bash >= 4 and prints the fix if it is missing
cd your-project
team init                    # config + docs skeleton + both skills into the project's .pi/skills/
```

`team init` installs `teamsmith` and `teamsmith-init` into the project's **`.pi/skills/`** — Pi's project-level
skill search path — so any session in that project sees the toolkit (the `openspec init` model: per project, and
version-lockable). The default is a symlink to the package, so package updates are live; `--copy` copies the files
instead (for an ephemeral source such as an `npx` cache, excluding `.git/` and `node_modules/`), and `--no-skills`
skips the step. Re-running is idempotent, `team bootstrap` runs the same step, and a conflict is announced rather
than replaced (`--force` replaces only an entry recognised as this skill).

### As a Pi package (no global CLI)

```bash
pi install git:git@github.com:Track07-cda/teamsmith@v1.42.0      # user level: every project
pi install -l git:git@github.com:Track07-cda/teamsmith@v1.42.0   # project level: recorded in .pi/settings.json
```

- **Pin a released tag**: `@v<version>`, the version `team version` prints. Latest tag:
  `git tag --sort=-v:refname | head -1`.
- The `git@github.com:` form (or `ssh://git@github.com/Track07-cda/teamsmith@v1.42.0`) uses your SSH key. The HTTPS
  shorthand `git:github.com/Track07-cda/teamsmith@v1.42.0` only works for a public repository — while this one is
  private it asks for credentials and fails.
- The clone lands in `~/.pi/agent/git/<host>/<path>` (user level) or `.pi/git/<host>/<path>` (project level); the
  skill directory — the `<skill>` used in every command below — is `<clone>/skills/teamsmith`.
- `pi list` shows what is installed (add `--approve` for a project you have not trusted in this session yet);
  uninstall with `pi remove [-l] --approve <source>`.

### From a checkout (developers)

```bash
git clone git@github.com:Track07-cda/teamsmith.git ~/src/teamsmith
pi install -l ~/src/teamsmith    # project level; edits in the checkout are live (nothing is copied)
```

### Without Pi: `install.sh`

On a non-Pi host, `install.sh` puts the skill **files** where a skill directory can be read —
`~/.agents/skills` by default, next to other agent skills:

```bash
./install.sh                 # symlink every skill under skills/ into ~/.agents/skills (edit repo → live)
./install.sh --copy          # copy instead of symlink
./install.sh --target DIR    # custom target (e.g. ~/.pi/agent/skills)
./install.sh --uninstall     # remove what this repo installed
```

### What the package declares — and what it deliberately does not

The manifest (`package.json`) declares the two skills (`pi.skills: ["./skills"]` loads `teamsmith` and
`teamsmith-init`) and exactly one npm `bin` entry — `team` → `bin/team.mjs`, a transparent wrapper that runs the
bash CLI with your argv, stdio and exit status. The files under `skills/teamsmith/extension/` (`team-notify.ts`, `team-bg.ts`,
`team-inbox-watch.ts`) are deliberately **not** in the manifest: teamsmith injects each of them with `-e` when it
starts a PM or a worker window, so they exist only inside team windows. Installing the package adds no global
extension, command or hook to your own session.

## Requirements

| Need | Why |
|---|---|
| **Pi ≥ 0.76.0** | The session harness needs `--session-id`, which `team doctor` fails without; it landed in Pi 0.76.0 and is verified working on 0.85.1. Package installs work from 0.74.0 on, but 0.74.0 lacks `--session-id`, so 0.76.0 is the floor |
| `bash` ≥ 4 | The CLI is bash (no jq/python); the npm `team` entry point checks this before running and prints the fix when it is missing |
| `git` ≥ 2.31 | One worktree per agent; the PM does all branching/merging |
| `tmux` | One window per agent, the PM window, and the pulse window |
| `node` ≥ 20 or `bun` ≥ 1.3 | Only for the pulse console/patrol (`scripts/panel`); point `TEAM_JS_BIN` at it when it is not on `PATH` |
| **magic-context** — `pi install npm:@cortexkit/pi-magic-context` | Recommended: the PM's cross-session memory (`ctx_search` / `ctx_memory` / `ctx_note`). `team doctor` checks it |
| **OpenSpec CLI** (`openspec`) | The spec layer and `openspec validate --all --strict` inside the gates |
| `podman` | Optional: only for the tmux-touching tests (`skills/teamsmith/tests/container-tmux.sh`) |

No forge dependency: the PM uses `git`/`gh`/`glab` directly, and cross-project contact is `team meeting`.

## Quickstart (in a project repo)

1. **Bring the project up** — ask your agent to run the `teamsmith-init` skill. It settles the questions with you
   (session and roster, models, gates, VCS mode, patrol rhythm), shows the plan, then writes it:

   ```bash
   bash <skill>/scripts/team bootstrap --print    # the plan; writes nothing
   bash <skill>/scripts/team bootstrap            # .pi/team/config.sh + docs/team/** + agent worktrees + pulse
   bash <skill>/scripts/team doctor               # self-check: git/tmux/agent CLI/dependencies/gates/capacity
   openspec init --tools pi                       # required dependency: spec root + the five phase commands
   ```

   `bootstrap` is idempotent and prints the `git worktree add` command for each agent (git stays with the PM).

2. **Dispatch the first task**:

   ```bash
   TEAM="bash <skill>/scripts/team"

   $TEAM task T1.1 --title "first task" --agent dev
   $EDITOR docs/team/tasks/T1.1-*.md               # context / deliverables / boundaries / acceptance commands
   $TEAM dispatch dev T1.1 docs/team/tasks/T1.1-*.md
   ```

3. **Verify, don't trust the report**: `$TEAM review T1.1 --dir /tmp/t1.1-check` runs the gates on an independent
   checkout of the task branch and writes `docs/team/reviews/T1.1.md` — that record, not the report, is the evidence.

## Compatibility (former name: pi-team)

- The command is still **`team`**; project config is still **`.pi/team/config.sh`**; env vars are still **`TEAM_*`**;
  team docs are still **`docs/team/**`**.
- The `skills/pi-team` **compatibility symlink was removed** (the alias period ended early by the user's call).
  Existing projects that reference the old absolute path must change it to `skills/teamsmith` — see
  [`skills/teamsmith/references/migration.md` §2](skills/teamsmith/references/migration.md).
- An `AGENTS.md` section marked `<!-- pi-team:begin -->` is migrated in place to the new marker by the next
  `team init`/`bootstrap` (idempotent).
- The Pi command `/pi-team-reload` stays registered as an alias of `/teamsmith-reload` (a command name, unrelated
  to the removed path).

## License

MIT — see [LICENSE](LICENSE).
