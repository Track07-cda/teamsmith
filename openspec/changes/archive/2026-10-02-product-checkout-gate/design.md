## Context

See proposal.md for motivation and `specs/verification/spec.md` for the contract. This is one planning-only task; none of the implementation described below has landed.

At P146's starting revision `603a4e8e`, the public allowlist is `skills bin install.sh openspec/specs README.md LICENSE package.json .gitignore ci .github`. The generator bans `docs/team`, `.pi`, and `.worktrees`; it also does not export `AGENTS.md`, `SCOPE.md` or `openspec/changes`. `release-check.sh --with-gates` exports committed HEAD, initializes an independent git repository in that export and runs FAST there. CI instead runs the full correctness suite in its pinned image, with a read-only checkout.

The pure-file P146 probes (no tmux, no smoke run) found:

| Probe | Internal tree | Public export |
|---|---|---|
| `section-select.sh --check` | exit 0, `ok 7 bad 0`, 115 rows, 101 needs edges, 481 literals | exit 1, `ok 6 bad 6`; table/needs/token coverage still execute |
| Missing public literals | none | row 2 `AGENTS.md`; rows 17/18 `SCOPE.md`; row 19 `.pi/skills`; row 20 `openspec/changes/archive`; row 12k `AGENTS.md` |

These paths do not include `docs/team/**`: those paths are already the selector's exempt class. Six literal failures cause three enclosing §36 assertions to fail (real tree, unchanged table copy, clean token-variant tree). Do not exempt the entire selector or remove these table patterns.

The PM's recorded FAST totals are public **✓3141 ✗16** and internal **✓3156 ✗0**. The brief itemizes only 14 failures (3 + 1 + 5 + 5), and the current source's phase assertions are in §19, not §18. P146 has not rerun FAST and does not invent identities for the other two. Apply starts with a fresh, same-revision baseline and records all failing assertion labels before changing code. No unclassified failure may be relabeled a prerequisite skip merely to reach zero.

## Goals / Non-Goals

**Goals:** implement the delta with a single gate, local prerequisite attribution, unchanged internal coverage, and independently falsifiable public coverage.

**Non-Goals:** change the published payload, generate Pi files during a gate run, relax missing-tool policy, modify runtime behavior, sanitize public specs (the separate public-spec work owns that), or alter CI triggers/failure tolerance. P146 may write only its change and its own report/evidence. The later implementer needs an explicit grant for test sources; neither proposer nor verifier implements.

## Decisions

### 1. Choose A and keep the publication boundary

A keeps the export/scan rules unchanged and makes unavailable checks honest. B would add ten generic generated planning files, but requires exceptions to both the `.pi` directory ban and release checks, adds tool/version maintenance to the payload, and still needs A for `SCOPE.md` and selector checks. That is greater scope for no additional product-behavior coverage. The price of A is visible skips for this development repository's planning install. Product fixtures, including initialization of a user's project, still test the shipped mechanism.

### 2. Recognize the source checkout conservatively

Use one small pure-file prerequisite helper shared by smoke and the selector, under `skills/teamsmith/tests/lib/`. Resolve the source root from the test script (honor the selector's existing explicit `--root`); do not consult `TEAM_ROOT`, a git common/main worktree, the CI provider or a runtime fixture's `$REPO`.

Snapshot the shape before smoke's fixture setup. The narrow product-only shape has published `skills/` and `openspec/specs/` in place and **all six** named internal surfaces absent: `docs/team/`, `openspec/changes/`, `AGENTS.md`, `SCOPE.md`, `.pi/prompts/`, `.pi/skills/`. Here absent means no filesystem entry, not merely a failed `-d` or `-f` test: an empty directory, broken symlink, unreadable file or wrong type is evidence of a present/broken surface, not permission to skip. Any mixed shape is conservatively internal/partial. Removing just `docs/team` or just `openspec/changes` cannot switch off the rest of an internal gate.

This conjunction intentionally protects damaged internal installs. A contributor adding development scaffolding to a public checkout has made a mixed/development checkout and must provision that scaffolding consistently; this proposal does not add a public-mode override. Product completeness itself stays with the existing product checks; the shape predicate is not a replacement integrity scan.

### 3. Attribute only the specific file-existence assertion

For §18, attribute the source `SCOPE.md` presence assertion only. Continue scanning both product reference directories, exercise the installer, and keep all sandbox prose/code negative controls. The sandbox's SCOPE injection creates its own file and remains valid even without a source SCOPE file; do not skip that self-test or its file:line check.

For §19, attribute the ten source Pi phase-file presence assertions, one check/path per attribution. Continue the five-phase product-doc/template checker and every sandbox corruption flip. Do not gate the whole section on `.pi` presence.

For `--check`, allow only the exact known prerequisite literals observed above (`AGENTS.md`, `SCOPE.md`, `.pi/skills`, `openspec/changes/archive`) under the product-only predicate. This is an existence exception, not a path-selection exemption. Unknown spellings and arbitrary paths under `openspec/changes` or `.pi` stay red. Row uniqueness, section coverage, needs order, token coverage, prologue and exempt-class policing remain unconditional. Keep missing-row, narrow-pattern, unknown-needs, claimed-exempt, missing-product-literal and undeclared-token flips alive on both shapes.

If implementation adds the helper/fixture, update only the necessary path-map claims so the existing token and copy guards still judge them. Do not remove internal patterns, change the exempt class, weaken match semantics or rewrite unrelated table rows.

### 4. Preserve skip attribution through subprocess boundaries

Use the gate's existing skip counter/section accounting rather than counting a skip with `ok()`. The selector prints a distinct skip count in its check summary and per-row/path attribution; it exits 0 if all executed integrity checks succeed and unavailable internal existence checks are its only gaps.

§36 currently captures selector output into logs. Relay each captured prerequisite attribution through the smoke skip outlet, so it appears in output and the section's/run's skip counts. An enclosing assertion may still judge the executed selector integrity checks (and a corrupted table must fail), but its successful exit is never described as proof that omitted files existed. Nested captures must not lose reasons or counts; repeated invocations must be accounted consistently and summed, not silently discarded.

Do not make existing FAST/full/selection/timeout outcomes depend on checkout shape. In particular, a genuine product failure alongside a prerequisite skip must survive and force non-zero exit.

### 5. Compare the two shapes section by section

The following is an expected transition table, not an executed post-change result. Apply/verify replace it with actual counts and labels from the same tools/revision lineage.

| Section/check | Public before | Public after A | Internal after A |
|---|---|---|---|
| §36, three clean-selector wrapper assertions | 3 red from missing internal literals | selector integrity executes; internal existence checks visibly SKIP and are relayed/countable; wrapper judges executed integrity | existing checks run with unchanged semantics |
| §18 source `SCOPE.md` existence | 1 red | 1 prerequisite SKIP | existing presence assertion executes |
| §18 reference prose, installer, all sandbox flips (including sandbox SCOPE) | execute | still execute, same assertions | unchanged |
| §19 source `opsx-*` phase files | 5 red | 5 individually named prerequisite SKIPs | all five execute |
| §19 source phase skills | 5 red | 5 individually named prerequisite SKIPs | all five execute |
| §19 product pipeline/template contract and flips | execute | still execute | unchanged |
| Remaining two reds in the PM total | labels not supplied | classify from baseline evidence; true product failures remain failures | no speculative coverage cuts |
| §0b skill loading; §0c/0d static/conflict checks; §2 init; §3b PM-owned git; §31 container checks; other product fixtures | FAST-eligible checks execute; existing non-FAST skips apply | same eligibility; no new checkout skip | existing section pass counts must not decrease |
| `openspec validate --all --strict` | validates published specs | validates published specs, never skipped | validates specs and changes |
| Full-only runtime fixtures / CI | not proved by PM's FAST sample | run in full gate, never suppressed merely for lacking a source ledger | unchanged |

Do not pin the future aggregate pass total to 3156: the apply baseline may have gained unrelated assertions and new guards add assertions. Require `post-existing-assertions ⊇ pre-existing-assertions` and, for every old section, `post ✓ ≥ pre ✓`, with zero new checkout skips internally. Aggregate counts alone are insufficient.

## Verification plan and acceptance commands

### Planning acceptance (P146)

```bash
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
PATH="$HOME/.bun/bin:$PATH" openspec status --change product-checkout-gate
```

The local CLI exists under `~/.bun/bin`, which is absent from this session's initial PATH. That PATH adjustment is not an install or a project modification.

### Implementation acceptance, disposable containers only

Run each long command through `team_bg_run` and harvest it; run one suite at a time. These one-liners use the existing full gate image `localhost/teamsmith-gate:local`, not the minimal Alpine tmux image. They mount a standalone clone rather than a worktree whose git pointer escapes the mount. No host tmux socket, host HOME or Pi session store is mounted, and inherited `TEAM_*` identities are not injected. The pinned image supplies the gate tools; its version/revision must be recorded. `--pid=host` matches the existing CI's SIGTTIN fixture; fixture signals remain limited to recorded spawned PIDs.

Internal FAST (committed current HEAD; retained output can be redirected into the apply report):

```bash
D=$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-p146-internal.XXXXXX") && git clone -q --no-local "$PWD" "$D/tree" && git -C "$D/tree" checkout -q --detach "$(git rev-parse HEAD)" && distrobox-host-exec podman run --rm --pid=host --userns=keep-id -e HOME=/tmp -v "$D/tree:/work:ro" -w /work localhost/teamsmith-gate:local bash -c 'openspec validate --all --strict && TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null'; RC=$?; [ -z "${D:-}" ] || rm -rf "$D"; (exit "$RC")
```

The existing release-check command, including the public FAST run (writable disposable clone, never this worktree):

```bash
D=$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-p146-release.XXXXXX") && git clone -q --no-local "$PWD" "$D/tree" && git -C "$D/tree" checkout -q --detach "$(git rev-parse HEAD)" && distrobox-host-exec podman run --rm --pid=host --userns=keep-id -e HOME=/tmp -v "$D/tree:/work" -w /work localhost/teamsmith-gate:local bash -c 'bash docs/team/tools/release-check.sh --with-gates'; RC=$?; [ -z "${D:-}" ] || rm -rf "$D"; (exit "$RC")
```

The release-check also judges tags/packaging, not just this defect. Separate any version/tag failure from the public gate's outcome; do not fabricate an overall release pass. Because it only reports the public gate's tail, use the following explicit export/full command for retained per-section CI-equivalent evidence:

```bash
D=$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-p146-public.XXXXXX") && bash docs/team/tools/publish-public.sh --out "$D/tree" && git -C "$D/tree" init -q -b main && git -C "$D/tree" add -A && git -C "$D/tree" -c user.email=fixture@example.invalid -c user.name=fixture commit -q -m 'public gate fixture' && distrobox-host-exec podman run --rm --pid=host --userns=keep-id -e HOME=/tmp -v "$D/tree:/work:ro" -w /work localhost/teamsmith-gate:local bash -c 'openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh --keep </dev/null'; RC=$?; [ -z "${D:-}" ] || rm -rf "$D"; (exit "$RC")
```

Public FAST with directly retained per-section counts (the full command above is mandatory too; FAST does not prove CI's full-only fixtures):

```bash
D=$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-p146-public-fast.XXXXXX") && bash docs/team/tools/publish-public.sh --out "$D/tree" && git -C "$D/tree" init -q -b main && git -C "$D/tree" add -A && git -C "$D/tree" -c user.email=fixture@example.invalid -c user.name=fixture commit -q -m 'public gate fixture' && distrobox-host-exec podman run --rm --pid=host --userns=keep-id -e HOME=/tmp -v "$D/tree:/work:ro" -w /work localhost/teamsmith-gate:local bash -c 'openspec validate --all --strict && TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null'; RC=$?; [ -z "${D:-}" ] || rm -rf "$D"; (exit "$RC")
```

Final internal full gate:

```bash
D=$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-p146-internal-full.XXXXXX") && git clone -q --no-local "$PWD" "$D/tree" && git -C "$D/tree" checkout -q --detach "$(git rev-parse HEAD)" && distrobox-host-exec podman run --rm --pid=host --userns=keep-id -e HOME=/tmp -v "$D/tree:/work:ro" -w /work localhost/teamsmith-gate:local bash -c 'openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null'; RC=$?; [ -z "${D:-}" ] || rm -rf "$D"; (exit "$RC")
```

Pure-file checks may run in this worktree: `bash skills/teamsmith/tests/section-select.sh --check`. Do not trigger remote Actions as a substitute for local evidence.

### What flips (apply and independent verify, not executed during P146)

1. **Public attribution reversal:** in an owned scratch copy, restore the old source-presence assertions/selector literal policy while leaving product checks intact. Public §18/§19/§36 become red again; restore the fix and they execute or explicitly skip as specified. Save commands, labels and exit statuses.
2. **Internal false-skip mutation:** force one old internal presence assertion down the skip branch in a scratch copy. The baseline assertion inventory/per-section comparison must fail. Restore it and the comparison succeeds. Also remove one internal source file while keeping the other surfaces: the real gate must fail, not skip.
3. **Public product damage:** add the existing §36 missing-product-literal mutation; inject prose CJK in a product reference. Both must remain red while prerequisite skips coexist. Reintroducing row corruption, a narrowed pattern, unknown needs, a claimed exempt path or an undeclared product token must likewise fail.
4. **Boundary/inheritance/accounting controls:** exercise product-only, full, and partial/empty/broken-symlink shapes; inherited identity must not change source classification. A fixture-created ledger must not affect it. Selector skips must survive §36's capture, and section counts must sum to totals. Required-perl absence retains its original red.

The new focused coverage may live in a dedicated fixture driven by existing §18/§19/§36. It is a guard fixture, not a second public suite. Its mutation controls use owned scratch copies and recorded child PIDs only. Evidence must distinguish an intentionally red subject run from the passing guard that caught it.

## Risks / Trade-offs

- [A broad absence predicate could excuse deleted internal files] → require the narrow all-surfaces-absent shape and partial-tree red controls; no runtime bypass knob.
- [A successful selector exit could hide skips in a captured log] → relay path/row attributions and count them at the smoke assertion outlet; test the real nested path.
- [New guard assertions could mask lost old coverage] → compare assertion inventory and each section's old counts, not just the grand total.
- [FAST green might be mistaken for public CI green] → run the unchanged full command in the pinned image as well.
- [The historical sixteen-failure sample is incompletely labeled] → collect/reconcile all labels before changing implementation; no guessed exemption for the remainder.
- [Generated proposal references can affect static token scans] → use only published/test source paths in the helper and preserve the selector's existing coverage discipline; do not solve failures by dropping mappings.

## Migration Plan

PM reviews these planning artifacts and records ACCEPTED before granting an apply slice. A different developer implements the test-only change; independent verification exercises both tree shapes and both mutation directions. The PM reruns final protected-branch gates before any user-approved archive/publishing step. Rollback is a normal revert of the test-only implementation, restoring the known public false reds but changing no product behavior or publication payload. No production environment is brought up and no remote repository state is changed by P146.
