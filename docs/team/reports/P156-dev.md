# P156 · `26-c` 纯文本对比：归一化只作用于实时读数

agent: dev   status: done（待 PM 独立复验）   time: 2026-10-02
branch: `task/P156-apply`（local 模式：分支留在本地工作树，未 push）
change: -   phase: apply   anchor: none (infra) — 只改一条断言的归一化口径与其红侧
base: `main@10d7ea4e`（本分支已合入）

## 交付物

| 路径 | 内容 |
|---|---|
| `skills/teamsmith/tests/smoke.sh` | `p10_norm` 改为只归一实时读数的**数值**（时钟 + RAM/swap/可再加/磁盘剩余空间/inode，见下表）；紧跟 `--print` 之后新增双向守卫自检：绿侧 1 条（只动读数的数值 → 归一后逐字节相同）+ 红侧 5 条（字段名 / 行数 / ESC / 分隔符 / 单位 → 仍须不同） |
| `skills/teamsmith/tests/flip-p156.sh` | 翻转夹具：同一份 26-c 聚焦探针跑三面（当前树 / 合并基线的旧归一化 / 掏空的归一化），断言「当前绿 · 旧口径红在绿侧 · 掏空红在红侧」 |
| `docs/team/reports/P156-dev.md` + `docs/team/reports/P156-dev/**` | 本报告与原始输出（清单见「证据文件」） |

提交：

```
b003ff7f Merge branch 'main' into task/P156-apply   # 合入 main@10d7ea4e（P162 等 8 个提交）
5c60345b wip(dev): PM snapshot of work in progress when the shared tmux server died   # PM 的快照，不是我写的
903ceccc test(teamsmith): P156 — the flip fixture that proves the guard tests the right thing
44d97647 fix(teamsmith): P156 — the normalizer blanks every reading on the line, and the guard's sample keeps the unit
8edb5980 fix(teamsmith): P156 — 26-c normalizes the live readings instead of comparing two samples' numbers
（报告与容器证据：本分支最后一个提交）
```

## 根因

任务书现场的两条原始红行：

```
✗ 26-c 纯文本：重定向的 --once 与 --print 内容不一致（ESC=0，时间戳已归一）：4c4 < RAM 3.9G ｜ swap 63.0G …
✗ 26-c 纯文本：TEAM_MONITOR_UI=text 与 --print 内容不一致（ESC=0，时间戳已归一）：4c4 < RAM 3.9G ｜ swap 63.0G …
```

`--print`、`--once`、`UI=text` 是三次**独立执行**；它们比较的帧里有一条容量带：

```
RAM <x> ｜ swap <x> ｜ 可再加 <n> 个 agent ｜ <path> <剩余空间>（inode <n>）
```

来源是 `skills/teamsmith/scripts/panel/src/layout.ts` 的 `capacityBlock`：`fmtMB(ram_avail_mb)`、`fmtMB(swap_free_mb)`、`agents`、以及每个受判文件系统的剩余空间与空闲 inode。这些都是「采样时刻的函数」，两次采样之间会变。旧的 `p10_norm` 只归一了 `HH:MM:SS` 与两种磁盘形状，**没有**归一 RAM / swap / 可再加的数值；差异行因此永远落在这一行（`4c4` = 第四行）。

## 修法

`p10_norm` 的规则（`smoke.sh`，26-c）：

| 形状（真实帧里的例子） | 归一后 | 说明 |
|---|---|---|
| `10:32:22` | `TIME` | M12 起就有，未动 |
| `RAM 3.9G` / `swap 63.0G` | `RAM ·G` / `swap ·G` | 数值换成 `·`，字段名与单位留在原位 |
| `可再加 11 个 agent` | `可再加 · 个 agent` | 同上 |
| `9.4G（inode 3302289）` | `·G（inode ·）` | 面板磁盘段 |
| `可用 9.4 GB（inode 3302289）` | `可用 · GB（inode ·）` | shell 形态的等价延续（`team_capacity_line`），不是新放宽 |
| `（inode 3302289）` | `（inode ·）` | 兜住上一条规则先后顺序的差异 |

**没放宽的**（照旧逐字节比，全部由红侧钉住）：字段名、单位、分隔符、行数、行顺序、空格、ESC 控制字节、`—`/`?` 这类无数字的兜底读数、路径名、行尾的 sparkline。

单位留在原位是有意的：值在 `1024M ↔ 1.0G` 边界上换了单位仍会红。这是任务书「单位照旧逐字节比」的直接后果，属于已知边界而不是漏网。

## 翻转证据（red → green）

### ① 修复前的红（把实时读数当内容比）

`skills/teamsmith/tests/flip-p156.sh` 用**同一份** 26-c 聚焦探针跑三面，只换 `p10_norm` 的实现。第二面把合并基线（`main` 合并点 `10d7ea4e`）的旧归一化原样拼回探针：

```
① 当前（修复后）：rc=0 == 结果 ==  ✓ 24  ✗ 0
② 旧归一化（BASE）：rc=1 == 结果 ==  ✓ 23  ✗ 1
    26-c P156 绿侧：只有实时读数不同 → 归一后逐字节相同（归一后仍不同：4c4 < RAM 3.9G ｜ swap 0M ｜ 可再加 1 个 agent ｜ /tmp 287.3G（inode —） --- > RAM 1.1G ｜ swap 1.1M ｜ 可再加 999 个 agent）
✓ 旧口径红在绿侧（把实时读数当内容比）
```

这就是任务书那两条的还原：旧口径下「只差实时读数」的两段被判成不同。

### ② 破坏实现 → 守卫必须失败（守卫有牙）

第三面把 `p10_norm` 掏空成恒等（`p10_norm() { :; }`）：

```
③ 掏空的归一化：rc=1 == 结果 ==  ✓ 19  ✗ 5
    26-c P156 红侧：字段名不同仍然不同（归一后被吃掉 —— 红侧空了：4c4 < RAM 3.9G ｜ swap 0M ｜ 可再加 1 个 agent ｜ /tmp 287.3G（inode —） ）
    26-c P156 红侧：多一行仍然不同（归一后被吃掉 —— 红侧空了：21a22 > P156 多出来的一行 ）
    26-c P156 红侧：混进 ESC 仍然不同（归一后被吃掉 —— 红侧空了：1c1 < teamsmith pulse · p10-repo  10:32:22  巡检 900s · 待命 off ）
    26-c P156 红侧：分隔符不同仍然不同（归一后被吃掉 —— 红侧空了：4c4 < RAM 3.9G ｜ swap 0M ｜ 可再加 1 个 agent ｜ /tmp 287.3G（inode —） ）
    26-c P156 红侧：单位不同仍然不同（归一后被吃掉 —— 红侧空了：4c4 < RAM 3.9G ｜ swap 0M ｜ 可再加 1 个 agent ｜ /tmp 287.3G（inode —） ）
✓ 掏空归一化时红侧失败（守卫不是空跑的绿）
flip-p156: 翻转成立（当前绿 → 旧口径红在绿侧 → 掏空红在红侧）
```

5 条红侧的原始输入确实与基准帧不同（每条的括号里就是原始 diff 片段：改字段名、加一行、前置 ESC、换分隔符、换单位）。恢复实现（当前树）后同一份探针 ✓24 ✗0。

### ③ 修复后两次真实采样逐字节相同（门禁里的真跑，不是合成样本）

`--select 26` 连跑三次（容器内），每一次都包含那两条原始红断言：

```
✓ 26-c 纯文本：重定向的 --once 与 --print 只差时间戳（且 0 ESC）
✓ 26-c 纯文本：TEAM_MONITOR_UI=text 走同一渲染（与 --print 只差时间戳）
✓ 26-c P156 绿侧：只有实时读数不同 → 归一后逐字节相同（原始差异：4c4 < RAM 3.9G ｜ swap 0M ｜ 可再加 1 个 agent ｜ /tmp 287.3G（inode —） ）
✓ 26-c P156 红侧：字段名不同仍然不同
✓ 26-c P156 红侧：多一行仍然不同
✓ 26-c P156 红侧：混进 ESC 仍然不同
✓ 26-c P156 红侧：分隔符不同仍然不同
✓ 26-c P156 红侧：单位不同仍然不同
```

三次运行都 `== 选段结果 ==  ✓ 210  ✗ 0`（10:29:18 / 10:30:08 / 10:30:56 起始，rc=0）——任务书要求的「多跑几次以证明不再抖」。

## 验收命令与结果

**门禁全部在容器里跑**（PM 2026-10-02 的临时纪律）。命令的宿主外形：

```sh
distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp \
  -v <本 worktree>:/work \
  -v <home>/Documents/syncthing/Work/Projects/pm-skills:<home>/Documents/syncthing/Work/Projects/pm-skills:ro \
  -w /work localhost/teamsmith-gate:local bash -c 'git config --global --add safe.directory /work; <命令>'
```

主仓**只读**挂同一绝对路径是必须的：这是 linked worktree，`/work/.git` 指向 `…/pm-skills/.git/worktrees/dev`（绝对路径），不挂主仓时容器里 `git status` 直接 `fatal: not a git repository`。

| 任务书要求 | 实际命令（容器内） | 结果 |
|---|---|---|
| `--select 26-c` | 这个 smoke 版本**没有** `26-c` 这个 key：`smoke.sh --select 26-c` → `未知 key：26-c`，rc=2，什么都没跑（见 `container-select-26c-unknown.txt`） | 用存在的 key `26`（= 含 26-c 的整段）替代 |
| `--select 26-c`（多跑几次） | `bash skills/teamsmith/tests/smoke.sh --select 26` ×3 | 三次都 `✓ 210  ✗ 0`，rc=0（`container-select-26-x3.txt`） |
| `openspec validate --all --strict` | `openspec validate --all --strict` | `Totals: 20 passed, 0 failed (20 items)`（同一证据文件尾部） |
| FAST | `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh` | `== 结果 ==  ✓ 3420  ✗ 0`，`fast rc=0`；账本自查 `✓3420 ✗0 SKIP36` 一致（`container-fast.txt`） |
| 翻转（缺陷类必交） | `bash skills/teamsmith/tests/flip-p156.sh` | rc=0，三面如「翻转证据」（`container-flip.txt`） |

### 宿主上的旧一次（重启前，如实记录）

- `docs/team/reports/P156-dev/gates-fast.txt` 是我在宿主上 07:29–07:44 跑的 FAST：`✓ 3421  ✗ 1`。那 1 条红是 §7 的
  `F26：收件箱被重建到更短后新消息仍然可见`，与 P156 无关（我不碰 notify/inbox）；容器 FAST 里没有复现。
- 关于「私有 socket 没生效」：那次宿主运行里没有这条红。开跑行打印了 `tmux 私有 socket：/tmp/teamsmith-smoke.iCOX2s/tmux/tmux-1000/default`，§36⑥ 的两条环境侧断言（深 TMPDIR 归因、119 字节路径 > AF_UNIX 107 上限）都是 ✓。

## 没跑的（点名）

- **26-m（真 pane 渲染）**：FAST 跳过（`SKIP（FAST 模式）`），本任务不动它。
- **不带 `TEAM_SMOKE_FAST` 的全量门禁**：容器 FAST 跳过的 36 个真进程段落都没跑（清单在 `container-fast.txt` 尾部）；其中包含容器 tmux 自检、真 pane 端到端等。
- **`--select 26` 之外的段**：选段运行本来就只跑选中的 6 段（0 / 0b / 0c / 0d / 2 / 26），其余 113 个 key 未跑。
- **`--select 26-c`**：键不存在，见上。

## 证据文件

| 文件 | 是什么 |
|---|---|
| `container-select-26-x3.txt` | 容器内 `--select 26` 三次 + `openspec validate --all --strict` |
| `container-select-26c-unknown.txt` | 容器内 `--select 26-c` 的拒绝（rc=2）与 `26` 的选段头 |
| `container-flip.txt` | 容器内 `flip-p156.sh` 三面 |
| `container-fast.txt` | 容器内 FAST 全量输出（`✓3420 ✗0`） |
| `gates-fast.txt` / `select-26-fast-1.txt` / `select-7-fast.txt` / `openspec-validate.txt` | 重启前宿主上的旧一次（见上节）；`select-26c-1..3.txt` 是当时三次敲错的 key，已被新的 `container-select-26c-unknown.txt` 取代并删除 |

## 已知边界与取舍

1. **单位不归一**：`RAM 3.9G` → `·G`，`swap 0M` → `·M`。两次采样跨 `1024M ↔ 1.0G` 边界时仍会红。这是任务书「单位照旧逐字节比」的明确要求。
2. **绿侧样本是从真实帧 sed 出来的「第二次采样」**，不是真跑第二次；真跑两次的是紧随其后的 `--once` / `UI=text` 两条断言。守卫自检的作用是把「归一化放过了什么、没放过什么」钉成断言，而不是替代真跑。
3. **容器里的磁盘读数不报 inode**（`/tmp` 挂的是 tmpfs），所以容器现场是 `287.3G（inode —）`；宿主上 inode 是数字（PM 的原始红就是那条线）。数字形态由 `（inode [0-9]+）` 规则覆盖，宿主复验时那两条真跑断言会实际走到它。
4. 宿主 FAST `✓3421` 与容器 FAST `✓3420` 差 1：两边跑的不是同一棵树的同一时刻（宿主那次在合入 main@10d7ea4e 之前，且 §7 的那条红是环境相关的 flake），不当作回归。

## 问题（写给 PM）

- 任务书里的 `--select 26-c` 在这个 smoke 版本不存在，实际 key 是 `26`（`26-c` 是段内子段号，不是选段键）。我没有改选段机制，也没有伪造一个 `26-c` 键；如果希望支持子段键或让报错更直白，那是另一条任务。
