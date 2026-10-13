# V26 · P239（账本禁令对报告类改动开火 + 报告模板固定验收行）独立复验

task: V26
agent: dev
phase: verify
category: verify
change: -
anchor: none (infra) — 对门禁选段归属与报告模板改动做独立复验
deltas: -
branch: task/V26-ledger-claim-verify
deps: P239（apply 已交付，tip 见任务消息）

## 复验对象与动机

P239 要解决的是**第四次同族缺陷**：交付报告里带回真家目录/对端名，而作者自己的验收抓不到——因为选段器对 `docs/team/**` 一律「不开火」，且账本禁令段只 claim 了自己的脚本路径。P239 的做法：`section-paths.tsv` 支持 `# ledger-scan:` 表头把 `docs/team/*` 归到 §60，并新增 `tests/ledger-claim.sh`。

## 必须自己做的（不许只复跑作者脚本）

1. **归属真的生效**：在你自己的分支上造一份报告改动（例如改你这份复验报告），`bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/<你的文件>.md` 必须 `RUN` 且 `reason=60`；再 `bash skills/teamsmith/tests/smoke.sh --paths docs/team/reports/<你的文件>.md` 确认只跑前导 + §60。
2. **牙齿**：在 scratch 副本里往一份报告**植入一个家目录字面量** → §60 必须**红并点名 file:line**；删掉 → 绿。植入到 `docs/team/` 下**别的**子目录（例如 `docs/team/threads/`）也要同样被咬住（表头的 glob 覆盖范围自己核）。
3. **反自指**：确认 `# ledger-scan:` 只出现一行；确认 §60 行**没有**把 `docs/team/**` 写进 patterns 列（那是老规矩被放宽的信号）；`section-select.sh --check` 仍 `ok` 且 `bad 0`。
4. **不改既有强度**：逐条看 `smoke.sh` / `section-paths.tsv` / `section-budgets.tsv` / `section-select.sh` 的 diff——是「新增归属」还是「删断言 / skip 换绿」；新增的跳过必须有名有理由。
5. **预算**：新增/改动的段行要有实测用时依据；§60 现在多扫了账本面，贴出它的用时并与预算对比。
6. **容器内一次**：`smoke.sh --select 36,60`（或按你实际改动选段）在钉死容器 + 干净 clone 里跑一次，贴结果与红/跳过归因。
7. **同命令对照**（PM 的教训，必须写进报告）：若要声称「某条红是既有红」，必须在 **v0.1.2（`69692a6`）** 上用**同一条命令**复跑并贴数字，不许拿父 tip 或不同 `--select` 当基线。

## 交付

`docs/team/reviews/V26.md`（抬头含机器可读的 `判定: **PASS**` / `判定: **FAIL**` 行；逐条命令 + rc + 证据路径；写明运行模型）；证据包仓外 `pm-skills-ledger/team/reports/V26-dev/`；不改候选、不合并、不推送；结论按协议通知 PM。
