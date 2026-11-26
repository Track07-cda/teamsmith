## Why

The default shared AGENTS instructions and the PM startup checklist reserve standby for a human, while the same startup prompt later tells the PM to enter it. The ordinary Pulse message sent to a running PM also tells it to enter standby. These instructions can either turn routine standby into a needless approval request or quiet the patrol while the PM still has work or a result to receive.

## What Changes

- Put the complete default PM standby decision in the generated AGENTS section. The default permits eligible PMs to enter standby and record why without asking again; a project's own rules take precedence.
- Keep the startup checklist about when to start Pulse. Point other instruction surfaces to the shared rule or describe the command's effect, removing only competing guidance. In the ordinary Pulse message, keep the existing prefix, pending summary and digest instruction; delete only the standby suffix.
- Preserve the three turn endings, background-result return, upgrade and shared-state approvals, human standby release and the existing scheduled Reminder exception. This is wording only: no runtime behavior change, automatic switching, install or refresh of any project.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `init-skill`: Extend the existing shared-rules and role-procedures requirement to cover standby guidance and its adoption boundary.

## Impact

One apply task can make the text edits in the three templates, the daily skill, the four affected reference pages and the README line named in the design, plus one message string in `common.sh`. No other script change. A non-author reviews the final wording and Git diff; no added test or session is needed. New defaults affect new projects or projects that explicitly adopt them, not existing instructions or sessions merely because the source changed.
