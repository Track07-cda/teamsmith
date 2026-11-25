---
id: V200
title: 独立验收 Pulse 看板按更新时间倒序
agent: dev3
deps: P502,V199
category: verify
phase: opsx-verify
change: pulse-board-recent-first
specs: panel,board-and-status
deltas: -
branch: task/V200-pulse-board-recent-first-behaviour-verify
---

# V200 · 验收真实看板读写和排序

实施者 dev-bob，冻结 `78466b22caada29ce916af5e7f84a6dcc56abff0`，独立检出 `/var/tmp/p503-review-78466b22.ok194J`。先读 AGENTS、本人线程、归属、P503、作者交接及已接受 change 的 design/specs/tasks。按 tasks §3 集中验收一次，作者构建/类型/结构记录可引用，不重复这些检查。固定检出保持干净，所有夹具与持久证据只用本人 `/var/tmp` 根。清除继承的项目、tmux 和状态路径，核对私有仓库身份，危及真实环境就停下保留现场，不接触本项目当前看板、Pulse、个人设置或安装。

- **实际行为。** 按作者交接留证 `TMPDIR=/var/tmp TEAM_B3_KEEP=1 bash skills/teamsmith/tests/panel-b3.sh board fold` 和 `TMPDIR=/var/tmp bash skills/teamsmith/tests/smoke.sh --select 4c </dev/null` 各一遍，分别记录实际段和通过/失败数。受控时间下核新增 A/B、实际修改较早 A 后上移、给 B 重复提交原值不抬高；读实际表、内部数据及捕获帧。核等时、旧行、历史首次可见、宽窄、两种滚轮区域和刷新后从键盘/点击打开该任务正文。已接受的旧 M48 业务字段比较与拒绝、重复语义不丢。用该场景保留的私有样本实际对照 `monitor --json` 顶层、`board ls` 文件顺序、同参数 `panel.js --print --page 4` 与 `--snapshot` 的预期差异和计数；不要重起另一套交互验收。
- **一个对照。** 用 A 实际更新后的同一私有样本、同尺寸和同一帧顺序判据，正常/反向比较/恢复各打开一次 `--snapshot`。反向只在私有副本改比较方向并以原构建脚本和固定依赖生成实际加载的 bundle；保存帧、构建及哈希，断言应明确针对 A、B 次序，而不是环境失败或某行没出现。不能重跑整组，也不为它在产品里加开关。验证前后把样本表恢复，保留唯一原件。
- **代码对照。** 确认改动在已审写集，旧业务写入落点/重复寻址没有改义；同一现有锁内读写、成功后上层缓存处理与失败归属，有没有两个排序或有操作在刷新时指到错行。检查继续使用原数据和帧，判断新增代码/测试与删掉的重复是否相称；足够依据时点名高风险分支，未运行的并发、派单或办结不冒称实测。无须为审查看法增加独立测试项。标签与巡检不属于本轮。

用 `TEAM_GATES='bash /var/tmp/<你的证据根>/<runner>' bash skills/teamsmith/scripts/team review P503 --dir /var/tmp/p503-review-78466b22.ok194J --branch 78466b22caada29ce916af5e7f84a6dcc56abff0` 保存原生记录。默认已有超时、锁和队列，不并行启动两批；提前核私有路径、Node/Bun 和 tmux socket 可用。长运行后台起后结束回合，收到完成通知再收，不轮询。允许原生 review 写中央 `docs/team/reviews/{P503.md,P503-verify.log}`，其余主检出只读。某段没跑或有失败保留全部原件，点名未验与原因，不自行改测试/候选或重跑有效结果。不得运行全量、整个 B3、真实项目部署或替换 Pulse。

只提交本人分支 `docs/team/reports/V200-dev3.md`，先给结论、实际命令/回执与原始数据/画面位置，随后给根因与操作边界；记录 `git diff --check` 等实际回执，本地小步提交 V200 / `Agent: dev3`。不推送、不合并、不勾原生清单、不归档；通过候选后仍需同一验证者在 PM 的合并版固定检出做必要短核对。原件保留至 PM 确认。

## 首轮后定点补验

冻结修正 `68e27674e3a06cc62a15c9a5622ba6a3d24ce9f4`，独立干净根 `/var/tmp/p503-review-68e27674.AKBkUL`。原 V200 同一会话续行。`78466b22..68e27674` 只有 `common.sh` 的共享 AWK 名称是否首次出现与作者报告；面板、比较器和测试没换。前次 FAIL 与七份摘取原件已保存；保留全部临时根，不覆盖或改动。新 `team review P503` 用本轮私有 runner、上述路径和新完整 SHA。

- 只运行一次 `TMPDIR=/var/tmp TEAM_B3_KEEP=1 bash skills/teamsmith/tests/panel-b3.sh board`，实际看首帧已有时间、较早任务真正修改后上移、不变写入和后续原定键鼠/刷新、两栏真实历史数据。`fold` 原 30/0 复用，已执行 4c 109/0 保留原版本边界，不另跑其前导段；时间启用后的旧表路径另做同一短读写检查：私有六列旧表首次实际改负责人（也可直接新增），确证专用末列出现，目标行有有效时间、其它原行/业务格未改。读取同一真实 `board` JSON 核列和位置，不对主检出写入。
- 复用前轮机器 JSON 结构和文件顺序证据；因输入现在有时间，按已审方案仅补同一实际表的 `--print --page 4` 原序与 `--snapshot` 新序/历史首窗、以及原定单帧反例 `正常→反向→恢复`。不能用未启用时间的首轮替代新交互。若仍失败，保留实际到达和未到达的断言、原因及原件；只查因，不在本席位改产品或再启动行为组选段。

给原报告追加核对、实际数量、回执和判断；不重跑折叠、全量、类型、静态构建或真实 Pulse。仅反例私有副本需用现有方式构建一次。记录未执行内容，不得把首次已验证的分支当作新候选全覆盖。