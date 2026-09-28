# Tasks: `model-id-shape`

Planning only — the propose task (P102) writes this file and nothing here runs until the PM's proposal review
(`docs/team/reviews/model-id-shape-proposal.md`) is ACCEPTED and an apply brief is dispatched to an agent that
did not propose it. One apply brief finishes the change; an independent verify brief follows.

Coverage map (requirement → items): **R1** *A model id is a single-segment provider plus a model that may
contain `/`* → 1.1–1.2 (one shape judgement), 2.1–2.2 (model extraction in readers), 3.1–3.5 (fixtures for every
scenario), 4.1 (gate and report).

How each scenario is re-checked (run what → read which part → expected value):

| Scenario | Run | Read | Expected |
|---|---|---|---|
| three-segment accepted by every write route | the four writes against a fixture (`config-cli.sh shape`) | exit codes; contract lines; `config list --json` | `0/0/0/0`; ids verbatim; id in `models.known` and the `dev` row |
| suffix stripped first, kept in the value | `team config set TEAM_DEFAULT_MODEL kimi-coding/kimi-for-coding:high --yes`; `team config set-agent-model dev openrouter/amazon/nova-lite-v1:high --yes` | exit codes; written lines | both 0; `:high` stored verbatim |
| shape stays closed, message names the segment | the reject matrix (`a`, `/a`, `a/`, `a//b`, `a/b/`, `a/:high`, `a:q/b`, a value with a space; then `/a`, `a/`, `a//b` via `set-agent-model`; `a//b` via `add-agent --model`) | exit codes; messages; sha256; audit | 4 each; `provider`/`model` named; nothing written (the roster too) |
| one judgement, not one copy | `TEAM_CONFIG_TREE=<scratch> bash skills/teamsmith/tests/config-cli.sh shape` (`flip-shape` builds the scratch tree) | the run's rc and its red lines | scratch tree red naming `a//b` on all three routes; unmodified tree green |
| renderers split at the first `/` | `team dispatch dev <id> <brief> --print` with the 3-seg default; `team up --print` with a 3-seg `TEAM_PM_MODEL`; a launch template carrying `{model}` | the rendered commands | `--provider openrouter --model amazon/nova-lite-v1`; placeholder `amazon/nova-lite-v1` |
| window from both sources | `team ps` with the scratch catalogue; then with `TEAM_MODEL_WINDOWS='openrouter/stealth/union-alpha=300000'` | the WINDOW row for that model | `131k`, not `?`; then `300k` |
| read surfaces and the picker | `team config list --json`; `bash skills/teamsmith/tests/panel-choices.sh`; `bash skills/teamsmith/tests/panel-p21.sh` | `models.known`; `choices.values`; picker frame; receipt; the contract line | ids verbatim; the picker lists the 3-seg id; selection writes the full id |

Path grants (OWNERSHIP): the apply agent may touch only `skills/teamsmith/scripts/lib/cmd-config.sh`,
`skills/teamsmith/scripts/lib/common.sh`, `skills/teamsmith/scripts/lib/cmd-agents.sh` (implementation, granted
by this change), `skills/teamsmith/tests/**` (agent-owned), `openspec/changes/model-id-shape/**` (the phase
owner's) and its own `docs/team/reports/P102-*.md`. It must not touch `openspec/specs/**`, `docs/team/tasks/**`,
the other `docs/team/*.md` ledgers, `.pi/**`, or `skills/teamsmith/scripts/panel/**` (the picker consumes
`models.known` and the owning command's message; no panel source changes).

Fixture notes: every new fixture clears inherited identity (`env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT
-u TEAM_SESSION -u TMUX -u TMUX_PANE`, as `config-cli.sh` already does) and writes only inside its own scratch
tree; the window fixture points `TEAM_PI_AGENT_DIR` at a scratch `models.json` and never reads the real
`~/.pi/agent`; the pty case runs under the existing `panel-p21.sh` harness. No fixture touches a real tmux
server, the network, or a model endpoint.

## 1. One shape judgement (apply, R1)

- [ ] 1.1 `cmd-config.sh`: add `team_config_model_violation <model>` (prints the reason; exit 0 and empty stdout
  when valid) implementing the shape from the delta: at least one `/`; provider (before the first `/`) non-empty
  and without `:`; model (after the first `/`) with the optional suffix removed at its first `:` — body
  non-empty, every `/`-separated segment non-empty; no whitespace. Route the `model` kind and the `pairlist` kind
  of `team_config_validate_value` through it (the pairlist message keeps the seat context), and reduce
  `team_config_model_shape_ok` to its boolean wrapper so `set-agent-model` and `add-agent --model` judge with the
  same code. Verify: `team config set TEAM_DEFAULT_MODEL openrouter/amazon/nova-lite-v1 --yes`,
  `team config set-agent-model dev openrouter/amazon/nova-lite-v1 --yes` and `team config set TEAM_AGENT_MODELS
  'dev=openrouter/amazon/nova-lite-v1' --yes` all exit 0 against a fixture; `a`, `/a`, `a/`, `a//b` still exit 4.
- [ ] 1.2 Messages and codes: replace the "恰好一个 /" wording with a segment-naming reason (`provider` for a
  missing/empty/colon-carrying provider; `model` for an empty body, an empty segment or whitespace) in
  `team_config_validate_value`, `set-agent-model` and `add-agent --model`; keep exit 4 for every refusal and keep
  the "nothing written, sha256 unchanged" property. Verify: each reject-matrix command's tail names the segment;
  `sha256sum` of the contract is unchanged after the whole matrix; `state/config.log` gained no `result=ok` line.

## 2. Model extraction in readers (apply, R1)

- [ ] 2.1 `cmd-agents.sh` `team_pi_args` and `common.sh` `team_pm_pi_args`/`team_agent_expand`'s `{model}`:
  `${model##*/}` → `${model#*/}` (everything after the provider), and align the `dispatched … model=…` line the
  same way. Verify: with `TEAM_DEFAULT_MODEL=openrouter/amazon/nova-lite-v1`, `team dispatch dev <id> <brief>
  --print` prints `--provider openrouter --model amazon/nova-lite-v1`; with `TEAM_PM_MODEL` set to the same id,
  `team up --print` does too; a launch template containing `{model}` expands to `amazon/nova-lite-v1`.
- [ ] 2.2 `common.sh` `team_model_window_from_pi`: `model="${want##*/}"` → `model="${want#*/}"` (the catalogue id
  is the whole model part). Verify: scratch `models.json` (`openrouter` → `stealth/union-alpha`, `contextWindow`
  131072) + `TEAM_DEFAULT_MODEL=openrouter/stealth/union-alpha` makes the `team ps` WINDOW row read `131k`; with
  `TEAM_MODEL_WINDOWS='openrouter/stealth/union-alpha=300000'` it reads `300k`; a two-segment id's window is
  unchanged.

## 3. Fixtures (apply, R1)

- [ ] 3.1 `config-cli.sh` `shape` section (registered in the default `SECTIONS` list): the accept matrix (the
  four write routes, both suffix spellings), the reject matrix with exit codes and segment-naming messages
  (`add-agent --model a//b` included), the verbatim `config list --json` read-back (`models.known`, the `dev`
  row), and the audit/sha invariants. Verify: `bash skills/teamsmith/tests/config-cli.sh shape` exits 0 with
  every assertion green.
- [ ] 3.2 The `flip-shape` section: copy the tree, widen the single predicate to accept any token containing `/`
  in `team_config_model_violation`, run `TEAM_CONFIG_TREE=<scratch> bash skills/teamsmith/tests/config-cli.sh
  shape` and require non-zero with `a//b` named; run the same on the unmodified tree and require 0. Verify:
  `bash skills/teamsmith/tests/config-cli.sh flip-shape` prints the two rcs and both match.
- [ ] 3.3 Renderer and window assertions in `config-cli.sh` (fold into `shape` or the `models` section): the two
  `--print` renderers, the `{model}` expansion, and the catalogue-window fixture from 2.2 (`team ps` reads
  `131k`/`300k`, not `?`). Verify: the same `config-cli.sh shape models` run is green.
- [ ] 3.4 `panel-choices.sh`: a three-segment id in the `known` fixture so `models.known`, the model/pairlist
  `choices.values` and the `walk` gate carry it and the validator accepts every offered value. Verify:
  `bash skills/teamsmith/tests/panel-choices.sh` exits 0.
- [ ] 3.5 `panel-p21.sh`: extend the seat-picker case so a three-segment known model is listed and selected (the
  contract line and the receipt carry the full id). Verify: `bash skills/teamsmith/tests/panel-p21.sh` exits 0
  with that case green (real pty process; the CLI fixtures remain the requirement's primary evidence).

## 4. Gate and report (apply, R1)

- [ ] 4.1 Run the brief's acceptance commands on the final tip and write `docs/team/reports/P102-<agent>.md`
  with the red/green matrix, the flip transcript and the gate's summary line: `openspec validate --all --strict`,
  `bash skills/teamsmith/tests/config-cli.sh`, `bash skills/teamsmith/tests/panel-choices.sh`, and the full
  `bash skills/teamsmith/tests/smoke.sh` before delivery (local mode: leave the branch in the worktree, no push).
