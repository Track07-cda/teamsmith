## ADDED Requirements

### Requirement: The worker prompt makes suspension on background jobs a third legal turn end and teaches the lane by purpose

The dispatch prompt SHALL present the background lane by its purpose: start a long job with `team_bg_run`,
end the turn, and let the job's completion wake-up bring the result back for harvesting in the woken turn. It
MUST NOT demand a harvest before the turn ends, and MUST NOT frame the wake-up as a cost, a penalty or a
loss. In-turn waiting SHALL be described as the bounded exception, permitted only when the job is expected to
finish within the inline-wait budget the text names, its result blocks the immediate next step, and no other
task work can advance meanwhile.

The prompt SHALL name exactly three legal turn-end states: **delivered** (the acceptance commands ran, the
report is written and the branch is settled), **hard-blocked** (the PM is notified and the report states
`BLOCKED:`), and **suspended on background jobs** — jobs this session started are still running and every
step that does not depend on their results is done. A suspension SHALL require the turn's last line to name
every awaited job id; it is not a delivery and not a blockage, so the worker SHALL NOT write the report's
final verdict and SHALL NOT notify `BLOCKED:` for it. The prompt SHALL tell a resumed or restarted session
that a previous session's wake-ups died with its process, so jobs it left running are checked on disk —
`state/bg.log` and `team bg list` — before their results are awaited or re-run.

The lane block SHALL be injected only where the lane exists: the built-in Pi path or a custom adapter
template carrying `{bg_ext}`, under the same condition that governs it today. The same three-state contract
and the same suspend-default lane rule SHALL appear in the rendered team-protocol section
(`templates/AGENTS.section.md.tmpl`) and in `references/protocol.md` and `references/workflows.md` §E2, so
the prompt, the rendered `AGENTS.md` and the references cannot drift apart; the PM prompt template's
existing rule (`templates/pm-prompt.md.tmpl`) is the reference phrasing and SHALL NOT be weakened.

#### Scenario: The built-in Pi prompt carries the three states and the suspend default

- **GIVEN** a fixture project with every adapter key empty
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs
- **THEN** the printed prompt contains the lane block stating the end-the-turn default, the completion
  wake-up as the normal harvest point and the three exception conditions with the inline-wait budget figure;
  it names all three turn-end states and requires a suspension's last line to name the awaited job ids; and
  it contains no demand to harvest every job before the turn ends and no framing of the wake-up as a cost

#### Scenario: A template without the lane placeholder gets no lane block

- **GIVEN** `TEAM_AGENT_CMD='myagent run --ask {prompt}'` (no `{bg_ext}`)
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs
- **THEN** the printed prompt carries the three-state contract but no lane block, and with
  `{bg_ext}` present in the template the lane block appears

#### Scenario: One contract across the shipped surfaces

- **WHEN** the worker prompt (built-in Pi), `templates/AGENTS.section.md.tmpl`, `references/protocol.md`,
  `references/workflows.md` §E2 and `templates/pm-prompt.md.tmpl` are read
- **THEN** each names the same three turn-end states, the lane rule is the same suspend default with the
  same inline-wait budget figure everywhere it is stated, and the PM template's existing rule is unchanged —
  and the fixture's red side (the third state dropped from the AGENTS template, or the old
  harvest-before-ending wording restored to the prompt) fails this scenario naming the surface that diverges

#### Scenario: The resume guidance points at the on-disk evidence

- **WHEN** `team dispatch dev T1.1 <brief> --print` runs
- **THEN** the printed prompt's resume guidance names `state/bg.log` and `team bg list` as the way to find
  jobs a previous session left running, and states that the previous session's wake-ups died with its
  process
