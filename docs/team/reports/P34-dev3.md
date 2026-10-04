# P34 · pi-only-scope — propose package (the contract promises Pi, the adapter seam becomes an internal frozen seam)

agent: dev3   status: DONE   time: 2026-09-22T06:57:49Z
branch: `task/P34-scope-pi-only-init-propose`   PR/MR: - (local mode: no push)

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/pi-only-scope/proposal.md` | why / what changes / capabilities / impact / acceptance / flips / boundaries / report evidence (497 words, under the 500 limit) |
| `openspec/changes/pi-only-scope/design.md` | recon with file:line, the ADDED-vs-MODIFIED-vs-downgrade argument, the nine-file claimed surface, the schema free-text marking decision (M67 precedent), the init detection surface, the no-test-edit invariance method, risks, per-requirement review methods |
| `openspec/changes/pi-only-scope/tasks.md` | one apply batch, coverage map, path grants (tests/** explicitly not granted), four flip sets |
| `openspec/changes/pi-only-scope/specs/agent-adapters/spec.md` | **ADDED** — Pi is the only supported harness; the launch/notify seam is internal and frozen (5 scenarios) |
| `openspec/changes/pi-only-scope/specs/init-skill/spec.md` | **ADDED** — the questionnaire checks Pi's version and plugins, asks nothing about adapters (3 scenarios) |
| `openspec/changes/pi-only-scope/specs/memory-and-deps/spec.md` | **ADDED** — the four worker keys are an internal frozen seam; the marking reaches `team config list --json` (3 scenarios) |

3 requirements / 11 scenarios (brief budget: 3–5 requirements, 10–18 scenarios). Planning only: no
implementation path (`scripts/**`, `tests/**`, `extension/**`, `references/**`, `README.md`, SKILL files) was
touched by this task.

## Verification evidence (must have actually been run)

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ spec/agent-adapters … ✓ change/pi-only-scope … ✓ spec/watchdog
Totals: 16 passed, 0 failed (16 items)
EXIT=0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2301  ✗ 0
FAST 模式：跳过 27 个真进程段落（1c·M11 真沙盒窗口|6·dispatch 真拉起|6g·非 Pi agent 端到端|…）
smoke 全绿
EXIT=0
```

- Verdict: **pass** — both acceptance commands run on this branch; the smoke job is `p34-fast-smoke`
  (exit 0 after 500.9 s), full output `/tmp/p34-fast-smoke.log`, bounded job tail
  `.pi/team/state/bg/p34-fast-smoke.log`.
- `git status --porcelain` → empty at the committed tip (`75782af`); the report is the only file added after
  that check, committed on the same branch.
- Notes (be explicit): the FAST run skipped 27 real-process sections by design (FAST mode prints them); the
  post-run edits were confined to `openspec/changes/pi-only-scope/**`, which smoke does not read
  (`grep -rn 'openspec/changes' smoke.sh` shows only scratch-fixture paths). No implementation was changed, so
  the FULL suite is not owed by this task — the apply brief's gate (tasks item 4.3) runs it.

## Falsifiability evidence (the red side exists today — measured, not promised)

Every scenario in the three deltas fails **today**, so none is vacuous.

```
$ grep -nE 'any TUI agent|any TUI Agent|another TUI agent|其它 TUI agent|任意 TUI agent' \
    README.md skills/teamsmith/SKILL.md skills/teamsmith-init/SKILL.md \
    skills/teamsmith/references/{agent-adapters,config,migration,troubleshooting}.md \
    skills/teamsmith/templates/config.sh.tmpl skills/teamsmith/scripts/monitor.mjs
README.md:5:Runs on Pi today; designed to adapt to any TUI agent (adapter layer: ROADMAP M3.0).
README.md:61:For another TUI agent CLI, or to put the skills in `~/.agents/skills` next to other agent skills:
skills/teamsmith/SKILL.md:3:description: … Works with Pi today and is designed to adapt to any TUI agent. …
skills/teamsmith/SKILL.md:186:## Agent adapters (any TUI agent can be a worker)
skills/teamsmith/SKILL.md:255:| `references/agent-adapters.md` | To run workers with codex/opencode/any TUI agent: …
skills/teamsmith/references/agent-adapters.md:1:# Agent adapters · run workers (and the PM) with any TUI agent
skills/teamsmith/references/config.md:68:### agent adapter (workers may be any TUI agent; …)
skills/teamsmith/references/migration.md:137:| … set them only to run the PM under another TUI agent …
skills/teamsmith/references/migration.md:214:- **The PM side is Pi.** Only *workers* can be another TUI agent, via the four `TEAM_AGENT_*` keys; …
skills/teamsmith/templates/config.sh.tmpl:25:# ---- agent adapter (workers may be any TUI agent; …) ----
skills/teamsmith/scripts/monitor.mjs:7: *   - **其它 TUI agent**：配了 --log-glob / TEAM_AGENT_LOG_GLOB 时，…
skills/teamsmith/scripts/monitor.mjs:613:      '  （没有 Pi 会话文件；换用其它 TUI agent 时可设 TEAM_AGENT_LOG_GLOB，…）',
→ 12 matching lines (grep exits 0)

$ grep -nE '\bomp\b|another CLI|which harness|TEAM_AGENT_CMD|TEAM_AGENT_BIN|TEAM_AGENT_NOTIFY_CMD|TEAM_AGENT_LOG_GLOB|agent-adapters\.md' \
    skills/teamsmith-init/SKILL.md
30:   Then also fill the four adapter keys (`TEAM_AGENT_CMD` / `TEAM_AGENT_BIN` / `TEAM_AGENT_NOTIFY_CMD` /
31:   `TEAM_AGENT_LOG_GLOB`); the contract is `references/agent-adapters.md` in the daily skill.
36:4. **Harness and installed plugins.** Ask which harness the user's own sessions run (`pi`, `omp`, another CLI) — it
41:   magic-context, which `doctor` already checks. If the harness is **omp**, it already has background jobs (`bash`
→ 4 matching lines (grep exits 0)

$ awk -F'|' '$1=="TEAM_AGENT_CMD"||$1=="TEAM_AGENT_NOTIFY_CMD"||$1=="TEAM_AGENT_LOG_GLOB"||$1=="TEAM_AGENT_BIN"{printf "%s class=%s route=[%s]\n",$1,$2,$8}' \
    skills/teamsmith/scripts/lib/cmd-config.sh
TEAM_AGENT_CMD class=apply route=[]
TEAM_AGENT_NOTIFY_CMD class=apply route=[]
TEAM_AGENT_LOG_GLOB class=apply route=[]
TEAM_AGENT_BIN class=apply route=[]
→ no marking exists today
```

The init-checklist grep uses `\bomp\b`: a bare `omp` matches "pr**omp**t" (measured while writing this
report — the first version of the check hit `bootstrap-prompt.md.tmpl`), so both the delta's scenario and the
design's review command carry the word-boundary form.

## Flip evidence (required for defect-fix tasks; here the plan the apply must produce)

This is a propose task, so the flips are specified, not run. tasks.md item 4.4 lists them; design D7 maps the
risks. In short:

1. banned phrase appended to a scratch `README.md` → the nine-file grep prints `README.md:<n>:` and exits
   non-zero; removed → green.
2. one adapter row's marking cleared in a scratch tree (`TEAM_CONFIG_TREE`) → the config section reds naming
   the key; restored → green.
3. `omp`/`TEAM_AGENT_CMD` appended to the init checklist → the init grep reds; removed → green.
4. built-in Pi worker/PM commands rendered on this tree and a pre-change `git worktree` of the same fixture →
   byte-identical `diff`; §6i's recorded PM literal stays green — **no test edit** (D35).

## Decisions and deviations

- **ADD-only, no MODIFIED (design D1).** The brief allowed "keep as-is" or "downgrade to an internal fact".
  Kept as-is: a partial MODIFIED "loses detail at archive time" (OpenSpec's own instruction), and a downgrade
  would drop the twelve scenarios that pin what the built-in Pi path itself relies on. R1 scopes them
  explicitly instead.
- **The frozen marking lives in the schema row's free-text column (design D3)** — the M67 tombstone's
  mechanism, with class kept `apply` and every domain untouched, so `team config list --json` becomes the
  evidence instead of a grep of prose. Rejected: a new column, `choices.note`, a `refuse` class, docs-only.
  Named consequence: the panel shows a note line under the four rows; item 4.3 makes the apply run the
  panel sections and report whether any window count moved.
- **Two surfaces the brief's evidence list did not name were added to the claimed set (design D2/D7)**:
  `references/migration.md` (two "another TUI agent" routes) and `scripts/monitor.mjs`'s degradation message
  (the one runtime string a user reads as an offer). Leaving them would keep the promise alive in exactly the
  places the user looks; the monitor change is one string plus its comment line, and no test asserts either.
- **The template's opencode worked example leaves the template (tasks 1.7/3.3).** The seam stays documented in
  `references/agent-adapters.md`; a new project's contract should not ship a ready-to-use other-CLI recipe.
  The four keys stay rendered so the seam remains usable.
- **Known asymmetry recorded, not fixed (design D4):** `team doctor`'s `pi` row is skipped when
  `TEAM_AGENT_CMD` is set, so a configured seam can hide a too-old Pi. Fixing it is a behaviour change in
  `cmd-project.sh`, which D35 forbids; a future change can take it up.
- **Purpose handling (design D8):** the base `agent-adapters` Purpose is not rewritten (a delta cannot carry
  one for an existing capability; base specs are written by archive). R1's scope sentence corrects the
  framing; a direct Purpose edit stays the PM's call.
- **No D35 conflict found that blocks the proposal.** No `BLOCKED:` items; the ROADMAP rows M3/M8.1/C1 are the
  PM's edit, noted in design D7 and in the proposal's Impact.

## Suggested next steps

- PM proposal review (`docs/team/reviews/pi-only-scope-proposal.md`), then — only if ACCEPTED — dispatch the
  apply brief with the path grants tasks.md lists (`README.md`, both SKILL.md files, `references/**`,
  `templates/**`, the four `cmd-config.sh` rows + header comment, the `monitor.mjs` message), and with
  `tests/**` explicitly not granted.
- Before dispatch, the PM may want to settle the two judgement calls this package makes: the schema-column
  route (D3) and whether the README install-section line and `monitor.mjs` message are in scope (D2/D7).
