## Context

See `proposal.md` for motivation and `specs/boundary/spec.md` for the complete replacement contract. P159 is merged, but its ADDED signal requirement remains in the unarchived `safe-signal-discipline` delta. This proposal modifies that effective requirement, not a second signal policy. The archive prerequisite is material: `openspec validate --all --strict` does not resolve a MODIFIED header against the main spec.

Sources: `docs/team/reviews/P159.md`; `scripts/shim/signal-gate`; `scripts/lib/common.sh:2195-2229`; the four call sites below. Paths under `scripts/`, `tests/` and `references/` are relative to `skills/teamsmith/`. Evidence is in `docs/team/reports/P164-verify/pkg/logs/`.

## Goals / Non-Goals

**Goals:** cover the common interactive PID-producing selector route with the existing PATH gate, keep current diagnostic/count callers usable, retain P159 behavior and audit semantics, and make the new assertions falsifiable.

**Non-Goals:** prove ownership from parent/group membership, intercept shell `kill`, infer shell dataflow, add a sandbox, rewrite process management, expand the static lint, or wrap `ps`/`fuser`. No claim that a count cannot be misused as a PID, or that other read-only process tools cannot supply PID lists. Those are explicit residuals, not reasons to build a universal process-inspection ban.

## Decisions

### D1. Inventory before choosing a rule

A runnable-source scan of `skills/teamsmith/scripts/**` and `tests/**` finds **four actual calls in three files**, plus availability checks. `pidof` has no live call there. Comments in the shim/shell lexer, lint recognition strings, `signal-lint-cases.txt` source examples and historical report packages are not additional product callers. Historical evidence is not rewritten to accommodate a new runtime policy.

| Site | Actual argv and use | Narrow A, literally banning all `-f` | Recommended A plus count exception | Blanket B |
|---|---|---|---|---|
| `scripts/lib/common.sh:1507` | `pgrep -g "$g"` → group-liveness Boolean; `ps` is the primary route, this is its fallback | Pass for a positive scalar | Pass unchanged; bad/implicit ID is refused | Breaks the fallback when the `ps` route is unavailable or empty |
| `tests/panel-cpu.sh:285` | `pgrep -P "${time_pid:-0}"` → find the measured child of this fixture's pane wrapper | Pass for a positive scalar | Pass on valid pane PID; missing PID becomes refusal, then existing startup error exit 3 | Breaks child discovery and hence CPU measurement |
| `tests/panel-cpu.sh:340` | `pgrep -P "$time_pid"` → see whether wrapper still has a child during bounded shutdown | Pass for a positive scalar | Pass unchanged | Makes a refusal look like no child; premature loop exit / missing summary risk |
| `tests/smoke.sh:8095` | `pgrep -fc "$FAKE/pi-sleep"` → FAST assertion that the count is `0` | **False positive:** `-f` alone would block it; empty output is not `0` | Pass unchanged; no matches must preserve stdout `0` **and exit 1**, not fabricate exit 0 | Breaks the FAST self-check |

The two panel queries do not themselves signal. A later `kill -TERM "$pane_pid"` exists in that fixture, which manages its own pane; allowing the query does **not** certify provenance of a discovered PID. This proposal keeps that existing flow rather than extending scope into process-management redesign. Similarly, `common.sh`'s diagnostic group may come from terminal state rather than a spawner record: group membership is not an authorization.

The container observation (procps-ng 4.0.4) recorded its own owner/child IDs: `-g` returned that group, `-P` returned the child, and absent `-fc` returned `0`/exit 1. `-g 0` selected the calling process group implicitly; a shell with the marker in its own argv matched itself under `-f`. No selector output was signalled. `counterexamples.log` shows three compatibility assertions becoming RED under a blanket-refusal shadow.

### D2. Recommend A with a count-only exception; do not add a general option parser

| Choice | Benefit | Cost / residual | Decision |
|---|---|---|---|
| A as suggested in the brief | Small guard, group/parent remain usable | A ban keyed only on `-f` breaks FAST; a blacklist keyed only on `-f`/`-u` misses default name selection, `-U`, inversion and unsupported spellings | Refine with a complete-argv allowlist and count exception |
| B: block all selectors | Simplest verdict and stops the direct `pgrep`/`pidof` route | Rework all four sites: group liveness needs another numeric diagnostic, panel startup must record the child at creation, shutdown must check the recorded identity, FAST must retain a falsifiable no-spawn check. `ps`/`/proc` replacements can still supply PIDs, so this is not complete confinement | Reject: product/fixture churn without a sandbox guarantee |
| C: documentation only | No runtime compatibility cost | Interactive substitution remains executable; script-only lint cannot see it. Baseline witness forwarded `424242` to a recording `kill` | Reject: leaves the repeated accident route unchanged |

Use the exact grammar in the delta: two positive scalar-ID shapes, three full-command count shapes, four single informational tokens. Match the **whole argv**, not the presence of a good flag. The `-fc` spelling is the current caller; the two separate-flag spellings have the same simple count-only semantics. All other spellings (including long aliases, short attached IDs, `-p`, name-only counts, lists, additional flags and `--`-introduced patterns) are intentionally unsupported for now. Users can express the supported query canonically; future widening needs a measured caller and a refusal-side test, not a generic getopt emulator.

Reasons for each allowance:

- Positive `-g N`: diagnostic scoped by an explicit group number; preserves the measured fallback. No zero-ID shorthand or inversion.
- Positive `-P N`: diagnostic scoped by an explicit parent number; preserves both measured panel uses. Does not mean the caller owns those children.
- Full-command count: **no PID enumeration**; preserves FAST's independently observable count and original non-match status. Reject listing/output flags that turn a count query into something else. Numbers remain data, not signal targets.
- Single help/version token: no process selection; inherits P159's informational route. Preserve the real tool's own result, even on a platform where a particular token is unsupported. This is not a claim that all `pidof` implementations implement all four tokens.

`pidof`'s selecting operation is name-based, so no selecting form is allowed. Refusals are exit 64 with empty stdout, existing safe-route diagnostic and no real-tool resolution. There is no grant flag, environment authorization or extra configuration key.

### D3. Extend one shim family without routing selectors into pkill

Add `pgrep`/`pidof` symlinks beside `pkill`/`killall`, pointing to the existing `signal-gate`; extend its tool-name dispatch and whole-argv classification. Reuse the same log/forensics functions and `pass`/`refused` vocabulary. No parallel executable, queue or log schema.

`team_signal_real_bin` currently exports a single `TEAM_SIGNAL_REAL`, normally the real `pkill` (or `killall` fallback). Passing an allowed `pgrep -P N` to that pin would execute a signalling tool rather than a diagnostic. Therefore new selector branches **ignore that legacy pin** and resolve their own basename via PATH, skipping the shim itself. Keep the existing pin semantics for `pkill`/`killall`; do not expand config/UI/launch pins. With no real same-name tool, an allowed call keeps the existing missing-tool error (127); a refused call remains 64 regardless.

Fixture truth: put recording same-name selector stubs immediately after the gate in PATH, and use a separate pkill witness for the legacy pin. Also test an unusable pin. All fallback paths are stubs, including mutation tests; no test may accidentally fall back to a real signalling executable. Exact argv, stderr, stdout and configured nonzero exit status are checked separately. Keep deliberately unsafe shell source forms as fixture data (the existing `signal-lint-cases.txt` convention); install a recording-only `kill` function before evaluating substitution cases. Do not exempt executable fixture scripts from the lint.

### D4. Keep the effective baseline intact

The five original scenarios remain verbatim, not abbreviated during MODIFIED replacement:

| P159 scenario | P164 replacement | Check |
|---|---|---|
| A pattern kill is refused, executes nothing, and the decoys live | Same header/body | Retained byte-for-byte after trimming boundary whitespace |
| Every selecting form is refused | Same header/body | Retained |
| An inherited environment grants nothing | Same header/body | Retained |
| The read-only forms pass through | Same header/body | Retained |
| The pid-exact route stays open | Same header/body | Retained |

Original refusal/recorded-PID behavior survives. Only the prose that deliberately left `pgrep`/`pidof` outside the runtime gate is superseded; `kill` and absolute/ungated routes stay outside. Other P159 requirements (logging, launch prefix, `team bg`, static lint) are not copied or modified here. Their generic contracts apply to the extended gate, while selector-specific scenarios exercise those contracts from this requirement.

### D5. What flips and how its red side can be observed

These are acceptance **plans**, not claims of an implemented green side. Extend the existing `tests/signal-gate.sh`, including its `--break=pass` mode, so red output names the *new* assertions. Exit 1 from old pkill assertions alone is insufficient.

| Change / covered scenarios | Baseline or mutation RED | Restored GREEN expectation |
|---|---|---|
| F1: gate entries in PM/worker PATH | Baseline observation resolves both selectors to `/usr/bin`; remove either new symlink in a scratch shim and resolution assertion fails | `command -v` names gate entries in both rendered launch routes and real container windows |
| F2: refuse PID-producing selection, widening/implicit IDs, inherited grants; shell substitution | Baseline stub route executes selectors and supplies `424242` to recording kill (five observed RED assertions). After implementation, unconditional pass-through / accepting based only on `-g` presence makes the corresponding new exit-64/no-call/empty-output assertions RED | All listed negative shapes refuse; recording kill has zero PID arguments |
| F3: preserve group/parent/count/help semantics and avoid legacy pin | Blanket shadow causes three observed RED compatibility assertions. In a scratch implementation force all-selector refusal or reuse the pkill pin: pass-through/zero-pkill-call assertions must fail | Correct same-name stub receives exact argv, stdout/stderr/status preserved, no signals |
| F4: new calls share audit/retention | Baseline selector calls bypass the log. In a scratch implementation omit the selector log write or refusal retention, then the tool-specific line/cmp/rotation assertion must fail | One line per selector call, only refused retained, write failure visible and refusal status unchanged |
| F5: keep other tools and original five scenarios unchanged | Shadow a readonly `ps`/`fuser` witness with a refusal to redden the out-of-scope assertion; current P159 `--break=pass` remains the original refusal red side | Original fixture assertions still green; ps/fuser reach witnesses with no signal log |

No real signal in selector/substitution probes. The existing recorded-decoy-PID signal control is allowed only inside the disposable container. Mutation output and restored output must be retained by apply and independently rerun by a different verifier.

## Risks / Trade-offs

- **Residual bypass:** `kill $(ps …)`, absolute selectors, shell functions, an ungated shell, or even misuse of a count remain possible → explicitly describe scope in `references/protocol.md`; do not claim process confinement or provenance enforcement.
- **Interactive false positives:** valid but unsupported pgrep options are refused, including pure read-only PID queries → narrow documented canonical forms; no current valid-path call is lost.
- **Zero parent fallback:** panel missing-PID path gets gate exit 64 but redirects its diagnostic; the existing panel startup error still reports exit 3 → test zero separately and retain that visible fixture error, rather than treating implicit PID 0 as owned.
- **PATH portability:** alternate pgrep/pidof implementations may reject an allowed canonical/help shape themselves → preserve their status rather than translate it; no new dependency or emulation layer.
- **Stale shells:** already-running windows keep their old PATH command cache → new launch behavior is tested; shell refresh/relaunch is PM-managed, never restart live windows as part of a fixture.

## Migration Plan

1. PM accepts this proposal before dispatching one apply brief to a different agent. Grant only `scripts/shim/signal-gate`, new `scripts/shim/{pgrep,pidof}`, `tests/signal-gate.sh`, targeted launch-resolution assertions in `tests/smoke.sh`, and `references/protocol.md`.
2. Keep product call sites, static lint, config schema, other gate families and team ledgers unchanged. Commit implementation before the `--checkout` acceptance commands (they test HEAD, not uncommitted edits).
3. Run focused green, new-assertion red mutations and restored green; full smoke in a disposable container; independent verification by another agent. The PM must resolve findings before archive.
4. Before real archive, synchronize/archive `safe-signal-discipline` only after its own independent verification and confirmation, then trial-archive this delta on that effective base. Never use `--skip-specs` or weaken MODIFIED to ADDED to hide the prerequisite.
5. Rollback is a task-scoped revert restoring the old shim and removing the two new links. It restores the documented interactive-selector residual. PM owns any live-window restart; this propose task changes no running environment.
