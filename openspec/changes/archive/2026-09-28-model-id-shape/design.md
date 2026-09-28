# model-id-shape · design

The normative text is the delta (`specs/memory-and-deps/spec.md`); this file records why the rule and the fix
look the way they do, the alternatives rejected, and the evidence each claim rests on.

## Evidence that opened the change

Measured on this tree (fixture project, private `TEAM_*` environment), before the change:

```
config set TEAM_DEFAULT_MODEL openrouter/amazon/nova-lite-v1 --yes   → rc 4 「必须形如 provider/model（恰好一个 /）」
config set-agent-model dev openrouter/amazon/nova-lite-v1 --yes      → rc 4 「模型必须是 provider/model 形状（恰好一个 /）」
config set TEAM_AGENT_MODELS dev=openrouter/amazon/nova-lite-v1 --yes→ rc 4 「席位 dev 的模型必须形如 provider/model」
config set-agent-model dev openrouter/amazon/nova-lite-v1:high --yes → rc 4 (same)
config set TEAM_DEFAULT_MODEL kimi-coding/kimi-for-coding:high --yes → rc 0
config set TEAM_DEFAULT_MODEL "a b/c" --yes                          → rc 0   (whitespace reaches the contract today)
config set TEAM_DEFAULT_MODEL p:q/model --yes                        → rc 0
```

and the window fixture (`TEAM_PI_AGENT_DIR` → scratch `models.json` with provider `openrouter`):

```
team_model_window openrouter/stealth/union-alpha → (empty)
team_model_window openrouter/plain-model         → 8192
TEAM_MODEL_WINDOWS='openrouter/stealth/union-alpha=300000' team_model_window … → 300000
```

Pi's side, from its own code (`dist/bundle/chunks/chunk-OJP47DM6.js`): `parseModelPattern` tries an exact match
on the full pattern first, then splits at the **last** `:` and accepts the suffix only if it is one of
`off|minimal|low|medium|high|xhigh|max`; `resolveCliModel` calls it with `allowInvalidThinkingLevelFallback:false`.
`parseArgs` stores `--provider` and `--model` separately, and `resolveCliModel` strips a leading `provider/` from
the model pattern when the provider is given. So Pi's authority is: a model id is provider + everything that
follows, with an optional thinking suffix.

## The shape rule

1. **Provider = text before the first `/`**: non-empty, no `:`. It cannot contain `/` by construction, so
   "exactly one `/`" disappears: `/a` fails (empty provider), `a/b/c` passes (model `b/c`).
2. **Model = text after the first `/`**, with an optional thinking suffix removed first (from the first `:` of
   that text), then judged: body non-empty, and every `/`-separated segment of the body non-empty. `a/`, `a//b`,
   `a/b/`, `a/:high` all fail; `a/b`, `a/b/c`, `a/b:high`, `a/b/c:high` pass.
3. **No whitespace** anywhere (space, tab, newline). Today a quoted `"a b/c"` is accepted into the contract and
   later reaches `--provider a b --model c`-shaped launch rendering; the model kind must refuse it.
4. **Refusal = exit 4 + a message naming the segment**. The old "恰好一个 /" wording goes; each fault names
   `provider` or `model` and the reason (missing `/`, empty segment, whitespace).

Why strip the suffix before the judgement and not validate its vocabulary: the contract's job is to guarantee a
non-empty model name, not to clone Pi's thinking-level table. The repo already forbids a second option table
(`memory-and-deps`: the schema is the choices' only source), and model ids can legitimately contain `:` (e.g.
Ollama's `hf.co/user/repo:Q4_K_M`), which Pi resolves by exact match before it ever looks at a colon. First
colon rather than last: for `a/::high` Pi ends with no model at all, and first-colon stripping refuses it
(empty body) while last-colon stripping would accept `a/:`. `provider/model:bogus` is accepted here and refused
by Pi at launch — the dispatch startup proof already reports that, and it is a model-validity question, not a
shape question.

One intentional narrowing: `provider:suffix/model` is refused. The suffix can only attach to the model, so a
`:` before the first `/` is a typo of the very form the suffix exists for; today the token is accepted and Pi
fails at launch.

## One implementation

Add `team_config_model_violation <model>` (prints the reason; empty and exit 0 when valid) and make the three
existing judgements call it:

- the `model` kind in `team_config_validate_value` prints its reason through the existing
  `"$key=$val 不合法：$reason"` wrapper;
- the `pairlist` kind wraps it with the seat context (`席位 <seat> 的模型：…`);
- `team_config_model_shape_ok` becomes the boolean wrapper, so `set-agent-model` and `add-agent --model` — and
  the panel, which shows the owning command's message — judge through the same code.

Rejected: keep the three copies and rely on tests to keep them equal. The flip scenario (widen the single
predicate → all routes change together) is what proves the promise; with copies, the next write route added
would silently diverge again.

## Model extraction in readers and renderers

`--provider X --model <rest>` is how teamsmith launches a worker (`team_pi_args`, `cmd-agents.sh`), the PM
(`team_pm_pi_args`, `common.sh`) and a custom launch template (`{model}`, `common.sh`). All three use the last
segment today (`${model##*/}`), which for `openrouter/amazon/nova-lite-v1` renders `--model nova-lite-v1`. Pi
resolves that only by fuzzy matching; the model part is everything after the provider, so the renderers use
`${model#*/}` (and `${want#*/}` in `team_model_window_from_pi`, which looks up the catalogue under the provider,
where the id is the whole `stealth/union-alpha`). Two-segment ids expand identically, so every existing
rendered command, window reading and fixture assertion is byte-stable.

Rejected: stop passing `--provider` and hand Pi the full `provider/model` as `--model`. Pi accepts it, but it
changes the rendered command for every existing configuration and fixture, for no behavioural gain.

## Read surfaces and the panel

`models.known`, `choices.values` and the seat rows are plain strings, and a hand-edited three-segment default
already round-trips through `config list --json` today. The picker lists `models.known` and its selection writes
through `team config set-agent-model` — after the validator change the same write that used to be refused
succeeds; no panel source changes. The fixtures pin the vocabulary (headless) and one selection (pty), and the
CLI fixtures pin the write.

## Where the tests live

- `skills/teamsmith/tests/config-cli.sh`: a new `shape` section (registered in the default section list) with the
  accept/reject matrix, the verbatim read-back, the renderer `--print` assertions and the catalogue-window
  fixture in the `models` section; a `flip-shape` section builds a scratch tree whose predicate accepts any
  token containing `/` and requires `shape` to go red there and green here.
- `skills/teamsmith/tests/panel-choices.sh`: a three-segment id in the `known` fixture, so `models.known`,
  `choices.values` and the `walk` gate carry it.
- `skills/teamsmith/tests/panel-p21.sh`: the existing seat-picker case additionally lists and selects a
  three-segment known model (pty; marked real-process, never the only evidence for the requirement).
- Gate: `openspec validate --all --strict` and the full `smoke.sh`.

## Risks and non-goals

- A hand-edited contract still bypasses validation; readers must tolerate arbitrary bytes (unchanged).
- Model-body colons and unknown thinking levels remain Pi's judgement (deliberate boundary; documentation of the
  thinking levels is not duplicated here).
- `references/config.md` needs no change: it shows `provider/model` examples, none of which the new rule refuses.
