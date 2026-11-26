# Proposal

## Why

Six board states say where a task stands, not what kind of work it is or what should be handled first. Project-defined labels let people mark several reasons on the same task and explicitly order work by their combined importance, without changing what any board state means.

## What Changes

- Add `team board label` to define, list, edit or delete project labels and attach or detach several names on one board task. Keep names, colors, weights and associations in one file beside `BOARD.md`; a project that has never used labels needs no migration or new file.
- Keep plain `team board ls` as the current Markdown inspection. Filtering and priority sorting require explicit options. Priority is the sum of distinct attached labels' weights; ties keep file order.
- On Pulse's board page, add read-only label and order choices; show labels and priority in the existing task detail on either owning page. Keep the board’s existing recent-first order by default, including its order for rows without an update time. A label filter can narrow either view. Only choosing priority changes the order within a state; ties follow the original board file, not the update time.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `board-and-status`: project-local label management and opt-in board listing; preserve existing board commands, reports and row identities.
- `panel`: opt-in view over the existing state lanes and read-only task label detail; preserve the other pages, task card text, machine exits and existing navigation.

## Impact

The future apply touches the board CLI and its existing help entries, one shared reader/scorer, the existing board data block and Pulse board/detail rendering, their documentation and existing fixtures. No new runtime service, commands outside `team board`, global configuration key, or project initialization step. No task editor, project settings view, default label names, migration, GitHub issue sync, or change to statuses, dependencies, model selection, dispatch, patrol, standby, wake or recovery. No editing the existing capability files in this phase. This is a planning change; implementation requires separate authorization and an accepted independent proposal review.
