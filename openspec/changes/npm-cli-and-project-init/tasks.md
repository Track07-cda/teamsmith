# Tasks: `npm-cli-and-project-init`

Planning only — nothing in this file is executed by the propose task (P37). **One apply brief** can finish the
change: the pieces are small (a ~60-line wrapper, a flag-guarded block in `team init`, a doctor row, text) and
they interlock — the fixture that proves the install matrix also packs the tarball and runs the wrapper — so the
split is by *file*, not by an intermediate mergeable state. If the PM prefers two briefs, the order is
**A1 = items 1–2 (code, manifest, fixture)** then **A2 = item 3 (skill text and docs)**, and the verify task must
run only after both, because requirement R1's scenarios are red until A2 lands.

Coverage map (requirement → items): **R1** “Initialization guidance lives in a dedicated teamsmith-init skill”
(the install beat on every surface) → 3.1–3.5; **R2** “team init installs the project skills” → 2.1–2.4, 4.1–4.2;
**R3** “The CLI ships as one npm bin entry and the package carries what it runs” → 1.1–1.3, 4.1;
**R4** “The shell the CLI runs on is a checked dependency, not an assumption” → 1.2–1.3, 4.1;
**R5** “The project-local install is visible in team doctor, and repairable with team init” → 2.5, 4.1.
Docs that carry no requirement (README
alternatives, PUBLISH rehearsal) → 3.4–3.5. Gate/evidence → 4.3–4.4; independent verification → 5.1.

**Path grants the apply brief must state (OWNERSHIP).** Everything below is PM-owned by default and is granted
for this change only, for these paths: `package.json`; new `bin/**`; `skills/teamsmith/scripts/lib/cmd-project.sh`,
`skills/teamsmith/scripts/lib/cmd-bootstrap.sh`; `skills/teamsmith-init/SKILL.md`,
`skills/teamsmith-init/references/bootstrap.md`; `skills/teamsmith/SKILL.md`; `README.md`;
`docs/team/PUBLISH.md`. `skills/teamsmith/tests/**` is the agent's already. `install.sh`, the extension files,
`openspec/**` and every other `scripts/lib/*.sh` are **not** granted. `docs/team/{BOARD,ROADMAP,DECISIONS,
OWNERSHIP}.md`, `docs/team/tasks/**` and `docs/team/reviews/**` stay PM-owned (the report is the agent's own
file).

**Fixture notes (apply must follow).** Every fixture is a fresh git repo under `$TMPDIR`, clears the caller's
`TEAM_*`/`TMUX`/`TMUX_PANE` identity before the first `team` call, and asserts `team paths`' `main_root` is the
fixture before any command that writes. No fixture starts tmux or pi. The headless fixture runs under
`TEAM_SMOKE_FAST=1`; anything needing `npm` prints a visible `SKIP` when npm is unresolvable — never a silent
pass. Every flip is produced by editing a **scratch copy** of the tree (the `config-cli.sh`/`TEAM_CONFIG_TREE`
pattern), never the working tree under test.

## 1. The npm entry (`init-skill` R3 + `memory-and-deps` R4)

- [x] 1.1 `package.json`: add `"bin": { "team": "./bin/team.mjs" }` and add `"bin/"` to `files`. Verify:
  `node -e 'const p=require("./package.json"); if (Object.keys(p.bin).join()!=="team") process.exit(1); if (!p.files.includes("bin/")) process.exit(1)'` exits 0, and the pack walk of 4.1 lists `bin/team.mjs`.
- [x] 1.2 `bin/team.mjs`: the wrapper — resolve the bash CLI from `import.meta.url`
  (`../skills/teamsmith/scripts/team`), probe the shell with `spawnSync(bash, ['-c', 'printf %s
  "${BASH_VERSINFO[0]:-0}"'])`, print the fix and exit non-zero when the shell is missing (`ENOENT`) or the
  probe is not a number ≥ 4, otherwise `spawnSync('bash', [cli, ...process.argv.slice(2)], { stdio: 'inherit' })`
  and exit `status` (signal → `128 + signo`). No subcommand knowledge. Verify: `node bin/team.mjs help` is
  byte-identical to `bash skills/teamsmith/scripts/team help` (`diff <(...) <(...)`), `node bin/team.mjs bogus`
  exits 2, and the two shell failures of 4.1's `shell` section are red→green.
- [x] 1.3 The real user path, not just the file: `npm pack` the tree, `npm install -g --prefix "$T"
  ./teamsmith-<version>.tgz`, and run `"$T/bin/team" version` + `"$T/bin/team" help`. Verify: both match the
  bash CLI (`version` line equal, `help` byte-identical) and the tarball's bin target came out executable
  (`test -x "$T/lib/node_modules/teamsmith/bin/team.mjs"`). Flip: `bin` pointing straight at
  `skills/teamsmith/scripts/team` leaves the old-shell failure without a fix message (4.1 red side).

## 2. `team init` installs the project skills (`init-skill` R2 + R5)

- [x] 2.1 `scripts/lib/cmd-project.sh`: the install step as one function — target `$TEAM_MAIN_ROOT/.pi/skills/`,
  sources `$TEAM_SKILL_DIR` and `$(dirname "$TEAM_SKILL_DIR")/teamsmith-init` (skip + say so when absent),
  modes link (default) / `--copy` (everything except `.git/` and `node_modules/`), `--no-skills` skips, per-skill
  lines `link`/`copy`/`skip`, the conflict table of the design §3 with a non-zero exit and untouched bytes, the
  `.gitignore` line `.pi/skills/` added once. Flags parse in `team_cmd_init` next to the existing ones. Verify:
  4.1's `install` section green, and `bash -n` on the file plus the FAST smoke tail.
- [x] 2.2 `scripts/lib/cmd-bootstrap.sh`: call that same function in **both** branches (the `had_config=1`
  branch included) so re-running bootstrap installs for an existing project; add the step to the `--print` plan
  without writing anything. Verify: 4.1's `bootstrap` section, plus the §1b FAST smoke section stays green.
- [x] 2.3 `scripts/lib/cmd-project.sh` (`team help`): the `init` line names the project skill install plus
  `--copy` and `--no-skills`, the `bootstrap` line names the step. Verify: `bash skills/teamsmith/scripts/team
  help | grep -A3 '^  init'` carries `.pi/skills`, `--copy`, `--no-skills`; the R1 scenario's surface grep.
- [x] 2.4 Conflict and idempotence evidence is the fixture's, not a claim: 4.1's `conflict` section records the
  before/after sha256 of every entry it refuses to touch. Verify: the section's tail, and the `--force`
  replacement's `SKILL.md` bytes equal the source's.
- [x] 2.5 `scripts/lib/cmd-project.sh` (`team doctor`): one row for the project-local install — silent with no
  teamsmith entry; `pass` for a link to `$TEAM_SKILL_DIR` or a copy at `TEAM_VERSION`; `warn` naming the found
  version/target and `team init --force` for a copy from another version, a foreign symlink, or an unreadable
  entry; `warn` never changes the exit code. Verify: 4.1's `doctor` section (three states), plus `bash
  skills/teamsmith/scripts/team doctor` still passing in the smoke fixture.

## 3. Surfaces say the same thing (R1)

- [x] 3.1 `skills/teamsmith-init/SKILL.md`: open with the installation beat — `npm install -g teamsmith`, then
  `team init` in the project (names `.pi/skills/`), with `pi install …` and `./install.sh` kept as the two
  alternatives; adjust the `Preconditions` bullet so it no longer assumes `team` is already on PATH; keep the
  checklist → `team bootstrap` → handoff beats and stay ≤ 100 lines. Verify: `wc -l <
  skills/teamsmith-init/SKILL.md`, the R1 scenario's line-order grep, and `bun skills/teamsmith/tests/skill-load.mjs skills/teamsmith-init`.
- [x] 3.2 `skills/teamsmith/SKILL.md`: the command-table row for `init` names the project skill install; the
  "Starting a new project" pointer names `.pi/skills/` next to the other install locations. Verify: the R1
  surface grep; **do not** touch the `description`, the version lines or anything P34 is moving (Pi-only
  wording is P34's delta, not this one).
- [x] 3.3 `skills/teamsmith-init/references/bootstrap.md`: the step table gains the skill-install row (target,
  modes, idempotence) and the "what the PM does afterwards" list stays accurate. Verify: `grep -n '.pi/skills'
  skills/teamsmith-init/references/bootstrap.md`.
- [x] 3.4 `README.md` §Install: npm global CLI + `team init` as the primary route (one copy-pasteable block),
  the Pi-package route and `install.sh` as alternatives with what each is for; §Requirements' `bash` row gains
  the "the npm entry checks it and prints the fix" sentence. Verify: the R1 surface grep (line order), and every
  command in the block is real (run 1.3's prefix install against it).
- [x] 3.5 `docs/team/PUBLISH.md` (PM grant): §3's npm checklist gains the rehearsal step — after `npm publish`,
  a scratch project does `npm i -g teamsmith@<version>`, `team init`, asserts `.pi/skills/teamsmith` resolves to
  the installed package and `team doctor` is green — and §0's table gains the pack/bin evidence. Verify:
  `grep -n 'team init' docs/team/PUBLISH.md` shows the step inside §3, and no publish/tag/visibility action is
  performed by the apply.

## 4. Fixtures, gate, evidence (the apply's own report)

- [x] 4.1 New headless fixture `skills/teamsmith/tests/install-shape.sh` (own scratch repos under `$TMPDIR`,
  identity-stripped, no tmux/pi; sections selectable by argument like `config-cli.sh`), with sections:
  `install` (link both entries, linked-worktree target, `.gitignore` once, re-run `skip`, `--no-skills`,
  `--copy` without `node_modules`/`.git`, `bootstrap` on an existing project, `bootstrap --print` writes
  nothing), `conflict` (unrecognisable dir ×2 ×`--force`, hand-edited skill copy ×`--force`, every refusal's
  before/after sha256), `shell` (no `bash`; a `bash` shim answering `3`; the normal path), `pack` (`npm pack
  --dry-run --json` walk + the private-prefix install of 1.3, `SKIP`-visibly without npm), `doctor` (linked /
  absent / drifted copy / foreign symlink, with the repair re-checked), and `flip` (the scratch-tree variants
  that make each red). Verify: `bash skills/teamsmith/tests/install-shape.sh` green, then each flip's red tail.
- [x] 4.2 `skills/teamsmith/tests/smoke.sh`: wire the fixture into the FAST sections the way §33 wires
  `config-cli.sh`, and extend §2's assertions to the main fixture — both entries after `team init`, the
  `.gitignore` line, the second run's `skip`, and that `team dispatch --print` still renders `--skill
  "$SKILL_DIR"` with no `teamsmith-init` (§18b R6 must stay green). Verify: `TEAM_SMOKE_FAST=1 bash
  skills/teamsmith/tests/smoke.sh </dev/null` green, and the new section's failure text on a deliberately broken
  scratch tree.
- [x] 4.3 Gate: `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` and
  `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`, then the **full** smoke once (the slow
  pty sections) — paste the tails; `git status --porcelain` clean after the report commit.
- [x] 4.4 Report: delta→requirement and requirement→item maps; the pack walk with the `bin/` flip; the npm
  prefix shim run; the install matrix's tails; the two shell failures; the three doctor states; the flip tails;
  and one line each that `install.sh`, the extension injection, the other subcommands and `openspec/**` were not
  touched.

## 5. V — independent verification (a different agent)

- [x] 5.1 Rerun on the apply's tip, out of tree: the whole `install-shape.sh` (all flips red and green), the
  FAST smoke, the **full** smoke, `openspec validate --all --strict` (plus a trial archive on a scratch copy of
  `openspec/`), the pack walk, and the npm-prefix install; then hand-check against the delta that R1's base
  scenarios are intact. The record goes to `docs/team/reviews/<ID>.md` with a verdict; a PASS carrying findings
  is rework, not archive.

> **PM 勾选说明（2026-09-22）**：propose=P37 · apply=P40（dev2）· verify=P51（dev，PASS，含 F1 文档行由 PM 当场修正）—— 全部任务项已在各自交付与复验里逐条落实。
