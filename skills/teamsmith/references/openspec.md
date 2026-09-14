# OpenSpec: the spec and change layer

teamsmith keeps the **evidence** (task briefs, reports, reviews, decisions). OpenSpec owns **what must hold**
(requirements with scenarios) and the **change workflow** (proposal → specs → design → tasks → archive). There is no
second spec system: if a promise belongs to the product it goes into a spec; if it is reasoning or guidance it goes
into `references/`.

## 1. Division of labour

| Layer | Owns | Lives in |
|---|---|---|
| OpenSpec | requirements + their scenarios; changes; archive | `openspec/specs/`, `openspec/changes/` |
| teamsmith | one work slice: brief, dispatch, verification, merge, ledger | `docs/team/**`, `.pi/team/**` |
| the PM | writing briefs that name the change, running the gates, archiving when the change is done | — |

The mapping is: **change** = requirement-level unit; **brief** = one work slice that satisfies some scenarios;
**report** = the worker's claim; **review** = the PM's evidence; **archive** = close the change once the code landed.

## 2. Artifacts and what they look like

```
openspec/
  config.yaml                     # context + rules (proposal/specs/tasks) + apply/archive guidance
  specs/<capability>/spec.md      # the contract: ## Purpose + ## Requirements
  changes/<change>/
    proposal.md                   # Why / What Changes / Capabilities / Impact
    specs/<capability>/spec.md    # ADDED/MODIFIED/REMOVED/RENAMED deltas
    tasks.md                      # the implementation checklist
  changes/archive/<change>/       # finished changes (history; not a spec)
```

A main-spec requirement is a level-3 header inside `## Requirements`, must contain SHALL or MUST, and needs at least
one level-4 scenario; scenarios use WHEN/THEN bullets with concrete commands or observable outcomes. A requirement
without a scenario that can fail is a smell — either make it observable or leave it as prose in `references/`.

```md
### Requirement: Empty or relative tmux targets are refused

Every destructive or typing operation MUST reject an empty or relative target before calling tmux.

#### Scenario: An empty target cannot hit the caller

- **WHEN** an internal kill-window call is made with an empty target
- **THEN** it exits non-zero and no window or pane is affected
```

## 3. Day-to-day commands

```bash
openspec list --specs                    # capabilities + requirement counts (the tool's promises)
openspec list                            # open changes
openspec change show <change>            # proposal, deltas and tasks of one change
openspec context                         # the project context + rules the AI sees when creating artifacts
openspec validate --all --strict         # structure + strict mode; the first step of TEAM_GATES
bash skills/teamsmith/tests/spec-lint.sh # falsifiability (requirements/scenarios); the second step
openspec archive -y <change>             # merge the deltas into specs/ and move the change to archive/
```

`team paths` prints the resolved OpenSpec CLI and spec root (`TEAM_OPENSPEC_BIN`, `TEAM_SPEC_DIR`; both default to
`openspec`), and `team doctor` fails when the CLI or the spec directory is missing while `TEAM_REQUIRE_OPENSPEC=1`
(the default — OpenSpec is a required dependency, see `openspec/specs/memory-and-deps/spec.md`).

The gate command runs the spec checks **before** the smoke suite, because they are fast and structural: a spec that
no longer parses (missing scenario, missing SHALL, a delta header in a main spec) fails the PM's review, and so does
a spec that parses but cannot fail (see the next section). Note that the CLI must be on `PATH` for the gate — for a
bun-built install that is `~/.bun/bin`, so either put it on `PATH` or pass an absolute path.

### The falsifiability companion (`tests/spec-lint.sh`)

`openspec validate` owns *shape*, not *falsifiability*: deleting a scenario's `THEN`, deleting the scenario (leaving
its requirement scenario-less) or reducing a `spec.md` to a heading still validates green, so the CLI alone can
pass with a spec that cannot fail. `skills/teamsmith/tests/spec-lint.sh` is the project-level companion that closes
that hole (it is also a smoke-suite section, so both directions are tested):

```bash
bash skills/teamsmith/tests/spec-lint.sh            # default root: $TEAM_SPEC_DIR, else openspec
bash skills/teamsmith/tests/spec-lint.sh path/to/openspec
```

It prints one `path:line: rule: detail` line per violation and exits 1; exit 0 prints the file/requirement/scenario
counts, and exit 2 means the root itself is unusable (missing `specs/`). The rules, by name:

| Rule | Fails when |
|---|---|
| `no-specs` | `specs/` contains no `specs/*/spec.md` at all |
| `no-requirements` | a main `spec.md` has no `### Requirement:` block |
| `requirement-without-scenario` | a requirement has no `#### Scenario:` block |
| `scenario-without-when` | a scenario has no `WHEN` bullet (an assertion with no trigger) |
| `scenario-without-then` | a scenario has no `THEN`/`AND` bullet (a trigger with no assertion) |
| `scenario-placeholder` | a `WHEN`/`THEN` bullet is empty or vacuous (`THEN it works`, `... as expected`) |
| `change-incomplete` | a `changes/<id>/` without a `specs/` delta, `proposal.md` or `tasks.md` |
| `delta-requirement-without-scenario` | an `ADDED`/`MODIFIED` delta requirement has no scenario |

Changes are proposals, so the checker is deliberately tolerant there: a `REMOVED`/`RENAMED` requirement may be
scenario-less and `changes/archive/` is history, not a promise. Anything the lint refuses in a main spec is either a
missing scenario (write one) or a statement that cannot be made observable (move it to `references/` prose — the
`rules:` in `openspec/config.yaml` say so).

## 4. Threading a change through a task

1. The PM opens (or picks) a change: `openspec new change <name>`, then fills `proposal.md`, the delta spec and
   `tasks.md` (the `rules:` in `openspec/config.yaml` say what a proposal and a task list must contain).
2. Each brief names the change and the scenarios it must satisfy (`change:` / `specs:` in the brief header) and its
   acceptance commands show how those scenarios are exercised.
3. The worker implements, runs the brief's commands and reports; the PM verifies on an independent checkout
   (`team review <ID> --dir <checkout> --strong` for milestone work).
4. When the change is fully implemented and landed, the PM archives it: `openspec archive -y <change>`. Archive is
   the last step — not a substitute for the ledger: `docs/team/reviews/<ID>.md` and the reports stay as the evidence.

## 5. When a change is bigger than one task

Keep the change open and split it into several briefs against the same change (one capability or one scenario group
per task). Sequence them by dependency (`deps:` in the brief), verify each one on its own, and merge them one by one.
Archive only when the last task has landed — a half-applied change stays in `openspec/changes/` where the next PM can
see it.

## 6. What deliberately stays as prose

Some promises cannot be made falsifiable yet (a style of writing, "the PM should be sceptical", a policy that needs
human judgement). Those live in `references/` as prose and MUST NOT be turned into requirements with scenarios that
cannot fail — an unfalsifiable green is worse than no requirement. The rules in `openspec/config.yaml` encode this:
specs need observable scenarios, proposals need copy-pasteable acceptance commands plus explicit boundaries, and a
defect fix must state its flip (red before → green after, or a destructive test that must fail when the guard is
removed).
