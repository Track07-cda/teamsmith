# P243 · 改产品侧路由逻辑时，选段必须选中 §61/§61b（覆盖边界）

task: P243
agent: dev3
phase: apply
category: infra
change: -
anchor: none (infra) — 门禁选段登记，不改产品行为
branch: task/P243-routing-paths-coverage
deps: P238（已并入 main，V28 PASS）

## 缺陷（V28 的 nit 3，PM 复核后立项）

`section-paths.tsv` 里 §61/§61b 的 patterns **只登记夹具文件**（`tests/task-model-routing.sh`、`tests/lib/model-routing-*`），且表里没有任何行 `needs:61`。后果：**改产品侧的路由逻辑（`scripts/lib/cmd-agents.sh`、`common.sh` 的类别/模型解析、`cmd-config.sh` 的映射读写、`cmd-watch.sh` 的续跑）时，`--paths` 选段不会选中 §61/§61b**——只有全量门禁才会。也就是说：日常按改动跑选段（本项目推荐的资源纪律）时，路由产品的回归不会被路由测试咬住。

## 要求

1. 让「改动集含产品侧路由路径」时选段**包含** §61（必要时含 §61b）；做法你定（给这两段补 patterns，或加 `needs:` 关系），但要给出选段的实测：改 `scripts/lib/{common,cmd-agents,cmd-config,cmd-watch}.sh` 后 `section-select.sh --paths <这些文件>` 的输出**包含** 61。
2. **不许把选段面放大到人人付费**：改一个与路由无关的文件（例如 `panel/` 或 `references/`）时，选段**不应**因此带上 §61/§61b；给这条反向证据。
3. 成本要可见：§61 在 FAST 约 123s；若 §61b（live 82 分）因此被选中，必须在输出里能看出来（选段输出与本段的行齐备）。是否把 §61b 也绑到产品路径上，你给判断与依据（PM 的倾向：**只绑 §61，不绑 §61b**——因为 §61b 是夹具自证，且它的成本太高；除非你能给出低成本又有牙的做法）。
4. 顺手修 V28 的另一条 nit：`section-budgets.tsv` 里 §61b 的实测带 4900s 已被实测 4946s 突破，抬到 ≥5000s 并在报告里注明依据（实测 4946s + 余量）。**注意**：该文件正被 P242 持有——若 P242 尚未合并，先做本任务第 1–3 条，把这条留给 P242（在报告里写明）。

## 验收（贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/lib/common.sh skills/teamsmith/scripts/lib/cmd-agents.sh
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/panel/panel.mjs
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

**红侧**：把新加的 patterns/`needs:` 去掉 → 第 1 条的选段结果不再包含 §61（还原后复绿）。

## 交付

`docs/team/reports/P243-dev3.md`（两条方向的选段前后对照、成本说明、nit 处理与归属、未做项）；不合并、不推送；做完 `team notify pm`，随后由未写过本任务的席位独立复验。
