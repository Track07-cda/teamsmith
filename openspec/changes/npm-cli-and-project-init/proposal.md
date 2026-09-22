# npm-cli-and-project-init · proposal

## Why

The user asked for OpenSpec's install story (2026-09-22): «**CLI 作为一个 npm 应用来安装**，并且可以**通过类似于
`openspec init` 在项目中安装 skill**». Today `package.json` has `pi.skills` and **no `bin`**: `npm i -g
teamsmith` installs no command, and skills reach a project only through `pi install …` or `./install.sh`
(machine-global `~/.agents/skills`). No per-project install step exists.

## What Changes

- **ADDED — `init-skill`**: `team init` installs the two skills into `<main>/.pi/skills/` (Pi's project search
  path): link by default, `--copy`, `--no-skills`, idempotent, conflicts announced with a non-zero exit, and
  `--force` replacing only what it recognises as that same skill. `bootstrap` runs the same step in both
  branches (an existing project's upgrade route), `--print` names it, `.pi/skills/` joins `.gitignore`.
- **ADDED — `init-skill`**: one `bin` entry, `team → bin/team.mjs` — a transparent Node wrapper (argv, env and
  exit status unchanged, npm's prefix shim included) — and `files` gains `bin/`.
- **ADDED — `init-skill`**: `team doctor` reports a project-local install when there is one (silent when there
  is none) and warns, without failing, when it is stale or foreign, naming `team init --force`.
- **ADDED — `memory-and-deps`**: the npm entry checks its shell first — a missing or pre-4 `bash` prints the fix
  and exits non-zero before the CLI runs.
- **MODIFIED — `init-skill`**: the init skill opens with the installation beat (`npm install -g teamsmith` →
  `team init`) ahead of the checklist/bootstrap/handoff beats, its four base scenarios kept verbatim, and the
  installation-facing surfaces (README §Install, `team help`) say the same thing.

## Capabilities

### Modified Capabilities

- `init-skill`: the install beat; the project-local install; the one bin entry; the doctor row.
- `memory-and-deps`: the shell check and its fix.

## Impact

`package.json` + a new `bin/team.mjs`; the `init`/`doctor`/`bootstrap` code paths; both `SKILL.md` files,
`references/bootstrap.md`, `README.md` §Install and `docs/team/PUBLISH.md`; a new headless fixture
`tests/install-shape.sh` in the FAST smoke. Untouched: every other subcommand, the extension injection,
`install.sh`, the gates, `openspec/**`; no publish.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
git status --porcelain
```

## What flips

- Drop `bin/` from `files` → the pack walk is red naming the missing `bin/team.mjs`.
- Point `bin` at the bash script → the old-shell fixture loses the fix message (a `bash` shim reporting 3).
- Drop the conflict check → a foreign directory is overwritten and its before/after hash is red.
- Sweep `skills/` instead of named sources → a source carrying only `teamsmith` installs a foreign skill.

## Boundaries

Planning only (this task writes `openspec/changes/npm-cli-and-project-init/**` + its report). Apply must not
touch `install.sh`, the extension injection, other subcommands, the gates or `openspec/**`, must not add a
second install semantics beside `team init`'s, and must not publish; the task list carries the per-path grants
(`package.json`, `bin/**`, the granted `skills/**` files, `README.md`, `docs/team/PUBLISH.md` — PM-owned by
default). Wording stays Pi-only (D35); the rewording itself is P34's delta.

## Evidence the report must contain

Both acceptance tails; delta→requirement and requirement→item maps; the pack walk with the `bin/` flip; the
npm-prefix shim run; the install matrix's tails; the shell-check failures; the three doctor states; every flip's
red/green tail; one line that the untouched paths were not touched.
