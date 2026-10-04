# P57 · trust-prompt-and-fixtures — the trust prompt is not a draft, and the install says it is coming (propose)

agent: verify   status: DONE (propose phase; apply/verify not started — planning only)
time: 2026-09-22T13:35:00Z
branch: `task/P57-propose`   PR/MR: `-` (local mode: no push, branch left for the PM for review)

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/trust-prompt-and-fixtures/proposal.md` | Why / What Changes / flip / boundaries / acceptance / evidence (59 lines) |
| `openspec/changes/trust-prompt-and-fixtures/design.md` | The measured scene, the fixture-strategy comparison (A/B/C), the judgement rule, the install-hint decision, the residuals |
| `openspec/changes/trust-prompt-and-fixtures/tasks.md` | Coverage map, 3 apply batches + verify batch, 13 verifiable items, path grants, fixture notes |
| `openspec/changes/trust-prompt-and-fixtures/specs/verification/spec.md` | 1 ADDED requirement, 3 scenarios |
| `openspec/changes/trust-prompt-and-fixtures/specs/init-skill/spec.md` | 1 ADDED requirement, 3 scenarios |
| `openspec/changes/trust-prompt-and-fixtures/.openspec.yaml` | The schema marker `openspec new change` writes |
| `docs/team/reports/P57-verify/` | This task's evidence: the two raw pane captures, their frame-level judgement output, the provenance README |

No `MODIFIED`/`REMOVED` delta: nothing in the base specs is superseded and no base scenario is touched (why
`ADDED` and why that keeps the archive order free of D40's hazard: design §4). Nothing outside
`openspec/changes/trust-prompt-and-fixtures/**` and `docs/team/reports/P57-verify*` was changed by this task:

```
$ git diff --stat d06e09a..HEAD
 .../trust-prompt-and-fixtures/.openspec.yaml       |   2 +
 .../trust-prompt-and-fixtures/design.md            | 145 +++++++++++++++++++++
 .../trust-prompt-and-fixtures/proposal.md          |  59 +++++++++
 .../specs/init-skill/spec.md                       |  35 +++++
 .../specs/verification/spec.md                     |  58 +++++++++
 .../changes/trust-prompt-and-fixtures/tasks.md     |  96 ++++++++++++++
 6 files changed, 395 insertions(+)
```

Commits on the branch: `8149916` (the change artifacts). The report and its evidence are the next commit.

## Verification evidence (actually run)

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict | tail -4
✓ change/trust-prompt-and-fixtures
✓ spec/verification
✓ spec/watchdog
Totals: 23 passed, 0 failed (23 items)                     # exit 0 (PIPESTATUS[0])

$ PATH="$HOME/.bun/bin:$PATH" openspec validate trust-prompt-and-fixtures --strict
Change 'trust-prompt-and-fixtures' is valid                # exit 0
```

### The measured scene the proposal argues from

All on the host, Pi 0.87.0, a **private** tmux socket (`TMUX_TMPDIR=/tmp/trust-repro/sock`,
`env -u TMUX -u TMUX_PANE`), real `HOME` for provider config only; the project had `.pi/skills/teamsmith` (the
`team init` install shape) and no saved trust decision. Raw captures and their full outputs:
`docs/team/reports/P57-verify/`.

**(1) The prompt is real and it is what the fixture meets.** The captured prompt frame (30 rows): full-width rule
at row 1, `Trust project folder?` at row 3, the cwd at row 4, the five options at rows 8–12, the key hint at row
14, the prompt's own bottom rule at row 16; `cursor_y` reported 15 (0-based, i.e. row 16).

**(2) The fixture's `EMPTY`-only check calls the prompt a draft — both cursor shapes:**

```
$ . scripts/lib/{common,outbox}.sh; raw=$(cat …/pi-0.87.0-project-trust-prompt.txt)
$ printf '%s\n' "$raw" | _team_box_geometry 16        # the real cursor row
                                                                # → no output (no box below the cursor)
$ printf '%s\n' "$raw" | _team_box_rows_of_frame 16
NONE                                                            # → input-box verdict UNKNOWN

$ printf '%s\n' "$raw" | _team_box_geometry 9         # a cursor on the Trust option row
1 16                                                            # → pairs the prompt's own rules
$ printf '%s\n' "$raw" | _team_box_rows_of_frame 9 | head -3
  row 14||2
  row 13| Trust project folder?|3
  row 12| /tmp/trust-repro/proj|4                               # → box text = the prompt; verdict BUSY
```

Both are non-`EMPTY`, so the current fixture prints `M45 idle-read=NOT-EMPTY BAD` (the P54 F2 shape). Its M45
check does not stop the script, so the run then reaches the paste/retraction steps — with no locatable box the
retraction is a no-op, and the payload is typed into the prompt (no `Enter` follows) — the red side the change
plans to cut.

**(3) The green side exists with one flag.** The same project, Pi started with `--approve`:

```
$ printf '%s\n' "$(cat …/pi-0.87.0-approved-normal-ui.txt)" | _team_box_geometry 20
19 21                                                           # the real input box
$ … | _team_box_rows_of_frame 20
1||20                                                           # only the hint slot → EMPTY
```

**(4) A one-line-patched copy of the fixture runs green end to end on the host** (the repo fixture was copied to
`/tmp` and `--approve` added to the Pi launch — the repo itself was **not** touched; `M24_SKILL_DIR` pointed at
this worktree's skill):

```
$ cd <home>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify
$ M24_SKILL_DIR=$PWD/skills/teamsmith timeout 180 bash /tmp/p57-box-approve.sh --idle-secs 3 \
    > /tmp/p57-approve-run.log 2>&1; echo "rc=$?"
rc=0
$ grep -E 'verdict=|M45 idle-read|RETRACT=|隔离自检' /tmp/p57-approve-run.log
  verdict=EMPTY state=EMPTY
  M45 idle-read=EMPTY ok
  verdict=BUSY state=BUSY
  HOLDS_ONLY=yes MID_RENDER=no RETRACT_SAFE=yes
  RETRACT=ok
✓ 隔离自检：夹具 session 不在真实默认 server 上
```

**(5) The one-run override writes no trust decision:** `~/.pi/agent/trust.json`'s mtime was
`2026-09-14 07:17:42` before the run and unchanged after it (no content was read), and no interactive answer was
ever given — the prompt frame was only captured.

### Flip evidence (what exists before apply, and what apply must complete)

- **Red before (measured, frame level):** the stored trust-prompt frame under the current judgement reads
  `NONE`/`UNKNOWN` or `BUSY` — never `EMPTY` — which is what makes the fixture print `idle-read=NOT-EMPTY`.
- **Green after (target, measured in the patched-copy run above):** real pane → `idle-read=EMPTY ok`,
  `RETRACT=ok`, rc=0.
- **Still for apply to produce (tasks 1.2/1.5):** the frame mode's two outcomes and their flip control —
  `overlay=trust-prompt` (exit 0) with `M24_OVERLAY_DETECT=0` bringing back `idle-read=NOT-EMPTY` (exit ≠ 0) —
  plus the install-line assertions. The propose phase does not implement them, so this report does **not** claim
  them.

## Not run (honest)

- **`smoke.sh`, FAST or full.** Three reasons: this task changed no file under `skills/**` (OpenSpec change dirs
  are not read by the suite); at delivery time the shared machine was already running several `smoke.sh` suites
  (`pgrep -af smoke.sh` showed two full suites, one FAST suite and P55's gate waiter), and the project discipline
  is one gate at a time; and the **full** suite is red at §31b2 today by construction — that red is P54's F2, the
  defect this change plans to fix. The change's own acceptance block lists both commands for the apply/verify
  phases.
- **An attempted FAST run, stopped after ~2 minutes — not a result.** It was started through the background-job
  harness, whose PATH turned out to carry no `pi` (the suite then substitutes its stub, so the Pi-parser
  assertions would have degraded to skips); the run had reached section 6h all-green when it was stopped rather
  than let it contend with the suites already running. Nothing in this report counts it as a gate result — the
  phase gate that did run is `openspec validate --all --strict` above.
- **The §31b2 container run.** Pre-apply it is the known red this change addresses (P54 F2, measured by the PM),
  and it runs inside the full suite — not run for the reasons above. After apply it must go green
  (tasks 1.6/3.2).

## Boundaries respected

- Propose only: no implementation file was touched; the change dir is the only `openspec/**` write, the report
  and its evidence dir the only `docs/team/**` writes.
- No push (local mode); no merge, no force-push, no branch switch; small commits with `Refs: …` and
  `Agent: verify` trailers.
- The host experiment ran inside a private tmux socket; the developer's trust store was neither read nor written;
  no credential file was touched.
- The one-line-patched fixture lived in `/tmp`; the repository's fixture is untouched (as the phase demands).

## Residuals handed to apply/verify (design §5)

1. The delivery guard's `UNKNOWN → deliver as today` path can type into a modal (no `Enter` follows) — a future
   `delivery-guard` change, not this one.
2. `overlay=trust-prompt` keys on Pi's measured wording; a rename degrades to the legible readiness failure, not
   to a false draft.
3. The fixture's one-run override depends on `--approve` (present since long before 0.86; pinned image carries
   it).
4. `install-shape.sh`'s existing assertions stay untouched; the new hint assertions go beside them.

## Self-check against the PM's proposal-review checklist

1. **Matches the approved approach** — the brief (P54 F2 → PM-verified attribution) is the approved scope; no
   widening (the delivery guard is explicitly out of scope) and no narrowing (§31b2 keeps running).
2. **Observable** — the deltas state fixture output tokens, exit statuses, the stored frame, the install line's
   content and the absence cases; every scenario can fail.
3. **Closed coverage, both ways** — the tasks' coverage map names items for both requirements and every item
   names a capability.
4. **Explicit boundaries** — proposal Boundaries + design §6 + tasks' path grants.
5. **Acceptance commands** — copy-pasteable and existing (the gate pair); the scenarios' new commands are marked
   as apply deliverables (tasks 1.2/1.5).
6. **Defect fix states the flip** — proposal Flip + the report's flip evidence section above.
7. **No conflict with existing specs** — no base requirement is superseded; both deltas are ADDED and distinct
   by name from every base and pending change.
8. **Granularity** — one apply brief, three ordered batches; B1 and B2 independent, B3 last.
9. **One change per task** — the change dir holds exactly one id; no briefs are dispatched by this task.
10. **The anchor exists** — this is the change itself (`change: trust-prompt-and-fixtures`).
