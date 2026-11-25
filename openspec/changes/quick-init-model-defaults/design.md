## Context

`skills/teamsmith/scripts/lib/cmd-project.sh` already owns model input resolution in `team_init_model_policy_resolve` and writes both values through `team_config_set_in_file`. In `cmd-bootstrap.sh`, the fresh `--print` branch skips that resolver, and the real branch already passes the resolved pair to `team_cmd_init` as two explicit flags. Keep that handoff and the existing checks on both entries; share default lookup and preview resolution rather than add another way to run init.

## Goals / Non-Goals

- Put first-run model selection before the first effect, with one resolved pair passed to the existing init writer. No changes to config discovery or write targets, profile schema, PM/worker launch or same-task recovery.
- Take a snapshot of the values saved in Pi user settings, not the model a particular Pi launch might choose after applying project settings, trust, authentication, enabled-model restrictions, extensions or recovery.

## Decisions

### 1. Decide whether this is a first run before filling blanks

Keep `common.sh`'s `team_find_config` / `team_load_config` discovery: `TEAM_CONFIG_FILE` (including `--config`) if set, otherwise walk ancestors of the existing identity root. A missing/non-file explicit path already makes discovery return empty without trying alternatives; conversely a path found by `-f` may still fail when loaded. `team_cmd_init` targets `$TEAM_MAIN_ROOT/.pi/team/config.sh` regardless of discovery; `team_cmd_bootstrap` currently treats an empty `TEAM_CONFIG` as fresh and would call init, then reload using the very same discovery. Thus an empty discovery result alone cannot permit the first write.

| Configuration state | Entry result before model selection |
|---|---|
| Explicit path missing or unusable (including unreadable files and dangling links) | Init, bootstrap and preview stop with the selected path; even both explicit model flags do not permit writing somewhere else. Check this at discovery/load for these entry points, before sourcing an unreadable selection or treating discovery failure as absence. |
| No config discovered and the main-checkout init target is already there | Bootstrap, including preview, stops without calling init and names the target. For a usable target, point to the main checkout or explicitly select the actual config with `--config`; for an unusable target, point to the path to fix. Do not automatically discover or use another config. Direct init continues to own that target. |
| Init would use a path that exists but is unusable | Init stops and names its target before effects, even with explicit model flags or `--force`; do not overwrite a directory, unreadable file or dangling link as though it were absent. A symlink to a readable regular config still works. A selected readable config stays on the existing load/validation path; do not add a Bash config parser or repair bad contents. |
| Discovery succeeds with usable config | Bootstrap retains the discovered config and does not invoke init. Init continues to use its current target; a separately selected or discovered config neither redirects its writes nor supplies Pi defaults. With a valid existing init target, normal refresh retains it and `--force` keeps explicit re-render semantics. |
| No selected/discovered configuration and the init target really is absent | Ordinary first-run init/bootstrap may use Pi defaults. `init --force` is explicit re-render, never a default-selection path. |

Use existing discovery/identity and ordinary file presence, including a link before dereference, plus usability on the paths actually selected or about to be used. Do not reimplement discovery, add owner/mode policy or repair an unusable config. These refusals happen before default lookup, previewing a runnable plan, or any project effects. Only after the configuration path can proceed do the model input rules below apply.

| Model input | Task map | PM value | Pi default lookup? |
|---|---|---|---|
| First run, neither flag | `routine`, `analysis`, `verify` | same model, stored separately | once |
| First run, `--pm-model` only | three defaults | explicit value | once |
| First run, `--task-models` only | exact explicit map | saved default | once |
| Both flags supplied | exact explicit map | explicit value | no |
| Existing, without re-render | preserve existing values; differing explicit flags still refuse | preserve existing value | no |
| Explicit init re-render | valid existing or explicitly replaced values | valid existing or explicit value | no |

Validate supplied flags with `team_config_validate_value` before considering any default lookup. Keep existing refusal for a bad explicit value. Missing/damaged existing model values use the existing config repair or explicitly valid re-render path, not first-run advice. Keep `team_config_legacy_model_keys` and `team_legacy_model_route_lines` ahead of the default path; legacy refusal, derivation and both migration routes remain unchanged (also in preview and with force). Save only `TEAM_TASK_MODELS` and `TEAM_PM_MODEL`. The model policy in `memory-and-deps` remains complete and separate before effects; a PM model is populated directly, never borrowed from the stored task map. No second capability change is needed.

### 2. Read user settings once, without starting Pi

Use `team_js_runner` from `common.sh` and its existing runtime selection to read JSON as data. Read `settings.json` from `PI_CODING_AGENT_DIR` (including the usual `~/` home expansion) or `$HOME/.pi/agent` when no directory is set; a supplied directory is not a search list. This is not `TEAM_PI_SETTINGS_FILE` (the plugin detection input). Do not call `pi`, use a Pi SDK or require a Pi executable on PATH at this point. A missing runner, unreadable file, unparseable JSON or absent/unrepresentable model fields means no usable saved model. Only extract the needed fields; no settings dump or raw parser exception in output. Explicit pairs, re-entry, and path or explicit-value refusals do not invoke this lookup. Do not conflate that with existing dependency or plugin checks: after a successful real bootstrap, `team_required_dep_issues` can still use `team_magic_context_version`, which looks at `TEAM_PI_SETTINGS_FILE` (default `$HOME/.pi/agent/settings.json`), possibly the same file. Keep that package check and the existing plugin checks unchanged.

Use the saved `defaultProvider` and `defaultModel` strings together, without trimming, splitting again or inferring a missing provider. A provider must occupy the provider segment (no `/` within it); preserve the full model ID, including embedded `/`. Reject values that cannot be passed intact as single-line arguments (including NUL), and use the existing model/map writer validation for the assembled values. Do not inspect `models.json`, `auth.json`, `trust.json`, project `.pi/settings.json`, installed extensions, model catalog or session state. A shape accepted by the writer is not a provider-availability or authentication check.

For thinking level, try the saved `modelThinkingLevels["<provider>/<model>"]` for the exact saved model, then the saved `defaultThinkingLevel`, then the original model ID unchanged. Try an optional level only if it is a nonempty string that can be appended as one unambiguous `:suffix`. Never split a saved model ID at its colon; if it already contains a colon, leave it intact rather than append an ambiguous suffix. Check NUL and line breaks in the JSON reader before handing any value to Bash: discard an optional level with those characters, and reject an invalid base ID rather than truncate it. Judge each candidate with the existing writer rules for **every field it fills**. For example, `high=bad` breaks the map token's one-`=` rule (`common.sh`, `team_task_map_violation`), even if the PM value's model shape accepts it; when a map is missing, try the saved general level next instead of rejecting a usable base model. Do not serialize a built-in level, maintain a list of Pi's levels/models, or reinterpret explicit input. `cmd-config.sh`'s `team_config_model_violation` judges the body before the suffix and the writer stores the complete value; `team_pm_pi_args` and the worker launch path in `cmd-agents.sh` pass everything after the first `/` to `--model`. Thus `vendor/nested/model:high` keeps its complete ID and suffix on both paths. Later personal defaults never cause Teamsmith to reselect the saved project model; a model without a suffix can still use Pi's then-current thinking behavior.

### 3. Share the result, not just the helper

Replace the fresh `--print` bypass at the start of `team_cmd_bootstrap` with the same resolution used for real init/bootstrap. Distinguish three outcomes: complete pair, unavailable default on a first run (possibly one explicit value), and an input/config refusal. A real first run with missing values exits 4, before window rename, install, files, worktrees or Pulse. Only the fresh missing-default preview continues read-only with the partial result; invalid flags and existing config refusals do not become a preview success. Keep the five plan stages and existing `--print` exit 0 for a missing-default preview. Replace the model placeholders in the summary and step 1: show actual values or mark only missing inputs; with missing values label the step pending rather than print a runnable-looking `init` with placeholders. When a valid config already exists, say the actual config will be retained in step 1 rather than show an init command that bootstrap will skip.

For a complete fresh result, keep `cmd-bootstrap.sh`'s current `team_cmd_init … --task-models "$task_models" --pm-model "$pm_model"` handoff and the resolver's existing two model lines on success. Init checks both now-explicit values and the write target as before. It does not look up the Pi default again. Keep init rendering/install order and writer validation, and reload bootstrap's config only after successful init. Do not add an internal call layer, flag, environment switch, or another writer to skip validation. Preview is not a lock: a later command selects from its own inputs; to pin the pair shown, provide both flags. Existing bootstrap re-entry still skips init, including the AGENTS refresh; normal explicit `init` refresh and existing `--force` consequences are not broadened.

### 4. Replace mandatory model questions with the shortest default path

Keep the init checklist and its Pi version/plugin checks. The model part explains defaults and optional customization first; only ask for a value that has not been provided when the user chooses to override it or the saved default cannot supply it. The delta updates both checklist requirements directly, without removing the model topic or changing other checklist rules. Use “Pi 用户设置中保存的默认模型” / “the default model saved in Pi user settings”, not “the model Pi would choose now”. Keep independent verification by a non-implementer even if they use the same model.

Representative wording with `vendor/model` saved and only the task map missing in the error example:

| Surface | 中文 | English |
|---|---|---|
| Help examples | `team init`；`team bootstrap --print` → `team bootstrap` | `team init`; `team bootstrap --print` → `team bootstrap` |
| Success or resolved plan | PM、`routine`、`analysis`、`verify`：`vendor/model` | PM, `routine`, `analysis`, `verify`: `vendor/model` |
| Missing | `bootstrap: 缺少任务类型模型。请在 Pi 保存默认模型，或给 team bootstrap 加上 --task-models。` | `bootstrap: Task models are missing. Save a default model in Pi or pass --task-models to team bootstrap.` |

Use `init` in the corresponding init error, `--pm-model` when only PM is missing and both flags only if both are missing. When Pi settings cannot be read, say so without presenting the raw file or exception. Keep the parser's refused retired flags (`--model` and `--default-model`); derive the correction from the configuration state above without a Pi lookup. Give a fresh project the simpler current command, keep existing-project configuration and upgrade routes as applicable, and point to the selected path if it cannot be used; leave existing legacy advice and `config upgrade-models` examples as they are. Preset categories remain ordinary editable project categories, not required engine categories or a rule that infers task type.

## Risks / Trade-offs

- A saved default can be absent, stale, or different from a project-specific Pi override. Report only what initialization would save and let normal Pi launch handle availability; never replace it with a guessed valid model.
- Missing model selection must stop before a real run renames a tmux window or writes files. The `--print` exception only renders the incomplete first-run plan.
- Keeping first-run guidance and examples consistent matters: the old two-model example is useful for explicit overrides, not a default. The checklist and plan layout stay; only the model questions and model lines change.

## Migration Plan

No project migration. Apply only after independent proposal review is accepted, and verify in private projects before any source adoption. Existing authorization and migration paths are unchanged. Reverting the source returns first-run commands to requiring explicit inputs; projects already initialized by this change can keep their two ordinary model fields, with no cleanup or process changes.
