# teamsmith

**Give one agent real ownership of a project**: it plans, dispatches, verifies independently, merges and keeps the ledger.

Runs on Pi today; designed to adapt to any TUI agent (adapter layer: ROADMAP M3.0).

In one line: teamsmith turns a single agent session into a **project owner with a crew that can be inspected** —
not "more agents chatting with each other".

## What it actually does

| Capability | Mechanism |
|---|---|
| Dispatch | Task briefs are self-contained (context / deliverables / boundaries / copy-pasteable acceptance commands); `team dispatch` puts a worker agent into its own tmux window and git worktree |
| **Independent verification** | The agent's report is a **claim**; the PM runs the gates on an **independent checkout** (`team review <ID> --dir …`) and that becomes the evidence |
| Ledger | `BOARD.md` (state), `reviews/` (verification evidence), `threads/` (decision trail), `DECISIONS.md` (the "why") |
| Not rigid | The watchdog only wakes the owner when there is pending work; the PM can `standby` deliberately; when capacity is tight, work queues instead of thrashing |
| Boundaries | Cross-project interaction is discussion only (`team meeting`) — never command; git/forge work stays with the PM's own tools |

Design rationale: [references/philosophy.md](skills/teamsmith/references/philosophy.md) (8 principles) and
[references/protocol.md](skills/teamsmith/references/protocol.md) (why each rule exists).

## Included

| Skill | Notes |
|---|---|
| [`teamsmith`](skills/teamsmith/SKILL.md) | See above. Former name: `pi-team` (`skills/pi-team` is a compatibility symlink) |

## Install

```bash
./install.sh                 # symlink every skill under skills/ into ~/.agents/skills (edit repo → live)
./install.sh --copy          # copy instead of symlink
./install.sh --target DIR    # custom target (e.g. ~/.pi/agent/skills)
./install.sh --uninstall     # remove what this repo installed
```

Requirements: `bash` ≥ 4, `git` ≥ 2.31, `tmux`, and a supporting agent CLI (Pi today).
No forge dependency, no container dependency, no jq/python/node.

## Quick start (inside a project repo)

```bash
SKILL=~/.agents/skills/teamsmith
TEAM="bash $SKILL/scripts/team"

bash $SKILL/scripts/team bootstrap         # config + docs skeleton + agent worktrees + watchdog window
$TEAM doctor                               # self-check (git/tmux/agent CLI/gates/capacity)
$TEAM task T1.1 --title "first task" --agent dev
$EDITOR docs/team/tasks/T1.1-*.md          # make the brief self-contained
$TEAM dispatch dev T1.1 docs/team/tasks/T1.1-*.md
```

## Compatibility (former name: pi-team)

- The command is still **`team`**; project config is still **`.pi/team/config.sh`**; env vars are still **`TEAM_*`**;
  team docs are still **`docs/team/**`**.
- `skills/pi-team` is a **compatibility symlink** to `skills/teamsmith`, so existing projects that reference the
  old absolute path keep working with zero changes.
- An `AGENTS.md` section marked `<!-- pi-team:begin -->` is migrated in place to the new marker by the next
  `team init`/`bootstrap` (idempotent).

## License

MIT — see [LICENSE](LICENSE).
