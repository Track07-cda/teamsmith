# agent-death-reason · proposal

## Why

A seat that dies stops quietly: the pulse says `停了的 agent N`, never why (D46's pane frame: `Error: 403
permission_error: reached your weekly (7-day) usage limit`; kimi's 5-hour quota did the same to the user
on 2026-09-28). No classification exists — a grep for `usage limit`, `insufficient_balance` or a
provider `*_error` frame finds only unrelated config text.

## What Changes

- **ADDED — `watchdog`** (*A seat death has a classified cause…*): the closed set
  `quota|balance|rate_limit|window|auth|normal|unknown` from two bounded sources (corpse scene + the
  newest pi session file's last error). A non-`unknown` category needs a vendor error frame plus its
  wording; a mere mention of `quota` is not a match, unreadable evidence is `unknown`, and the raw line
  stays with the cause.
- **ADDED — `watchdog`** (*A cause belongs to the current launch…*): identity `(seat, category, anchor)`
  anchored on the launch nonce or `pane_dead_time`; evidence older than the seat's current `started` is
  ignored, so a restart never inherits the old cause.
- **ADDED — `watchdog`** (*The seat surfaces name the cause…*): `team status <ID>` prints category +
  source + time + raw line; `team digest` [1] names each stopped seat's category; readers stay read-only.
- **ADDED — `watchdog`** (*The patrol reports each abnormal death exactly once…*): one record in
  `state/deaths.log` and one knock per death identity when evidence is readable; `normal` is silent;
  standby defers; an evidence-less death is surfaced as `unknown` without a second knock.
- **ADDED — `notify-and-inbox`** (*A seat-death knock carries…*): seat + cause + raw line through the
  delivery guard; an `unknown` knock says so without naming a cause.
- **ADDED — `panel`** (*The agents block carries each seat's death cause*): `cause`/`cause_source`/
  `cause_line` in `team __panel-data --block agents` and the token in the printed row.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `watchdog`: the death classification, its current-launch scoping, the seat surfaces, the one-knock rule.
- `notify-and-inbox`: the death knock's content and honesty.
- `panel`: the agents block fields and the printed token.

## Impact

`skills/teamsmith/scripts/lib/**`, the panel sources + rebuilt `panel.js`, `skills/teamsmith/tests/**`
(new `death-cause.sh` + the exact `team_pending_text` equality). No extension change, no daemon, no new
dependency.

## Flip

Red before: the kimi 403 corpse reports `停了的 agent 1` everywhere, the panel JSON has no cause key,
three ticks send only the standing nudge. Green after: `quota` + raw line on `team status` and the panel
JSON, `dev=quota` in digest [1], one knock per death, `unknown` for quota-mentioning prose, silence for a
clean exit, no old cause after a restart.

## Boundaries

Propose only — no `skills/**` change here. Out of scope: M6.5's liveness rule, automatic provider/model
fallback, the `[auto·interrupted]` tag, other projects, any weakened assertion. `openspec/specs/**` and
`docs/team/{tasks,BOARD,ROADMAP,DECISIONS,OWNERSHIP}.md` stay PM-owned.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
bash skills/teamsmith/tests/death-cause.sh
bash skills/teamsmith/tests/smoke.sh </dev/null
git status --porcelain
```
