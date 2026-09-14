# Cross-project meetings (meeting mode)

This is the mechanism for **normal conversation** between two projects (how an interface fits, advice, problem
reports); it is not a chat room and certainly not a command channel.

## Boundaries (they apply to every meeting)

| Allowed | Not allowed |
|---|---|
| Discussing interfaces/contracts/fields/ordering/error codes | Telling the other side's PM or agents what to do |
| Advice + its basis (measurements/docs/trade-offs) | Making a decision on the other side's behalf |
| Reporting problems with a reproduction | Impersonating a human to issue instructions |
| Asking for information, scheduling a joint test window | Changing the other side's repository/state, merging its PRs for it |
| Each side claiming its own half | Pushing a "joint decision" as a fait accompli |

- **A meeting only produces "consensus + each side's own todos"**, never a command aimed at the other side; landing the
  work always happens inside each side's own project.
- `intent` is limited to `info | question | report | proposal | request` —— **there is no `command` in the mechanism**.
- Consensus requires both sides to `agree` separately; every entry in `AGREEMENTS` records "our side lands / their side lands".
- **Workers do not attend**: cross-project traffic goes through the PM only. A worker that needs outside help writes
  `BLOCKED:` in its report.
- **The user** is the only one who can give instructions across projects (`team meeting say --as-user` from a human
  terminal; an agent process is refused).

## Shared area (outside both projects)

```
<meetings>/<slug>/            # default ~/.pi/team/meetings/<slug>/
├── agenda.md                 # topics + boundaries + closure record
├── state.env                 # participants / peer session / TTL / MAX_TURNS / status
├── transcript/0001_<project>_<intent>.md    # append-only turns (the only truth; written before any knock)
├── agreements/A1.md          # consensus entries (proposal + agreed-by of each side)
├── read/<project>.seq        # each side's read position (inbox counts unread from it)
└── knocks.log                # knock record (when knocking is used)
```

## Commands

```bash
team meeting open <slug> --with <project>[:<session>] --topic "order API integration" --ttl 72 --yes
team meeting say <slug> --intent proposal "POST /orders should take an idempotency_key (UUID, required)" [--knock]
team meeting read <slug> [--since N] [--peek]      # marks what it reads by default
team meeting inbox                                  # which meetings are waiting for my reply
team meeting list [--all]
team meeting propose <slug> "interface contract v1: fields/error codes/timeouts" --sides "ours:… / theirs:…"
team meeting agree <slug> A1 [--note "our side lands: T4.2"]   # must be the other side confirming (never your own proposal)
team meeting close <slug> [--summary "conclusions and leftovers"]        # read-only afterwards (the transcript freezes)
```

The session in `--with <project>:<session>` is what **knocking** uses (to tell the other PM there is a meeting message);
a meeting can be opened without knowing it, only knocking is unavailable then (the message still lands in the shared
area, where the other side's patrol of `meeting inbox` finds it).

## Workflow example

```bash
# project A (initiates)
team meeting open order-api --with <peer>:<peer> --topic "order API integration" --yes
team meeting say order-api --intent proposal "POST /orders should take an idempotency_key; a repeat returns the same order number"
#   → to nudge the other PM immediately (their project must allow knocking): add --knock
#     (and both sides need TEAM_MEETING_KNOCK=1)

# project B (responds)
team meeting inbox                     # → order-api (1 new turn)
team meeting read order-api
team meeting say order-api --intent question "how long is the repeat window? is 10 minutes enough?"
team meeting say order-api --intent request "your call: 10 minutes / 24 hours"   # asks for their decision, but does **not** decide for them

# forming consensus
team meeting propose order-api "window 24h; a repeat returns the same order_id" --sides "ours:api side / theirs:order side"
# the other side confirms
team meeting agree order-api A1 --note "order side lands: T5.1"
team meeting close order-api --summary "contract settled; leftover: idempotency-key format for batch submission"
```

## Knocking (off by default)

- `say` only **writes to disk** by default: the other PM sees it on its next `team meeting inbox` patrol.
- For something urgent, `--knock` sends one line (`[meeting:<slug>] … has a new turn`) to the other PM's window.
  Preconditions: ① the global switch `TEAM_MEETING_KNOCK=1`; ② the peer session was registered at `open` time;
  ③ Pi is actually running in that window.
- Knocking is the **only** allowed cross-session action, and it only announces "there is a message" — it never decides
  anything for the other side.

## When knocking fails

```bash
team meeting peer <slug> <project>:<session>   # register/update the peer session afterwards (works even if open did not have it)
team meeting knock <slug>                   # knock again for the last turn after registering
```

`knock` reports five things in order: ① the `TEAM_MEETING_KNOCK` switch ② whether the peer session is registered
③ whether that session exists in tmux ④ whether Pi is really running in the peer PM's window ⑤ whether the boundary
guard lets it through. **A failed knock does not affect the message** — it is already in the shared area.

## Guards (at the code level)

| Guard | Behaviour |
|---|---|
| Cross-session typing refused by default | an unregistered cross-session `send-keys` is always refused; only "knocking for a registered meeting" passes (`TEAM_GUARD_FOREIGN_TARGET=1`) |
| Write first, knock second | a message can only be knocked for after it is in the transcript; a failed knock loses nothing |
| Identity cannot be forged | every turn carries `from: <project>/pm@<session>`; the receiver always treats it as a peer statement |
| Impersonating a human refused | `--as-user` needs a human terminal + `TEAM_MEETING_ALLOW_USER_ID=1`; an agent process is refused |
| Giving orders refused | anything outside the `intent` whitelist is refused; a body carrying an order marker (`[order]`/`[command]`, or the Chinese equivalents) is refused too |
| Rate limit | `MAX_TURNS` per side (default 20, taken from the meeting record; a stricter env `TEAM_MEETING_MAX_TURNS` wins) |
| Expiry | after `TTL_HOURS` (default 72) the meeting is read-only; it needs `close` or `open --force` to continue |
| Zero writes to others | the meeting path only writes the shared area; it has no write permission in the peer's repository |

## Configuration

| Key | Default | Meaning |
|---|---|---|
| `TEAM_MEETINGS_DIR` | `~/.pi/team/meetings` | shared-area location (outside both projects, never inside one of the repositories) |
| `TEAM_MEETING_TTL_HOURS` | `72` | meeting lifetime; read-only afterwards |
| `TEAM_MEETING_MAX_TURNS` | `20` | per-side turn budget (a hard limit; wins when it is stricter than the meeting record) |
| `TEAM_MEETING_KNOCK` | `0` | `1` = allow `--knock` to nudge the peer PM's window |
| `TEAM_MEETING_ALLOW_USER_ID` | empty | `1` = allow a human terminal to use `--as-user` (cross-project instructions come from the user only) |
| `TEAM_GUARD_FOREIGN_TARGET` | `1` | the global cross-session typing guard (a meeting knock is the only exception) |
