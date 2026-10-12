# P233 · P229 独立复验（发布工具与发布清单）

task: P233
agent: dev3
phase: verify
category: verify
change: -
anchor: none (infra) — 对发布工具与发布清单做独立复验，不写交付代码、不改产品契约行为
deltas: -
branch: task/P233-p229-verify
deps: P229（apply 已交付 tip `7663ec663f91`）

## 复验对象

`docs/team/tasks/P229-release-readiness.md` 的实现：`docs/team/tools/{release-check.sh,publish-public.sh}`（进仓）、`docs/team/RELEASE-PUBLIC.md`（新清单）、`.gitignore` 去掉两条忽略。作者自报：自测 4/4、发布前恰好 1 条红（HEAD 领先 tag）、临时 clone 演练全绿、FAST ✓3897 ✗0。

## 必须自己做的检查（不许只复跑作者脚本）

1. **冻结输入**：独立 clone（`git clone --no-local --single-branch --branch task/P229-release-readiness`，detached 到 `7663ec663f91`），记录 HEAD、确认 `.git` 是真目录、树干净；自己另建 `/tmp` scratch 做变异。
2. **自测有牙**：`release-check.sh --self-test` 4/4；再**自己造**两条变异（不在作者那四条里）——例如把 `package.json` 的版本与 README 的一处 pin 同时改错、把最新 tag 指向一个非 HEAD 祖先的提交——每条都必须被抓且点名。
3. **两面扫描语义**：接真名单（`.pi/team/forbidden-names.txt`）跑 `publish-public.sh`，确认它现在**红在已知的 13 行对端名**（这是已排队清理 P231 的对象，**不是 P229 的缺陷**：报告里要写清这 13 行在哪、为什么在、以及它与账本面 `ledger-ban.sh` 的分工）；名单缺失时必须 **exit 3 可见跳过**而不是通过。
4. **不假绿**：把导出/安装路线各破坏一次（例如把 `skills/` 从 npm 包里排除、把 `install.sh` 的软链目标改错），对应检查必须红且点名。
5. **清单可执行**：照 `RELEASE-PUBLIC.md` 在一句话层面核对步骤顺序（版本落点 → tag → 分两次推 → npm → 发布后验证），确认它引用的命令在仓内存在、且没有把不可逆动作写成自动执行。
6. **记录面**：`ledger-ban`（真名单）0 命中；`section-select.sh --paths <改动路径>`；容器内 FAST 一次确认无新红。

## 交付

`docs/team/reviews/P233.md`（抬头必须含 `判定: **PASS**` 或 `判定: **FAIL**` 的机器可读行；逐条命令 + rc + 证据路径）；证据包仓外 `pm-skills-ledger/team/reports/P233-dev3/`；不改候选、不合并、不推送；结论按协议通知 PM。
