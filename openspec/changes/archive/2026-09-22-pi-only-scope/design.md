# Design: `pi-only-scope` — the contract promises Pi; the adapter seam becomes internal and frozen

## 1. Context

Read-only recon against this checkout (branch point `cc1d1d3`, worktree `.worktrees/dev3`), measured
2026-09-22.

- **The promise is everywhere, the evidence is not.** The banned phrases (`any TUI agent` / `any TUI Agent` /
  `another TUI agent` / `其它 TUI agent` / `任意 TUI agent`) appear on the claimed surface here — README.md:5
  and :61;
  `skills/teamsmith/SKILL.md`:3 (frontmatter `description`), :186 (`## Agent adapters (any TUI agent can be a
  worker)`) and :255 (deep-reading row, "codex/opencode/any TUI agent");
  `references/agent-adapters.md`:1 ("run workers (and the PM) with any TUI agent"); `references/config.md`:68
  ("workers may be any TUI agent"); `references/migration.md`:137 and :214 ("run the PM under another TUI
  agent", "Only *workers* can be another TUI agent"); `templates/config.sh.tmpl`:25 plus an opencode worked
  example at :37–41; `scripts/monitor.mjs`:613 (the degradation message printed when no session log matches)
  and :7 (comment). It rests on the M3.0/M8.1 probes only.
- **The seam itself is built and tested.** Schema rows `cmd-config.sh`:86–88 and :90 (`TEAM_AGENT_CMD` …
  `TEAM_AGENT_BIN`, all class `apply`); the placeholder engine (`common.sh`:3935 `team_agent_placeholders`, :4028
  `team_agent_kind_var`, :4137 `{notify_ext}`/`{bg_ext}`, :4190 the built-in worker render); PM side
  `common.sh`:1861 `team_pm_pi_args`, :2101 `team_pm_launch_cmd`; writer validation `cmd-config.sh`:412
  (`tpl`). Gates: smoke §6f (worker render / placeholders / doc contract, line 1397+), §6i (PM adapter,
  byte-for-byte PM invariance literal at 2034–2036), §15b (Pi version probes, 4833), §15c (harness+plugins,
  inform only, 4891), §18b (P16 split invariants, 7050+), M73 English-body invariant (6820+), `config-cli.sh`
  completeness (551+).
- **No test pins the promise.** `grep -rn 'TUI' skills/teamsmith/tests/` finds only fixture vocabulary
  (`FAKE_TUI_*`, section titles); no assertion greps the claimed surface for a harness phrase, none asserts
  `route` (the only hit is a binary `.pyc`), and none asserts the template's opencode example. Rewording the
  docs cannot turn an existing assertion red — the risk is the opposite: over-deleting a table the doc
  scanners read.
- **The M67 precedent for a schema annotation.** `cmd-config.sh`:70 puts a retired-key explanation in the
  row's free-text column (`refuse` class), the panel shows it verbatim, and `team config list --json` reports
  it as `route` (:696–699). The header comment documents the column as "refuse 类的用法指引（面板把它原样展示）"
  (:33).
- **D35** (user, 2026-09-22): promise Pi only; keep the four keys as an internal frozen seam (L2), no
  compatibility promise, not asked in the init questionnaire; no code deletion, no Pi behaviour change, no
  test change (L3 rejected); ROADMAP M3 / M8.1 / C1 deferred, not deleted.

## 2. Goals / Non-Goals

**Goals.** (1) One harness is promised: Pi, at the existing version floor. (2) Every sentence that advertises
another harness is either reworded under the frozen wording or removed. (3) The seam stays writable,
diagnosable and documented well enough to maintain (its placeholder tables and the reference doc's worked
examples survive).
(4) The new-project questionnaire checks Pi's version and plugins, nothing else. (5) The four keys are marked
as an internal frozen seam in the schema read and the config doc. (6) Zero behaviour change, zero test edit.

**Non-Goals.** Deleting or `refuse`-gating the adapter code (D35 L2); changing dispatch, the placeholder
engine, the writer, the built-in Pi commands, the PM lifecycle or the notify contract; a general audit of
`scripts/**` comments (code comments stay); the ROADMAP edits (PM-owned); archiving the change.

## 3. Decisions

### D0. Spec homes: one requirement per capability, three deltas

| # | Promise | Capability | Op |
|---|---|---|---|
| R1 | The contract promises Pi; the launch and notify seam is internal and frozen (claimed surface, banned phrases, frozen wording, seam still usable, built-in commands byte-identical) | `agent-adapters` | ADDED |
| R2 | The new-project questionnaire checks Pi's version and plugins and asks nothing about adapters | `init-skill` | ADDED |
| R3 | The four worker keys are an internal frozen seam; the schema read and `references/config.md` carry the marking; class `apply` and every validated domain unchanged | `memory-and-deps` | ADDED |

`agent-adapters` owns R1 because the promise is about the adapter layer; `init-skill` owns R2 because the
questionnaire is the init skill's body (the base spec already owns its three beats); `memory-and-deps` owns R3
because it is a property of the config schema and its read, next to the existing key-class requirements.

### D1. The three existing `agent-adapters` requirements: keep them, do not modify, do not downgrade

The brief asks to argue "leave as-is" versus "downgrade to an internal fact". **Leave as-is**, for three
reasons:

1. **The archive loses detail on a partial MODIFIED.** OpenSpec's own artifact instructions say a MODIFIED
   block MUST carry the entire requirement and that partial content "loses detail at archive time" — and the
   project has already chosen ADDED for new concerns without behaviour change. Rewriting three requirements
   only to add a framing sentence would mean transcribing twelve scenarios, with real drift risk and zero
   behavioural gain.
2. **A downgrade would delete tested behaviour from the spec.** Moving the engine's rules out of the spec
   (into code comments or a reference doc) would drop the twelve scenarios that pin what the built-in Pi path
   itself relies on: malformed templates fail loudly, the first word is resolved on the caller's `PATH`,
   `{prompt}` travels as `argv[0]`, the PM uses the same engine with `{resume_args}`. Those are exactly the
   invariants that must keep holding while the seam is frozen — the difference is *who* they are for, not
   *whether* they hold.
3. **ADDED composes.** R1 states the scope explicitly ("the three existing requirements of this capability
   … stay exactly as they are; this is not a public extension point"), so the capability reads correctly
   without touching them. If a
   future change ever wants to shrink the engine, it will have the scenarios to modify deliberately.

What replaces the evidence surface a downgrade would have needed: the existing §6f/§6i/§15b/§15c gates stay
the behavioural pins, and R1 adds the promise-scope pins (banned phrases, frozen wording, seam usability,
byte invariance).

### D2. The claimed surface is a named file list, not "the docs"

A negative claim ("no document promises another harness") is only falsifiable against a closed list. The list
is: `README.md`; `skills/teamsmith/SKILL.md` (whole file); `skills/teamsmith-init/SKILL.md`;
`skills/teamsmith/references/{agent-adapters,config,migration,troubleshooting}.md`;
`skills/teamsmith/templates/config.sh.tmpl`; and `scripts/monitor.mjs`'s degradation message (the one runtime
string a user reads as an offer). Everything else is out of scope, deliberately:

- **Source comments in `scripts/**`** (`common.sh`, `cmd-agents.sh`, `cmd-project.sh`, `cmd-watch.sh`) keep
  their bytes: D35 forbids changing code, comments are not promises, and rewording them would widen the diff
  without adding a guarantee. The one exception is `monitor.mjs`, whose degradation message is on the claimed
  surface: its comment line (:7) is reworded together with the message so that the file does not keep the
  claim the message drops.
- **The test suite** (smoke section titles say "任意 TUI agent"): tests are not a promise surface, and D35 says
  no test change.
- The **panel bundle** is untouched: the settings view already renders the seam through the same read.

The banned set is mechanical: `any TUI agent`, `any TUI Agent`, `another TUI agent`, `其它 TUI agent`,
`任意 TUI agent`. The fixture greps the list above; the flip appends a phrase to a scratch copy. The positive
half (every non-Pi mention sits under the frozen wording) is checked by requiring the frozen sentence to
appear before the first worked example in `references/agent-adapters.md` and in the contract template, and by
the reference-doc tables staying intact so §6f/§6i keep scanning them.

### D3. The frozen marking lives in the schema row's free-text column

R3 needs a machine-readable home. Chosen: the row's 8th field (`route` today), the same place M67's tombstone
lives, with the header comment widened from "refuse 类的用法指引" to "the free-text route/note column the panel
shows for `refuse` routes and frozen-seam notes". Text (all four rows, verbatim):
`内部接缝（frozen）：为将来非 Pi 适配预留，不承诺兼容；不在 init 问卷里问`.

Alternatives rejected:

- **A new schema column** — a position change for 111 rows plus the field-range doc, for one note; the free
  column already exists and is already rendered.
- **`choices.note`** — `note` is defined as the key-domain explanation (today the `path` kind's existence
  check) and is part of the `choices` contract the panel's pickers read; a seam note there would change the
  choices machine contract rather than add a note.
- **A `refuse` class or a warning string** — the keys must stay writable (D35 L2); `refuse` would make
  `team config set TEAM_AGENT_CMD …` fail, which is exactly what the user rejected.
- **Documentation only** — then no fixture can see the marking and R3's main scenario would be a grep of
  prose; the schema column makes `team config list --json` the evidence.

Consequences, accepted and named: the panel's settings view gains a note line under each of the four rows
(`layout.ts:1289` renders `warning || route || comment`); the JSON read gains a `route` value where it used
to be `""` for four keys (an additive value, not a new field); no settings-view snapshot exists and the
panel fixtures filter by key, so the risk is contained — but apply MUST run the panel sections and report
whether the note lines moved a window count.

### D4. The init questionnaire checks Pi's version and plugins

D35: the detection surface is Pi's version (the README's `Pi ≥ 0.76.0` floor, the `--session-id` criterion
`team doctor` uses — §15b proves both the stdout and stderr `--help` shapes) plus the plugin report (M26/M29:
`已装插件 packages`, information only, never a third-party recommendation — §15c). The init SKILL's current
items 2 (second half) and 4 carry the seam question and the `omp` branch; both go. The doctor rows themselves
are untouched: this change does not alter doctor's code, so the `harness` row keeps its diagnostic branches
(including `omp`) and the `pi` row keeps its current "custom adapter ⇒ pi not needed" condition. That last
point is a **known asymmetry**, recorded here rather than fixed: with a configured seam, doctor does not check
the Pi floor. Fixing it would be a behaviour change in `cmd-project.sh`, which D35 forbids; a future change can
take it up with a spec of its own.

### D5. Zero behaviour change, and how it is proven without a new test

D35 says no test change. The strong invariance evidence for the default path already exists for the PM
(§6i's `LEGACY_REF` byte comparison, which includes the M27 `-e team-bg.ts` and M30 `-e team-inbox-watch.ts`
fragments). For the worker, this change adds **no fixture**: the check is a two-tree comparison — render
`team dispatch … --print` in a fixture on this branch and on the pre-change revision and `diff` the two
strings; the existing §6f fragment assertions stay the second witness. The apply report carries both tails,
and the diff shows the rendering code untouched.

### D6. Budgets the apply must not break

- **Description length**: `SKILL.md`'s description must stay ≤ 1024 characters and must keep the
  `teamsmith-init` pointer (§18b).
- **Init skill ≤ 100 lines** and the three beats (§18b, base `init-skill` requirement).
- **English bodies**: `references/**` prose must stay CJK-free outside code spans (M73), so the frozen wording
  in the reference docs is English; the schema note is `scripts/**` and stays Chinese like every other route.
- **Doc↔engine scanners**: the placeholder tables in `references/agent-adapters.md` (worker table + the
  `<!-- pm-side:begin -->` block) and the `agent-adapters.md` deep-reading row must survive rewording.

### D7. Risks

| Risk | Containment |
|---|---|
| An over-eager apply deletes the placeholder tables while "de-advertising" | R1's scenario 3 names both tables and the two gate sections; tasks item 1 forbids deleting rows |
| The panel's note line shifts a window count and reds a pty fixture | D3 names the fixture risk; tasks item 3 requires running the panel sections and reporting the outcome |
| The ban catches README's install section (`install.sh`, another CLI's skill directory) | Reworded factually: `install.sh` places skill *files*; it is not a harness promise. The banned phrase must still go |
| `migration.md` claims go stale (it is the upgrade guide) | Reworded to "the seam is frozen; the PM side runs Pi"; no new keys, no migration step |
| Someone reads "frozen" as "removed" and files a bug that the keys stopped working | R1/R3 scenarios assert the seam still renders and still writes, and `team paths` still says `custom: …` |
| The ROADMAP still advertises M3 "任意 TUI Agent" | Out of this change: the ROADMAP edit is the PM's (noted here and in the proposal); the apply report carries a one-line note, not an edit |

### D8. The capability Purpose is not rewritten here

The base `agent-adapters` Purpose still reads "one template contract for the CLI that runs a worker or the PM".
A delta cannot carry a Purpose for an existing capability (OpenSpec ignores it), and `openspec/specs/**` is
written by archive, so this change corrects the framing through R1's scope sentence instead. R1 is appended
after the three requirements, so the archived spec reads: the mechanics first, then "the contract promises Pi;
this seam is frozen". If the PM later wants the Purpose paragraph itself adjusted, that is a direct PM edit to
`openspec/specs/agent-adapters/spec.md` — named here so the choice is explicit rather than forgotten.

## 4. Review method per requirement (the apply report must show each)

| Requirement | Command / script | Expected |
|---|---|---|
| R1 banned phrases | `grep -nE 'any TUI agent\|any TUI Agent\|another TUI agent\|其它 TUI agent\|任意 TUI agent' <the nine claimed files>` | no hit; the scratch-copy flip prints `README.md:<n>:` and exits 1 |
| R1 frozen wording | `grep -n 'internal seam (frozen)' skills/teamsmith/references/agent-adapters.md skills/teamsmith/references/config.md` and the template's adapter section | the sentence appears before the first worked example; the template points at the reference doc |
| R1 seam usable | `TEAM_AGENT_CMD='myagent run --ask {prompt}' TEAM_AGENT_BIN=bash team dispatch dev T1.1 <brief> --print` | prints `adapter: custom: myagent run`, renders, exits 0 |
| R1 byte invariance | `team dispatch … --print` on the branch vs the same fixture on the pre-change revision, then `diff`; §6i's PM literal assertion | identical strings; §6f/§6i green unmodified |
| R2 Pi-only checklist | `grep -nE '\bomp\b\|another CLI\|which harness\|TEAM_AGENT_CMD\|agent-adapters\.md' skills/teamsmith-init/SKILL.md` | no hit; the file names the Pi floor and `已装插件 packages`; scratch-copy flip is red |
| R2 doctor rows | `team doctor` against the three stub `pi` shapes (§15b) and plugin fixtures (§15c) | version row passes the stderr shape and fails the missing flag; plugin row informs only |
| R3 marking read | `team config list --json` in a fixture | four records with `"class":"apply"` and the `内部接缝（frozen）` route; `TEAM_CONFIG_TREE` walk red when one row loses it |
| R3 writable/domains | `team config set` with a valid template, an unresolvable `TEAM_AGENT_BIN`, and a two-line template | `0`, `0`, `4`; audit lines; sha unchanged on the refusal |
| R3 template | `config-cli.sh completeness` | green unmodified; no opencode example in the rendered contract |

## 5. Scenario → fixture map

| Delta scenario | Fixture |
|---|---|
| R1/1 no advertised harness | a grep walk over the nine files + a scratch-copy append flip |
| R1/2 frozen, still usable | `dispatch --print` with a custom template; a read of the reference doc's head |
| R1/3 examples marked, tables kept | §6f/§6i doc↔engine scanners; template read |
| R1/4 built-in byte-identical | §6i's `LEGACY_REF` + the §6f fragment assertions + the two-tree `diff` |
| R1/5 daily description | §18b's `p16_desc_of` / length check |
| R2/1 checklist | grep walk + scratch-copy flip |
| R2/2 doctor rows | §15b stubs + §15c plugin fixtures |
| R2/3 no contract moved | `team bootstrap --print` + `config-cli.sh` completeness |
| R3/1 marking read | `team config list --json` + `TEAM_CONFIG_TREE` walk |
| R3/2 writable/domains | `team config set` on a fixture contract |
| R3/3 template | rendered contract read + `config-cli.sh completeness` |

## 6. What apply must not do

No `tests/**` change (D35; every scenario above is checkable with the existing suite plus a two-tree diff);
no change to `scripts/**` except the four schema rows' 8th field, the schema header comment's line about the
column, and `monitor.mjs`'s degradation message plus its one comment line; no `refuse` class, no danger-list
entry, no writer rule; no `ROADMAP.md` edit (PM-owned); no base-spec edit (`openspec/specs/**` is written only
by archive).
