# inbox-spool-resilience · PM proposal review

time: 2026-09-20T08:5x:00Z · reviewer: pm · verdict: **ACCEPTED**

```
change:  inbox-spool-resilience
owner:   dev2（propose）
tip:     738abf0（task/P25-propose）
```

## Commands run

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict   → Totals: 15 passed, 0 failed
$ git -C .worktrees/dev2 status --porcelain | wc -l              → 0
$ node docs/team/reports/P25-dev2/probe-p25-red.mjs              → 当前树上复现假缩容/循环/过期唤醒（红态证据）
```

## Findings

1. **根因被复核并修正了 PM 的判断 — PASS（这是这次提案最有价值的部分）。** PM 的假设是
   「offset 按缓冲区长度推进」，方向对但机制不准。作者的实测链是：
   **① 生产者** `outbox.sh:1017` 用 `LC_ALL=C cut -c1-700` 裁预览——`cut -c` 在本机（GNU coreutils 9.10）
   **按字节**裁，落在多字节字符中间就写出**非法 UTF-8** 的 spool 行；
   **② 读者** `readNewLines()` 把新 offset 算成 `Buffer.byteLength(text.slice(0, end+1),'utf8')`——
   一次「解码→再编码」的往返，每个非法字节变成 U+FFFD（3 字节），于是 offset **大于**物理字节，
   `baselineOffset()` 直接给出 `size + 1`；
   **③ 定量对账**：全文件只有一处非法预览（`.seen` 里 2026-09-19T16:59:42.057Z 的 M40 手工 knock 行），
   它恰好贡献 +1 —— 19634 + 1 = 19635，与 06:42:39 的 `baseline=19635` 严丝合缝；
   **④ 同一根因还解释了 2026-09-19 那次 42 行重放**（同一行的写入时刻）；
   **⑤ 排除项**（`.seen` 512 上限、`trimSpool` 128KB、fs.watch、进程内竞争）都逐条查过并给了理由。
2. **四条 requirement 都是不变量而不是补丁 — PASS。** `notify-and-inbox` **ADDED ×4**：
   R1 offset 按**实际读到的字节**推进且永不越过文件末尾（含"字节裁切的预览不再把 offset 推过末尾"、
   "起始于行中的读取不得投递碎片"）；R2 缩容要有**证据**且恢复要**收敛**（1 字节回退 + 头部不变 → 修复而非重扫；
   头部变化 → 有界重扫一次并收敛；同一 `(size, head)` 不重扫两次）；R3 **只有新鲜行唤醒**（
   `TEAM_INBOX_WATCH_STALE_SEC` 默认 900），过期行只计数不唤醒，**时间戳不可解析的行仍然投递**（不静默吞）；
   R4 **账本把新流量与恢复分开**（`total` 只随真新增增长）。
3. **delta 可被后续增量叠加 — PASS。** 全为 ADDED、没有大段重写既有 requirement → P28（backfill）之后仍能干净地在其上追加。
4. **红态证据是真复现，不是描述 — PASS。** `probe-p25-red.mjs` 在**当前树**上跑出假缩容/循环/过期唤醒，并带 ASCII 对照。
5. **与 M43/M46 既有断言的关系写清了 — PASS。** 指明哪些既有断言保持不变、哪些新增（tasks.md 里 S18–S20 及各自的翻转）。

## PM 决定：把生产者一并修（B6），理由与边界

design §5 把 `outbox.sh:1017` 的字节裁切标成「PM-owned follow-up（不阻塞）」。**我决定把它并进本 change**：
它就是这次事故的**触发器**（虽然读者修好后不再引发 loop），且修法极小（`printf` 前用 bash 的
`${text:0:700}` 这一类按字符裁切，而不是 `cut -c`），证据也现成。
边界：B6 只允许**一行实现 + 一条断言**（spool 行必须是合法 UTF-8，且 `LC_ALL=C` 下也成立）；
若作者判断它会牵动 `team_inbox_watch_deliver` 的其他路径（`say`/`notify`/`draft` 三种发送者共用），
**就报 PARTIAL 交回来**，不许为它破坏 B1–B5 的主修。

## 注意（交 apply 时我会盯）

- R2 的头部指纹与收敛记忆是**进程内**状态还是持久化？若持久化，必须写进 `state/inbox-watch/` 且**不得**成为第二份真源；
- R3 的新鲜度判据必须用 spool 行自带的 `team_epoch_ms`，**不能**用"文件 mtime"或"`.seen` 里的顺序"。
