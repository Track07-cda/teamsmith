# P280 · 门禁锁的嵌套运行纪律（一个席位的嵌套夹具运行把整队门禁堵住一小时）

task: P280
agent: dev-bob
phase: propose
category: analysis
change: -
anchor: none (infra) — 门禁资源纪律；不改产品行为
deltas: -
branch: task/P280-gate-lock-hygiene
deps: 2026-10-15 的实测（见下）；与 P255 报告里那三次「机器欠的账」同源

## 现象（PM 2026-10-15 实测，进程树与耗时都是真的）

锁 `/tmp/teamsmith-smoke.lock` 被**一个席位自己的嵌套运行**持有了 **1 小时 16 分**，期间别的席位的门禁全部排队：

```
dev3 的 pi
└ smoke.sh --paths …（dev3 自己的交付验收，1h37m）
  └ /tmp/teamsmith-select.1074048.sh
    └ flock -w 1800 /tmp/teamsmith-smoke.lock  ← 拿到锁
      └ /tmp/teamsmith-select.1074048.sh（嵌套，在 fixture 仓 /tmp/teamsmith-smoke.W8u8UY/repo 里）
        └ tests/task-model-routing.sh ← 全量（含 --flip 的量级），已跑 1h16m
```

**代价（实测）**：别的席位的门禁运行在这段时间里只能排队——我自己那次 `--select 13c` 等了 19.5 分钟（我主动停了）；另一个席位的完整验收等了一小时二十分（它的报告里记着）。而队列上限是 1800s，也就是说**排队超过 30 分钟就会变成一次响亮的 FAIL**，报的是「持有者：smoke.sh」——**看不出那是嵌套运行、也看不出它还要多久**。

## 要做什么

1. **判定**：嵌套运行（fixture 内部的 smoke/select 调用）该不该抢机器级的那把锁？给出结论与理由（两侧代价都要写：抢 → 一个席位能堵住整队；不抢 → 两个席位的嵌套运行可能同时在机器上跑重活，loadavg 会上去——作者的报告里已见到 loadavg 20+）。
2. **修法**（按上一条的结论）：至少要做到
   - 等待者能看到**它到底在等谁**：持有者一行里区分「外层运行 / 嵌套运行」、点名所属席位与工作树、并给出**已经跑了多久**与**预计上限**（预算表里有 band，可算）；
   - 嵌套运行的**预算**要显式：一个 fixture 内部的全量套件不该按外层那套预算无声地跑 80 分钟；
   - 排队上限的判定要基于**可预期的剩余时间**，而不是「超过 30 分钟就 FAIL」——或者 FAIL 的文案必须让 PM 一眼看出「这是嵌套运行堵住了，不是谁坏了」。
3. **红侧**：① 造一个「嵌套运行持有锁」的现场 → 等待者的一行里必须点名它是嵌套、属于谁、已跑多久；② 嵌套运行超预算 → 必须被**可见地**处理（点名并释放锁），不许无声占着；③ 正常单层运行的行为不许回退（排队与「排到了再跑」的语义不变）。
4. **不许**把锁整个去掉（它的价值是别让机器被压垮）；也不许把嵌套运行直接放行而不解决「两个席位同时跑重活」的问题——两侧都要有交代。

## 边界

- 只写提案（含上面三条红侧的设计）；apply 与 verify 另换人。
- 与 P255 的报告对照：它记的三次「机器欠的账」（两次 ENOSPC、一次 §36 超时）与本条同源，你的提案里要引用它们。
- 排期：todo。

## 验收（本阶段）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
