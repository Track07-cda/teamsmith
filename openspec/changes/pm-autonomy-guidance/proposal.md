# Proposal

## Why

The default PM instructions say when to ask for authorization but do not say clearly which routine decisions the PM should make once the user has approved the work. State that distinction where every PM starts, so routine work does not keep coming back to the user for a decision.

## What Changes

- Add one short PM rule just after the roles in the default team rules: carry authorized work forward without asking again, and when a user decision is needed, advance the unaffected work first and bring a recommendation with its concrete impact.
- Scope the PM startup prompt’s four separately authorized steps to Teamsmith tool-source upgrades. Point the startup prompt and daily skill to the default rule; keep their local approval instructions in place.
- Keep decisions on new product trade-offs and scope with the user. Do not change authorization for production operations, merges, pushes, releases or any other protected action, or who performs independent review.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `init-skill`: clarify the required content of the default team rules, PM startup prompt and daily skill without changing how those instructions are generated or loaded.

## Impact

Only `skills/teamsmith/templates/AGENTS.section.md.tmpl`, `skills/teamsmith/templates/pm-prompt.md.tmpl` and `skills/teamsmith/SKILL.md` are planned product edits. The rule applies to all PM models. New projects get it through the existing setup path; existing projects keep their current `AGENTS.md` until an explicit refresh under the existing preservation and write rules. No project is refreshed here. No generator, loader, model policy, permission, verification procedure or release behavior changes.
