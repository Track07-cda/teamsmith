# P239 · 让账本禁令对「报告类改动」必然开火（+ 报告模板固定验收行）

task: P239
agent: dev3
phase: apply
category: infra
change: -
anchor: none (infra) — 门禁选段归属与报告模板，不改产品契约行为
branch: task/P239-ledger-claim
deps: -

## 缺陷（PM 2026-10-13 实测，同族第 4 次）

同一个坑已经出现四次（P206、P208 那一族、P230、P237）：**交付报告里带回真家目录/对端名，而作者自己的验收没抓到**。这次（P237）的机制终于查清，两条：

1. **选段器不给账本路径开火**：`bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/P237-dev.md` → `keys=0`、`没有段落需要运行`（`docs/*` 是豁免类）。而 §60（账本禁令）在 `section-paths.tsv` 里只claim 了 `tests/ledger-ban.sh` 与 `tests/lib/tmp-root.sh` —— **没有人claim `docs/team/**`**。于是报告类改动「不跑任何段落」，而报告恰恰是泄漏最常出现的地方。
2. **在主检出跑该检查扫不到分支上的报告**：作者的验收命令虽然写了 ledger-ban，但若在主检出执行，新报告还没进那棵树 → `hits=0` 假绿。PM 实测同一份文件：在 `.worktrees/dev` 里跑 `files=1368 hits=1`（点名 `docs/team/reports/P237-dev.md:29`）；在主检出跑 `files=1369 hits=0`。

## 要求

1. **选段归属**：让「写/改账本文本」的改动必然选中账本禁令段。做法你定（把 `docs/team/**` 归到 §60，或新立一个只跑账本禁令的段并claim 这些路径），但必须满足：
   - `section-select.sh --paths docs/team/reports/X.md` → **包含**该段（不再是「没有段落需要运行」）；
   - 该段在**被测分支的工作树里**对**该分支的树**开火（不是主检出的树）；
   - 段成本要有实测数字（现在 1369 文件几秒量级），并登记预算行；
   - 不要因此让每次都跑整套门禁：只加这一段。
2. **报告模板**（`skills/teamsmith/templates/report.md.tmpl`）加一条**固定验收行**：账本禁令必须在**自己的 worktree / 自己的分支树**上跑，并贴 `hits=` 与 `rc`（写明「在主检出跑扫不到本分支新文件」这句警告）。
3. **红侧**（三条，各给可跑的失败证据）：
   - 在 scratch 副本的**某份报告里植入一个家目录字面量** → 新归属下 `section-select` 选出的段跑起来必须**红并点名 file:line**（植入前绿）；
   - 把该归属从 `section-paths.tsv` 去掉 → 同一改动不再选中该段（回到「没有段落需要运行」）；
   - 在**主检出**跑同一检查对同一份分支文件 → 复现 `hits=0` 假绿（把这条写成夹具里的对照，说明为什么要求「在自己的 worktree 里跑」）。
4. **不改产物行为**：只碰 `skills/teamsmith/tests/section-paths.tsv`、`section-budgets.tsv`、必要时 `smoke.sh` 的段登记、`skills/teamsmith/templates/report.md.tmpl`；不碰产品代码与既有断言强度。

## 验收命令（贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/P239-dev3.md
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/smoke.sh --select <新/改动的段号>
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

## 交付

`docs/team/reports/P239-dev3.md`（两条机制实测、三条红侧前后证据、段成本数字、模板改动说明、未做项）；证据包按 D94 放仓外；不合并、不推送；做完 `team notify pm`，随后由未写过本任务的席位独立复验。
