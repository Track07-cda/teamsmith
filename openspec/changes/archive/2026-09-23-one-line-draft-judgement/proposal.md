# one-line-draft-judgement · proposal

## Why

Pi 0.87.0 draws the input box as `top border / content rows / bottom border` with its **status row below the
box**; on 0.85.1 that status row was the last row **inside** it. The guard's extraction (`team_input_box_text`)
and the frame-level judgement the fixtures share (`tests/lib/box-judge.sh`) still exclude the row immediately
above the bottom border (`OFFSET==1`) **by slot**, as 0.85.1 required — so on 0.87.0 a **single-line draft** sits
on that row and the box reads `EMPTY`. Measured with the unmodified tree on the raw frames P61 stored (cursor row
26; probe: `design.md` §6):

| frame | box text today | verdict today |
|---|---|---|
| `docs/team/reports/P61-dev3/logs/15b-one-line-draft-frame.log` (`HUMAN-ONE-LINE-DRAFT`) | `[]` | `idle-read=EMPTY` |
| `docs/team/reports/P61-dev3/logs/10c-real-draft-box.log` (`DRAFT-p61-half-sentence`) | `[]` | `idle-read=EMPTY` |
| `docs/team/reports/P61-dev3/logs/10c-real-empty-box.log` (0.87.0 empty control) | `[]` | `idle-read=EMPTY` |
| `skills/teamsmith/tests/frames/pi-0.85.1-update-banner.txt` (status row at `OFFSET==1`) | `[]` | `idle-read=EMPTY` |

Two consequences, both with a scene: the readiness gate releases on a one-line draft and the fixture types its
payload (`15d`: `rc=0`, `M45 idle-read=EMPTY ok`, one keylog line); and the production path
`team_delivery_verdict` also returns `EMPTY` while `team_box_holds_only` answers with empty-box semantics, so a
payload is pasted over the draft. Multi-line drafts read `BUSY` (`15c`).

## What Changes

- **MODIFIED — `delivery-guard`** (*An automated send never types into a non-empty input box*): the
  border-adjacent row SHALL be content unless it is **provably the box's own status row** — the cursor is not on it
  AND its text matches the status-row shape measured from the two real frames (` deepseek-flash  Deepseek  max`,
  ` k3  Kimi Coding  max`). The slot exclusion and its V9-C3 paragraph are replaced; the remaining hole (a single
  row that is a perfect status-row clone with the cursor elsewhere) is named in `references/troubleshooting.md` §3.
- **MODIFIED — same requirement**: the box-text extraction has exactly **one implementation**, called by
  `team_input_box_text`, by `box-judge.sh`'s frame verdict and by the gate's frame probes; a fixture that
  re-implements the exclusion is a spec violation.
- **MODIFIED — `notify-and-inbox`** (*Messages to a stopped agent fall back to the inbox*): a single-line draft is
  a draft — no key is sent, the message is held and reported `queued`, and the readiness fixture does not release.

## Flip

Red before: both 0.87.0 single-line-draft frames → `idle-read=EMPTY`, and the readiness fixture over such a pane
releases and types (`15d`: `rc=0`, one keylog line). Green after: the same frames → `idle-read=NOT-EMPTY`; the
0.87.0 empty control and the 0.85.1 frame → `EMPTY`; the fixture refuses (`rc≠0`, zero keys, frame printed); the
multi-line control stays `BUSY`. Falsifiability: the probe shadows the status-row predicate to the legacy
"always chrome" behaviour, and the draft frames must flip back to `EMPTY`.

## Impact

Apply touches `skills/teamsmith/scripts/lib/outbox.sh`, `skills/teamsmith/tests/**` (incl. `tests/frames/**`) and
`skills/teamsmith/references/troubleshooting.md` — the apply brief must grant those three; the tree's synthetic
status rows must be re-shaped to the measured one (measured impact: `design.md` §4). Deltas: `delivery-guard`
(one MODIFIED requirement, five new scenarios) + `notify-and-inbox` (one MODIFIED requirement, one new scenario).
No `verification` delta.

## Boundaries

Planning only. F2 (a draft whose text is the overlay's wording is classified as an overlay) is **not fixed here**:
it is the unarchived `trust-prompt-and-fixtures` change's `verification` promise with its own 30-cursor-row
evidence, so a structure-first rewrite belongs to a `verification` change — the reason, the direction of harm and
the named follow-up are in `design.md` §5. This change only removes exclusions (a text row is content unless
proven chrome), never adds one, so it cannot weaken "a draft in the box means no key" (M24/M30).

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
```

(The first line runs on this proposal; the second and third need the apply commit, the third being the full gate.)

## Evidence the report must contain

Both acceptance tails; the before/after probe output for the four frames above; the new FAST section in both
directions (predicate on → drafts `NOT-EMPTY`; shadowed → drafts `EMPTY`); the readiness-fixture refusal over a
one-line draft (`rc≠0`, no `deliver_text_lines=`, zero keylog lines) beside the pre-fix `15d` tail; the multi-line
control's `BUSY`; `guard-matrix.sh`'s unchanged result; and the paths the diff touched.
