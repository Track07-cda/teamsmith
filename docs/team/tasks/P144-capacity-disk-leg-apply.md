# P144 · `capacity-floor-disk` apply：派单前的磁盘/inode 腿 + 两个阈值键注册 + 标签

```
task:   P144
agent:  dev-bob                  # 提案人继续实现（复验换人即可，D31）
issue:
change: capacity-floor-disk      # 提案已验收并合入 main（reviews/capacity-floor-disk-proposal.md）
specs:  dispatch#The capacity floor protects the host
phase:  apply
anchor: change
deltas: dispatch,watchdog,panel
grant:  skills/teamsmith/scripts/lib/** · skills/teamsmith/tests/** · skills/teamsmith/references/** · panel/src/** · openspec/changes/capacity-floor-disk/** · docs/team/reports/P144-dev-bob.md · docs/team/reports/P144-dev-bob/**
deps:   `openspec/changes/capacity-floor-disk/tasks.md`（**1.x–8.x 全覆盖映射，照它做** ✅）· OWNERSHIP：`openspec/specs/**` 与 `docs/team/**`（除你自己的报告）不许碰 ✅ · D67（席位被 ENOSPC 打死 ✅）· D58（临时根归属靠证据 ✅）
status: wip
budget: 一个工作块
priority: 高（一次真实席位阵亡 ✅ 且这是"能问出问题"的基础设施 ✅）
```

> 本地模式：不 push main ✅；推送带 `[skip ci]`（CI 不是判据 ✅）。

## 交付 = change 的 `tasks.md` 全部做完（含每项自己写的 verify 与 red）

## 我审提案时点名、apply 必须落实的

1. **schema 注册（R1）** ✅：`TEAM_TMP_MIN_FREE_MB` / `TEAM_TMP_MIN_FREE_INODES` 进 schema（默认 1024 / 100000、类别同 `TEAM_MIN_AVAIL_MB`）✅
   + **zh/en 标签**（M49 的规矩 ✅）+ 夹具缝旋钮 `TEAM_DISK_STATS_FILE` 也注册（`refuse` 类 ✅）；
   数 schema 键的夹具改成**取新总数**，**不许**写死旧值 ✅。
2. **三条判据一个都不能少** ✅：不足 → 拒绝（点名路径/读数/阈值 + `修法：`，含归属有据的 `tmp-hygiene --status/--sweep` ✅）；
   充足 → 放行并**打印读数** ✅；**读不到 → 不判不说**（可见地写"读不到" ✅、不拒绝 ✅）。
3. **逃生口令走审计写入器** ✅：`team config set TEAM_TMP_MIN_FREE_MB 0` 成功并让派单放行 ✅（这是 R1 的验收面 ✅）。
4. **同文件系统只判一次** ✅；`TEAM_DISK_STATS_FILE` 夹具能造出"不足/充足/读不到/无 inode 表"四态 ✅。
5. **不动既有容量腿** ✅（RAM/swap/MemAvailable 的行为与文案不变 ✅ 要有反向断言 ✅）。

## 门禁与证据

`openspec validate --all --strict` ✅ + **FAST 全绿** ✅ + **一次全量**（动了派单主路径 ✅）；
每条 What flips 与每个红侧留**原始输出** ✅；报告点名"哪些自己跑、哪些引用" ✅。
