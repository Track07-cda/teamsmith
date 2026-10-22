# V97 · P367 的独立验收：flip 树照源派生、表行补 needs、以及它自报的第三处缺陷

task: V97
agent: dev
phase: verify
category: verify
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 夹具与选段表
deltas: -
branch: task/V97-fixture-table-verify

## 受检

候选 `43cdbc96`（交付提交 `44013ff1`、`387493af`、`c9e602ed`），报告 `docs/team/reports/P367-dev3.md`。
它声称：① flip 树改为照源派生并带上 `SKILL.md` → `38-a` 绿、`--select 38` 收口 `✓410 ✗0`；
② 选段表 `13` 行补 `needs: 5` → `--select 13` 与 `--select 5,13` 读数一致；③ 两条红侧各只红那一条；
④ 修的过程中**撞出第三处缺陷**：flip 夹具在「源技能目录本身是软链」的树上会把翻转补丁**顺着软链写进真树**
（它自己做红侧时踩中，真树的 `scripts/lib/cmd-config.sh` 被改脏，已从 HEAD 复原，第三轮后 `git status` 为空）。

## 要回答的四件

1. **① 成立吗**：`--select 38` 里 `38-a` 是否真绿（贴行）；再按 ③ 造一次红侧——**把 flip 树里的 `SKILL.md` 再拿掉**
   → `38-a` 必须重新红并点名，且**只有它**红。
2. **② 成立吗**：`--select 13` 与 `--select 5,13` 各跑一次，贴读数；两者应一致；再看逐键审计工具是否不再判 `bad 13`。
3. **③ 最要紧：那个「写进真树」的缺陷真的关上了吗**。自己造那个形状：让源技能目录是**软链**，跑一条会打补丁的
   flip，然后 `git status --porcelain` 必须**为空**（真树一个字节不变）；再做反向：把它的防护去掉 →
   必须能看到真树被改脏（这样才证明防护是承重的，而不是碰巧）。**这一步是整个任务里唯一可能留下长期伤害的**。
4. **写集没越界**：`git diff main 43cdbc96 --name-only` 应只有 `tests/panel-choices.sh`、`tests/section-paths.tsv`、
   报告、（可能的）`tests/lib/*` 助手；**产品面 `scripts/` 必须为空**。若产品面有改动，点名。

## 边界

只读代码、破坏只在 `/var/tmp` 私有副本（**真树里做软链实验时先确认那条 flip 不会写穿**；一旦发现写穿立刻停止并报我，
不要「修好再报」）、只写 `docs/team/reports/V97-dev.md` 与自己的线程。不跑整套；不碰别的席位的工作树。
结论先写 PASS/PARTIAL/FAIL，并单列「必须修」。
