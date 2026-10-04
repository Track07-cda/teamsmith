# dispatch-verify-seat-guard · PM proposal review

time: 2026-09-22T08:2xZ · reviewer: pm · verdict: **ACCEPTED**

```
change:  dispatch-verify-seat-guard（P38，propose=dev3）
tip:     b59679b（task/P38-dispatch-apply-verify-propos）· validate 18/18
user:    D36（2026-09-22 我把实现任务派给 verify 席位两次：M53、P36）
```

## Findings

1. **判据与我在 D36 里写的一致**：`phase: apply` **或**（phase 不可用 + `grant:` 列了实现路径）→ 拒绝；
   `explore`/`propose`/`verify`/`archive` 与"无 phase 的台账/勘察"→ 放行 ✓
2. **席位由 `TEAM_VERIFY_SEAT` 决定**（默认 `verify`）——项目把验证席位叫别的名字也覆盖得到 ✓
3. **拒绝时机在开窗前**（且 `--print` 同样拒），**不动看板行**——拒绝不留半成品状态 ✓
4. **报错内容**：点名 `OWNERSHIP.md`、席位、两条出路（换席位 / 改成 verify 阶段），并引
   `verification#The verification seat does not implement` 与 `references/protocol.md` §5b ✓
5. **undeclared phase 的拒绝会"打印它读到的三条实现路径"**——不只说"拒了"，还说"我据什么拒"✓
6. **`--force` 的语义精确**：放行 + 一条警告 + **恰好一行** `state/watchdog.log` 审计；
   `--print` **不写**审计行 ✓
7. **反向夹具**：`agent: dev` 的同一份 apply → 放行（守卫关于**席位**，不是关于 apply 阶段）✓
8. ADDED ×2（dispatch + verification），既有 requirement 不动、无删除 ✓

## 结论

**ACCEPTED**。apply 排在 **P40 之后**（两者都改 `cmd-agents.sh`：P40 加 doctor 行、P38 加 dispatch 判据——
串行落地，避免同文件对冲）。verify 换人。
