# M75 · tmux-gate-grant-redesign 独立验证（verify 阶段）

```
task:    M75
agent:   dev3
branch:  task/M75-tmux-token（local 模式：不 push，分支留在 .worktrees/dev3；PM 复验后本地合并）
change:  tmux-gate-grant-redesign（phase: verify）
         propose = M63（dev-bob）· apply = M67（dev-bob，4b8a435 + 10dd3ba，已合并）→ verify 换人，D31 成立
specs:   boundary#A destructive tmux call is decided by the object it targets… /
         boundary#The gate's actions are logged… / boundary#Destructive gate fixtures never aim the real tmux…
被验修订: 实现自 4b8a435 合并后未再改动；本分支 HEAD 的实现 blob：
         shim/tmux 7df321d5dbdca7e3acb71568f12b5058baf8553a · team 20e9b10451f3548cf7a481900d00030698346299 ·
         smoke.sh fa7a4d0457c85d007707da6494d89ab39536acbb · tmux-lint.pl 7e83f30210ef9a50179dc66e1874169ad4653e56 ·
         container-tmux.sh aa17110367075f290ed75f175c2112ab20680786
status:  PASS（六条对抗性验证全过 + 三条验收命令全绿；package 295 ✔ / 0 ✗ / 0 finding / 0 skip）
```

**本任务不改实现**：`scripts/**`、`tests/**`、`extension/**`、`openspec/**` 零改动（§7 的
`git diff -- skills openspec extension` 与 shim 的逐字节比对为证）；所有变异只在 `/tmp` 副本里做。
证据目录 `docs/team/reports/M75-dev3/pkg/`（`lib.sh` + `run.sh` + 8 段 + 原始日志）。PM 可在任意 checkout：

```sh
bash docs/team/reports/M75-dev3/pkg/run.sh            # 全部（约 13 s）
bash docs/team/reports/M75-dev3/pkg/run.sh --only 40  # 选段
```

**安全纪律（任务书第一条）**：一切「共享默认 socket」探针把 `TEAM_TMUX_REAL` 钉到 argv 记录桩
（判定错了也只执行假命令）；一切「真执行」的破坏性调用只打 `TMUX_TMPDIR=<已 mkdir -p>` 的私有 server；
本包自己的 tmux 调用还额外被 PATH 里 `exec /usr/bin/tmux -L m75pkg-$$` 的 shim 强制隔离；每个探针用
`env -i` 起（不继承 dev3 窗口的 TMUX/`TEAM_*`）；EXIT trap 用 `BASHPID == $$` 守卫（管线子 shell 不收尸）。
全程宿主默认 server 只被**只读**探针（`-S <sock> ls`/`list-sessions`）碰过，会话与客户端数前后一致。

## 判定总表（任务书逐项）

| 任务书项 | 对抗性方法 | 结果 | 证据 |
|---|---|---|---|
| 1 判定按目标（R1） | 89 条矩阵探针（钉桩）：own/foreign/unprovable/server/widening/歧义前缀/身份绑定/拒绝文案；5 条只读直通 | **PASS** 89✔ | §1，`logs/10*.{log,tsv}` |
| 1b M41 表与两个假隔离形态 | 私有/`-L`/`-S`/`TMUX` 私有直通；默认靶 6 种等价写法全拒；不存在的目录与普通文件两形态；socket 解析块与 M67 前基线**逐字节 diff** | **PASS** 51✔ | §2，`logs/20.log` |
| 2 环境零授权（R2） | 调用方 `=1/=0/空` + 未绑定身份；**host 版泄漏形状**（server 全局环境带键 → pane 继承 → 仍拒）；残留读取方普查；词汇表；日志 2000/1000 有界 + FIFO 不挂 | **PASS** 43✔ | §3，`logs/30-*.txt` |
| 3 argv token 真假两态（R2） | 全局位执行/剥除/不进执行进程环境/`act=explicit-flag`/任何 socket；子命令后同名词原样到达下游；`=1` fail closed（桩 + 真私有 server 两侧）；`-L` 值里的同名词不被剥 | **PASS** 47✔ | §4，`logs/40.log` |
| 4 CLI 自用路径没坏（D5） | `teardown` 与 `pulse down` 两条：默认 socket 钉桩 → `act=allowed-owned`；真私有 socket → 窗口**真的被杀**、`act=pass`；7 个站点静态审计；树外 `--root` 对抗（推导身份不扩权） | **PASS** 32✔ | §5，`logs/50-*.txt` |
| 5 doctor 与墓碑（R2 可见面） | 私有 server 全局环境带键 → doctor 一行（点名 + 不再授权 + 重启）；清掉后无该行；`config set`/`--dry-run` 均 exit 5 且文件 sha 不变；`config list` 仍列出 refuse 类 | **PASS** 12✔ | §6，`logs/60-*.out` |
| 6 夹具纪律（R3） | smoke §31c 的裸 kill 普查（全部属「私有/钉桩/私有 session/负向对照」四类）；lint 38 条自检 + 含本包的全仓扫描；`container-tmux.sh --selftest` 真跑 + 宿主指纹 | **PASS** 14✔ | §7，`logs/70-*.log` |
| 变异 ≥2 条 | ①去掉绑定身份检查 → ①d 未绑定夹具红；②token 去掉全局位限制 → 载荷透传夹具红；还原后实现零改动 | **PASS** 7✔ | §8，`logs/80.log` |
| Acceptance | `openspec validate --all --strict`；`TEAM_SMOKE_FAST=1 smoke.sh`；`container-tmux.sh --selftest` | **全绿** | §9 |

包总结果（`run.sh` 尾行）：

```
== M75-10-判定矩阵 结果 ==  ✓ 89  ✗ 0 finding 0 skip 0
== M75-20-socket表 结果 ==  ✓ 51  ✗ 0 finding 0 skip 0
== M75-30-环境零授权 结果 ==  ✓ 43  ✗ 0 finding 0 skip 0
== M75-40-argv-token 结果 ==  ✓ 47  ✗ 0 finding 0 skip 0
== M75-50-CLI路径 结果 ==  ✓ 32  ✗ 0 finding 0 skip 0
== M75-60-doctor墓碑 结果 ==  ✓ 12  ✗ 0 finding 0 skip 0
== M75-70-夹具纪律 结果 ==  ✓ 14  ✗ 0 finding 0 skip 0
== M75-80-变异 结果 ==  ✓ 7  ✗ 0 finding 0 skip 0
== M75 package result == PASS（finding/skip 见上文逐节）
```

---

## §1 判定按目标（R1，`pkg/10-verdict.sh`）

**自己的命名对象**（绑定身份 `TEAM_SESSION=teamx`，`TEAM_ROOT/TEAM_MAIN_ROOT` = cwd 祖先，共享默认
socket，桩为真身）：`kill-window -t teamx:dev`、`kill-pane -t teamx:dev.0`、`kill-session -t teamx`、
`-tteamx:dev` 连写、最后一个 `-t` 胜出（两个方向）、`kill-window -a -t teamx:dev`、
`kill-session -C -t teamx`（`-C` 只清告警、目标仍受约束）、`teamx:dev.1`、裸 `teamx` —— 全部
exit 0 / `act=allowed-owned` / sock=默认靶 / 桩收到 argv **逐字节**（含 `-t teamx:dev -t teamx:dev2`）。

**拒绝矩阵**（exit 64 + `act=refused` + 桩从未被叫）：`otherproj:pm`、`otherproj`、`%1`、`@1`、
`dev`（无 session 段）、`:dev`、`""`、无 `-t`、`.`/`+`/`-`、`teamxx:dev`、`Teamx:dev`、
「自己的目标 + 多余位置参数」、「自己的目标 + 未知旗标 `-x`」、`-t` 后缺值、裸 `-`；
`kill-server`、`kill-ser`、`kill-s`（歧义）、`kill-session -a -t teamx`、`-t teamx -a`（顺序反转）、
`-at` 组合旗标、无目标 `-a`。

原始矩阵（`logs/10-matrix.tsv`）：

```
row: ①a kill-window -t own            rc=0   sock=/tmp/tmux-1000/default  stub=exec argv=[kill-window -t teamx:dev]
row: ①b foreign otherproj:pm          rc=64  sock=/tmp/tmux-1000/default  stub=-    argv=[kill-window -t otherproj:pm]
row: ①c kill-server                   rc=64  sock=/tmp/tmux-1000/default  stub=-    argv=[kill-server]
```

**身份绑定（M40）**：cwd 在 `TEAM_ROOT` 之外 / `TEAM_SESSION` 缺失 / 为空 / 两个根都缺 / `TEAM_ROOT`
指向别处 → 全拒；`TEAM_MAIN_ROOT` 是 cwd 祖先（worker 窗口形状）或 cwd 在子目录 → 放行。

**拒绝文案**（`logs/10-refusal-samples.txt`，节选）：

```
$ tmux kill-window -t otherproj:pm   # 绑定身份 + 共享默认 socket
✗ teamsmith tmux 闸门：已拒绝 kill-window —— -t 'otherproj:pm' 的 session 段是 'otherproj'，与本项目身份 TEAM_SESSION='teamx' 不符
  解析出的 socket：/tmp/tmux-1000/default（共享默认 server：本机所有项目共用）
  唯一的带内放行（一次性、记 act=explicit-flag）：把 token 放在**子命令之前**：
    tmux --teamsmith-allow-destructive kill-window -t otherproj:pm
  或换私有 server：env -u TMUX -u TMUX_PANE TMUX_TMPDIR=<已 mkdir -p 的私有目录> tmux …
```

**只读直通**：`ls`、`list-sessions`、`display-message -p hi`、`capture-pane -p -t x`、
`send-keys -t x y` 全部 exit 0、桩各记一笔、无任何 `refused/allowed-owned/explicit-flag`。

**审计词汇**：四种调用（refused/allowed-owned/pass/explicit-flag）恰好四行，act 集合 =
`{pass, allowed-owned, refused, explicit-flag}`；`act=override` 在 shim 与产出日志里不存在。

## §2 socket 表（R1 的 M41 面，`pkg/20-sockets.sh`）

- **私有即直通、且不需要身份**：`TMUX_TMPDIR=<已建目录>`、`-L m75priv`、`-S <私有路径>`、
  `TMUX=<私有 socket>,1,0`、软链→私有目录（realpath 规范化）全部 `act=pass`，argv 逐字节到桩，
  日志 sock 正确；无 `TEAM_SESSION` 也放行。
- **共享默认靶的等价写法**：`-L default`、`-S /tmp/tmux-<uid>/../tmux-<uid>/default`（规范化后 =
  默认）、`TMUX=<默认 sock>,1,0`、`TMUX=,1,0`（逗号开头按无 TMUX 算）、`TMUX_TMPDIR=''` → 全拒。
- **假隔离两形态**：`TMUX_TMPDIR=<不存在>/sock` → 拒，文案点明「静默回退默认 socket」，日志 sock =
  **默认**靶，桩未被叫；`TMUX_TMPDIR=<普通文件>` → 拒，文案「不是目录」；假隔离 + 自己的目标名也拒；
  同形状的只读 `ls` 照常放行（sock 仍记默认）。
- **真私有 server**：`TMUX_TMPDIR=<私有>` 的 `kill-server` 真把私有 server 收掉（不是只记日志）。
- **不许动的地基**：socket 解析块与日志块各自与 `4b8a435^`（M67 前）**逐字节 diff 相同**
  （`diff` 无输出；提取时按两代文件的不同分节标记分别对齐）。

## §3 环境零授权（R2，`pkg/30-env-zero.sh`）

- 调用方环境：`TEAM_ALLOW_DESTRUCTIVE_TMUX=1/0/空` + kill-server/别的会话/空目标/未绑定身份 → 判定
  全不变（`refused`），日志无任何 `act=override`；显式 argv token 仍然有效（`explicit-flag`）。
- **泄漏形状 host 复现**：用带 `TEAM_ALLOW_DESTRUCTIVE_TMUX=1` 的环境**真起一台私有 tmux server**
  → `show-environment -g` 显示该键进了 server 全局环境 → 新 pane 的 `env` 里也确实带着它（中间环成立）
  → 该 pane 里经闸门的 `kill-server`（TMUX/TMUX_TMPDIR 清掉、解析到默认靶、钉桩）仍 exit 64 /
  `act=refused`、桩未被叫。容器版的完整形状由 `--selftest` 覆盖（§7）。
- **残留读取方普查**（`logs/30-residual-grep.log`）：`scripts/**` 里没有 `$TEAM_ALLOW_DESTRUCTIVE_TMUX`
  形态的变量展开、没有赋值/export；只剩退役注释、`cmd-config.sh` 的 `refuse` 墓碑行、doctor 的
  `show-environment -g` 只读探针（面板的两个 UI 短标签不在闸门路径）。`act=override` 在 `scripts/**`
  为零；tests/ 里的 6 处逐条核对全部是「断言它不存在」的负向夹具（见 §10 观察 1）。
- **词汇表**：shim 源码、真实拒绝文案、troubleshooting §18、config.md 退役行、CHANGELOG M36 条目
  均无 `override`。
- **窗口不带授权**：`team_tmux_shim_exports` 前缀 = PATH 最前 shim + `TEAM_TMUX_CALLS_LOG` +
  `TEAM_TMUX_REAL`，没有退役键；`team_agent_launch_cmd` / `team_pm_launch_cmd` 渲染结果同样为零。
- **日志契约未退化**：2100 行 → 调用后留最新 1000 行、最新一行为本次调用、丢的是最旧行；
  FIFO 日志目标不阻塞（rc=0）且调用照常透传。

## §4 argv token（R2，`pkg/40-token.sh`）

- 全局位 `--teamsmith-allow-destructive kill-server`（默认靶，桩）→ exit 0 / `act=explicit-flag` /
  日志 sock=默认 / 桩 argv = `kill-server`（token 剥掉）/ 被执行进程的环境里没有 token 字样；
  别的会话目标、两个 token、私有 socket 上的 token 都执行并记 `explicit-flag`。
- **子命令之后是数据**：`send-keys -t teamx:dev <token>` → `act=pass`，桩 argv 原样含载荷 token；
  「全局 token + 载荷 token」→ 只剥全局的（桩 argc=4，载荷保留）；`kill-server <token>` /
  `kill-window -t X <token>` → 拒（token 不授权）。
- **fail closed**：`--teamsmith-allow-destructive=1` 不识别 → 桩侧 exit 64 且桩未落盘；真私有 server
  侧真 tmux 报错退出（rc≠0）且私有 server 仍活着。token 作为 `-L` 的值不算 token（argv 原样、
  按私有 socket 放行）；`-L m75priv <token> kill-server` 只剥全局位的那个。
- **一次性真执行**：真私有 server 上 `tmux <token> kill-server` → exit 0、server 消失、记
  `explicit-flag`（不是 override）。

## §5 CLI 自用路径（D5，`pkg/50-cli-paths.sh`）

两条路径（`team teardown --agent` 与 `team pulse down`），两个方向：

```
$ # 默认 socket 钉桩（ownership 判定路径）
2026-09-22T03:04:01+00:00 · act=allowed-owned · sock=/tmp/tmux-1000/default · TMUX=- · TMUX_TMPDIR=- · argv=kill-window -t m75sess:m75ghost · pid=… cwd=/tmp/…/proj
2026-09-22T03:04:02+00:00 · act=allowed-owned · sock=/tmp/tmux-1000/default · TMUX=- · TMUX_TMPDIR=- · argv=kill-window -t m75sess:pulse · pid=… cwd=/tmp/…/proj
2026-09-22T03:04:02+00:00 · act=allowed-owned · sock=/tmp/tmux-1000/default · TMUX=- · TMUX_TMPDIR=- · argv=kill-window -t m75sess:watchdog · pid=… cwd=/tmp/…/proj
```

- ledger 里没有 `explicit-flag`、没有 `override`；CLI 输出真的报 `kill window m75sess:<name>`。
- **真私有 socket**：两路径的窗口（teardown 的 `m75ghost`；pulse 的 `pulse`+旧名 `watchdog`）在真实
  私有 server 上**真的被杀**（`list-windows` 前后对比），ledger 记 `act=pass`。
- **对抗（B1.4 推导身份不扩权）**：从项目树外 `team --root <proj> teardown --agent …` → ledger
  `act=refused`、桩只收到只读 `list-windows`、CLI 不报「杀了窗口」（绑定不成立）。
- D5 点名的 7 个站点（`cmd-agents.sh:779/812/1069`、`cmd-review.sh:883`、`cmd-watch.sh:1361/1376/1380`）
  静态审计：目标全是 `$TEAM_SESSION:<命名对象>`，站点里没有 token（`logs/50-cli-sites.log`）。

## §6 doctor 与墓碑（R2 可见面，`pkg/60-doctor.sh`）

```
$ team doctor    # 私有 server 全局环境带 TEAM_ALLOW_DESTRUCTIVE_TMUX=1
  tmux 闸门退役键     ! 运行的 tmux server 全局环境里还有 TEAM_ALLOW_DESTRUCTIVE_TMUX=1（M67 退役）：它不再授权任何操作（判定按目标）；重启该 server 后残留消失
```

清掉残留（`set-environment -gu`）后同一 grep = 0 行；`team config set TEAM_ALLOW_DESTRUCTIVE_TMUX 1`
与 `--dry-run` 都 exit 5，config 文件 sha256 前后一致（`922f59ba…`）；`config list` 仍列出该键且为
refuse 类。

## §7 夹具纪律（R3，`pkg/70-fixtures.sh`）

- **smoke §31c 普查**（507 行）：helper 把 `TEAM_TMUX_REAL` 钉到 argv 记录桩、PATH = shim:桩:系统、
  固定靶 `/tmp/tmux-$UID/default`、真杀只走私有 `TMUX_TMPDIR`；段首/段尾默认 server 探活只有只读
  `ls`。§31c 里所有裸 kill 逐条归档，全部落在四类里（`m36_priv` 私有包装 / `m36_bound|probe|mut_probe`
  钉桩 / ⑪ 在 smoke 自己的私有 session 上收尾 / ⑨ 的桩 PATH 负向对照），没有一条裸真杀默认 socket。
- **lint**：`--selftest` 38/38（含 `gate_token_bare` 红、`gate_token_private` 净、
  `gate_token_after_sub` 红、`abs_path_with_private` 红）；对仓库（含本复验包）扫描干净。
- **容器**：`container-tmux.sh --selftest` 真跑 exit 0 —— 容器内裸 kill-server 安全；泄漏形状
  「server 全局环境带退役键 → 无 token 拒（exit 64 / act=refused / server 还在）→ 带 token 执行
  （server 消失 / act=explicit-flag）→ 无 override」；宿主指纹前后逐字节不变（含本包独立捕获的
  默认 server 会话/客户端数、`tmux -V`、state ledger）。宿主默认 server 全程存活。

## §8 变异（红→绿，`pkg/80-mutations.sh`）

两个原始红绿对（副本都在 `/tmp`，实现零改动）：

```
⑧a 变异 A：判定里去掉「绑定身份」条件 → ①d 未绑定夹具
    GREEN 原件：①d 未绑定 → rc=64 act=refused 桩=未叫
    RED   mutant：①d 未绑定 → rc=0 act=allowed-owned 桩=被执行
⑧b 变异 B：token 去掉「全局参数位」限制（子命令后也剥）→ 载荷透传夹具
    GREEN 原件：argv 参数个数=4（载荷 token 保留）
    RED   mutant：argv 参数个数=3（载荷 token 被吃掉）
⑧c 被验实现（skills/openspec/extension）相对 HEAD 无改动；shim/tmux 相对 HEAD 逐字节未动
```

## §9 Acceptance

```sh
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ spec/verification … ✓ spec/watchdog
Totals: 15 passed, 0 failed (15 items)                    # rc=0
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2294  ✗ 0        # rc=0，用时 432 s；FAST 跳过 27 个真进程段落（含 31c 的 ⑩/⑪ 与 31b 容器自检）
smoke 全绿
$ bash skills/teamsmith/tests/container-tmux.sh --selftest
✓ 自检通过：容器内 tmux 生死正常（含裸 kill-server），宿主 server 指纹逐字节不变（90936a40…）   # rc=0
```

FAST smoke 里 §31c 的静态探针段（①–⑨）全绿，真身解析行：

```
· 31c 真身解析：默认 socket 探针 → …/m36/stub/tmux（argv 记录桩，TEAM_TMUX_REAL 钉死）；真杀探针 → /usr/bin/tmux（只打私有 socket）
✓ 默认 server 前后都活着（本段没碰它）
```

被 FAST 跳过的两个真进程子段由本包独立补上：真私有 server 生死/退役键/token（§2 ②e、§4 ④d）与
CLI 真执行（§5）；完整 smoke（含 ⑩/⑪）仍是 PM/`team review` 的门禁。

## §10 观察（不构成 finding，记录备查）

1. **`act=override` 在 tests/ 里以负向断言形式存在**（6 处：`smoke.sh` 5 + `container-tmux.sh` 1），
   闸门代码与产出日志为零。M67 报告引用的 `grep -rn 'act=override' skills/teamsmith/`「无输出」按
   字面不成立（它只在「断言该词不存在」的夹具文本里）；动作值语义没有被破坏（R2 的 `MUST NOT be
   named override` 成立）。tasks.md 1.3 的验证口径若要求字面 grep 为零，应改为 `scripts/**`。
2. **`container-tmux.sh --selftest` 的宿主指纹检查对共享 server 的并发活动敏感**：7 次运行中 2 次
   fixture 内部前/后指纹不等（逐字节证据 `logs/70-fingerprint-flake-evidence.txt`），两次里本包在整段
   外捕获的宿主指纹都前后一致、容器内泄漏形状断言全过；随后 3 次直跑 + watcher 观测（默认 server
   上 <peer>/<peer-d>/<other-project>/teamsmith 四个活动会话的窗口数在动）全绿。指纹含 `#{session_windows}` 与
   `list-clients` 数，他项目窗口增删就会抖动 —— 环境竞争，非 M67 引入；若 PM 认为 gate 需要稳定，
   处置在 fixture（比如只比 socket 存在性与 server 进程集）而非闸门。
3. **B1.4（`scripts/team` 载入配置后导出推导身份）**：超出 B1.3「nothing else changes argv」的字面，
   但 apply 报告已明确宣告、M67 复核记录在案；本包 §5 的树外 `--root` 对抗证明它不扩大授权面（绑定
   仍要求 `TEAM_ROOT/TEAM_MAIN_ROOT` 是 cwd 的祖先），CLI 自用路径靠 ownership 过（`allowed-owned`），
   未给任何站点加 token。

## §11 决定与偏差

- 不复述 M67 的 apply 结论：所有断言都由本包的独立探针在**被验修订**上重跑；不引用 apply 报告里
  的数字。
- 默认 socket 上的破坏性探针一律钉桩（不真执行），真执行只在私有 server —— 因此「默认 socket 上
  token 会执行真 kill」只以桩 argv/exit/log 证明，真 kill 由容器夹具在容器自己的默认 socket 上证明
  （与 R3 的纪律一致）。
- 独立探针一开始把 `kill-session -Ct teamx` 当拒绝；按 tmux 语义（`-C` 清告警，目标仍受 `-t` 约束）
  与 D2 表格修正为放行，矩阵随之保留该用例（它证明「组合旗标逐字符走」没有把 `-C` 误当加宽）。
- 无实现改动；分支为本地模式（不 push），报告与原始日志一并提交。

## §12 给 PM 的建议

- 复验入口：`bash docs/team/reports/M75-dev3/pkg/run.sh`（或 `--only 10…80`）；`team review M75 --strong`
  可直接引用 `pkg/logs/` 的原始输出。
- 若批准 archive：`openspec/changes/tmux-gate-grant-redesign/` 的三条 ADDED 需求已全部由本记录覆盖；
  §10.1 的 grep 口径与 §10.2 的 fixture 抖动是否需要收尾由 PM 决定（都不阻塞本 change 的正确性）。
- BLOCKED：无。
