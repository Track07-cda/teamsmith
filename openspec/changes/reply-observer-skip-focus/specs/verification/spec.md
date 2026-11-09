## MODIFIED Requirements

### Requirement: A gate that cannot judge says so

The correctness gate SHALL distinguish a product-only checkout, which deliberately contains the published product and `openspec/specs/` but none of this development repository's internal surfaces (`docs/team/`, `openspec/changes/`, `AGENTS.md`, `SCOPE.md`, `.pi/prompts/`, `.pi/skills/`), from an internal or partially populated checkout. Classification MUST inspect the checkout under test before creating fixture data; inherited project identity, CI environment, and a fixture-created ledger MUST NOT decide it. An empty, unreadable, malformed or partially populated internal surface MUST NOT be treated as absent. No production environment override SHALL turn a missing product or internal-checkout file into a prerequisite skip.

Only a check whose named prerequisite is one of those deliberately absent internal surfaces SHALL skip on a product-only checkout. Each such attribution MUST print `SKIP（条件不满足）`, the affected check and missing prerequisite, be counted as a skip rather than a pass, and reach the gate's output and per-section/run accounting. Missing product files, unavailable required tools, a failed executed assertion, and corruption of a present internal surface MUST retain their existing failure/degradation rules; the checkout classification MUST NOT swallow them. An executed check's verdict MUST rest on evidence the subject itself carries: when the call's command word is the wrapped command itself (`tmux`), an isolation wrapper defined in one file MUST NOT certify a mutation call made by another file, while a dedicated wrapper name defined alongside the caller MAY keep its directory-level meaning; a check MUST NOT be reported as satisfied on evidence the subject does not have. A run with prerequisite skips and no failures SHALL exit 0, without claiming the skipped checks passed; a real failure alongside skips MUST still exit non-zero.

The same correctness command SHALL run on both shapes, with no second public suite. The product's static checks, skill loading, published-spec validation, container-build checks and every ledger-independent fixture MUST remain eligible exactly as before (including the existing FAST/full and tool-premise rules). A fixture that provisions its own ledger MUST still run in the product-only checkout. For an internal checkout, except for the three route-page control replacements and the reply-observer duplicate-execution retirement specified below, every pre-existing assertion MUST still execute with its original verdict and at least its pre-change per-section pass count under identical run settings; replacing an existing assertion with a new one MUST NOT satisfy that coverage comparison. CI's correctness step MUST retain its blocking failure semantics, and it SHALL run the product floor the way `verification#CI runs the two gates separately and performance does not block` states: a failing applicable product assertion in that step fails the job, and the selection it makes is disclosed in the output tail rather than presented as the full gate.

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
- **THEN** every pre-existing assertion outside the three named route-page replacements and the identified reply-observer retired executions is present in the post-change executed assertion inventory with its original verdict, each unaffected section's pass count is at least its baseline, and no new checkout-prerequisite skip appears
- **AND** this FAST run does not produce the route-page replacement evidence; that separate source-attributed baseline, retained non-FAST record/manual undeclared-usage receipt and explicit non-FAST `routes.sh pages` inventory are judged by the named scenario below, without relaxing any retained assertion or count obligation
- **AND** reply-observer replacement evidence comes from its focused absence sample and normal §62 run, with only the named duplicate executions retired and with parent/child counts kept separate
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
  only the three specified route-page complete-walk replacements and the separately named reply-observer retirement are allowed

## ADDED Requirements

### Requirement: Reply observer absence is proved without replaying unrelated checks

The reply fixture SHALL prove observer absence through the same diagnostic, bounded-observation, full_scan and result-consumption paths used normally. It MUST replace the complete forced-absence bounded/flip replay and failure trace replay with a focused sample. The sample MUST require named absence evidence and completion status, not a total SKIP threshold, and its failures MUST reach the invoking fixture's non-zero exit.

#### Scenario: A focused sample actually takes the normal absence paths
- **GIVEN** the existing test-only observer-absence input makes the real process-I/O capability check unavailable
- **WHEN** the focused sample invokes the normal driver notice, bounded-observation entry and full_scan probe with its normal skip-result consumer
- **THEN** its output names all three facts: unavailable `/proc/<pid>/io` with the reason, skipped bounded read-volume assertions with the reason, and skipped `flip/full_scan` with the reason and no conclusion
- **AND** those paths run before observer-specific large-store preparation, without executing the complete bounded/flip groups, unrelated mutations, or a second trace run
- **AND** the sample uses its own result-line identity, never the parent's `== P234 key-replies 结果 ==` prefix; smoke's parent-summary reader still selects only the real parent result

#### Scenario: Observer-specific preparation is absent, not merely unused
- **GIVEN** the absence sample's own empty projects and private temporary root contain no reply indexes
- **WHEN** the bounded observation entry and full_scan probe return, before any sample cleanup
- **THEN** neither project's `.pi/team/state/key-replies/index.v1` exists and no second prepared index exists elsewhere in that owned root, including a 60-slot or 100000-slot store
- **AND** a subshell control that moves capability handling after preparation is rejected for the unexpected index and its restoration is accepted; a tiny real index suffices for this damaged-order control, while the healthy sample calls the real unoverridden functions

#### Scenario: Skipped observations remain distinct from passed or failed observations
- **WHEN** that unmodified focused sample completes
- **THEN** it has exactly two skipped observation identities, bounded read-volume and full_scan, neither earns a pass or product failure, and its real process exits 0 with a complete zero-failure result
- **AND** the driver's capability notice is not a third skipped observation, the bounded prediction of a later full_scan skip is absent, and the enclosing fixture reports verification of that classification rather than successful read-volume measurement

#### Scenario: Unrelated skips cannot substitute for a missing diagnosis
- **GIVEN** subshell-only function overrides remove respectively the driver, bounded, or full_scan absence diagnosis, including a variant that emits unrelated skips instead
- **WHEN** the same short sample and its normal evidence judgement run for each mutation and restoration
- **THEN** every mutated case is rejected naming the missing fact even if total SKIP is three or more, and each restoration is accepted
- **AND** matching a phrase in a hand-authored expected log cannot satisfy the judgement; each negative control calls only the sample collector and shared judgement in its subshell, never launches `--select skip-path` or recursively enters the group, and the healthy/restored sample uses the real functions

#### Scenario: A missing observer cannot earn a success
- **GIVEN** subshell-only function overrides respectively turn bounded absence and full_scan absence into successful observation results
- **WHEN** the same short sample and evidence judgement run for each mutation and restoration
- **THEN** each mutated case is rejected for its wrong result classification, even if the capability notice remains, and each restoration is accepted
- **AND** no normal success line or increment can count the unobserved read bound as verified

#### Scenario: A missing observer cannot become a product failure
- **GIVEN** subshell-only function overrides respectively turn bounded absence and full_scan absence into a failing result
- **WHEN** the same short sample and evidence judgement run for each mutation and restoration
- **THEN** the unmodified requirement for non-failing absence rejects both mutations and accepts each restoration
- **AND** a real unrelated product failure still retains its existing failing status; absence handling does not convert failures to skips

#### Scenario: The actual caller cannot discard an observation outcome
- **GIVEN** an external one-off scratch copy with broken shared bounded or full_scan absence handling and a second copy with that same damage which also discards the failed sample judgement
- **WHEN** each copy is invoked once through the existing `key-replies.sh --select skip-path` entry, without an internal negative control relaunching that entry
- **THEN** the first parent exits 1 and its ordinary sample-consumption branch emits a named `✗ skip-path` assertion identifying the missing diagnosis or wrong classification; the discard copy still exits 1 from negative controls' failed restoration sides but that specific parent assertion is absent, and internal controls cannot emit that parent-only assertion
- **AND** restoration completes successfully; non-zero exit alone, or a helper-only red result, cannot prove parent consumption

#### Scenario: Normal coverage stays in the ordinary reply section
- **GIVEN** an available process-I/O observer and the normal reply section selection
- **WHEN** §62 invokes the reply fixture's ordinary all-groups entry once
- **THEN** normal bounded checks and the nine original bad-source/restored-source mutation controls run once each, including real kernel full_scan evidence, while only the focused sample simulates observer absence
- **AND** real storage, concurrency, receipts, interruption, paging, FIFO, permissions, read-only behavior, Pi capture and UI coverage retain their existing locations and verdicts; none is transferred to a nightly or alternative mode

#### Scenario: Accounting retires only the identified repeat
- **WHEN** the before/after execution inventories and parent/child summaries for the affected reply fixture are compared under identical settings
- **THEN** the only retired whole-group runs are the forced-absence bounded/flip replay and its failure-only trace replay, alongside the replaced skip-path checks and redundant predictive notice; all normal assertions remain
- **AND** the focused child's two skipped observations are not counted as product successes or merged twice into parent totals, new negative controls are identified as such, and no fixed global pass total or elapsed-time saving is claimed
- **AND** PM-only trial integration of the two complete verification modifications in route-page-then-reply order preserves both reply retirement exceptions once each; reverse-order copies lose both exceptions even though the added reply requirement remains, so checking only the added requirement is insufficient
