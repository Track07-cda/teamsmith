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
| `.pi/team/config.sh` | sourced by bash, flat `TEAM_*` keys; new keys ship with a default, so a config written years ago keeps working |
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
| `skills/pi-team` (repository path **and** installed skill directory) | `skills/teamsmith` | **nothing**: the repository keeps `skills/pi-team` as a compatibility symlink, so a project or `settings.json` entry that points at the old absolute path keeps working |
| the Pi command `/pi-team-reload` | `/teamsmith-reload` | **nothing**: the old spelling stays registered as an alias |
| the `AGENTS.md` marker `<!-- pi-team:begin -->` … `<!-- pi-team:end -->` | `<!-- teamsmith:begin -->` … `<!-- teamsmith:end -->` | run `team init` (or `team bootstrap`) once: the marker is rewritten **in place** and idempotently, with no duplicate section. `team doctor` prints a pointer to this file while the old marker is still there |
| the repository name `pi-team` | `teamsmith` | only if your own notes or scripts hard-code it; the skill's contracts (command, config, `TEAM_*`, `docs/team/**`) were never renamed |
| prose in your own docs, briefs or scripts | — | by hand: the skill cannot rewrite your files (the former name is also what a "stale session" error message used to say) |

Note on absolute paths: the compatibility symlink follows the **repository**, so it keeps working for the common
`~/.agents/skills/<name>` link and for a `settings.json` `skills` entry. A *copy* install (`./install.sh --copy`)
made before the release where `pi-team` was renamed keeps a frozen directory with no symlink inside; re-run
`./install.sh` there.

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
| `team add-agent <a>` / `team bootstrap` silently creating worktrees | they now **print** the `git worktree add` command | keep git in your hands: run the printed command, or pass `--create` / `--create-worktrees` to delegate creation | `references/bootstrap.md` |
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
| the PM's own CLI is configurable (`TEAM_PM_CMD` / `TEAM_PM_BIN` / `TEAM_PM_RESUME_ARGS`) | M8.1 | nothing to do — all three keys are empty by default and the built-in Pi command is byte-for-byte unchanged; set them only to run the PM under another TUI agent (`references/agent-adapters.md` §2) |
| the console brings three state files and one changed default: `TEAM_MONITOR_REFRESH` drops `5` → `3` | v1.38.0 (pulse-console B3) | the TUI keeps its own preferences in `state/panel.conf` (`lang`, `page`, `activity`, `mouse`, `density` and an optional `theme`), remembers the last page in `state/panel-page`, and holds the PM's compose draft in `state/draft.md`. All three are runtime state: deleting them is safe and `--print`/`--json` never read them. Set `TEAM_MONITOR_REFRESH=5` to keep the old cadence (`references/config.md` lists the key) |

## 6. Upgrade recipe

Replace `<skill checkout>` with the git checkout the installed skill points at (`team paths` prints it).

```bash
# 1) get the new skill (a copy install updates by re-running ./install.sh instead)
git -C <skill checkout> pull --ff-only         # refuses when the checkout has diverged (local commits) — deliberate

# 2) is this session still the old version?
team version --check
#    expect two version numbers (loaded vs disk) and a hint to run /reload;
#    identical versions print "consistent" instead. Exit code stays 0 either way.

# 3) environment self-check — fix every ✗ before going on
team doctor

# 4) re-render this project's contracts (idempotent: config is kept, the AGENTS.md
#    section is refreshed in place, and a legacy marker is rewritten to the new one)
team init

# 5) the spec layer, only when openspec/ is missing
openspec init --tools none

# 6) put the spec gate into TEAM_GATES in .pi/team/config.sh
#    TEAM_GATES="openspec validate --all --strict && <old gates>"

# 7) rebuild the pulse window and look at it (renamed from `watchdog` in v1.36.0 — §2b:
#    the old commands/window/variables still work; a running `watchdog` window is adopted
#    and `team pulse restart` swaps it for a `pulse` one)
team pulse up
team pulse status

# 8) prove the tooling end to end in a throwaway repository (never touches this project)
bash skills/teamsmith/tests/smoke.sh                        # full suite (tens of seconds idle, minutes on a loaded box)
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh      # logic-only subset; each skipped section prints SKIP
```

Expected output, in order:

| Step | What you should see |
|---|---|
| `version --check` | the disk version, the `SKILL.md` version and the loaded version, then either a "consistent" line or the "this session is old" line with the `/reload` hint |
| `/reload` in Pi | the skill list is rebuilt; the extension sends a follow-up that makes the PM read `SKILL.md` again (text already in the conversation history does **not** change by itself) |
| `doctor` | every line prefixed with a check mark; each `✗` line carries its own fix (`pi install …`, `openspec init --tools none`, `TEAM_*_BIN`, …); the summary line counts failures and warnings |
| `init` | a write/refresh line per generated file — the `AGENTS.md` protocol section appears exactly once (check with `grep -c '<!-- teamsmith:begin -->' AGENTS.md`) |
| `smoke` | an all-green summary (or the failure count), and in fast mode a line listing the skipped process sections |

Do the upgrade **before** dispatching new work, and note the version in `DECISIONS.md`: a worker dispatched after the
upgrade gets the new prompt template, one dispatched before does not.

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

## 8. What is deliberately not supported

- **The PM side is Pi.** Only *workers* can be another TUI agent, via the four `TEAM_AGENT_*` keys; the PM prompt,
  `pi -c` restarts and the notify extension stay Pi. Contract, worked examples and the unsupported list:
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
