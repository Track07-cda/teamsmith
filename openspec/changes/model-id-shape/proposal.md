# model-id-shape · proposal

## Why

Pi's model ids are not always two segments: `pi --model openrouter/amazon/nova-lite-v1 -p …` works (rc 0), and
Pi's bundled OpenRouter catalogue keys ids like `amazon/nova-lite-v1` under provider `openrouter`. On 2026-09-28
the user typed `opencode-go/deepseek/deepseek-v4.1-flash` in the panel's seat picker and the CLI refused it: all
write routes implement "exactly one `/`" (`cmd-config.sh`: the `model` kind, the `pairlist` kind, and
`team_config_model_shape_ok`, shared by `set-agent-model` and `add-agent --model`). A legal configuration cannot
be written, and the message ("恰好一个 /") states a rule neither Pi nor this project has.

## What Changes

- **ADDED — `memory-and-deps`** (*A model id is a single-segment provider plus a model that may contain `/`*):
  one shape predicate for every write route; provider = the first segment (non-empty, no `:`), model = the rest
  (non-empty, may contain `/`); the optional `:thinking` suffix is removed before the model is judged, never
  validated, and stored verbatim; whitespace is refused; refusals exit 4 with a message naming the rejected
  segment.
- The predicate becomes the single implementation behind the `model` kind, the `pairlist` kind and
  `team_config_model_shape_ok`; the panel keeps showing the owning command's message.
- Readers that split provider from model take everything after the first `/`: `team_pi_args`, `team_pm_pi_args`,
  the `{model}` placeholder, and `team_model_window_from_pi`. `TEAM_MODEL_WINDOWS`'s syntax and matching are
  unchanged.

## Fact-check against the brief (details in design.md)

- The brief's window note (`model=${want##*/}` ✓) holds only for the `TEAM_MODEL_WINDOWS` branch: the catalogue
  branch prints nothing for a three-segment id (fixture `openrouter`/`stealth/union-alpha` → empty; two-segment
  → `8192`; explicit override → `300000`). Fixed by `${want#*/}`.
- The same last-segment extraction is in the launch renderers; `--model nova-lite-v1` resolves only through Pi's
  fuzzy matcher. Included above; the review may narrow that item.
- New precision, accepted today: `provider:suffix/model` becomes a refusal (a suffix attaches to the model).

## Capabilities

Modified `memory-and-deps` (one ADDED requirement). `deltas: memory-and-deps`.

## Impact

`skills/teamsmith/scripts/lib/{cmd-config,common,cmd-agents}.sh`, tests `config-cli.sh`, `panel-choices.sh`,
`panel-p21.sh`. Out of scope: Pi, `TEAM_MODEL_WINDOWS` syntax, the current default model, catalogue
auto-completion, `dispatch --model` (an ephemeral per-run choice).

## Flip

Red before: the three writes reject `openrouter/amazon/nova-lite-v1` (rc 4); the catalogue window for a
three-segment id is empty. Green after: the writes exit 0, the id round-trips, `team ps` prints `131k`, and both
`--print` renderers carry `--provider openrouter --model amazon/nova-lite-v1`. Break-it: widen the one predicate
to accept any token containing `/` → `a//b` is written and the `shape` fixture turns red; restore → green.

## Boundaries

Propose only: this phase writes `openspec/changes/model-id-shape/**`. Apply may touch only the three script paths
and three test files named in Impact plus its own report; not `openspec/specs/**`, `docs/team/**` (except its
report), `.pi/**`, or the panel sources (the picker needs no change).

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
bash skills/teamsmith/tests/config-cli.sh
bash skills/teamsmith/tests/panel-choices.sh
bash skills/teamsmith/tests/smoke.sh
```

## Evidence the report must contain

The red/green matrix with real output tails (three write routes; the catalogue-window fixture; the two `--print`
renderers), the `shape` flip (scratch tree red naming `a//b`, unmodified tree green), the panel fixtures'
summary lines, and the full gate's summary line.
