# test-tmp-hygiene · PM proposal review

time: 2026-09-22T11:3xZ · reviewer: pm · verdict: **ACCEPTED**

```
change:  test-tmp-hygiene（P50，propose=dev3）
tip:     （P50-dev3 分支）· validate 21/21
firsthand: 2026-09-22 09:50 `/tmp` 100%（0 可用、inode 满）→ panel-p21 的 ENOSPC 假红
```

## Findings

1. **一个拥有者助手**：`tests/lib/tmp-root.sh` 是**唯一创建者**，根一律 `${TMPDIR:-/tmp}`
   （**消灭写死的 `/tmp`**——`smoke.sh:215` 那条我实测过、已写进 brief），名字进**一个 owned 家族**
   （`teamsmith-<kind>.XXXXXX` / `review-<ID>`），根里写 owner 标记（创建 pid/启动时间/kind/run id）并记进 run 台账 ✓
2. **回收三态**：正常退出 **与 `INT`/`TERM`** 都回收；只有 `TEAM_TMP_KEEP=1` 才留（并打印路径）✓
3. **越界进程按 D37**：出界的进程（anchor tmux session、`sleep`）**spawn 时记 pid**，cleanup **只对记录的 pid 发信号**，
   禁止按名字/命令行匹配 ✓ —— 与今天 dev3 那次事故的教训一致
4. **sweep 先证明占用**：只碰 owned 家族、**先证明无进程占用**、打印清单与总量（可审计）✓
5. **占用可见**：门禁打印自己的临时根用量；`team doctor` 增加**临时根余量**行
   （`/tmp` 是共享 tmpfs，满了会让测试假红——今天就是）✓
6. 它把今天的三组数字（`config-cli.*` 607 个 / 3.2G、`review-*` 127 项 / ~6G、23h/69h 的孤儿夹具）写进了 proposal ✓

## 结论

**ACCEPTED**。apply 等一个实现席位；verify 换人。
