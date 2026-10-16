# P299 · `init` 信任提示两处新契约的 falsifier（`slash-team` 3.3）

task: P299
agent: dev
phase: apply
category: code
change: slash-team
specs: init-skill
deltas: -
branch: task/P299-init-trust-falsifier
deps: P270（已并入）、V50（复验 PASS）、P298（**3.3 是唯一未勾项，缺口形态＝缺 falsifier**）

## 现场（P298 的 G1，我核过两侧）

**实现侧已做**：`cmd-init.sh:298` 打印的那行确实同时点名 `.pi/skills/` 与 `.pi/extensions/`，`--no-skills` 不打；`skills/teamsmith-init/SKILL.md` 与 `references/bootstrap.md` 也都提到了 `.pi/extensions/`。
**缺的是**：`init-skill` 那两条**新增契约**没有 **falsifier**——没有夹具断言「这行必须同时点名两处、且 `--no-skills` 时安静」，也没有「删掉再搜必红」的翻转臂。

## 要做什么

1. **加断言**（放进既有合适入口，别新开套件）：安装面夹具里断言 `team init` 的输出行**同时**含 `.pi/skills/` 与 `.pi/extensions/`（并点名 `/trust` 与 `--no-skills` 三条出路里的关键字）；`--no-skills` 时该行**不出现**。
2. **加红侧**：① 把输出行里的 `.pi/extensions/` 删掉 → 夹具必须红并点名该行；② 让 `--no-skills` 也打印该行 → 必须红（我们要求它在那种情况下安静）。
3. **文档同步的 falsifier**：在两个 init 文档里任选一处，断言「`.pi/extensions/` 与该行的关键字同页出现」——用**稳定 token**（不是整句），删掉该 token 必红（照 `init-skill` 场景 3 的形态）。
4. **不许**为了绿放宽既有断言；**不许**改那行输出本身的语义（三答案、一行、`--no-skills` 安静）。
5. 交付验收只跑**闭包选段**（D-口径），贴结果与 `/tmp` 根数前后。

## 验收

```bash
bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/smoke.sh --select <上面打印的段号>
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
