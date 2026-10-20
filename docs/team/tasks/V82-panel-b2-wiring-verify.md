# V82 · P327 的独立验收：夹具接进 §38，且地板里真的没有它

task: V82
agent: verify
phase: verify
category: verify
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 门禁接线
deltas: -
branch: task/V82-panel-b2-wiring-verify

## 受检

候选 `09aada88`（实现 `e63282cb`），报告 `docs/team/reports/P327-dev.md`。写集：`smoke.sh`（选段块 + §38 一条腿）与 `section-paths.tsv`（§38 那行 patterns），`panel-b2.sh` 声称**一个字节没改**。

作者自己交代了一段重要经过：**第一版接线是错的**——它把「本轮为什么被选中」的 reason 当整串匹配，于是 `floor, needs:63` 被当成「直接点到」，7 分钟的夹具真的进了地板（§38 从 332 s 涨到 767 s），是地板实测抓回来的；第二版按逗号拆开逐条判。

## 要回答的四件事

1. **`panel-b2.sh` 真的没被改**：与 `main` 逐字节比对（给 blob 哈希），并确认场景数 11、`✓167 ✗0` 这组读数与 P336 记录一致（你可以只跑 `--select 38` 一次拿到它）。
2. **地板里确实没有它**：`--floor` 在这棵树上必须给 §38 一条**具名 SKIP（条件不满足）**而不是执行它；并给出 §38 在地板里的用时（作者读数：跳过 332 s、执行 767 s）。**不要**为了这个再跑一整轮地板（一次约 90 分钟）——用 `--select 38` 与 `--floor --select` 能给的证据，加静态读选段块，说清「地板路径不会把 reason 里的 `floor` 当直接点到」。
3. **直接点到时会执行**：`--select 38` 必须真的跑它（`38-h` 出现 ✓167 ✗0），而单独 `--select 38-h` 之类的间接路径若无法单独选，说明清楚。
4. **逐条判 reason 不是新漏洞**：读选段块，指出它如何拆分 reason；验证形如 `floor,needs:63`、`full`、`paths:…` 这几种都不能被当成「直接点到」。若你自己造一个 reason 串喂给那段逻辑（私有副本里），把结果贴出来。

## 反例与收口

- 反例：私有副本里把 `panel-b2.sh` 的一条关键断言改坏（作者用的是 Esc 后草稿保留那条）→ 同一次 `--select 38` 必须 **rc=1 并点名**那一条；改回必须绿。
- 没有新段/新检查器：`section-select.sh --check` 的段数应与改动前相同（135 行 / 135 段）。
- 轻量收口：`bash -n`、账本禁令固定验收行、`git diff --check`。

## 边界

- 只读代码、只在 `/var/tmp` 私有副本里造破坏、只写 `docs/team/reports/V82-verify.md` 与自己的线程；不改实现、不合并、不 push。
- 一次 `--select 38` 约 13 分钟，属正常；不要跑整套、不要跑容器。跑前 `ps` 确认没有别人的 `smoke.sh`。
- 结论先写 PASS/PARTIAL/FAIL。local 模式。
