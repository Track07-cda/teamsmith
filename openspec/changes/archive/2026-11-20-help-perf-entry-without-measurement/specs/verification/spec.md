## MODIFIED Requirements

### Requirement: A gate that cannot judge says so

The correctness gate SHALL distinguish a product-only checkout, which deliberately contains the published product and `openspec/specs/` but none of this development repository's internal surfaces (`docs/team/`, `openspec/changes/`, `AGENTS.md`, `SCOPE.md`, `.pi/prompts/`, `.pi/skills/`), from an internal or partially populated checkout. Classification MUST inspect the checkout under test before creating fixture data; inherited project identity, CI environment, and a fixture-created ledger MUST NOT decide it. An empty, unreadable, malformed or partially populated internal surface MUST NOT be treated as absent. No production environment override SHALL turn a missing product or internal-checkout file into a prerequisite skip.

Only a check whose named prerequisite is one of those deliberately absent internal surfaces SHALL skip on a product-only checkout. Each such attribution MUST print `SKIP（条件不满足）`, the affected check and missing prerequisite, be counted as a skip rather than a pass, and reach the gate's output and per-section/run accounting. Missing product files, unavailable required tools, a failed executed assertion, and corruption of a present internal surface MUST retain their existing failure/degradation rules; the checkout classification MUST NOT swallow them. An executed check's verdict MUST rest on evidence the subject itself carries: when the call's command word is the wrapped command itself (`tmux`), an isolation wrapper defined in one file MUST NOT certify a mutation call made by another file, while a dedicated wrapper name defined alongside the caller MAY keep its directory-level meaning; a check MUST NOT be reported as satisfied on evidence the subject does not have. A run with prerequisite skips and no failures SHALL exit 0, without claiming the skipped checks passed; a real failure alongside skips MUST still exit non-zero.

The same correctness command SHALL run on both shapes, with no second public suite. The product's static checks, skill loading, published-spec validation, container-build checks and every ledger-independent fixture MUST remain eligible exactly as before (including the existing FAST/full and tool-premise rules). A fixture that provisions its own ledger MUST still run in the product-only checkout. For an internal checkout, except for the three route-page control replacements, the reply-observer duplicate-execution retirement, the routing-argv repeat replacements, the routing-parameter replacements, the selected-settings display replacements and the perf help claim replacement specified below, every pre-existing assertion MUST still execute with its original verdict and at least its pre-change per-section pass count under identical run settings; replacing an existing assertion with a new one MUST NOT satisfy that coverage comparison. CI's correctness step MUST retain its blocking failure semantics, and it SHALL run the product floor the way `verification#CI runs the two gates separately and performance does not block` states: a failing applicable product assertion in that step fails the job, and the selection it makes is disclosed in the output tail rather than presented as the full gate.

The route-page replacement exception is the three complete nested walks in the route-page controls for a column-zero
command line, an undeclared command-page usage and an unread group level, as specified by
`dispatch#The printed route is a route that works`. Their shared file judgement and the two single-page
damaged/normal renderer experiments SHALL replace those executions, not skip their content obligations.
The delivery evidence SHALL map each retired control to its replacement's intended-rule finding and no-finding
normal result. Its counted objects SHALL be routes.sh's own `✓/✗` totals and per-case named result inventory,
not smoke's single successful-child section count; nested-walk log lines MUST NOT be added to parent counts.
Pre-change evidence SHALL identify each old parent assertion and count from source, retain the existing non-FAST
51m record and manually reproduce only the undeclared-usage control once with unchanged test source. The other
two old controls SHALL be labelled source-attributed, not rerun; no modified baseline test or selector is allowed.
Post-change evidence SHALL come from non-FAST `bash skills/teamsmith/tests/routes.sh pages`, including actual
`替代④`, `替代⑪`, `替代⑬` results and its own totals. FAST/default smoke does not produce this sample evidence.
Old parent, nested-walk, new sample and any retained full-flips totals MUST retain their separate provenance,
not be summed or presented as comparable measurements of identical execution scope.

Only counts attributable to these named replacements MAY differ; the real route walk and all other controls
MUST retain their original assertions/count obligations, with the unchanged normal real-walk command compared
under identical settings. Replacement assertions SHALL count only when executed; neither an assumed old count,
duplicate success lines nor a retired assertion reported as passed SHALL make the new total resemble the old one.
This exception permits no new prerequisite skip or permanent deletion-policing guard.

The separate reply-observer exception SHALL retire only the forced-missing-observer replay of complete
bounded/flip groups, its failure-only trace replay, the bounded notice predicting a later full_scan skip, and
the seven old skip-path checks replaced by focused diagnostic/outcome checks and their negative controls.
Only those retired executions SHALL be removed from the comparison inventory; no other assertion, normal
bounded run or original mutation arm SHALL be retired under that exception. Child replay counters MUST NOT
be subtracted from parent counters that never included them. The replacement SHALL report its actual checks
and distinct skipped observation identities, never pad passes to preserve an obsolete raw total. This exception
does not modify the route-page obligations above or permit a new prerequisite skip.

The routing-argv exception SHALL retire only the complete boundary executions for
`worker-literal-resplit` and `pm-literal-resplit`, replacing them with actual-shell argv checks, and the
second complete CORE executed on the unmutated source tree at the end of `--flip`. It SHALL retain the
first complete normal CORE, including the normal worker/PM literal-argv launch and continuation checks,
and all other mutation arms. The replacement SHALL preserve the three existing intended-failure identities:
`worker-expansion-literal-argv:extra`, `pm-expansion-literal-argv:extra` and
`pm-resume-literal-argv:builtin`. Each modified arm SHALL obtain healthy, mutated and byte-restored results
on its own copy, with real PM identity validation and legal private configuration/continuation metadata.
Expected argument values SHALL be fixed independently of the product tokenizer; the observation SHALL be
arguments actually formed by Bash, not product tokens compared with themselves. An unmet setup or renderer
error MUST NOT count as the intended argv failure.

This exception deliberately drops unrelated template/role/refusal/PM-transaction observations on those two
mutated trees and a second independent normal-tree repeatability sample; it does not claim equivalent
preservation of those incidental observations. Their normal coverage remains in the first CORE and original
groups. The retired full executions SHALL have no alternate slow entry and no prerequisite skip. Existing
parent failure accounting SHALL consume child exit codes, intended-failure names and healthy/restored outcomes;
a sample failure MUST NOT disappear in a helper-only result. Actual replacement assertions SHALL be counted
where executed, separately from child totals; a retired pass MUST NOT be reported as executed, and no fixed
global total or net elapsed saving is promised. This exception changes neither the route-page/reply-observer
exceptions nor normal first-order routing coverage.

The routing-parameter exception SHALL replace repeated negative CLI permutations in normal boundary
verification with shared direct parameter judgements and named real-call refusal witnesses. It SHALL also
replace complete boundary execution in exactly five original mutation arms: `extra-shadow`,
`template-shadow`, `template-unbound`, `template-roles` and `literal-shell-expansion`. Their direct
judgements SHALL be the same assertions executed by normal boundary verification, with fixed expectations
independent of the product algorithm. A separate test-only parameter selection SHALL perform no project
initialization, configuration-writer calls, dispatch/up, tmux launch or PM transaction replay.

This exception permits retirement of per-string preview/launch/fresh CLI permutations and their per-attempt
captures, not of parameter rules or the named real-call witnesses. It deliberately abandons rejection-purity
observations for every removed permutation and unrelated live-launch/metadata/rollback observations on those
five mutated trees. Normal legal-selector, literal-argv, continuation, fresh identity and PM metadata/rollback
checks SHALL remain real; other groups and original mutations, including the prior two argv replacements,
SHALL remain unchanged. The retired calls SHALL not survive in a slow entry or become skips or passes.

Each of the five arms SHALL obtain healthy, original-mutated and byte-restored parameter outcomes on the same
disposable copy. The existing parent SHALL consume child status, required failure identities and both healthy
and restored results; a setup error, missing intended name or timeout MUST NOT satisfy a mutation.
A functioning pure judgement SHALL NOT substitute for evidence that worker and PM callers use it before
effects, that the launch renderers still reject bad inputs, or that actual shell argv matches committed
identity. No product predicate, launch authorization, timeout or observation window changes under this exception.

For this batch, source-attributed old inventories and already accepted unchanged-group evidence SHALL be
reused. One non-author verification on a frozen independent checkout SHALL supply the changed normal boundary,
the five original faults/restorations, targeted caller-bypass evidence and existing-parent failure propagation.
It SHALL NOT require another complete CORE, 61b or full suite merely to pay the prior routing-argv batch's
already completed acceptance again. Post-merge verification SHALL check byte identity and necessary short
integration only, unless an evidence premise changed. Old child, new direct, real-call and parent totals SHALL
remain separate; no fixed pass total, elapsed saving or whole-suite success follows from this replacement.

The selected-settings display exception SHALL retire or replace only obsolete presentation assertions
superseded by `panel#Project settings expose selected user operations rather than the complete configuration table`,
`panel#Selected settings editors preserve owning-command choices and writes` and
`panel#Settings groups follow user purposes and keep visible action state`. Its scope is the full-key/unknown-key
and automatic new-key display, fixture-marker removal restoring a row, schema-group/order and full-schema label
binding, raw-key-led prompts/confirmation and repetitive class/default badges, mandatory schema-kind/no-choice explanatory text for retained editors and its display-dependent waits, mandatory disk/inode setting rows,
the duplicate whole-map jump, running-process claims from model records and UI-only editors for excluded
enum/path keys. Their replacements SHALL observe selected operations, current-view row counts, two secondary
entries/return routes, user labels, retained editors opening with the original value editable and original validation/confirmation intact, and accurately named records, using the existing
settings/groups/wheel/choices/choices-schema/categories/policy fixtures and string checks.

Only that explicit old-to-new display inventory SHALL leave the pre-change assertion/count comparison.
Full CLI reads/group metadata, choices/validation, writer/CAS/actor/danger/cancel/conflict/failure, model/SID and
provenance, missing-versus-unreadable records, real errors, and keyboard/mouse/navigation/window behavior SHALL
retain coverage. No generic UI exemption, new prerequisite skip, fabricated old pass count or new policing
check is permitted. Old source inventory, actually executed replacement assertions and unchanged-coverage
evidence SHALL keep distinct provenance; replacing an obsolete display assertion does not prove the old
assertion executed.

For this selected-settings batch, the implementer SHALL provide static evidence only. A non-author SHALL run
the affected existing project-settings scenarios once on a frozen independent checkout; short/long rows, counts
and fill are observed in settings/wheel, not in the unrelated preference-overlay snapshot suite. The existing
`scn_flip` SHALL retain its category-write-route and policy-as-record-model product mutations plus its normal
policy finish; only product touchpoints required by the display change are adjusted. Its normal finish SHALL
supply the ordinary policy result, with no separate normal policy invocation in that batch. Schema-input
witnesses are not product mutations. Unchanged complete CLI coverage is cited with its original revision/scope,
not rerun or claimed as new. No new FAST/full/61b run, screenshot matrix or wait budget is required to accept
this narrow replacement; post-merge evidence uses same-verifier identity and necessary short integration unless
the evidence premise changed. All unrelated coverage obligations and prior exceptions above remain intact.

The perf help claim exception SHALL replace only the bounded measurement attempt for `team perf --host` in
§51's `help-surface.sh` `claims` group, keeping the original initialized calling-project fixture and its six
fingerprints: state, documents, configuration, worktrees/local branches, installed skills and meetings.
The check SHALL execute the real CLI from that project and SHALL substitute only the measurement target
in private source. Evidence of the handoff SHALL be one complete, test-owned record outside the calling
project containing the actual argument vector (exactly `--host`), the actual working directory (the scratch
calling project) and a distinguishable recorder exit status that the CLI returns. A missing, incomplete,
duplicate or mismatched record, an early return without handoff, a timeout, an unexpected status or a
changed fingerprint MUST NOT pass. The replacement SHALL count its one executed verdict, not claim the
old attempt ran or add an alternate execution or skip.

This check observes the handoff and the six faces for that one invocation, as required for the applicable
effect by `help-surface#Every behaviour a help page states is declared and probed`. It SHALL NOT run the
real performance program, invent readings, or claim that the real measurement's setup and execution are
covered by the calling-project observations. The existing independent real measurement remains unchanged
under `verification#The performance suite is separate, self-describing, and its numbers are reference-only`;
it does not establish the dropped observation about the real measurement's effect on the calling project.
`team smoke --select 0`, all other help claims and formal timeout settings SHALL remain unchanged.
One non-author verification SHALL record the normal sample and two faults below without an author repeat
or another run of the real measurement. The replaced attempt is source-attributed; no historical per-call
duration, fixed time saving or whole-suite result SHALL be inferred from the focused samples.

#### Scenario: The release export skips only unavailable internal checks

- **GIVEN** a clean product-only tree exported from committed HEAD by `bash docs/team/tools/publish-public.sh`, with the gate's required tools available
- **WHEN** `openspec validate --all --strict && TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` runs there
- **THEN** it exits 0 with no failing assertions, missing internal prerequisites are named on counted `SKIP（条件不满足）` lines, and all FAST-eligible product sections execute
- **AND** the section counts sum to the run totals and no skipped prerequisite is counted as a pass

#### Scenario: A public checkout still exercises the product checks and their negative controls

- **GIVEN** the same exported tree, then independent scratch copies with a missing product literal `skills/teamsmith/tests/skill-load.mjs` and with CJK prose injected into `skills/teamsmith/references/protocol.md`
- **WHEN** the first copy runs `bash skills/teamsmith/tests/section-select.sh --check` and the second runs the gate's English-prose check
- **THEN** both fail and name the damaged product path, despite their other internal prerequisites being skipped
- **AND** the unmodified export executes skill loading, reference scanning, installer tests, five-phase product-document contract checks and their sandbox negative controls, rather than skipping §18, §19 or §36 wholesale

#### Scenario: A sibling file's wrapper does not certify a planted product mutation

- **GIVEN** a product-only scratch tree (whose sibling fixture `smoke.sh` defines the same-named `tmux()` wrapper) with a bare `tmux kill-server` appended to a product file (`skills/teamsmith/tests/tmp-hygiene.sh`), a second copy of that tree whose lint has the same-directory rule restored, and a third copy where the same call is instead exempted through the lint's own frozen-hash exemption list
- **WHEN** §31's tmux-isolation lint runs in each tree (the internal-only exemption list attributed as a prerequisite skip in the first)
- **THEN** the first tree is red and names the planted file — a wrapper defined in another file is not evidence of isolation for that call — and the second and third trees are green, so the red judgment is demonstrably attached to §31's lint verdict and to the attribution rule itself rather than to an unrelated failure
- **AND** the unmodified product-only tree keeps the lint's green verdict, so the product check is not made red unconditionally

#### Scenario: The signal lint's frozen ledger is an internal prerequisite, not a product one

- **GIVEN** a product-only scratch tree whose P159 signal lint carries its frozen exemption ledger for `docs/team/reports/**`, a copy whose ledger also names an absent product file (`skills/teamsmith/scripts/p176-no-such-product-file.sh`), and a third copy whose per-entry attribution is relaxed so that any absent ledger entry is skipped
- **WHEN** §58's signal-discipline lint runs in each tree (the internal-only ledger attributed as a prerequisite skip in the first)
- **THEN** the first tree exits 0 with the ledger's absence printed as a counted `SKIP（条件不满足）` naming `docs/team/reports/**` while the lint's own verdict still executes, the second is red and names the missing product path, and the third is green — the skip is attributed to the internal surface, not to absence as such
- **AND** a name-selected signal call planted in a product file still makes the same check red in the product-only tree, so attributing the ledger as a prerequisite does not disarm the lint

#### Scenario: The internal checkout loses no existing coverage

- **GIVEN** pre-change and post-change independent internal checkouts with identical tools and FAST settings
- **WHEN** `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` runs in each
- **THEN** every pre-existing assertion outside the three named route-page replacements, the identified reply-observer retired executions, the named routing-argv retired executions, the routing-parameter retired executions, the explicit selected-settings display inventory and the single perf help claim replacement is present in the post-change executed assertion inventory with its original verdict, each unaffected section's pass count is at least its baseline, and no new checkout-prerequisite skip appears
- **AND** this FAST run does not produce the route-page replacement evidence; that separate source-attributed baseline, retained non-FAST record/manual undeclared-usage receipt and explicit non-FAST `routes.sh pages` inventory are judged by the named scenario below, without relaxing any retained assertion or count obligation
- **AND** reply-observer replacement evidence comes from its focused absence sample and normal §62 run, with only the named duplicate executions retired and with parent/child counts kept separate
- **AND** evidence for the preceding routing-argv replacement batch comes from its short actual-shell samples and its already accepted final complete 61b integration run, with only that batch's named repeats retired; its first CORE's normal real callers remain exercised and no first-order speedup is inferred. A later routing-parameter batch supplies its newly affected evidence under the scenarios below and cites that accepted record for unchanged coverage, not a new complete 61b run
- **AND** the selected-settings batch excludes only its named obsolete display inventory, retains the required behavior through its mapped focused UI/flip evidence and unchanged-coverage sources, and does not pad replacement passes or require another FAST/full run as payment for that narrow exception
- **AND** the perf help claim exception excludes just the old bounded `perf` assertion from comparison; its replacement is judged by the three focused samples below, with neither another complete run nor a fabricated old pass
- **AND** a scratch mutation that replaces any retained internal assertion with a prerequisite skip still fails the inventory/count comparison, even if new assertions keep the aggregate pass total unchanged

#### Scenario: Partial internal trees and broken installs remain red

- **GIVEN** scratch internal trees with, respectively, `SCOPE.md` removed, one `opsx-apply.md` removed, one phase `SKILL.md` removed, or the archive directory removed while other internal surfaces remain
- **WHEN** their relevant smoke assertions and `section-select.sh --check` run
- **THEN** each damaged tree exits non-zero and names the missing path, not a product-checkout skip
- **AND** creating an empty internal directory in an otherwise product-only scratch checkout cannot turn its missing required files into successful assertions or absence-based skips

#### Scenario: A synthetic ledger does not change the subject's classification

- **GIVEN** a product-only checkout invoked with inherited `TEAM_ROOT`/`TEAM_MAIN_ROOT` pointing at an internal checkout
- **WHEN** its smoke gate runs and `team init` creates ledger and OpenSpec data in the gate's private fixture repository
- **THEN** the source checkout still gets the same prerequisite skips as without those inherited variables, while the fixture's ledger-dependent CLI assertions actually execute

#### Scenario: A real failure is not hidden by prerequisite skips

- **GIVEN** an exported scratch checkout with a failing product assertion and deliberately absent internal prerequisites
- **WHEN** the correctness gate runs
- **THEN** its summary carries both failure and skip counts, the failure names its assertion, and the gate exits non-zero

#### Scenario: Missing tooling is not attributed to the checkout shape

- **GIVEN** a product-only scratch checkout with `perl` unavailable
- **WHEN** its English-prose check runs
- **THEN** it retains the existing missing-perl failure and does not relabel it an internal-file prerequisite skip

#### Scenario: The public workflow remains a blocking correctness check

- **WHEN** `.github/workflows/gates.yml` is read and its correctness container command is run on an independent product-only checkout
- **THEN** the command is `openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh --floor --keep </dev/null --paths "$@"` with the changed paths as its own arguments, without FAST or correctness `continue-on-error`, and it succeeds when all applicable checks succeed
- **AND** a failing applicable product assertion makes that same command fail; performance remains a separate non-blocking conclusion
- **AND** a changed-path list naming a fixture meta-mutation's own sources adds that self-check, one naming only product routing sources adds §61 and not the matrix, and the same command with no resolvable base runs the full suite instead of a narrower selection

#### Scenario: Route-page replacement evidence does not manufacture the old pass total

- **GIVEN** pre-change source identities/counts for all three old parent controls, a retained non-FAST 51m
  record and one actual undeclared-usage receipt without test-source edits, followed by the candidate's explicit
  non-FAST `routes.sh pages` run and identical-setting normal real-walk inventories before/after extraction
- **WHEN** the delivery evidence is read
- **THEN** ④/⑬ are marked source-attributed and not rerun; each replacement has a successful named `替代④`,
  `替代⑪` or `替代⑬` result grounded in its intended-rule finding and no-finding normal/restored result;
  both damaged-renderer experiments retain rc=0/nonempty outputs and unmutated-tree normal renderers
- **AND** actual routes `✓/✗` totals and per-case outcomes retain their execution scope and provenance;
  smoke's one-pass section total, FAST output or nested log counts cannot substitute or pad them. Unchanged
  real-walk assertions/counts are retained; any changed sample total is explained only by this exact mapping,
  and the partial old baseline is not reported as three measured runs or an elapsed saving

#### Scenario: The named replacement cannot hide a lost CLI or renderer assertion

- **GIVEN** delivery evidence that substitutes hand-written files for a required damaged-renderer experiment,
  accepts only the special-literal diagnosis instead of the required multiset difference, omits a retained real
  CLI claim, counts FAST/smoke output as the sample evidence, or labels a retired nested walk as an executed pass
- **WHEN** that evidence is compared with the named replacement scope and executed assertion inventory
- **THEN** it fails the coverage comparison even if the reported total equals or exceeds the baseline;
  only the three specified route-page complete-walk replacements, the separately named reply-observer retirement, the routing-argv retirement, the routing-parameter retirement, the selected-settings display replacement inventory and the single perf help claim replacement specified above are allowed

#### Scenario: Routing argv replacements detect the original resplitting errors

- **GIVEN** healthy private source copies and copies carrying the original `worker-literal-resplit` or
  `pm-literal-resplit` mutation, legal fixed model policy and PM continuation metadata
- **WHEN** their replacement samples form arguments through the product command renderer and real Bash
- **THEN** healthy samples exit 0 with one complete provider/model and the fixed literal extra values
  `two words`, `--mod*`, `{safe,words}`, `~/routing-note` and a literal backslash value;
  PM continuation delivers the single session value `fixture-literal-session`
- **AND** the original worker mutation exits 1 naming `worker-expansion-literal-argv:extra`, and the
  original PM mutation exits 1 naming both `pm-expansion-literal-argv:extra` and
  `pm-resume-literal-argv:builtin`; PM continuation actually uses the explicit resume-arguments path,
  not a fresh launch or a higher-priority session-id path that bypasses the mutation
- **AND** PM identity validation is real and succeeds on these legal premises; a renderer/setup failure,
  a tokenizer self-comparison or hand-authored argv cannot substitute for that red side

#### Scenario: Routing restoration observes the same mutated copy

- **GIVEN** each of the two changed arms has passed its short healthy check on its own disposable copy
- **WHEN** the original mutation fails that check, its changed script bytes are restored on that same copy,
  and the identical short check is run there again
- **THEN** both the restored script-byte comparison and the short behavioural check pass with exit 0,
  without substituting the original tree or running complete boundary/CORE for that restoration
- **AND** the other mutation arms retain their existing actual restoration obligations, without claiming
  that an unmutated-tree run proves every other copy's behaviour was restored

#### Scenario: Routing short outcomes reach the existing flip parent

- **GIVEN** a disposable run through the existing flip parent for the two changed arms
- **WHEN** a short child has an unexpected exit code, lacks its required intended-failure name, or fails its
  healthy/restored check
- **THEN** the parent emits the corresponding named `FAIL flip-...`, increments its own failure total and
  exits non-zero; timeout/setup errors are not accepted as the intended mutation red
- **AND** with original healthy/mutated/restored outcomes the same parent accepts both arms; a bounded
  parent-wiring sample is labelled as such, never as a complete matrix run

#### Scenario: Only the two routing boundary repeats and original-tree second CORE retire

- **WHEN** the preceding routing-argv batch's source-attributed old execution inventory and its accepted candidate's complete 61b log are compared
- **THEN** the old final unmutated-tree CORE and its success assertion are absent, the first normal CORE
  remains complete, the two resplit arms use their short samples, and the other 29 arms retain their
  original groups, assertions and verdicts except for the five routing-parameter replacements specified below
- **AND** the two replacements no longer execute the seven unrelated boundary subfixtures or their PM
  transaction tail, while the original normal real-call coverage remains in the first CORE; no retired
  full execution is moved to a slow/optional entry, counted as passed or relabelled as a prerequisite skip
- **AND** that completed batch's accepted log remains the evidence for these retirements; later routing-parameter
  changes obtain their affected evidence below and reuse unchanged facts, without supplying another complete 61b log

#### Scenario: Routing evidence reports actual scope instead of padding totals

- **WHEN** delivery and independent verification evidence for the preceding routing-argv replacement batch are read
- **THEN** old normal-tree, old boundary-child, new short-child and flip-parent inventories/counters remain
  separately attributed; only the removed final parent success and actually executed new parent checks
  explain that parent's count difference
- **AND** that routing-argv batch's final non-FAST complete 61b integration run supplies its first normal CORE
  and all retained mutation evidence; its already accepted record satisfies that batch's completed obligation.
  Later routing-parameter replacements supply only their affected evidence below and cite the accepted record
  for unchanged facts, without repeating complete 61b; short samples do not claim that complete run, full smoke,
  or faster normal §61
- **AND** historical costs and new elapsed readings remain references, not correctness thresholds or a
  claim that old retired seconds equal net savings
#### Scenario: Normal parameter rules do not replay every CLI permutation

- **GIVEN** a private legal routing fixture with fixed expected parameter outcomes
- **WHEN** normal boundary verification executes its shared parameter assertions and retained real callers
- **THEN** separate/equals/short/attached selectors, placeholder binding, tool scalar and argv-list roles,
  literal versus shell expansion, extra ownership and PM resume ownership are judged against independent expectations
- **AND** hard-coded and unbound identity, selectors consumed by tool data, unquoted model globs in both
  template/extra callers, and malformed PM continuation retain one named real-launch refusal per selected tag;
  the existing PM fresh hard-coded-provider template additionally exercises PM's separate preview entry.
  No rule multiplies all tags by preview/launch, and this arrangement is not a permanent invocation/pass quota
- **AND** the worker/PM argv-list witnesses use the existing unknown-before-model/resume inputs: standalone
  extra `--unknown harmless` is acceptable, but the surrounding template rejects unknown arity before a protected
  model or resume group with the intended role diagnostic; an earlier standalone missing-tool-value refusal
  cannot satisfy those witnesses
- **AND** each retained refusal requires the intended diagnostic, no new argv and unchanged observable project state
- **AND** removed per-string CLI attempts and their captures are absent, not counted as successful or skipped

#### Scenario: Five original parameter faults still fail shared assertions

- **GIVEN** five private copies with each original product mutation and unchanged test assertions
- **WHEN** the same direct parameter selection used by normal boundary verification runs on each copy
- **THEN** every child exits 1 with its required rule failures: extra model ownership; worker and PM hard-coded
  identity; worker positional/data identity and PM fresh/continued unbound identity; worker/PM tool-role and
  PM resume-role consumption; and worker/PM template plus shared-extra unquoted model-glob refusal, respectively
- **AND** no complete boundary, metadata matrix or launch transaction supplies that red; healthy and
  byte-restored executions on each same copy exit 0 with the original fixed expectations

#### Scenario: Correct helpers cannot hide a disconnected real caller

- **GIVEN** a private candidate whose direct parameter selection passes, and disposable copies bypassing
  only the relevant worker early-refusal boundary, worker final-renderer, PM real-up early-refusal boundary
  or PM final-renderer checks
- **WHEN** retained real-call refusal witnesses and direct product launch-renderer refusal witnesses run
- **THEN** a lost early refusal fails the diagnostic/purity observation even if a later check refuses,
  and a lost final-renderer refusal fails its own witness despite correct helpers
- **AND** with a stopped PM and legal policy, the real-up sample bypasses both identity checks before prompt
  creation together, retaining real
  guard functions and the final renderer, and observes prompt/diagnostic changes with the existing bad custom
  template through real up; it does not add a second direct-start experiment
- **AND** removing one redundant check while another preserves the same early refusal is not falsely
  required to fail; the observation concerns the effective caller boundary, not textual call presence
- **AND** caller wiring is not certified by a replacement helper, a success stub or self-comparison of product tokens

#### Scenario: Actual wrong-model and lost-binding observations remain grounded

- **GIVEN** the normal private recording CLI and cwd decoy `--model=wrong:low`
- **WHEN** retained legal worker/PM template and builtin launches and PM explicit continuation execute
- **THEN** real Bash argv preserves quoted spaces, wildcard/brace/tilde/backslash data, unique selected
  provider/model and worker SID or PM explicit continuation value; assignment/PM records agree with delivered identity
- **AND** continued/fresh controls, trusted/untrusted PM metadata and publication-failure rollback remain
  actual interface/state/process checks, not direct parameter-return assertions

#### Scenario: Parameter failures reach the real parent verdict

- **GIVEN** the existing flip parent's actual result-consumption path for these five arms
- **WHEN** a child unexpectedly exits 0, times out, has a setup error or lacks a required rule failure,
  or its healthy/restored result fails
- **THEN** the parent emits a named failure, increases its own failure count and exits non-zero
- **AND** restoring the real outcomes restores parent success; a bounded parent sample proves only this
  consumption path, not execution of the complete mutation matrix

#### Scenario: Only this batch's repeated executions and incidental observations retire

- **WHEN** source-attributed old and candidate execution inventories are reconciled with focused verification
- **THEN** normal boundary replaces the old potential 562 negative CLI attempts, conditional on writer
  acceptance, with the design's named real witnesses and shared direct assertions; each of the five arms has
  no complete boundary call, while other arms/groups and normal legal/transaction checks remain
- **AND** retirement of per-attempt captures and unrelated observations on the five mutant trees is explicit,
  not described as equivalent preservation of every old assertion or as a fixed number of seconds saved
- **AND** author static evidence, non-author executed results and post-merge byte checks are distinguished;
  focused evidence cannot be presented as a complete normal suite, complete 61b or measured §61 speedup

#### Scenario: The perf help claim observes a handoff, not a measurement

- **GIVEN** the existing initialized scratch calling project and a private entry source with its measurement target replaced by a short recorder
- **WHEN** the focused help claim invokes `team perf --host` from that project
- **THEN** one receipt records exactly one argument, `--host`, the actual scratch project's working directory and the recorder's expected nonzero status, which the CLI returns
- **AND** the six fingerprints are unchanged, the help claim passes by naming the handoff and unchanged project, and no measurement is run or printed

#### Scenario: The perf help claim rejects a success that never hands off

- **GIVEN** a disposable copy of the same entry source whose `perf` route returns 0 before invoking the target without changing the calling project
- **WHEN** the same focused help claim runs
- **THEN** the help fixture exits nonzero and names the missing `perf` handoff; unchanged project fingerprints and CLI exit 0 do not make it pass

#### Scenario: The perf help claim rejects a handoff that changes the calling project

- **GIVEN** another disposable copy whose `perf` route writes a state file in the scratch calling project before invoking the same recorder
- **WHEN** the same focused help claim runs
- **THEN** the receipt and CLI status still establish a valid handoff, but the help fixture exits nonzero and names the calling project's changed state face
