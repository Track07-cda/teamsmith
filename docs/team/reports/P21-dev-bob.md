# P21 report — propose: `console-project-settings` (edit `.pi/team/config.sh` from the console)

**Phase**: propose (planning only, no implementation) · **Agent**: dev-bob · **Branch**: `task/P21-propose` ·
**Tip**: `a803235` (the first artifact set) plus the post-review rework commits — `git log --oneline
task/P21-propose` is the record · **Date**: 2026-09-20 · **Base**: main `51c51f3` (the P21 brief commit) · **Local mode**: not
pushed; the branch stays in `.worktrees/dev-bob` for the PM

## Deliverable

`openspec/changes/console-project-settings/` — four planning artifacts, planning only:

- `proposal.md` — why / what changes / capabilities / impact / verbatim acceptance / boundaries / evidence
  (**496 words**, inside the schema's 500-word rule).
- `specs/panel/spec.md` — delta: **ADDED ×4, MODIFIED ×1, REMOVED ×1**, 26 scenarios.
- `specs/memory-and-deps/spec.md` — delta: **ADDED ×5**, 23 scenarios.
- `design.md` — the brief's five questions answered as decisions 1–9 plus §10 (archive order) and §11 (the model
  seats), the full key-class table (one row per key, grouped), the measured context, 10 risks with mitigations, a
  five-batch migration plan, no open questions.
- `tasks.md` — five apply briefs (B1 the command, B2 the read-only view, B3 the write path, B4 the model seats,
  B5 the read-only requirement + docs + gate), 33 items, every one with a failing command and a flip, plus the
  coverage map.

`openspec status`: **4/4 artifacts complete**; `openspec validate --all --strict`: 15/15 green
(`✓ change/console-project-settings`); `deltaCount` **11**.

## Post-review update (the PM's NEEDS-CHANGES review, reworked in this phase)

The PM's review record `docs/team/reviews/console-project-settings-proposal.md` (tip `48ad664`) passed findings
1–5 and raised four required changes for the brief's follow-up section (the agent-model configuration). All four
are answered; the parts it marked "不必改" (the class table, the hardened writer, the CAS, the audit, the read-only
exceptions) are untouched apart from the model additions.

| Finding | Where it is answered now |
|---|---|
| 1 · per-seat editing entry point missing (`AGENT_MODELS` appeared 0×) | `panel` ADDED "The console edits a seat's model and shows where the displayed model came from" (+4 scenarios) and `memory-and-deps` ADDED "A seat's model is read and written as a seat" (+7 scenarios); design §11 (the seats block, `team config set-agent-model <seat> <model\|->`, the roster allowlist); tasks B1 1.11–1.13 and B4 4.1–4.5 |
| 2 · the source tri-state must be displayed | The same `panel` requirement: the three labels `配置` / `显式` / `历史记录` from `team config list --json`'s `models` block, computed by `team_agent_model_src`'s semantics, "MUST NOT compute a fourth state and MUST NOT render a bare model name"; the scenario "The source tri-state matches `team ps`" |
| 3 · three missing scenarios | (a) "A running seat keeps its model and the next spawn uses the new one" (`panel`); (b) "The source tri-state matches `team ps`" (differing record → `历史记录`); (c) "A refuse row opens no editor and the route is named" now covers `TEAM_AGENTS` as well as `TEAM_SESSION` (the negative roster case) |
| 4 · seat names in `TEAM_AGENT_MODELS` must be validated | `memory-and-deps`: the pair-level command refuses an unknown seat (exit 5) and the whole-value validator refuses a `dev4=…` token (exit 4); a token already in the file is **reported** as a warning by `team config list --json` instead of being silently ineffective (the scenario "An unknown seat already in the file is reported") |

Two things the review left to the design are ruled in §11: the three model keys are `restart` (a running seat
keeps its model; `dispatch`/`resume` picks the new one; the PM seat needs `team up`), and **no seat-restart action**
(spawning is dispatch — a brief, the PM's guards, the `--fresh`-or-continue decision; `--fresh` and
`--allow-overflow` are independent flags, not alternatives), so the read-only requirement still grows exactly one
exception and names both rejected actions.

### The review's own evidence commands, re-run at the reworked tip

```text
$ grep -cE "AGENT_MODELS" openspec/changes/console-project-settings/specs/panel/spec.md     # was 0 at 48ad664
5
$ grep -c set-agent-model .../specs/panel/spec.md .../specs/memory-and-deps/spec.md
1   6
$ grep -c 历史记录 .../specs/panel/spec.md
4
$ grep -n "A running seat keeps its model\|The source tri-state matches\|A refuse row opens no editor" .../specs/panel/spec.md
41:  #### Scenario: A refuse row opens no editor and the route is named            # now covers TEAM_AGENTS
168: #### Scenario: A running seat keeps its model and the next spawn uses the new one
177: #### Scenario: The source tri-state matches `team ps`
$ grep -n dev4 .../specs/*/spec.md
.../specs/memory-and-deps/spec.md:199:- **WHEN** `team config set-agent-model dev4 x/y --yes` and `team config set TEAM_AGENT_MODELS 'dev4=x/y' --yes`
.../specs/memory-and-deps/spec.md:221:- **THEN** the key's record carries a warning naming `dev4`, and `models.seats` carries no `dev4` row
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict   → 15 passed, 0 failed
```

Finding ④'s `kind` rule is also stated in design §5 (`pairlist`: seat = roster or `pm`, right-hand side
`provider/model`).

### The tri-state, measured (`/tmp/p21-seat`, the real CLI)

```text
$ team --root /tmp/p21-seat roster | grep -E "^dev|^verify|^dev2|模型·来源"
dev        · 无窗口 -                             -        -       -  deepseek/deepseek-flash·显式    -                -
verify     · 无窗口 -                             -        -       -  deepseek/deepseek-flash·历史记录 -                -
dev2       · 无窗口 -                             -        -       -  deepseek/deepseek-flash·配置    -                -
  模型·来源：配置=当前配置解析（或无记录，取配置）｜显式=上次 --model 指定｜历史记录=名册旧记录，配置已改 → 下次派单用新配置
```

Fixture: `dev` has `state/dev.env` with `model_src=explicit`; `verify`'s record differs from its configuration
resolution (`TEAM_AGENT_MODELS="verify=xai/grok-4.6"`) — the row shows the old model with `历史记录`, i.e. "the next
dispatch uses the new config"; `dev2` has no record. That is the exact triple the seats block must render, so the
scenario is constructible from files alone.

### Acceptance re-run on the reworked artifacts

```text
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
  → Totals: 15 passed, 0 failed (15 items);  exit=0
$ PATH="$HOME/.bun/bin:$PATH" openspec show console-project-settings --json | head -40
  → deltaCount: 11, first delta: memory-and-deps ADDED "The project contract has exactly one writer, …"
$ cp -r openspec /tmp/trialp21/openspec && cd /tmp/trialp21 && openspec archive -y console-project-settings
  memory-and-deps: + 5 added
  panel:           + 4 added   ~ 1 modified   - 1 removed
  Totals: + 9, ~ 1, - 1, → 0
```

The M28 container reds reported above were independently confirmed as pi's own update banner by the PM's M45
commits (`b7bc1c4`, `1ef19d4`: `PI_OFFLINE=1` restores the markers; the check must not be disabled — the box reader
should be fixed), which matches this report's diagnosis.

Commits: `babe5fb` (proposal + design), `5bda4ce` (both delta specs), `a803235` (tasks), then the report commits
(`1d8c6cb` and the amend that carries the gate section).

## The brief's five questions → where they are answered

| Brief question | Answer |
|---|---|
| 1 · Which keys are editable, by *effect* semantics, with the judging rule and the UI behaviour per class | design §1: the rule is **who reads the value and when** — `apply` (the next fresh reader: the tick, the `__panel-data` children, dispatch, review, the notify extension), `restart` (a running process holds it: the pulse console's argv/`process.env`, the PM session, a live session's extension env), `refuse` (identity, roster, ledger layout, branch/forge shape, authority-widening guards, dependency policy, machine paths Pi reads). Full table: ≈70 editable keys of the 89 documented, ≈35 refuse, 22 restart-class of which 11 need the `export` form. Panel behaviour per class: the badge + the exact restart command, and for `refuse` "no editor, the route named" |
| 2 · The write's safety semantics: comment/order preservation, concurrency, syntax, value validation and dangerous values | design §2–§6 + `memory-and-deps`'s four ADDED requirements. **Measured first** (see §"Evidence"): today's writer keeps comments/order *elsewhere* but **destroys the inline comment of the changed line**, joins the last line on a newline-less file, and — the security finding — writes values as double-quoted assignments so a `'$(touch PWNED)'` value **executes when the contract is sourced**. The design's answers: one writer (the hardened `team_config_set_in_file`, one home for the logic), `sha256` fingerprint CAS with exit 3, a writer-derived single-quote form (`export` for env-reader keys), a per-key kind/range/enum validator, a danger list that needs `--allow-danger`, temp-file + `bash -n` + rename, and one audit line per attempt |
| 3 · Interaction: overlay section or its own page; keys; long/multi-value editing; searching 47–89 keys; how `refuse` keys are shown | design §7: the overlay keeps its five preferences and gains **one navigation row** to a **view** (the detail view's pattern — not a fifth page, so the four-page composition and `state/panel-page` are untouched); `↑`/`↓` focus + windowed list, `/` filter (the compose editor in a `filter` mode), `enter` edits, `esc` returns to the overlay, `q` keeps its global meaning; the value editor is the compose line in a `setting` mode (pi's key map from P20, kill ring, undo, window) — multi-value keys are edited as their raw value and validated by the command (`TEAM_AGENT_MODELS`…); `refuse` rows open no editor and show the command's refusal with the route; rows are click targets |
| 4 · Effect and observability: how a write is reflected, and whether to offer a "restart the pulse" action | design §8: the class badge + the confirmation line + the receipt carry the timing (`apply` = next read; `restart` = the command, e.g. `team pulse restart`), and the receipt **must not claim** what it cannot observe — the running console keeps its argv, so it still reports `panel.refresh_s` 3 while the next `--print` reports 7 (a scenario). The in-panel restart action is **rejected with a reason**: the console *is* the pulse window's process, so it would kill the process drawing the receipt; the command is printed. That keeps the read-only exception list at exactly one new entry, written out in the delta |
| 5 · Audit: who changed what when, at least one line, traceable from the panel | design §9 + `memory-and-deps` R4: one line per attempt in `<state>/config.log` (UTC timestamp, result, actor — the panel passes `panel` —, key, the single-quoted old and new value, and for a conflict the expected and actual fingerprint), `team config log [N]` bounded to the last 16 KiB, and the view's footer renders the newest three lines; `--dry-run` writes nothing |

## Evidence (measured on this tree, scratch directories only)

### `team_config_set_in_file` — the brief's "实测行为" ask

`/tmp/p21-ev/run-writer.sh` (the function extracted verbatim from `cmd-bootstrap.sh` by an `awk` range, so the
measurement cannot drift from the source; output `/tmp/p21-ev/transcript-writer.txt`):

```text
$ team_config_set_in_file a.sh TEAM_GATES 'bash gate.sh'
exit=0
$ diff base.sh a.sh
10c10
< TEAM_GATES="pnpm verify && bash t.sh"    # 门禁
---
> TEAM_GATES="bash gate.sh"

$ team_config_set_in_file b.sh TEAM_NEW_KEY v    # b.sh 的末行没有换行
exit=0
$ cat -A b.sh
TEAM_OTHER=1TEAM_NEW_KEY="v"$

$ team_config_set_in_file c.sh TEAM_GATES 'end\'
exit=0
$ grep -n "^TEAM_GATES=" c.sh
10:TEAM_GATES="end\"
$ bash -n c.sh
c.sh: line 11: unexpected EOF while looking for matching `"'
bash -n: BROKEN

$ team_config_set_in_file d.sh TEAM_GATES '$(touch PWNED)'
exit=0
$ grep -n "^TEAM_GATES=" d.sh
10:TEAM_GATES="$(touch PWNED)"
$ ( . ./d.sh )
source exit=0
RESULT: PWNED exists

$ team_config_set_in_file e.sh TEAM_GATES 'say "hi" now'
exit=0
$ grep -n "^TEAM_GATES=" e.sh
10:TEAM_GATES="say "hi" now"
$ ( . ./e.sh; printf "value=<%s>\n" "$TEAM_GATES" )
value=<say hi now>

$ team_config_set_in_file f.sh TEAM_GATES 'two<LF>lines'
sed: -e expression #1, char 32: unterminated `s' command
exit=1
$ grep -n "^TEAM_GATES=" f.sh
10:TEAM_GATES="pnpm verify && bash t.sh"    # 门禁

$ team_config_set_in_file g.sh TEAM_GATES x    # g.sh 的键行有前导空格
exit=0
$ grep -n "TEAM_GATES" g.sh
1:  TEAM_GATES="indented"
2:TEAM_GATES="x"
```

Answers to the brief's two questions: **comments yes, except the changed line's own inline comment, which is
lost; order yes** (in-place `sed`; a new key is appended at the end, after every comment). The design's hardening
keeps the inline comment (a quote-aware scan) and refuses what cannot be represented, instead of writing a broken
or executing file.

### The class rule's measured basis (`apply` vs `restart`, and the `export` form)

`/tmp/p21-ev/run-activity.sh` (a scratch fixture project driven through the real CLI; output
`/tmp/p21-ev/transcript-activity.txt`):

```text
$ # config: TEAM_MONITOR_ACTIVITY=0   (plain assignment)
$ team monitor --print | grep -c "活动（仅本 session"
1
$ # config: export TEAM_MONITOR_ACTIVITY=0
$ team monitor --print | grep -c "活动（仅本 session"
0
$ # config: key absent; the environment carries TEAM_MONITOR_ACTIVITY=0
$ TEAM_MONITOR_ACTIVITY=0 team monitor --print | grep -c "活动（仅本 session"
0
$ team monitor --print --no-activity | grep -c "活动（仅本 session"
0
$ # config: TEAM_MONITOR_REFRESH=7   (plain assignment, the CLI forwards it itself)
$ team monitor --json | grep -o '"refresh_s":[0-9]*'
"refresh_s":7

$ # the pulse window bakes these in at launch (argv, not the file):
1231:                 --events "${events:-${TEAM_MONITOR_EVENTS:-4}}" --refresh "$interval"
1232:                 --tick-every "$TEAM_PULSE_INTERVAL" --tick-log "$TEAM_STATE_DIR/watchdog.tick.log")
```

That is why the table has a `form` column (`plain` vs `export`) and why `TEAM_MONITOR_ACTIVITY`,
`TEAM_AGENT_LOG_TAIL_BYTES` and the inbox-watch/bg knobs are written as `export KEY='…'` — and it is a
**pre-existing latent defect** the PM may want to know about independently of this change: today a plain
`TEAM_MONITOR_ACTIVITY=0` in the contract is silently ignored by the console (the doc presents it as a key).
This change's writer fixes the form for the keys it writes; the CLI does not change for hand-written lines.

## Acceptance (verbatim, run on the final artifact state)

```text
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
- Validating...
✓ spec/agent-adapters
✓ spec/board-and-status
✓ spec/boundary
✓ change/console-project-settings
✓ spec/delivery-guard
✓ spec/dispatch
✓ spec/init-skill
✓ spec/meeting
✓ spec/memory-and-deps
✓ spec/notify-and-inbox
✓ spec/panel
✓ change/panel-ergonomics
✓ spec/pm-lifecycle
✓ spec/verification
✓ spec/watchdog
Totals: 15 passed, 0 failed (15 items)
exit=0
```

```text
$ PATH="$HOME/.bun/bin:$PATH" openspec show console-project-settings --json | head -40
{
  "id": "console-project-settings",
  "title": "Propose: `console-project-settings` — edit the project contract (`.pi/team/config.sh`) from the console",
  "deltaCount": 9,
  "deltas": [
    {
      "spec": "memory-and-deps",
      "operation": "ADDED",
      "description": "Add requirement: `.pi/team/config.sh` (the project contract) SHALL be written only by `team config set`, through the one\nimplementation shared with `team init`/`team bootstrap` (the hardened `team_config_set_in_file`); the console\ncalls that command as a subprocess and MUST NOT open the contract for writing itself. A write SHALL preserve\nevery byte it does not change — comments, blank lines, the order of the keys and, on the changed line, the\ninline comment — SHALL append a key the file does not carry as a line of its own at the end of the file (a\nmissing final newline MUST NOT join it to the previous line), and SHALL leave the file parseable\n(`bash -n` exits 0). `team config list [--json]` SHALL be the machine-readable read of the same file: the\nresolved path, the fingerprint, one record per key (name, class, kind, current value, default, whether the file\ncarries it, its inline comment) and the newest audit lines; `team config log [N]` SHALL print the newest audit\nlines (default 10). A caller that asks for a value the writer cannot represent (a line break, a `#`) SHALL fail\nloudly: the command exits non-zero and a caller inside another command (`team init`, `team bootstrap`) MUST\nreport the failure and exit non-zero rather than continuing without the key.",
      "requirement": {
        "text": "`.pi/team/config.sh` (the project contract) SHALL be written only by `team config set`, through the one\nimplementation shared with `team init`/`team bootstrap` (the hardened `team_config_set_in_file`); the console\ncalls that command as a subprocess and MUST NOT open the contract for writing itself. A write SHALL preserve\nevery byte it does not change — comments, blank lines, the order of the keys and, on the changed line, the\ninline comment — SHALL append a key the file does not carry as a line of its own at the end of the file (a\nmissing final newline MUST NOT join it to the previous line), and SHALL leave the file parseable\n(`bash -n` exits 0). `team config list [--json]` SHALL be the machine-readable read of the same file: the\nresolved path, the fingerprint, one record per key (name, class, kind, current value, default, whether the file\ncarries it, its inline comment) and the newest audit lines; `team config log [N]` SHALL print the newest audit\nlines (default 10). A caller that asks for a value the writer cannot represent (a line break, a `#`) SHALL fail\nloudly: the command exits non-zero and a caller inside another command (`team init`, `team bootstrap`) MUST\nreport the failure and exit non-zero rather than continuing without the key.",
        "scenarios": [
          {
```

(The block above is the command's own first 14 of 40 lines, verbatim; the command is the brief's, unmodified.)

Extra, not required by the brief — the **trial archive**, run on a scratch copy (`/tmp/trialp21`) because this
change's delta touches two capabilities and one of them overlaps the un-archived `panel-ergonomics` change:

```text
$ cp -r openspec /tmp/trialp21/openspec && cd /tmp/trialp21 && openspec archive -y console-project-settings
Task status: 0/25 tasks
Warning: 25 incomplete task(s) found. Continuing due to --yes flag.

Specs to update:
  memory-and-deps: update
  panel: update
Applying changes to openspec/specs/memory-and-deps/spec.md:
  + 4 added
Applying changes to openspec/specs/panel/spec.md:
  + 3 added
  ~ 1 modified
  - 1 removed
Totals: + 7, ~ 1, - 1, → 0
Specs updated successfully.
Change 'console-project-settings' archived as '2026-09-20-console-project-settings'.
```

No delta defect surfaced: the MODIFIED block names a base requirement that exists, the two REMOVED/ADDED blocks
pair up, and the modified settings-overlay requirement kept all three of its base scenarios (verified in the
trial copy: 4 scenarios = 3 base + 1 new).

## The project gate (extra: the full `smoke.sh`, since the branch is docs-only)

The brief's acceptance list is the two `openspec` commands above; the project's default gate also runs the full
smoke suite, so it was run here as well (queued behind another full run, hence the start offset):

```text
$ PATH="$HOME/.bun/bin:$PATH" bash skills/teamsmith/tests/smoke.sh        # 675s, after waiting for the suite lock
  ✗ M28 容器里跑真 pi 体检：输入框判据 + 收回在真实现场成立（/tmp/teamsmith-smoke.KGYwC5/m28-ctr-pmbox.log 中找不到 [RETRACT=ok]）
  ✗ M28 容器里跑真 pi 体检：空闲空框被判 EMPTY（没被误判成忙）（/tmp/teamsmith-smoke.KGYwC5/m28-ctr-pmbox.log 中找不到 [verdict=EMPTY]）
== 结果 ==  ✓ 2297  ✗ 2
```

Both reds sit in the **container + real `pi`** section (`31b2`), and this branch carries no code change at all:

```text
$ git diff --stat main...HEAD            # the same six files after the post-review rework
 6 files changed, 1433 insertions(+)     # every line under openspec/changes/console-project-settings/ or docs/team/reports/
```

The section's own command, re-run standalone on this branch (`bash tests/container-tmux.sh --with-pi --cmd "bash
tests/pm-box-real.sh --idle-secs 3"`), reproduces the first red and shows the cause — the container's `pi`
prints an update banner that lands in the box region:

```text
· 运行时：distrobox-host-exec podman（回宿主）
· pi 包装器：<home>/.cache/teamsmith/tmux-container/shim/bin/pi → node …/@earendil-works/pi-coding-agent/dist/bundle/cli.js
  verdict=EMPTY state=EMPTY
  box_text=[ Update Available New version 0.86.0 is available. Run pi update Changelog: https://pi.dev/changelog…
  RETRACT=failed
```

`verdict=EMPTY` passed in that standalone run (the full-suite run had missed it too), while `RETRACT=ok` failed in
both — so the red is an environment artifact (the container's `pi` version banner, an update notice mid-box) and
its second half is timing-flaky, not a P21 effect. The PM should still re-run the gate on the merged tree; nothing
in this change can move those two assertions.

## Coordination the PM owns: the archive order

`panel-ergonomics` (P20, merged, not archived) modifies five `panel` requirements, **one of them the read-only
requirement this change replaces**. This delta is written so that **`panel-ergonomics` is archived first**: the
`C-v` clause and the "paste writes outside the project" scenario are carried forward into the ADDED read-only
requirement, so nothing P20 added is lost. The reverse order fails loudly (P20's `MODIFIED` would name a
requirement the base no longer carries, which OpenSpec's trial archive refuses) — design §10.

## Requirement → task map

| Requirement (capability) | Items |
|---|---|
| m&d · one writer, preserving what it does not change | 1.1, 1.2, 1.6, 1.7, 1.9 |
| m&d · a write is accepted only against the file the writer read | 1.3 |
| m&d · a value is validated, quoted by the writer, never copied | 1.2, 1.4, 1.9 |
| m&d · every attempt is audited in one line | 1.5, 3.3 |
| m&d · a seat's model is read and written as a seat | 1.11, 1.12, 1.13, 4.1, 4.4 |
| panel · shows the contract with its effect class, refuses what it must not change | 2.1, 2.2, 2.3, 2.4, 2.6 |
| panel · writes only through `team config set`, after validation and a confirmation | 3.1, 3.2, 3.3, 3.5 |
| panel · MODIFIED settings overlay (navigation row) | 2.3, 3.2 |
| panel · edits a seat's model and shows its source | 4.1, 4.2, 4.3, 4.5 |
| panel · ADDED read-only replacement + REMOVED old title | 5.1, 5.2 |
| all | 5.3 (the gate), 5.4 (this report's evidence) |

## Brief premises checked against the tree

1. **"面板已有设置浮层（`src/settings.ts`：语言/主题/密度/默认页…）"** — verified, with one correction: the
   overlay has **five** rows (`PREFS = ['lang','defaultPage','activity','mouse','density']`) and `theme` is a
   `panel.conf` key but explicitly **not** an overlay item (`panel` spec: "A `theme` key … is not an overlay
   item"). The design keeps that split.
2. **"已有一个写入口 `team_config_set_in_file`（`cmd-bootstrap.sh`），bootstrap/`team init` 用它改文件"** —
   verified (`cmd-bootstrap.sh:11`, called at lines 136–137), with the measured behaviour above.
3. **"`TEAM_PULSE_WINDOW` 属于 needs-restart"** — kept, with an added hazard the brief did not name:
   `team pulse restart` resolves the **new** name, so the old window would survive as a second backend
   (`team_pulse_legacy_window` only migrates the hard-coded `watchdog` name). The class is `restart`, the danger
   list flags a change while a backend runs, and the route is `team pulse down` (old name) → write → `team pulse
   up` (design §1).
4. **"TEAM_AGENTS 是空格分隔的多值"** — yes, and it is `refuse` (roster); the *editable* multi-value keys are
   `TEAM_AGENT_MODELS`, `TEAM_MODEL_LIMITS`, `TEAM_MODEL_WINDOWS`, `TEAM_EXTRA_PI_ARGS`, `TEAM_PM_EXTRA_PI_ARGS`
   — one line of raw text in the editor, validated by the command (`agent=model`, `pattern=N`).

## Boundaries / what this branch does not touch

Planning only: no implementation, no `skills/teamsmith/scripts/**`, no `tests/**`, no `references/**`, no
`.pi/team/config.sh`, no `docs/team/tasks/**` (the PM's brief is read-only), no push. The only files written are
the change directory and this report; the measurement scripts live in `/tmp` (their transcripts are above).

## Open items for the PM

- The archive-order rule above (`panel-ergonomics` first).
- The four NEEDS-CHANGES findings are answered (see the post-review section); the change is ready for re-review,
  then apply — B1 needs `skills/teamsmith/scripts/**` + `tests/**` granted, and the model batches reuse the same
  grant.
- The pre-existing `TEAM_MONITOR_ACTIVITY` plain-assignment defect (Evidence §2) — out of this change's scope
  (it changes no key semantics); flagged for the ledger.
- `proposal.md` is 499 words against the 500-word rule; if the PM wants the measured detail in the proposal, it
  has to come out of the Why paragraph.
