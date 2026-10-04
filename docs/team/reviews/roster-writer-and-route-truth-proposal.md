# roster-writer-and-route-truth · PM proposal review

time: 2026-09-22T11:2xZ · reviewer: pm · verdict: **ACCEPTED**

```
change:  roster-writer-and-route-truth（P46，propose=verify 席位 —— 只写 openspec/changes/ 与报告）
tip:     aca9085（task/P46-propose）· validate 20/20
user:    2026-09-22「可以，也请你检查有没有类似的问题」（`do` 项目那次名册 catch-22 + 我排查出的三条同族）
```

## Findings

1. **名册只有一个授权入口**：`add-agent <a> [--register] [--model m]` 长名册；`teardown --agent <a> --register` 缩名册；
   两者都走**契约的唯一写入器**（值规则 + 指纹 CAS + `config.log` 审计），`TEAM_AGENTS` **仍是 `refuse` 类**；
   不带旗标的未知席位 → **exit 5**，点名**两条真能用的路线**（手改 `config.sh` / `--register`），
   **不开窗、不建 worktree、不写 state、不碰契约**；已知席位加 `--register` → 可见 no-op（0、不写、不审计）✓
2. **移除侧也补齐**：`teardown --register` 必须带 `--agent`（`--all --register` 是用法错 exit 2），
   未知席位 exit 5 且不写 ✓
3. **`--model` 被实现而不是删掉**（D4）：走 `set-agent-model` 的**同一个写入器与同一个 pairlist 序列化器**，
   `-` 移除覆盖；理由（保留打印出来的承诺 + 席位模型属于"这个席位是什么"）我认可 ✓
4. **`set-agent-model` 保持对未知席位拒绝**（D3）：它论证了两遍——① 改成允许会与 **P43 正在改的同一条 requirement**
   撞车（需要第二个 MODIFIED）；② 会往 `TEAM_AGENT_MODELS` 写入 pairlist 校验器自己都拒绝的 token。
   **我裁定同意**：将加入的席位由 `--register --model` 一次服务完 ✓
5. **路线真诚性 walk（本任务的重点）**：`tests/routes.sh` —— 遍历 `team help` 的每条用法行，**它打印的每个 `--flag`
   必须被该命令自己的解析器接受**（不可归因的行**必须红**，不许静默跳过）；**反向控制臂**：给每条打旗标的命令
   塞 `--frobnicate-probe`，**吞掉未知参数的必须红**（否则"被静默忽略"会读成"接受"）；schema 里点名的命令必须
   存在**且那句话承诺的事在夹具里真的发生**（探针集合**从 schema 推导**，不是手工清单）；全部在 `$TMPDIR` 下的
   临时仓 + 记录型 tmux shim 里跑、stdin 接 `/dev/null`、硬超时、跑完清理、**每行一条 ok**（不许静默跳过）✓
6. **控制臂当场抓出两个真缺陷**（D6）：`team version --frobnicate` 与 `team meeting list --frobnicate` **今天都 rc=0**
   —— 我**自己复跑核过**（`version rc=0`、`meeting list rc=0`、对照 `reload rc=2`）。修法是给它们加标准的
   未知参数拒绝——**这正是"印出来的路线必须真能用"该抓的东西** ✓
7. **D7 的文案同步表**列了 8 处（schema 两处、`team help`、SKILL 命令表、`config.md`、`protocol.md`、
   `workflows`/`troubleshooting`、init SKILL:27）✓
8. MODIFIED 的两条 requirement **base scenario 一条没丢**（4→7、4→5）✓；它还把**我那四条现场复现**独立复跑了一遍 ✓
9. **D8 排期**：apply 排在 **P43 之后**（两者都写 `memory-and-deps` 的契约/席位面）✓

## 结论

**ACCEPTED**。apply 等 **P47（P43 的 apply）** 落地后派；verify 换人。
