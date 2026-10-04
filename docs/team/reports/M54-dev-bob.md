# M54 · settings-choice-editors proposal

agent: dev-bob   status: DONE (proposal; pending PM proposal review)   time: 2026-09-21T04:45:00Z
branch: `task/M54-schema-bool-enum-model`   PR/MR: -（local 模式：不 push；分支留在 `.worktrees/dev-bob`，PM 独立复验后本地合并）
change: `settings-choice-editors`（phase: propose，只出提案包）

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/settings-choice-editors/proposal.md` | 632-word proposal: the schema already knows the choices, the read exposes them additively, the console stops showing a blank box. |
| `.../design.md` | Context, root cause, decisions D0–D9: field shape, the `suggest` column, per-kind editors, unset honesty, project-only model vocabulary, the unmoved write path, mouse parity, the consistency gate. |
| `.../specs/panel/spec.md` | ADDED: the choice editor (10 scenarios, incl. the enum flip). MODIFIED: the write requirement with all 7 base scenarios kept. |
| `.../specs/memory-and-deps/spec.md` | ADDED: the `choices` read contract (4 scenarios, incl. the bad-suggestion gate). MODIFIED: the seat-model requirement with all 7 base scenarios kept, plus the PM-known-set scenario. |
| `.../tasks.md` | 4 batches → 2 apply briefs (A1 = read, A2 = console), coverage map, path grants, flips F-A…F-D. |
| `.../.openspec.yaml` | change metadata (`schema: spec-driven`). |

Commits: `ea9d3e7` (proposal + metadata), `9279259` (proposal word budget), `9b1c60e` (design), `fe9e0ec` (both
deltas), `83abf23` (tasks), `4415ee2` (design: catalogue cache cited as measured twice), `f8bd790` (this report),
`747f926` and its follow-up (pairlist wording made consistent with the write requirement; docs only).

## Recon — the brief's facts, re-verified

```text
$ bash skills/teamsmith/scripts/team config list --json | python3 -c '…'
fields  ['class','comment','default','form','kind','known','name','route','set','value','warning']
kinds   {'bool': 22, 'path': 18, 'text': 17, 'int': 13, 'seconds': 11, 'cmd': 5, 'mb': 5, 'bytes': 4,
         'tpl': 3, 'enum': 3, 'model': 2, 'pattern': 1, 'winlist': 1, 'pairlist': 1, 'list': 1, 'pct': 1}
classes {'apply': 48, 'restart': 24, 'refuse': 36}
known   ['deepseek/deepseek-flash', 'kimi-coding/k3-256k', 'openai-codex/gpt-5.6-terra:xhigh']

$ python3 -c '…'   # the model-catalogue evidence
retired models.json.bak-20260921-031641 providers: ['sub2api','ollama','deepseek','openrouter']
sub2api baseUrl: http://<internal>/v1   models: ['gpt-5.4-mini','gpt-5.5','gpt-5.6-luna']
live models.json providers: ['ollama','deepseek','openrouter']
models-store.json bytes: 303800   providers: ['kimi-coding','deepseek','xai','openai-codex','openrouter','zai-coding-cn']
```

**One correction to the brief's evidence:** `sub2api` is **no longer in the live catalogue** — `models.json` was
rewritten on 2026-09-21 (the `.bak-20260921-031641` file is what still names it, `baseUrl
http://<internal>/v1`; that backup also holds a credential and nothing in this change copies it). The
underlying fact is unchanged and is what the design rests on: the cache is large and live (measured 200 652 bytes
at the start of this recon, 303 800 bytes minutes later) and is not a statement about this project's models — the
project's own set is 3 entries.

Also verified in the tree: `team config list --json`'s record carries no `constraints` or choice field
(`cmd-config.sh:496–524`); the console's only editor for a row is the compose line and the write goes
`team config set … --dry-run` → confirmation → `--yes --fingerprint` (`main.tsx:509–530`, `App.tsx`
`mode === 'setting'`); `models.known` omits the `pm` seat and no `team_state_set pm` exists (`cmd-config.sh:536–566`);
the writer has no unset operation (only `set-agent-model <seat> -` removes a pairlist token).

## The four decisions the brief asked for

1. **`--json` field shape (D1).** One additive field per key record:
   `"choices":{"source","values":[],"min","max","empty","note"}`. `source` ∈ `schema|known|none`; `values` is the
   closed domain for `bool`/`enum` and offered vocabulary elsewhere; `min`/`max` are the numeric bounds as strings
   (`''` = unbounded); `empty` says whether the writer accepts `''`; `note` is the command's optional reason. Bool
   labels stay in the zh/en tables (data vs language); `enum` values render verbatim precisely so a value added to
   `constraints` appears without a rebuild. Compatibility: additive; `team config list`'s human table,
   `team monitor --print/--json` and every existing record field keep their bytes.
2. **The write path does not move (D6).** The picker only produces the draft; `--dry-run`, the confirmation, the
   CAS fingerprint, the audit, danger handling and `team config set` as the only writer are the existing ones. The
   MODIFIED panel requirement says exactly that.
3. **Numeric suggestions are schema data (D2):** an optional 9th column `suggest`, not a `kind → value` table —
   one scale cannot fit a kind (`seconds` spans 1…1800, `mb` 512…6144), a kind table would invent options, and a
   separate file would be a third source. The consistency fixture turns a wrong suggestion into a red gate.
4. **Interaction (D7):** the picker reuses the seat picker's mechanism (view line budget, `placedWithHits`
   actions), so every entry is an `↑`/`↓` target and a click target, the wheel scrolls, `esc` returns to the row
   with its focus, and the free-text entry opens the compose editor by key and by click.

Two further decisions worth the reviewer's eye: **unset honesty** (D4 — the writer has no removal, so an unset
key's editor leads with an explicit keep-unset entry that cancels, and this change does not add a writer
operation; recorded as follow-up F1) and **`pairlist` routing** (D3 — `TEAM_AGENT_MODELS`' `enter` moves the focus
to the seats block instead of opening an editor, because the P22 requirement forbids composing that list in the
console).

## Acceptance (the brief's commands, actually run)

```text
# openspec validate green at 596f7b4 and at every commit of this branch (18/18); the fast smoke ran at 4415ee2,
# and the only commits after it are docs inside openspec/changes/settings-choice-editors plus this report — no
# suite section reads them (smoke's only 'openspec validate' occurrence is an AGENTS.md text assertion).
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
… 18 passed, 0 failed (18 items)        # was 17 before this change; exit 0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2172  ✗ 0
smoke 全绿                              # exit 0; 27 real-process sections skipped in FAST, listed by name

$ git status --porcelain
                                        # clean after the report commit
```

Baseline before the change (same tree, `5887509`): `openspec validate --all --strict` → 17 passed, 0 failed;
fast smoke → 2172 ✓ / 0 ✗. This proposal touches no implementation, so the suite's content is unchanged and only
the item count moved (the new change is the 18th validated item).

## Flip evidence

This is a **propose** task: it changes no implementation and no guard, so the usual red-before/green-after pair
does not apply to code. Instead the deltas themselves are falsifiable against OpenSpec's own archive gate, and
both sides were exercised in scratch copies:

```text
$ cp -r openspec /tmp/m54-trial && (cd /tmp/m54-trial && openspec archive -y settings-choice-editors)
Applying changes to openspec/specs/memory-and-deps/spec.md:  + 1 added  ~ 1 modified
Applying changes to openspec/specs/panel/spec.md:            + 1 added  ~ 1 modified
Totals: + 2, ~ 2, - 0, → 0              # exit 0

# red side: the same trial with one scenario deleted from the panel MODIFIED block
panel MODIFIED failed for header "### Requirement: The console writes a project setting only through
`team config set`, after validation and a confirmation" - current spec contains scenario(s) not present in the
modified block: "A concurrent change is refused and nothing is overwritten". Refresh the change spec before
archiving to avoid dropping scenarios.
Aborted. No files were changed.          # exit 1
```

Scenario counts on both sides: `panel` base 138 → 148 (+10 ADDED, the 7 MODIFIED scenarios intact);
`memory-and-deps` base 35 → 40 (+4 ADDED, +1 new in the MODIFIED block, all 7 base scenarios intact).

The apply briefs inherit the flip plan the design fixes (D8): **F-A** drop the PM resolution from `known` → the
model assertion red; **F-B** disable the bundle's `choices` reader → the picker scenarios red; **F-C** leak a
synthetic `sub2api` catalogue entry → the model-entry assertion red; **F-D** a suggestion outside its range → the
consistency gate red; plus the enum flip (new key/new value with the committed bundle, then constraints removed →
visible free-text fallback).

## Boundaries respected

Only `openspec/changes/settings-choice-editors/**` was written by this task (plus this report). No
`scripts/**`, `tests/**`, `extension/**`, `references/**` or base spec was modified, and no writer semantics
(validation, CAS, audit, danger list) or `refuse` key behavior was touched or proposed. The tasks file names the
per-brief path grants the apply phase needs, and the two apply briefs map one delta each (`memory-and-deps` to A1,
`panel` to A2), so the single-writer-per-delta rule holds.

## Notes for the reviewer

1. The `choices` record is emitted for every key, `refuse` rows included, for a uniform read; the console keeps
   refusing to open an editor for them (their route behavior is unchanged).
2. `path`'s existence mark is deliberately an advisory, not a refusal: the command's validator has no existence
   check and this change does not add one, so the console must not claim a refusal the writer would not make.
3. A `bool`/`enum` value already in the file that is no longer in the domain still renders as the current entry
   (the row must not lie about the file); the write remains the command's verdict.
4. Only the field name/shape is a compatibility surface: if the reviewer prefers another name (e.g. `options`),
   the delta and design are the only places that change — the implementation is untouched by this task.
