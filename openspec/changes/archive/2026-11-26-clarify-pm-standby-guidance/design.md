## Context

The shared AGENTS template says standby on/off is a human's call. The PM prompt repeats that in its startup checklist, then later tells the PM to turn standby on when there is nothing to advance or it is waiting on a person. Other surfaces echo the broader permission. An empty board does not account for a result still on its way, and ending a turn so a completion can wake the session is not the same as entering standby.

The existing `watchdog` and `agent-self-reminder` requirements already own the runtime: ordinary wake-ups pause without losing the backlog; manual off restores them; only the actual correlated Reminder wake can clear its provably bound current standby. This change does not amend either requirement.

## Goals / Non-Goals

- Replace the contradictory instructions with one default decision, subject to the project's rules.
- Retain local duties, exact existing test matches, human operations and the existing adoption route.
- Do not change commands, state, configuration, approval requirements, generation or loading. Do not add automatic switching, a checker, a test, or an adoption step.

## Decisions

### One home for the policy

In `skills/teamsmith/templates/AGENTS.section.md.tmpl`, end the existing Pulse description after “not an automatic dispatch.” Keep the mechanism and patrol references. Replace the human-only on/off sentence with a short adjoining rule:

> **PM standby.** Follow your project's standby rules. By default, you may run `team standby on --reason "…"` without asking when no work can advance, no task or verification is running, and no result is expected back automatically. Waiting only for a human decision can qualify; an empty board or a finished turn alone cannot. If your project leaves entry to the user, do not enter on your own. Standby pauses ordinary Pulse wake-ups. Leave `team standby off` to a human. A scheduled Reminder that actually wakes you can still clear its matching standby state.

Do not fold this into “PM — proceed within authorization” or broaden that rule. An on/off permission check in the CLI would change behavior; duplicating conditions in each prompt would recreate the drift.

### Remove only competing wording

Locations below are anchors in the existing source. Keep sections, local approvals, commands and reference pointers except for the named edits.

| Source | Smallest edit |
|---|---|
| `skills/teamsmith/templates/pm-prompt.md.tmpl` | Keep `team pulse status` in the opening checklist; use `# if Pulse is down and you are not on standby: team pulse up`. In “Background jobs and turn endings” remove only “and stand down” from the human-blocker parenthesis. In the Pulse paragraph replace the standby criteria and commands with “Follow **PM standby** in \`AGENTS.md\`.” Keep logging the human blocker to the same inbox or thread, the rest of the Pulse paragraph, the completion-wake path back to the session, and the tool-source upgrade paragraph verbatim. |
| `skills/teamsmith/templates/PROTOCOL.md.tmpl` | After “not an automatic resume,” replace the competing `on` and human-only clear sentence with “Follow **PM standby** in \`AGENTS.md\`.” Keep the rest of the summary. |
| `skills/teamsmith/SKILL.md` | Drop “and the owner can deliberately stand down” from the description. In the lifecycle row, keep the command and point its parenthesis to **PM standby** in `AGENTS.md`. In the Pulse rule, keep the patrol and resume description; replace the “Nothing to do or a human needed” instruction with the same pointer. Keep the startup Pulse line, general PM rule pointer, and tool-source upgrade wording. |
| `skills/teamsmith/references/protocol.md` §8 | Replace the broad permission with “Standby pauses ordinary Pulse wake-ups; the backlog is still logged. Follow **PM standby** in \`AGENTS.md\`.” Point to `workflows.md#standby` for commands and the Reminder exception. |
| `skills/teamsmith/references/workflows.md` §I | Remove the unqualified standby on/off pair from the patrol quick-start block; the same commands still appear under the existing Standby heading. Replace “lets the PM stand down deliberately” after the tick description with the effect and a link to Standby. Trim the heading to “Standby,” point to **PM standby** in `AGENTS.md` before the command block, and remove the redundant “When it applies” eligibility sentence. In that block, label on as pausing ordinary Pulse wakes and off as a human action. Keep backlog, `team digest`, actual Reminder exception, restart and human maintenance instructions. |
| `skills/teamsmith/references/troubleshooting.md` | Replace the blanket “both … qualify” and command directions in the PM-wake item with a pointer to the existing Standby subsection for pausing ordinary Pulse wake-ups without losing the backlog. |
| `skills/teamsmith-init/references/bootstrap.md` | In Common problems, use “Stop the periodic patrol” with only `team pulse down`. Remove the unconditional standby follow-up for a PM following setup, not any human maintenance procedure. |
| `README.md` | Replace only “the PM can \`standby\` deliberately” in the “Not rigid” row with “standby pauses ordinary Pulse wake-ups.” |

Leave the workflow's manual maintenance block and the panel README's human controls as written. Reminders guidance, command help, other references, tests and already generated files are not edit targets.

### Keep the ordinary Pulse message about pending work

When there is pending work and the PM is running, `skills/teamsmith/scripts/lib/cmd-watch.sh` calls `team_nudge` when a nudge is due. Its `msg` in `skills/teamsmith/scripts/lib/common.sh` tells the PM to enter standby if work is blocked on a human and promises no further wake-ups. That can contradict project policy, overlook a verification in flight and obscure the existing Reminder exception.

In `team_nudge`, end that same `msg` after `看详情`: the complete assignment becomes `msg="[pulse] 待办：$text → 跑 $TEAM_CLI digest 看详情"`. Delete the semicolon and everything after it. Keep the existing prefix, summary, digest instruction and language; add no replacement suffix. This is the only script edit. Keep other messages, counts, delivery, queueing, deduplication, recovery, and standby/Reminder behavior unchanged; no edit to the caller.

### Adopt deliberately, not by changing the source

For new projects using the revised source, the current init/first bootstrap path generates the revised shared section. Existing projects keep their existing instructions until they explicitly adopt the new ones. Use the current migration guidance for a separately authorized adoption: preview on a private copy with the project's actual inputs, preserve local rules outside the managed markers, and use the normal non-force refresh route. It is not an AGENTS-only write; ordinary init does not rewrite an existing PROTOCOL summary. Treat any update to that summary as separately authorized, not a reason to force-render the ledger. This plan does none of these steps.

Changing linked source may affect later reads of those files. It does not refresh the existing AGENTS file or replace text already read by a live PM; copies also do not adopt source changes on their own. Restarting Pulse does not apply wording. Leave the old “only the three instruction sources” check scoped to the change that introduced the proceed-within-authorization guidance, with its no-generation-change and no-auto-refresh protections intact. Use the new standby scenario to check the precise, separate wording-only diff here.

## Risks / Trade-offs

- **A PM treats “awaiting a person” as permission even with work in flight.** The shared rule applies both conditions; a non-author reads examples of an empty board, a running verification, a returning background result and a wait only for a human decision. These are review cases, not executions.
- **A prose edit erases a required phrase.** Keep the three endings, `team digest`, `pm-prompt.md`, `team_bg_run`, `let the turn end`, `harvest point`, `team_bg_wait`, `Your creed`, and `separate recorded gates` where existing `smoke.sh` and `task-model-routing.sh` match them. The reviewer checks existing matches against the source diff, not a new test.
- **Wording is mistaken for an automatic rollout.** Git should show only the named wording changes in the product, including the single suffix deletion; the review compares that with the existing adoption requirements. The same narrow source edits can be reverted by a later authorized change, with no standby/config migration to unwind.
