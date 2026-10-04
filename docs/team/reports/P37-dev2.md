# P37 · npm CLI + project init — the propose package

agent: dev2   status: DONE   time: 2026-09-22T07:23:51Z
branch: `task/P37-openspec-npm-cli-init-skill-`（local 模式：不 push，PM 复验后本地合并）   PR/MR: -

Task brief: `docs/team/tasks/P37-npm-cli-and-project-init-propose.md` · phase: `propose` · change:
`npm-cli-and-project-init` · deltas: `init-skill`, `memory-and-deps`. **Planning only — no implementation
code was written** (the only new script is the verification package below, which is evidence machinery).

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/npm-cli-and-project-init/proposal.md` | Why (the user's ask, the measured gap: no `bin`, no per-project step), the five requirement moves, capabilities, impact, the brief's acceptance commands verbatim, the flips, the boundaries, the report's evidence list (prose 478 words < 500) |
| `openspec/changes/npm-cli-and-project-init/design.md` | The recon the decisions rest on; **decision 1** (bin shape: thin `bin/team.mjs` wrapper, tradeoff table with the measured npm behaviour); **decision 2** (what `team init` installs, the idempotence/conflict table, bootstrap's existing-project route, `.gitignore`); the package shape, the shell check, the doctor row, the surfaces map, risks, the verification design, and what the change does not do |
| `openspec/changes/npm-cli-and-project-init/tasks.md` | One apply brief (with the fallback split and its order), the coverage map requirement → items, the per-path OWNERSHIP grants, the fixture discipline, five ordered batches with a failing command per item, and the independent-verification item |
| `openspec/changes/npm-cli-and-project-init/specs/init-skill/spec.md` | 1 MODIFIED + 3 ADDED requirements (15 scenarios) |
| `openspec/changes/npm-cli-and-project-init/specs/memory-and-deps/spec.md` | 1 ADDED requirement (3 scenarios) |
| `docs/team/reports/P37-dev2/pkg/run.sh` | The independent verification package: 5 sections, read-only against the repo, scratch dirs only, no tmux/pi/network |

Totals: **5 requirements, 18 scenarios** (init-skill 4 requirements / 15 scenarios, memory-and-deps 1 / 3) —
inside the brief's 3–5 and 10–18.

Delta→requirement map: `init-skill` = R1 “Initialization guidance lives in a dedicated teamsmith-init skill”
(MODIFIED — 4 base scenarios kept byte-identical + 1 new), R2 “team init installs the project skills” (ADDED,
5), R3 “The CLI ships as one npm bin entry and the package carries what it runs” (ADDED, 2), R5 “The
project-local install is visible in team doctor, and repairable with team init” (ADDED, 3); `memory-and-deps`
= R4 “The shell the CLI runs on is a checked dependency, not an assumption” (ADDED, 3).

## The two rulings the brief asked for

1. **`bin` shape = a thin Node wrapper (`bin/team.mjs`)**, not the bash script directly. Both work on POSIX
   (measured: `npm pack` keeps the file's own mode; `npm install -g --prefix …` symlinks the target and chmods
   it 755 — §4 of the package), so the decision rests on the failure modes the bash script cannot control: a
   `.sh` target under npm's Windows shims cannot execute (Pi ships Git Bash there), and a missing/pre-4 `bash`
   (macOS `/bin/bash` is 3.2) dies opaquely inside `common.sh`. The wrapper probes the shell, prints the fix,
   otherwise runs the CLI transparently (argv/env/exit status; no subcommand knowledge). It costs one process
   on shell invocations only — the panel spawns `bash <cli>` directly (`panel/src/data.ts:231`).
2. **`team init` semantics extended by one step, not forked**: install `teamsmith` + `teamsmith-init` into
   `<main worktree>/.pi/skills/` (Pi's project search path, already live in this repo for `openspec-*`), source
   = the running CLI's own skill directories **by name** (never a `skills/` sweep), default link / `--copy` /
   `--no-skills`, idempotent, conflicts announced with a non-zero exit, `--force` replacing only what it
   recognises as that same skill, `.pi/skills/` added to the `.gitignore` block once. `bootstrap` calls the
   same function in **both** branches, so re-running it is an existing project's upgrade route;
   `bootstrap --print` names the step and writes nothing. Dispatch's rendered `--skill`/`-e` command is
   untouched (asserted in the task list, smoke §18b R6).

## Verification evidence (must have actually been run)

### 1 · The brief's acceptance, on the committed tip

```
$ git rev-parse --short HEAD          # artifact commits: fd98959, bc1d112, 661a32d, 9de97bd (+ this report)
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ change/npm-cli-and-project-init          ← the change itself
✓ change/change-centric-discipline   ✓ change/settings-view-groups   ✓ spec/… (13 more)
Totals: 16 passed, 0 failed (16 items)
VALIDATE_EXIT=0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2301  ✗ 0
FAST 模式：跳过 27 个真进程段落（1c·M11 真沙盒窗口|6·dispatch 真拉起|…|38-b·panel-p21-choices）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿
SMOKE_EXIT=0

$ git status --porcelain        # after the report and the package were committed
（无输出）
```

The smoke ran on `661a32d`; every later edit is a document (`this report`, `tasks.md`'s coverage map, `design.md`'s
check table) or the package script — `git diff --stat 661a32d..HEAD -- skills README.md` is empty, i.e. every
file the smoke reads is byte-identical.

### 2 · Base scenarios are preserved (the MODIFIED block)

```
$ python3 <base/delta scenario diff, reproduced by pkg/run.sh §2>
base_scenarios=4 delta_scenarios=5 missing=[] byte_different=[]
  ok: every base scenario of the MODIFIED requirement survives byte-identically
```

### 3 · Trial archive on a scratch copy (delta semantics `validate` cannot see)

```
$ rm -rf /tmp/p37-trial3 && mkdir -p /tmp/p37-trial3 && cp -r openspec /tmp/p37-trial3/openspec
$ cd /tmp/p37-trial3 && git init -q -b main && openspec archive -y npm-cli-and-project-init
Task status: 0/18 tasks
Warning: 18 incomplete task(s) found. Continuing due to --yes flag.
Specs to update:
  init-skill: update
  memory-and-deps: update
Applying changes to openspec/specs/init-skill/spec.md:
  + 3 added
  ~ 1 modified
Applying changes to openspec/specs/memory-and-deps/spec.md:
  + 1 added
Totals: + 4, ~ 1, - 0, → 0
Specs updated successfully.
ARCHIVE_EXIT=0
$ openspec validate --all --strict      # on the archived tree
Totals: 15 passed, 0 failed (15 items)  EXIT=0
```

Note for the PM's own trial archive: the scratch copy must be a **git work tree** (`git init` in the scratch
dir first) — without it the CLI answers “No active changes exist in this root” and changes nothing. I hit that
on the first try; the recipe above is the one that works.

### 4 · The independent verification package

```
$ bash docs/team/reports/P37-dev2/pkg/run.sh
== 1 结果 == ok=2  finding=0 bad=0     # validate --all --strict, the change included
== 2 结果 == ok=4  finding=0 bad=0     # base-scenario verbatim diff + the archive flip
== 3 结果 == ok=7  finding=0 bad=0     # trial archive (− 0) + the archived tree still validating
== 4 结果 == ok=11 finding=0 bad=0     # the npm facts: tarball mode, prefix symlink, chmod 755, shim run
== 5 结果 == ok=16 finding=0 bad=0     # sizes, requirement/scenario counts, coverage, P34 collision check
==== 总计 ====  ok=16 finding=0 bad=0   (exit 0)
```

`pkg/run.sh` is read-only against the repository (every mutation is on a scratch copy under `$TMPDIR`), needs
no tmux/pi/network, prints a `== N 结果 ==` line per section and exits 0 unless a promise is outright false.

Section 4's measured baseline today (the red side the apply must turn green):

```
has_bin=no files=["skills/","install.sh"] pi.skills=["./skills"]
packed_files=162 has_skills=true has_install_sh=true has_bin=false has_docs_team=false has_node_modules=false
```

## Flip evidence

The artifact-level flip (red → green, run today on scratch copies):

```
RED — delete one base scenario from this change's MODIFIED block, then archive:
$ PATH="$HOME/.bun/bin:$PATH" openspec archive -y npm-cli-and-project-init      # in /tmp/p37-flip
init-skill MODIFIED failed for header "### Requirement: Initialization guidance lives in a dedicated
teamsmith-init skill" - current spec contains scenario(s) not present in the modified block:
"The init skill carries no code". Refresh the change spec before archiving to avoid dropping scenarios.
Aborted. No files were changed.
red_exit=1

GREEN — the delta as delivered, same command in a clean scratch copy:
Totals: + 4, ~ 1, - 0, → 0
Specs updated successfully.
green_exit=0
```

The code-level flips are the apply's to produce (the change has no implementation yet); this task establishes
each one's red side where it is measurable today, and `pkg/run.sh` reproduces the red side of the pack flip
(`has_bin=false`) and of the shell check (no wrapper exists to print a fix). The task list names the scratch-tree
recipe for every flip, and the fixture keeps its own red sides.

## Decisions and deviations

- **MODIFIED vs ADDED for R1.** The install beat changes what the init skill's *body* must contain and its
  base prose says “three beats”, so R1 is a MODIFIED block with all four base scenarios kept byte-identical
  (the alternative, a pure ADDED requirement, would have left a requirement that is now misleading). I checked
  P34's committed `init-skill` delta (`git show 75782af:…`) — it is ADDED-only, so no requirement block is
  claimed by two changes; the two changes do share the *file* `skills/teamsmith-init/SKILL.md`, so the applies
  must land one after the other and the second must re-read the file.
- **`PUBLISH.md` is PM-owned** (`docs/team/**`): item 3.5 asks the apply brief for the explicit grant. The
  proposal only *plans* the rehearsal step; nothing under `docs/team/` other than this report and its package
  was written.
- **`README.md` was not touched** (PM-owned); §Install's rewrite is item 3.4 of the apply plan.
- **No `team update` change.** The upgrade route for an existing project is re-running `team init`/`bootstrap`
  (which the change makes install the skills); adding a third call site is a deviation the design explicitly
  refuses.
- **`team paths` was left alone** — the doctor row (R5) is the visibility surface, so the change does not
  widen a machine-readable exit (`team paths` feeds other fixtures).
- **Windows is reasoned, not measured** (no Windows host): the wrapper's advantage follows from npm's shim
  behaviour and Pi's `docs/windows.md`; the fixture proves the missing/old-shell path on POSIX, which is the
  same code path. The proposal does not claim a Windows test.
- **Known pre-existing warts** found while measuring, not fixed here: `tests/__pycache__/fake-tui.cpython-313.pyc`
  is tracked and one `.pyc` ships in the tarball; `skills/teamsmith` is 46 MB in a developer checkout (43 MB of
  ignored `panel/node_modules`), which is why `--copy` excludes `node_modules/`. Both are the PM's call.

## Boundaries respected

Only `openspec/changes/npm-cli-and-project-init/**` and `docs/team/reports/P37-dev2/**` were written. Not
touched: `skills/**` (no implementation, no tests), `package.json`, `install.sh`, `README.md`, `AGENTS.md`,
`docs/team/` outside my own report, `openspec/specs/**`, and the PM's task brief. No push (local mode), no
merge, no npm publish, no token or credential read.

## Suggested next steps

- **PM proposal review** → `docs/team/reviews/npm-cli-and-project-init-proposal.md` (the ten-point checklist;
  `pkg/run.sh` gives points 2/6/8/9 a machine check). No apply brief before it is ACCEPTED.
- Sequence with P34 (`pi-only-scope`): same two delta files, same SKILL.md file — an apply of either must
  re-read `skills/teamsmith-init/SKILL.md` rather than replay a stale copy.
- If the PM wants the change split, the task list names the fallback (A1 = items 1–2, A2 = item 3, verify only
  after both).
- Open questions for the user, if the PM judges them worth asking: whether `--copy` should be the default under
  `npx` (the design documents `--copy` as the answer instead of auto-detecting), and whether the stray tracked
  `.pyc` should be removed in a separate task.
