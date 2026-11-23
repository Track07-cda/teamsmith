# Design

## Context

The PM startup prompt already lists `AGENTS.md` first. In the source today, the default role table assigns work but does not say how to proceed within an existing authorization. The startup prompt lists four approvals without naming the upgrade context; the daily skill’s PM loop starts from when to stop and ask, and its adoption rule lists the steps differently. The tool-source upgrade sequence is already stated in `skills/teamsmith/references/migration.md` under the model-policy upgrade instructions.

## Goals / Non-Goals

Use the shipped role guidance, not a new setting, model-specific instruction, or second rulebook. Keep the review and permission distinctions explicit: arranging independent review is not performing it, and a goal approval is not permission for a protected action outside that approval. This design changes instruction text only; it adds no automation or test.

## Decisions

1. **One default paragraph after the role table** in `skills/teamsmith/templates/AGENTS.section.md.tmpl`, before the reading order. Candidate wording:

   > **PM — proceed within authorization.** For work the user has already authorized, check the facts, break down and delegate the work, make small reversible choices, coordinate corrections, arrange independent review, and finish without asking again. If the user asked for a proposal only, stop at the proposal. Agreement on its goal and scope is not authorization to implement it. If a decision belongs to the user, advance the work that does not depend on it, then give your recommendation and say what it would affect. New product trade-offs and scope changes are for the user. Production operations, merges, pushes and releases still need the required explicit authorization.

   A single shared paragraph instead of three copies lets the startup prompt and daily skill point to the same rule. This is an instruction for every PM, not a change to worker duties, model selection or review ownership.

2. **Name the upgrade context where the four steps are listed.** In `skills/teamsmith/templates/pm-prompt.md.tmpl`, add a short pointer to the PM rule under `Roles and reading order` in `AGENTS.md`. Qualify the existing four-step paragraph with “For a Teamsmith tool-source upgrade” and keep the separately recorded steps, exact-command previews, per-command authorization and shared-link warning. Those steps remain private source verification, validated source landing on a shared/protected tree, project configuration and the first fresh launch that reads it, and changed shared skill/copy source adoption. Grouping configuration and first fresh launch as one step does not combine their authorizations. Leave the local shared-state boundary, independent review and archive instructions in place.

3. **Align just two passages in `skills/teamsmith/SKILL.md`.** At the end of “The PM loop,” replace the generic “Stop and ask…” opening with the short pointer to the default rule. Keep an explicit instruction to get the user’s decision for a new product trade-off or changed scope, obtain missing authorization before shared-state writes such as merge/push, and research and record a decision where needed. Keep the existing `--yes` distinction: where a `team` command requires it, it expresses authorization; it does not grant it or apply to direct git/forge writes. In “Non-negotiable rules,” qualify the four adoption steps as tool-source upgrades and align the list with the existing sequence in the startup prompt and migration reference; keep the previews and authorizations per command, including the first fresh PM launch. Leave the separate shared-state authorization bullet in place rather than relying on the pointer.

## Risks / Trade-offs

- “Finish the work” could be read as unconditional permission to merge or release. Keep the exceptions next to the shared rule and preserve the local approval language in both PM surfaces. The independent reviewer compares wording and authority against the prior text, not against a sample model reply.
- The rule could be mistaken for an installed change or a guarantee that a running PM reads it. Describe only what the shipped sources say and how AGENTS reaches a project. No delivery or outcome is inferred from the diff.

## Adoption boundary

Fresh `team init` (and fresh bootstrap through the existing init path) generates the shared section; no new entry point or flag is needed. An existing project with valid current configuration gets new AGENTS text only when its owner explicitly refreshes using non-force `team init`, after the existing authorized private-copy preview. Preserve project-specific rules outside the markers; inventory any rules still inside and preserve them outside under the project’s authorization before refresh. `team init` does not move them. `skills/teamsmith/references/migration.md` §1b owns the full recipe: main-checkout write target, retained existing valid config and ledger bytes, other scaffolding/ignore/permissions/install effects, and no rollback guarantee on a late failure. Existing-config bootstrap and `team up` do not refresh AGENTS; `--force` is not needed. A changed shared source can still affect later reads through existing links, which is why its adoption remains separately authorized. No refresh, source adoption, restart or release is part of this proposal.
