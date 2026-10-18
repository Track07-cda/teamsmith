# Migration and upgrade guide

One place for everything a project needs when it was set up with an older teamsmith — or under its former name,
`pi-team`, which was renamed in v1.13.0 (§2). It is written for the person who owns that project (usually the PM
session) and for anyone deciding whether upgrading is safe.

> **Headline: project data never needs migrating.** Task briefs, reports, reviews, the board, threads, decisions,
> `.pi/team/config.sh` and the runtime files under `.pi/team/state/` keep their format across every version. An
> upgrade is "get a newer skill checkout, re-run two commands, read what `doctor` says" — never a data conversion.
> What *can* move under you are the surfaces in §3–§5, and each has a one-line fix.

## 1. What is stable (stop worrying about it)

| Surface | Why it does not move |
|---|---|
| the `team` CLI | sub-commands are only ever **removed**, never renamed in place; everything that still exists keeps its name and flags |
| `.pi/team/config.sh` | sourced by bash, flat `TEAM_*` keys; new keys ship with a default, so a config written years ago keeps working (the one exception is the breaking model-policy upgrade — §5b) |
| `TEAM_*` environment variables | override the config file (env beats config) and are read that way in every version |
| the `docs/team/**` layout | `tasks/ reports/ reviews/ threads/ inbox/` plus `BOARD.md ROADMAP.md OWNERSHIP.md DECISIONS.md PROTOCOL.md` |
| `docs/team/BOARD.md` columns | `ID · task · agent · branch · deps · status`, with the status vocabulary `todo/wip/review/done/blocked/dropped` |
| the `AGENTS.md` protocol section | injected between markers and **refreshed in place** by `team init`, never appended twice; only the marker text changed once (§2) |
| `.pi/team/state/` | flat `key=value` files (agent records, `pm-loaded.env`, logs); version-agnostic and never migrated |
| version bookkeeping | `team mark-loaded` + `team version --check` compare a version string and a content hash; deleting `state/pm-loaded.env` only makes the tool say "unknown", nothing breaks |

The **text** of `SKILL.md`, `references/**` and the templates is the part that genuinely changes between versions.
Commands always re-read `scripts/**` from disk, but text already read into a running session does not change under
you — that is what `/reload` is for (§6), and §7 covers going back.

## 2. The rename: `pi-team` → `teamsmith` (v1.13.0)

The name change touched three things and only one of them needs a command from you.

| Old | New | What to do |
|---|---|---|
| `skills/pi-team` (repository path **and** installed skill directory) | `skills/teamsmith` | **change the path** (since the release that carries M22): the compatibility symlink was **removed**, so an absolute path or a `settings.json` entry that still says `skills/pi-team` must be updated to `skills/teamsmith` (or to the installed `~/.agents/skills/teamsmith`). The installed copy is unaffected — it is a link to *this repository*, not to the old name. See §2b below |
| the Pi command `/pi-team-reload` | `/teamsmith-reload` | **nothing**: the old spelling stays registered as an alias |
| the `AGENTS.md` marker `<!-- pi-team:begin -->` … `<!-- pi-team:end -->` | `<!-- teamsmith:begin -->` … `<!-- teamsmith:end -->` | run `team init` (or `team bootstrap`) once: the marker is rewritten **in place** and idempotently, with no duplicate section. `team doctor` prints a pointer to this file while the old marker is still there |
| the repository name `pi-team` | `teamsmith` | only if your own notes or scripts hard-code it; the skill's contracts (command, config, `TEAM_*`, `docs/team/**`) were never renamed |
| prose in your own docs, briefs or scripts | — | by hand: the skill cannot rewrite your files (the former name is also what a "stale session" error message used to say) |

Note on absolute paths: while the alias existed the compatibility symlink followed the **repository**, so the common
`~/.agents/skills/<name>` link and a `settings.json` `skills` entry kept working. That symlink is now **removed**
(§2c) — an absolute path written as `skills/pi-team` (the removed alias) must be updated to `skills/teamsmith`. A *copy* install
(`./install.sh --copy`) made before the release where `pi-team` was renamed keeps a frozen directory with no symlink
inside; re-run `./install.sh` there.

## 2b. The rename: `watchdog` → `pulse` (v1.36.0)

The periodic patrol was renamed. During the alias period (until v2.0.0) **nothing needs to change**:

- **Commands**: `team pulse up|down|restart|status|logs` (bare `team pulse` = `status`). The old names
  (aliases: `team watchdog …`, `watchdog-status`, `install-watchdog`, `uninstall-watchdog`) still work — they print one
  `[deprecated]` line on stdout and then do exactly what the `pulse` form does.
- **Window**: the default window name is now `pulse` (`TEAM_PULSE_WINDOW`). A still-running `watchdog` window is
  recognized as the backend: `team pulse status` / `team doctor` say so and point at `team pulse restart`, which
  swaps it for a `pulse` window. `team pulse up` never opens a second patrol next to a legacy one.
- **Variables**: each `TEAM_PULSE_<NAME>` wins over `TEAM_WATCH_<NAME>`, which wins over the default. Freshly
  generated configs write the new names; an old config keeps working, and `team pulse status` / `team doctor`
  name every legacy variable still in effect.
- **State files stay put**: `state/watchdog.pid/.log/.last/.nudge/.tick.log` keep their names during the alias
  period — two patrols side by side (double nudges, double restarts) is the one thing that must never happen.

To migrate fully: rename the six `TEAM_WATCH_*` keys in `.pi/team/config.sh` to `TEAM_PULSE_*` (values unchanged),
then `team pulse restart` to swap the window name.

## 2c. The removed path alias: `skills/pi-team` (M22)

The rename in §2 originally kept `skills/pi-team` as a compatibility symlink. That symlink is **gone** — the alias
period was ended early by the user's call. What this means for an existing project:

| Where the old path can still be written down | What to do |
|---|---|
| your `settings.json` `skills` array, or a config/`TEAM_*` value with an **absolute** path | replace the removed alias `skills/pi-team` with `skills/teamsmith` (a project that uses the CLI through `PATH` or a `~/.agents/skills/teamsmith` link needs nothing) |
| your own notes, briefs or scripts | by hand — the skill cannot rewrite your files |
| the installed directory `~/.agents/skills/pi-team` | re-run `./install.sh` (it installs the canonical directories only); `./install.sh --uninstall` also removes a legacy `pi-team` entry left by an older install |
| an `AGENTS.md` marker `<!-- pi-team:begin -->` | **still automatic**: the next `team init`/`team bootstrap` rewrites the marker in place (§2) |
| the Pi command `/pi-team-reload` | **still works**: it stays registered as an alias of `/teamsmith-reload` — a *command name*, not a path |

A *copy* install (`./install.sh --copy`) made while the symlink existed simply carries a copy of the old alias;
delete that one directory (or re-run the installer into the same target).

## 3. Removed commands (v1.10 → v1.11) and what replaced them

The skill stopped wrapping tools that already exist. Rolling those wrappers back is not on the roadmap; the
replacement is always "the PM runs the real tool", which is why the guide points at the procedure docs instead of a
command.

| What you typed (or a script still does) | What you see | What to run instead | Read |
|---|---|---|---|
| `team merge <ID>` (and `team merge --pr N`) | a "removed in v1.11.0" refusal (printed in Chinese), exit 2; on a pre-1.10 checkout it printed a recipe, and before that it actually merged | the PM runs git: squash-merge the task branch into the protected branch, commit from the main worktree, push; only then `team board set <ID> done` | `SKILL.md` → "git and forge", `references/workflows.md` |
| `team pr <ID>` | same removal message | push the branch with `git` and open the PR/MR with the forge's own tool (`gh`, `glab`, `tea`, `curl`, or the web UI); tokens stay in the project's token files | `SKILL.md` → "git and forge" |
| `team gh …` / `team gl …` | a "pass-through removed in v1.11.0" refusal for `gh`/`gl`, exit 2 | call the real `gh`/`glab`/`curl` and inject the token yourself (`GH_TOKEN="$(< .gh-pat)" gh …`); the skill never reads or echoes tokens | `SKILL.md` → "git and forge", `references/troubleshooting.md` |
| `team review <ID>` **without** `--dir` (changed in v1.11.0) | refused: a review needs a PM-prepared independent checkout | `git -C <root> worktree add --detach /tmp/review-<ID> <task branch>`, then `team review <ID> --dir /tmp/review-<ID> [--strong]` | `SKILL.md` → Verify row, `references/workflows.md` |
| `team add-agent <a>` / `team bootstrap` silently creating worktrees | they now **print** the `git worktree add` command | keep git in your hands: run the printed command, or pass `--create` / `--create-worktrees` to delegate creation | `../../teamsmith-init/references/bootstrap.md` |
| `team close <ID>` deleting the task branch | `close` never touches git any more | reset and delete the branch yourself; with `TEAM_TASK_BRANCH_RESET=1` (default) `close` prints the exact `git -C <worktree> switch --detach <protected>` command | `references/config.md` |

Two of these removals are *deliberate and permanent*: the skill has no `merge`, `pr`, `gh` or `gl` sub-command and no
forge wrapper script. If a script of yours calls one, it will keep exiting non-zero — change the script.

## 4. New required dependencies (v1.19.0): magic-context and OpenSpec

Before v1.19.0 both were optional; since then `team doctor` **fails** without them.

```bash
pi install npm:@cortexkit/pi-magic-context    # PM memory: cross-session recall (ctx_search/ctx_memory/ctx_note)
openspec init --tools none                    # the project's spec root (TEAM_SPEC_DIR, default: openspec/)
```

- `team doctor` checks both and names the fix when one is missing: a `✓` line with the resolved version for the Pi
  package (read from `TEAM_PI_SETTINGS_FILE`, default `~/.pi/agent/settings.json`) and for the OpenSpec CLI
  (`TEAM_OPENSPEC_BIN`, default `openspec`), plus a separate line for the spec directory (`TEAM_SPEC_DIR`).
- The project gate should carry the spec layer as well — `TEAM_GATES` is the config key:
  `openspec validate --all --strict && <your old gates>`.
- Escape hatch for unusual environments: `TEAM_REQUIRE_MAGIC_CONTEXT=0` and `TEAM_REQUIRE_OPENSPEC=0` downgrade the
  two checks from failure to warning, and `TEAM_PI_SETTINGS_FILE` / `TEAM_OPENSPEC_BIN` point the checks at a
  non-standard location. `dispatch` only warns about a missing dependency, it never blocks.
- **The honest cost of the escape hatch**: with `TEAM_REQUIRE_MAGIC_CONTEXT=0` the PM loses cross-session recall and
  has to fall back to `/compact` plus files on disk (see `references/memory.md`); with `TEAM_REQUIRE_OPENSPEC=0` there
  is no spec layer at all, and any gate line still calling `openspec validate` fails on its own. Turning the
  requirement off silences the *check*, not the *gap*.

## 5. Behaviour changes that can surprise an existing project

Each row is a v1.19.0-or-later change that a project set up earlier will notice. The "what to check" column is the
one-line reaction.

| Change | Since | What to check |
|---|---|---|
| `dispatch` refuses a worktree whose branch is not the task's branch | v1.21.0 | `git -C .worktrees/<agent> branch --show-current` must equal the task branch; the refusal prints the `git switch` command to run |
| `dispatch` refuses a brief outside the project, an unknown recipient, and a model-limit overrun | v1.21.0 | keep briefs under `docs/team/tasks/`, keep the recipient in `TEAM_AGENTS`, and check `team ps` for free concurrency slots (`TEAM_MODEL_LIMITS`) |
| `team board set <ID> done` requires evidence | v1.20.0 | the branch must be merged into the protected branch or a review record must exist; the only override is `TEAM_BOARD_DONE_FORCE=1` **plus** `TEAM_BOARD_DONE_REASON="…"`, and it is recorded in `reviews/<ID>-done.md` |
| a review must run in a clean checkout of the task branch, and the record is bound to that revision | v1.20.0 | prepare a detached worktree per review; if the branch moves afterwards `digest` lists the task for re-verification; `TEAM_REVIEW_ALLOW_DIRTY` / `…_IGNORED` / `…_ANY_DIR` are explicit, recorded overrides |
| empty or whitespace-only tmux targets are refused in every wrapper | v1.21.0 | nothing to do — this guard is what stops a wrapper from typing into (or killing) the *current* pane; only custom scripts that build a target from a variable need to prove it is non-empty |
| the patrol is a `pulse` window in **the project's own** tmux session, and `TEAM_SESSION` must match that session name | v1.12.0 (single backend); renamed `watchdog` → `pulse` in v1.36.0 (§2b) | `team pulse status`; after renaming a session, update `TEAM_SESSION` in `.pi/team/config.sh`. Real example: on 2026-09-14 this project's session was renamed while the config kept the old name, so `dispatch` and the patrol reported a missing session and the PM as not running until the config was fixed |
| long-lived sessions are checked against the model's context window; `--fresh` starts a new one | v1.22.0 | before switching an agent to a model with a smaller window, dispatch with `--fresh` (or accept the refusal); `team ps` / `roster` show used/window |
| reports that are not committed yet no longer point at a review, and a squash-merged branch reports "already merged (squash, same content) — no push needed" | v1.22.0 | read the wording before acting: both lines exist to stop a PM from reviewing or pushing something that is already done |
| the PM's own CLI is configurable (`TEAM_PM_CMD` / `TEAM_PM_BIN` / `TEAM_PM_RESUME_ARGS`) | M8.1 | nothing to do — all three keys are empty by default and the built-in Pi command is byte-for-byte unchanged. They belong to the internal seam (frozen): reserved for a possible future non-Pi adapter, no compatibility promise — the PM side runs Pi (`references/agent-adapters.md` §2) |
| the console brings three state files and one changed default: `TEAM_MONITOR_REFRESH` drops `5` → `3` | v1.38.0 (pulse-console B3) | the TUI keeps its own preferences in `state/panel.conf` (`lang`, `page`, `activity`, `mouse`, `density` and an optional `theme`), remembers the last page in `state/panel-page`, and holds the PM's compose draft in `state/draft.md`. All three are runtime state: deleting them is safe and `--print`/`--json` never read them. Set `TEAM_MONITOR_REFRESH=5` to keep the old cadence (`references/config.md` lists the key) |
| the fixtures' and gates' temp root defaults to **disk** instead of the memory-backed `/tmp`: `/var/tmp/teamsmith-<ns>`, resolved by `team_tmp_root` (`TMPDIR` → `TEAM_TMP_ROOT` → default) and printed as `source=tmpdir|config|default` | v0.3.0 (tmp-root-on-disk) | nothing to migrate — the first write creates the new root (0700) and old `/tmp` residue stays where it is; `tmp-hygiene.sh --status` names the resolved root, its `source=` and the old root's leftovers, and `TMPDIR=/tmp bash skills/teamsmith/tests/tmp-hygiene.sh --sweep --dry-run` selects the old base explicitly. An explicit root (`TMPDIR` / `TEAM_TMP_ROOT`) must already exist and be writable — it is never created for you. Rollback: `TEAM_TMP_ROOT=/tmp` |

## 5b. The breaking model-policy upgrade (task categories)

This is the one upgrade a re-render cannot do: it needs the four-key migration transaction. The retired keys
TEAM_AGENT_MODELS and TEAM_DEFAULT_MODEL are no longer read (an old seat model is **not** reinterpreted as a task
model): a project that still carries them is refused by `team dispatch`/`team up` and by `team init`/
`team bootstrap` — before any install, ledger, worktree or pulse work. Two routes apply the same transaction: the
**startup transaction** (the next `team up` derives the pairs from the old keys, prints every pair before → after
with the backup path and the restore command, writes through the checked writer and re-enters itself) or the
**explicit transaction**. The full sequence — upgrading the tool itself, backing up the configuration and rolling
back — is §6.

```bash
team config upgrade-models --task-models 'routine=<model> analysis=<model> verify=<model>' --pm-model '<model>'        # preview: prints the diff, writes nothing
team config upgrade-models --task-models '…' --pm-model '<model>' --yes                                                # the one write
```

It rewrites only those keys through the checked writer (temp file → `bash -n` → fingerprint CAS → atomic rename →
one audit line), turns a removed line's inline comment into a standalone one and leaves every other byte alone.
Shapes it cannot locate unambiguously (export/multiline/variable expansion/duplicate keys) are refused with the
file and line plus the manual-normalization route. `team up --print` writes nothing (it prints the same
prediction, with the backup path it would use) and `team up --no-migrate` refuses instead of writing, naming the
manual command. `team init --force`, `bootstrap` and inference are **not** migration routes; a fresh project
passes `--task-models`/`--pm-model` to `init`/`bootstrap` instead. For the step-by-step upgrade of an existing
project, including the npm install, the configuration backup and the rollback, see §6.

**How the shape is detected.** Detection is a version table with **one row per migration** — the shape it matches
(`from`), the shape it produces (`to`), the transform it applies and the tool version that introduced it — applied
in order and idempotently; adding a migration is one table row plus one transform plus one fixture group. A
project's shape number is `TEAM_CONFIG_VERSION` (written by `init`/`bootstrap` and by every migration; a `refuse`
key — the console never writes it); a configuration **without** that key is classified by its keys (a retired key
⇒ the pre-policy shape, otherwise the current one). A shape number **higher** than this tool's newest known one is
**refused** rather than migrated with an older row, and so is a shape the table has no row for.

After the policy is in place: a **new** dispatch takes the brief's `category:` model (routine for bounded ordinary
implementation, analysis for complex planning/judgment, verify for independent adversarial review — or the
project's own names), while a running/completed assignment keeps its recorded model/SID and is never rewritten by
the upgrade; a brief must carry a `category:` header before it can be dispatched again; the PM's own model is
`TEAM_PM_MODEL`, and a running PM on a different model is continued only with `team up --fresh-pm`.

The operations around a source upgrade are **separate recorded gates**, each previewed and authorized per command:
private source verification; landing validated source on a shared/protected tree; writing this project's
configuration (and the first fresh launch that reads it); and adopting a changed shared skill source. A shared
skill link (e.g. `~/.agents/skills/teamsmith` → this checkout's `skills/teamsmith`) reads its target's **current**
bytes, so changing that target affects later reads in other projects even without an installer; before landing,
either isolate the known shared consumers to preserved stable source and verify the isolation, or obtain explicit
approval of the identified shared impact. No partial slice should land on a shared main, and no zero-impact
promise is made for unknown consumers.

## 6. Upgrade recipe

This moves a project set up with teamsmith 0.1.x onto 0.2.0 or later. §1 still holds — `docs/team/**`,
`.pi/team/state/**` and your own files keep their format, so there is no data conversion. What does move is the
**tool installation** (step 1), this project's **model policy** (step 2), the PM's **launch identity** (step 3),
the **sessions** (step 4), and the way you **prove** (step 5) and **roll back** (step 6) the result.

Run every command from the project's main checkout, and replace `<v>` with the version you are moving to (for
example `0.2.0`).

### Step 1 — upgrade the tool itself (npm, not a checkout)

Since 0.2.0 the installed skill is a copy of the npm package `teamsmith`: `~/.agents/skills/teamsmith` is a
symlink into `$(npm root -g)/teamsmith/skills/teamsmith`. There is no checkout to `git pull`; the upgrade is the
package plus the installer that refreshes the shared links:

```bash
npm i -g teamsmith@<v> --registry https://registry.npmjs.org
bash "$(npm root -g)/teamsmith/install.sh"     # idempotent: refresh the shared skill links
team version                                   # the version the CLI reports now
readlink -f ~/.agents/skills/teamsmith         # must resolve under $(npm root -g)/teamsmith/skills/teamsmith
```

`install.sh` is safe to re-run and installs the canonical directories only. If `readlink -f` still points at an
old checkout, this machine has a second skill source — fix that link (or re-run `install.sh` into the target you
want) before going on, or later reads will mix two versions.

### Step 2 — per project: back up the configuration, then let the first `team up` migrate it

**Back up the configuration first.** The migration keeps its own backup, but this one is yours:

```bash
cp .pi/team/config.sh ".pi/team/config.sh.pre-upgrade-$(date -u +%Y%m%dT%H%M%SZ)"
```

Look before you write:

```bash
team up --print
```

On a 0.1.x-shaped configuration this writes nothing and prints, in order: the migration row it matched (which
migration, from which shape to which), a **per-key before → after table**, the backup path it would use, the `cp`
command that restores it, and why the keys move. `team up --no-migrate` is the same promise from the other side:
it refuses, writes nothing, and prints the manual transaction in whichever of the two command forms below fits
your configuration — the derived command when the derivation is unambiguous, the placeholder route when it is not.

Then run the real thing:

```bash
team up
```

`team up` now begins with a **startup transaction**. It prints the same before → after table, writes a backup
under `.pi/team/state/config-backups/config.sh.pre-<shape>-<timestamp>`, rewrites only the model keys through the
checked writer (temp file → `bash -n` → fingerprint compare-and-swap → atomic rename → one audit line in
`.pi/team/state/config.log`), prints the restore command, and re-enters itself to read the new configuration and
start the PM.

In 0.1.x terms the transaction does this:

| 0.1.x key | becomes |
|---|---|
| `TEAM_AGENT_MODELS='dev=<model> verify=<model>'` | one `TEAM_TASK_MODELS` pair per seat, with the seat name as the category |
| `TEAM_DEFAULT_MODEL='<model>'` | a `default=<model>` pair in `TEAM_TASK_MODELS` |
| `TEAM_PM_MODEL='<model>'` | the same value, re-written through the checked writer so the write is audited |
| — | `TEAM_CONFIG_VERSION='2'`, the shape number every later migration is measured against |

If it **refuses**, it names the obstacle and prints the manual transaction in one of **two command forms**. Which
one you get is a fact about *your* configuration, not a style: the tool never prints a command it cannot support.

- **A shape it can derive from** — every retired key is a top-level single-line literal, every value is a valid
  `provider/model`, and no two seat names normalize onto one category. The command is **derived from your own
  configuration**, with the map and the PM model already filled in
  (`--task-models 'dev=vendor/light verify=vendor/strong:high default=vendor/base' --pm-model 'vendor/pm:high'`).
  `team up --no-migrate` on such a configuration prints this form.
- **A shape the derivation stops on** — a value built by variable expansion or written as a multi-line literal, a
  seat name that normalizes onto the fallback `default` (the fallback name collides), or a value that is not a
  valid model. Here it prints the **placeholder route** instead: the command arrives with an *unfilled*
  `--task-models` and `--pm-model`, each holding a bracketed placeholder written in the CLI's own language, and
  *you* write the map. The refusal line above it names what stopped the derivation (for that first shape, the
  file and line that is not a plain literal). A derivation that resolved some pairs before stopping still prints
  them, with the bracketed placeholder standing in for the offending one — a partly filled map therefore means
  "fix that one pair", not "start from scratch".

The same conditional holds wherever a refusal offers the manual transaction (a refused `team config set` or
`team dispatch` prints these two forms under its two routes). The two are distinguishable at a glance: in a
**derived** command every `--task-models` value was read from *your* file, while a **placeholder-route** command
leaves a bracketed placeholder somewhere among its arguments.

The manual route is the same transaction, run by hand:

```bash
team config upgrade-models --task-models '<the map it printed>' --pm-model '<the model it printed>' --dry-run
team config upgrade-models --task-models '…' --pm-model '…' --yes
```

`--dry-run` prints the diff and writes nothing; `--yes` is the one write. `team init --force`, `team bootstrap`
and inference are **not** migration routes (§5b). Confirm the new shape before going on:

```bash
team config list        # exit code 0, and no `migration_required` line at the end
```

### Step 3 — the PM launch identity (`state/pm-launch.env`)

`.pi/team/state/pm-launch.env` is a flat record of the identity the PM was last started with: the project and
window, the resolved model, the resume key (which Pi session it continues), the launch mode (`fresh` or
`continued`) and a nonce. It is what lets a later `team up` prove it is resuming the *same* conversation on the
*same* model, and it is deliberately not project data (§1).

A project upgraded from 0.1.x has no such record — the file did not exist then. The first `team up` after the
migration handles that for you: a missing record is read as "no claim about the past", this launch is
**registered**, and the run prints one line saying so. That line carries `model=<model>`, `resume_key=<key>` and
`mode=continued`, and reminds you that changing the PM model requires `--fresh-pm`.

Two exits exist, and they differ in what they keep:

- **Let it register (the default).** The PM continues the conversation `team_pm_continuity` resolves — `pi -c`, the
  previous session for this directory, unless `TEAM_PM_SESSION_ID` or `TEAM_PM_RESUME_ARGS` say otherwise — and the
  record is written from the successful launch.
- **`team up --fresh-pm`.** This one launch starts a **new** conversation: the resume arguments are dropped, the
  old Pi session file is left untouched in the history, and the record is written with `mode=fresh`. Disk is the
  handover — `docs/team/**` and `team digest` carry the work.

When a record **exists and disagrees** with what the configuration resolves now, `team up` refuses instead of
guessing. The refusal names `PM launch identity changed` plus the field that moved (`model`, `resume_key` or the
window), and prints two exits:

- **`team up --fresh-pm`** — start a new conversation. The Pi history is not touched.
- **`team up --adopt-pm-identity --yes`** — declare that this continued run really is the recorded identity: it
  writes the record plus one audit line, and is refused while the PM is running.

**Why a changed model cannot continue the old conversation.** One conversation is pinned to one model: Pi's
session history is bound to the provider/model that produced it, so resuming that session under a different model
is not the same conversation. `--fresh-pm` is therefore the only honest way to change the PM's model;
`--adopt-pm-identity --yes` exists for the case where the *record* is stale but the resolved identity really is
what you are resuming. `team up --print` predicts all of this without writing: it prints the registration line it
would write, or the two exits when it would refuse.

### Step 4 — sessions: bring the PM and the seats back up

```bash
team up                 # the PM window in the project's own tmux session
team up --agents        # also resume the seats that have unfinished tasks
team resume --dry-run   # what --agents would do, without doing it
```

Text already read into a running session does not change under it: restart each project's own agent sessions (or
`/reload` the PM in Pi) so they read the new `SKILL.md` and `references/**`. `team up` starts the PM and nothing
else; the patrol window is created by `team pulse up`, and `team pulse status` shows its state.

### Step 5 — prove it

```bash
team doctor                                  # fix every ✗ before going on; each line carries its own fix
bash skills/teamsmith/tests/tmp-hygiene.sh --status   # the resolved temp root, its `source=` and any old /tmp residue
team config list                             # the new keys, exit code 0
team dispatch --print <agent> <ID> <brief>   # the brief's `category:` line resolves to the mapped model
```

The status line also settles the one on-disk change since 0.3.0: fixture roots resolve to `/var/tmp/teamsmith-<ns>`
on disk unless `TMPDIR` or `TEAM_TMP_ROOT` says otherwise, the line prints which of the three won, and the old `/tmp`
roots are **not** migrated (`TMPDIR=/tmp bash skills/teamsmith/tests/tmp-hygiene.sh --sweep --dry-run` shows them).
`TEAM_TMP_ROOT=/tmp` is the rollback to the old behaviour.

The `dispatch --print` line is the one that proves the policy is live: it must print
`category=<the brief's category> model=<the mapped model>`. A brief with no `category:` line is refused.

### Step 6 — roll back

```bash
cp "<the backup path the migration printed>" .pi/team/config.sh    # the configuration, byte for byte
```

Restoring the backup puts the old shape back (and `team config list` says `migration_required` again), which is
what you want if the new policy is wrong. `--fresh-pm` needs no rollback: it never touched the Pi session
history, so the old conversation is still there to `team up` into after you restore the configuration. Nothing
else moved — `docs/team/**` and the rest of `.pi/team/state/**` were never rewritten. §7 covers pinning an older
tool version, which is the other half of a rollback.

Do the upgrade **before** dispatching new work, and note the version in `DECISIONS.md`: a worker dispatched after
the upgrade gets the new prompt template, one dispatched before does not.

## 7. Rolling back

An upgrade is reversible and needs no data rollback, because §1 is true: the skill does not migrate project files.

```bash
git -C <skill checkout> tag -l                 # recent releases are tagged (e.g. v1.20.0); see what is available
git -C <skill checkout> checkout v1.20.0       # pin the older release
git -C <skill checkout> log --oneline | head   # no tag for the version you want? use its release commit
team mark-loaded                               # re-record what this session should compare against
```

- Restart or `/reload` the PM session after pinning, otherwise the running session still holds the newer `SKILL.md`.
- `team version --check` will compare against the pinned revision from then on; running `team mark-loaded` again stops
  it from reporting a mismatch you deliberately created.
- `openspec/`, `docs/team/**`, `.pi/team/**` and any existing review records stay exactly as they are — nothing needs
  to be re-generated.
- Two honest caveats: a config file written by a newer version may contain keys an older one ignores (harmless: they
  simply have no effect), and rolling back **below v1.11.0** brings back the git/forge wrappers — the skill would touch
  git again. Pin at v1.11.0 or later unless that is exactly what you want.
- Rollback and re-upgrade can be repeated freely; the only state the skill keeps about versions is
  `.pi/team/state/pm-loaded.env`.
- Since 0.3.0 the fixture/gate temp root lives on disk (`/var/tmp/teamsmith-<ns>`). Pinning an older tool sends it
  back to `/tmp` on its own; with the new tool, `TEAM_TMP_ROOT=/tmp` restores the old behaviour. Nothing under
  `/var/tmp/teamsmith-<ns>` is project data — those roots are disposable and the sweep reclaims them.

## 8. What is deliberately not supported

- **The PM side is Pi.** The four `TEAM_AGENT_*` keys are an internal seam (frozen) — reserved for a possible
  future non-Pi adapter, with no compatibility promise; the PM prompt, `pi -c` restarts and the notify extension
  stay Pi. Contract, worked examples and the unsupported list:
  [agent-adapters.md](agent-adapters.md).
- **The old Podman/container and systemd patrol backends** (removed in v1.12.0). There is exactly one backend
  now: the `pulse` window in the project's own tmux session. If the tmux server dies, the PM is gone too, and
  `team up` / `team pulse up` rebuild both.
- **git and forge wrappers** (`team merge`, `team pr`, `team gh`, `team gl`, a forge library script), removed in
  v1.11.0: the PM runs git and the forge's own CLI. See §3 and `SKILL.md`.
- The repository's own boundary — what this project will and will not do on someone else's machine — is in
  [SCOPE.md](../../../SCOPE.md).

If something here does not match what `team doctor`, `team version --check` or `team smoke` actually print, that is a
bug in the guide (or in the tool): report it with the command and the output rather than working around it.
