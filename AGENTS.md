<!-- teamsmith:begin -->
## Team protocol (teamsmith)

A **PM (orchestrator)** in tmux `teamsmith:pm` owns tasks and merge authority; **worker agents**
implement in parallel inside their own git worktrees. Tooling: `bash /home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/scripts/team help`.
Roster: dev verify dev2 dev3 dev-bob (editable in `.pi/team/config.sh`).

**Project rules belong outside this block.** Everything between `<!-- teamsmith:begin -->` and
`<!-- teamsmith:end -->` is generated and `team init` replaces it on refresh, so a rule written inside is lost at
the next upgrade: the managed block is not a customization surface. Rules already inside the pair must be
inventoried and preserved outside first -- the PM's job, recipe in `/home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/references/migration.md`.

### Roles and reading order

| Role | Owns | Must not |
|---|---|---|
| PM | Briefs / roadmap / decision log, dispatch, independent verification, merging, wrap-up | Treat "the agent says it passed" as evidence |
| agent:<name> | Exactly the brief, tests and reports, opening PR/MRs | push `main`, force-push, merge PR/MRs, touch other people's directories |

Before starting, in this order: this file (especially this section), your own thread
`docs/team/threads/<agent>.md` (the PM may have added instructions), and the task brief
`docs/team/tasks/<ID>-<slug>.md` -- the brief is the single source of scope and acceptance commands.
`docs/team/OWNERSHIP.md` decides whose directory is whose.

### Specs (OpenSpec)

Specs and change proposals live in `openspec/` -- a **required dependency** (`openspec init --tools none` creates
the spec root). Read the change's proposal in `openspec/changes/<id>/` and the capability spec it touches
(`openspec/specs/<capability>/spec.md`; finished changes move to `openspec/changes/archive/`).
`openspec validate --all --strict` is part of the gate. **Do not create a parallel spec system**: no requirement
lists, spec copies or design sections in task briefs or docs -- if it must hold, it goes into a spec.

A change runs as **five phases, one brief and one owner each**: `opsx-explore`, then `opsx-propose` (planning only);
a dev runs `opsx-apply`; a **different** agent runs `opsx-verify`; the PM runs `opsx-archive`. Two hard rules: **no
`apply` brief before the PM's proposal review (`docs/team/reviews/<change>-proposal.md`) is ACCEPTED**, and no
agent verifies its own work; the PM archives only after independent verification **and the user's confirmation**.
Phase names go in the brief's `phase:` line; flags, phase-command source and pinned-toolchain caveat are in
`/home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/references/openspec.md`.

**The change is the assignment unit** (`1 change : N tasks`, `1 task : 0..1 change`): the brief's header is the
foreign key — `change:` (exactly one id, or `-`), `specs:`/`anchor:` (a change-less brief must resolve
`openspec/specs/<capability>/spec.md#<requirement>` or declare `anchor: none (infra) — <reason>`) and `deltas:`
(the change's delta files this task writes; an absent line means the whole set). `team dispatch` refuses **before it
opens a window**: more than one `change:` id (no override), an unresolvable anchor, two unfinished tasks of one
change writing the same delta file, and a `verify` task whose agent authored an `apply` task of that change (the
last three take `--force` + one audited line). `team change status <id>` shows the tasks/deltas/blockers and exits
0 only when every mapped task is finished; an `archive` task cannot be set `done` while a sibling is unfinished.

### Non-negotiable discipline

- **Only change directories you own** (`docs/team/OWNERSHIP.md`); for cross-directory work write `BLOCKED:` in
  the report and hand it back to the PM.
- **Never stop mid-task to ask for confirmation**: end the turn in exactly three states -- **delivered** (gates run
  + report written + branch settled), **hard-blocked** (notify the PM + `BLOCKED:` in the report), or
  **suspended on background jobs** (this session's jobs still running, every step that does not depend on them
  done; the turn's last line names every awaited job id). The lane rule is the suspend default: `team_bg_run`
  starts a long job and the turn ends -- the completion wake-up is the normal harvest point -- and in-turn waiting
  is the bounded exception, only inside the inline-wait budget (about 2 minutes), when the result blocks the next
  step and nothing else can advance. A previous session's wake-ups died with its process: find its jobs on disk
  (`state/bg.log`, `team bg list`) before awaiting or re-running them (`/home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/references/workflows.md` §E2).
- **Never claim tests passed without having run them.** The PM re-runs in an independent worktree; a false report
  fails the task.
- Never write tokens/secrets into code, config, logs or commit messages; never read credential files
  (e.g. `~/.pi/agent/auth.json`).
- **A brief declares one task category; models belong to the project, not to your seat.** The `category:` line
  selects the model the PM dispatches with (`routine` ordinary bounded work, `analysis` planning/judgment,
  `verify` independent adversarial review -- or the project's own names). A same-task recovery keeps its committed
  model/SID: do not re-select, and never treat model strength as a substitute for a self-contained brief.
  **Independent verification cannot be waived by a strong model.**
- **Scope, report and disk handover survive a fresh takeover**: keep exactly the brief's scope, commit in small
  steps, write `docs/team/reports/<ID>-<agent>.md`, and leave the next step and evidence on disk -- a new
  session (or a verifier) must be able to continue from the files alone, never from your conversation.
- **A report is read for its answer first, and every sentence carries its evidence**: state what the brief's
  question resolves to before the account of how you got there. A caution, a limitation or a boundary earns its
  place by what it cites -- a measurement, a counterexample, a gap in the reasoning, or a boundary you did not
  observe -- and a sentence that names none is deleted; one that carries its evidence stays. Every finding states
  what it changed: the implementation, the next step, the conclusion, or nothing; an observation that changed
  nothing stays out of the body. See `/home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/references/protocol.md` §11b.
- Never push `main`, never `git push --force`, never merge PR/MRs or rebase/delete other branches.
- Commit in small steps: every verifiable step gets a commit (Conventional Commits + task ID + `Agent: <name>` trailer).

### Delivering

Gates are `openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`; a brief may require stricter commands and then the brief wins. One gate at a time -- the full
suite is the machine's shared resource, and `TEAM_SMOKE_FAST=1` runs a bounded batch. A selected run covers only
the sections it executed and names the ones it did not run; a full run stays a milestone/delivery check, not a
claim attached to a selected run. Review queues on the gate lock before its own timeout starts.

Implement in scope, small commits, run the brief's acceptance commands, then write
`docs/team/reports/<ID>-<agent>.md` with the real commands and output tails (plus flip evidence for a defect
fix) and settle the branch: a local branch stays local, and a remote push/PR follows only the PM's authorized
route. The PM verifies in an independent worktree, merges itself, sets the board and closes the task. Messages are
not deliverables -- evidence lives in `docs/team/reports/`, `docs/team/reviews/` and the commits (recipes:
`/home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/references/workflows.md` §B dispatch, §E verification, §F merge). `docs/team/inbox/<agent>.md`
and the knock on `teamsmith:pm` happen at turn end automatically. Blocked, or someone else's bug:
`bash /home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/scripts/team notify <agent> "<one line>"` and a report that says `BLOCKED:`.

### The rest of the machine (read on demand)

- New project, first step: `bash /home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/scripts/team bootstrap` (idempotent); recipe in
  `/home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/references/workflows.md` §A.
- The pulse is the PM's metronome, not a daemon: `team pulse up|status|logs|down` every `TEAM_PULSE_INTERVAL`
  seconds (default 900), waking the PM only when work is pending. It never manages tmux layout, agents or quota,
  and a stopped worker is pending work for the PM to `resume`, not an automatic dispatch; `team standby on|off` is
  a human's call. Mechanism: `/home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/references/protocol.md` §8; patrol: `references/workflows.md` §D/§I.
- Capacity floor (`team ps`): neither RAM nor disk swap may bottom out; model quotas are a separate limit
  (`/home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/references/protocol.md` §9).
- Cross-project meetings are PM-to-PM only: workers do not attend, and no agent touches another project's
  repository or session (`/home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/references/meeting.md`).
- The ledger is `docs/team/` (`tasks/ reports/ reviews/ threads/ inbox/` and `BOARD·ROADMAP·OWNERSHIP·DECISIONS.md`);
  seats are `.worktrees/<agent>/` and sessions are keyed by cwd, so keep that directory stable.
<!-- teamsmith:end -->

### Code discipline: no non-stick code (user rule, 2026-10-19)

- **Fixtures live in `tests/`.** Product code does not carry test scaffolding, self-checks or "just in case"
  branches for its own tests.
- **Do not swallow an error you cannot name.** `|| true`, `2>/dev/null` and `if fail then :` are allowed only where
  the failure is *expected and named in a comment*; everywhere else they are deleted — a silent failure is what makes
  the next debugging session expensive.
- **A test must be behavioural and falsifiable**: it asserts what the product does, and breaking the product turns it
  red. Performance numbers are **reference only** (printed, never blocking). A test that needs a quiet machine, or
  that guards a restatement of the code rather than a behaviour, is deleted rather than tuned.
- The scale is visible: 74.7k lines of tests against 105k of product, and 23.7k `|| true` in the product.

### Complexity discipline: this is a control plane, not a system to manage the control plane

An outside review named the real risk in one line: *"it is building a complex software system to manage
agents."* Measured the same day: 105k lines of product against 75k of tests, 164 gate sections, 23.7k `|| true`,
and 20 archived changes of which most are **guards about our own process** rather than product behaviour.

Two rules, both checkable:

- **Net-zero for guards.** A new guard (a check, a gate section, a fixture, a refusal) must **replace or retire an
  existing one in the same change**, or the brief says in one sentence why the product cannot carry that behaviour
  itself. "Add a guard" alone is not a complete task.
- **One task in ten minutes.** A newcomer must be able to install, create a project and land one task by following
  the shortest path, without reading the incident history. If a change lengthens that path, it needs a ruling.

The rule is subtractive on purpose: the failure mode is not "too few guards", it is a tool that needs its own team.


## 项目模型额度切换

仅在明确确认 `clinepass` 额度耗尽时，PM 可将受影响任务切换到 `opencode-go/deepseek-v4.1-flash:max`，无需再次申请换模授权；不提前改变当前配置或运行席位，普通连接失败、超时或限流不等同额度耗尽。切换须记录原因，保留任务分支和已有证据，显式选择新模型并创建新 SID，不把旧模型会话续到新模型上。此条是项目规则，保留在 Teamsmith 受管标记之外。

## 推送约定（dev 镜像分支）

唯一的远端是 `public`（`teamsmith`，公开仓）；内部的 `teamsmith-internal` 已按用户要求移除，`TEAM_REMOTE` 相应改为 `public`。`dev` 是 main 的**只读镜像**：每次 main 前进（合并或账本提交）后立即 `git push public main:dev`，让 GitHub 上的 dev 与本地 main 同一步。`dev` 不是工作分支：不从它反向合并、不在它上面提交。dev 公开可见，会暴露未发布的中间状态（账本、任务、事故记录），这是用户明确选择的。main 与 tag 仍只在发布检查全绿后按发布流程单独推，本约定不改变发布纪律。此条是项目规则，保留在 Teamsmith 受管标记之外。

## 界面文案（UI copy）

界面上的文字是**说明书和控件标签**，不是对话。写文案时遵守：

- **只陈述或指示**，不解释。不写反问句（「这条回复是写给谁的？」）、不写旁白（「——PM 写给用户的回复都在这里」）、不写括注补充。
- **能删就删**：一行说明如果删掉后用户仍能操作，就删掉，不要缩成小字。
- **不用内部行话**：不出现「槽位」「夹具」「受管块」「一阶/二阶」这类实现词；用用户能直接对照屏幕词。
- 一条文案只表达一件事；不要在一句话里塞进提示、免责声明和用法三样东西。

此条是项目规则，保留在 Teamsmith 受管标记之外。
