# V75 · P336 的独立验收：写信面夹具换成状态等待，断言一条没少

task: V75
agent: dev2
phase: verify
category: verify
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 夹具的等待方式
deltas: -
branch: task/V75-panel-b2-waits-verify

## 受检与问题

候选 `6703cc11`（实现 `8f4fdcad` + 注释 `b4dfdc36`），报告 `docs/team/reports/P336-dev.md`。产品面只有一个文件：`skills/teamsmith/tests/panel-b2.sh`（这套夹具今天**不在任何门禁段里**，接线是 P327）。

要回答三件事：**（一）断言与场景真的一条没少？（二）那两条原本的红变绿，是因为等对了状态，还是因为断言被放松？（三）剩余 11 处固定等待有没有藏着「分钟级上界」或「把 sleep 塞进循环」这类绕法？**

## 必须自己做的

1. **断言集合（自己抽，别抄报告）**：从 `main` 与候选各取一份 `panel-b2.sh`，抽出断言行（`assert_*`/`fail*`/`ok`/`bad` 那种你判定的断言行）与场景名列表，各自 `diff`。要求：**断言行逐字节相同、场景名与顺序相同**；有差异就逐条判「这是等待方式还是判据」，并说清哪一条改变了行为。贴 diff 结果。
2. **跑一次全场景**：私有磁盘 `TMPDIR`、私有锁、私有 tmux server。要求全绿；贴段尾与整次 rc、实际墙钟（参考值）。**再跑一次**确认不是一次运气。两次都要留现场（`TEAM_B2_KEEP=1`，收尾你自己清）。
3. **那两条原本的红**（作者说改前 `✓165 ✗2`、改后 `✓167 ✗0`，理由是等待判据从「固定等」换成「等旗标带上『待命 on』」）：
   - 在候选树上把这两条的**等待**改回固定 `sleep`（只改等待、不改断言），复现改前的红（或复现「时红时绿」）；
   - 确认断言本身仍在检查同一件事（读那一行断言的期望串）；
   - 结论只有两种写法：**「等对了状态」**或**「放宽了断言」**，选一个并给证据。不许写成「反正现在绿了」。
4. **剩余 11 处固定等待**：逐条读，判断它属于报告 §3 的哪一类理由；找出任何**没被报告点到**的剩余 `sleep`、或任何「把固定等待藏进循环/重试」的写法、或任何上界 ≥ 60 秒的等待；有就点名。
5. **私有性**：实验前后各打一次你自己调用者的默认 server（server pid + session 清单），逐行相同。
6. 轻量收口：`bash -n`、`openspec validate --all --strict`、账本禁令固定验收行、`git diff --check`。

跑之前 `ps` 确认没有别人的 `smoke.sh` 在跑；不要抢机器级门禁锁；不要跑整套门禁。收尾清掉自己的夹具根与私有 server（按显式 pid）。

## 边界与交付

只读代码、只写 `docs/team/reports/V75-verify.md` 与自己的线程；不改实现、不合并、不 push。结论先写 PASS/PARTIAL/FAIL。注意：**这个分支落后 main 很多**（它只应带来 `panel-b2.sh` 与报告），你判的是「相对 main，这个文件变了什么」，不要把 main 上别的改动算进来。local 模式，PM 合并与关单。
