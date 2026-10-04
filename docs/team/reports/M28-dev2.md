# M28 · tmux 接触型测试进 podman 容器 + 裸 tmux 调用 lint

agent: dev2   status: 交付（待 PM 复验）   time: 2026-09-18
branch: `task/M28-tmux-podman-tmux-lint`   PR/MR: -（本仓库 local 模式：不 push，分支留在 `.worktrees/dev2`，PM 复验后本地合并）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/container-tmux.sh` | 一条命令把「探测运行时 → 准备镜像 → 只读挂载仓库 → 在容器里跑给定命令」打包。运行时探测：`command -v podman`（真宿主直跑）＞ `distrobox-host-exec podman`（distrobox 里回宿主），可用 `TEAM_TMUX_RUNTIME` 显式指定。容器内 `env -u TMUX -u TMUX_PANE -u DBUS_SESSION_BUS_ADDRESS`；`--selftest` = 容器内 tmux 生死（含裸 `kill-server`）+ 宿主 server 指纹前后不变；容器不可用（没有 podman / 镜像构建失败 / 仓库路径不在宿主共享目录）→ 打印 `SKIP: <理由>` 并 **exit 77**（门禁跳过，不是红） |
| `skills/teamsmith/tests/tmux-lint.pl` | tmux 隔离 lint（真 shell 词法器，不是按行 grep）：扫 `tests/**` 与 `docs/team/reports/*/pkg/**`，凡 `kill-server/kill-session/kill-window/new-session/new-window/kill-pane/respawn-pane/split-window` 必须带隔离证据。`--selftest` 25 个双向夹具 + 历史豁免机制 3 条；`--list` 打印每条调用与判定；`--no-legacy` 让历史豁免全部报红 |
| `skills/teamsmith/tests/tmux-lint-legacy.txt` | 历史豁免清单（仅 M28 之前的 14 个证据包 / 34 条）：按 sha256 冻结、条数写死、每轮打印；文件一改或条数不符即红 |
| `tests/flip-glue.sh` · `flip-m4.3.sh` · `flip-m6.3.sh` · `flip-m6.5.sh` · `flip-m7.2.sh` | 五个夹具自己的 tmux 调用补上调用点可见的隔离证据（顶层 `unset TMUX TMUX_PANE` + 私有 `TMUX_TMPDIR`）；原先只有 PATH shim 或什么都没有 |
| `skills/teamsmith/tests/smoke.sh` | 新增第 31 节：31a = lint（纯逻辑，FAST 也跑，含门禁级三步翻转）；31b = 容器自检 + 容器里跑真 pi 体检（真进程，仅 FULL；条件不满足显式 SKIP）。另：15b 的「文档不得把容器当依赖」不变量细化为「产品 vs 测试 harness」两分，并补双向夹具 |

## 机制：为什么这样判定（M28 实测，全是只读探针）

tmux 客户端选 socket 的优先级（`display-message -p '#{socket_path}'` 探针；没有 server 时只报连接失败、不会起 server）：

```
#1 TMUX 设了 + 私有 TMPDIR + -L        → /tmp/m28td/tmux-1000/m28probe      （-L 赢过 $TMUX）
#2 TMUX 设了 + -L                      → /tmp/tmux-1000/m28probe           （-L 赢过 $TMUX）
#3 TMUX 清掉 + 私有 TMPDIR             → /tmp/m28td/tmux-1000/default       （私有目录生效）
#4 TMUX 设了 + 私有 TMPDIR（事故形状） → /tmp/tmux-1000/default             （$TMUX 压过 TMPDIR ⇒ 打到真实 server）
#5 TMUX 清掉、没有私有 TMPDIR         → /tmp/tmux-1000/default             （还是调用者的默认 server ⇒ 光 unset 不够）
```

（原文：`pkg/logs/50-socket-routing-probes.log`；全部是 `display-message -p '#{socket_path}'`，只有 #4/#5 真的连上了 server。）

⇒ 「隔离证据」只有两类成立：**`-L <非 default>` / `-S <非 /default>`**，或 **`env -u TMUX` + 私有 `TMUX_TMPDIR`**。
光 `env -u TMUX`（没有私有目录）仍会回到 `…/tmux-<uid>/default`（探针 #5），所以 lint 比任务书写得更严：
任务书要求「不带 `env -u TMUX`/已 unset → 红」，本实现把 `env -u TMUX` 单独存在也判红（缺私有目录）。
PATH shim（`exec /usr/bin/tmux -L …`）**不算证据**：M23 实测登录 shell 会重建 PATH、夹具回落默认 server（165 条红）。

## Verification evidence

全部在 `.worktrees/dev2`（今天 08:0x–08:4x）实跑，原文存在 `pkg/logs/`。

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ spec/agent-adapters … ✓ change/console-board-page … ✓ spec/watchdog
Totals: 14 passed, 0 failed (14 items)                     rc=0        # pkg/logs/31-accept-openspec-validate.log

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
== 31 · tmux 接触面：隔离 lint + 容器跑法（M28） ==
  ✓ M28：tmux 隔离 lint 存在
  ✓ M28 真树：变更类 tmux 调用全部有隔离证据（另有 14 个历史豁免文件，逐条打印）
  ✓ M28 lint --selftest：双向夹具全部符合预期（检查器这两方向都可信）
  ✓ M28 翻转①：干净文件（没有 tmux 调用）不报红
  ✓ M28 翻转②：塞一条裸 tmux kill-server → 红
  ✓ M28 翻转③：同一个 kill-server 带私有 -L → 不报红（不是见 kill-server 就红）
  SKIP（FAST 模式） 31b·容器 tmux 自检（podman） —— 要拉起 podman 容器做 tmux 生死实验（真进程），快模式不跑
== 结果 ==  ✓ 1572  ✗ 0            smoke 全绿                rc=0        # pkg/logs/30-…（首次）与 33-…（改完在冻结的树上复跑）

$ bash skills/teamsmith/tests/smoke.sh                       # 全量（含 31b 真进程部分）
== 31 · … ==
  ✓ M28 容器自检：容器内裸 tmux 开窗/杀 server 正常，宿主 server 指纹逐字节不变
  ✓ M28 容器里跑真 pi 体检：输入框判据 + 收回在真实现场成立
  ✓ M28 容器里跑真 pi 体检：空闲空框被判 EMPTY（没被误判成忙）
== 结果 ==  ✓ 2005  ✗ 0            smoke 全绿                rc=0        # pkg/logs/32-…（首次）与 34-…（冻结树上复跑）

$ bash skills/teamsmith/tests/container-tmux.sh --selftest
宿主 tmux 指纹（前）：f08edec0335c83abc49e2a7f6cffdcaa
  ok   容器内 tmux 可用 / TMUX 已清空 / TMUX_PANE 已清空 / DBUS_SESSION_BUS_ADDRESS 已清空
  ok   宿主 socket 不可见（/tmp/tmux-1000/default） / 容器 socket 目录里没有宿主的 tmux-1000
  info 裸 tmux 用的 socket：/tmp/tmux-0/default
  ok   裸 tmux new-session 在容器里成功 / capture-pane 能读 / 裸 tmux kill-server 成功
  ok   kill-server 后容器内没有 server
宿主 tmux 指纹（后）：f08edec0335c83abc49e2a7f6cffdcaa
✓ 自检通过：容器内 tmux 生死正常（含裸 kill-server），宿主 server 指纹逐字节不变    rc=0   # pkg/logs/20-…

$ bash skills/teamsmith/tests/container-tmux.sh --with-pi --cmd 'bash $PWD/skills/teamsmith/tests/pm-box-real.sh --idle-secs 3'
M24 真实 pi 窗格体检 · pi=<home>/.bun/bin/pi · 私有 socket=/tmp/teamsmith-pmbox.EDmIkA/tmux · idle=3s
--- 空闲空框（真实 pi） ---   verdict=EMPTY state=EMPTY
--- 粘贴之后（守卫的复检视角） --- verdict=BUSY state=BUSY  HOLDS_ONLY=yes RETRACT=ok
✓ 隔离自检：夹具 session 不在真实默认 server 上                rc=0（6.2s）  # pkg/logs/21-…

$ PATH="/tmp/m28-fakebin:$PATH" bash skills/teamsmith/tests/container-tmux.sh --selftest   # 真宿主直跑分支（podman 在 PATH）
runtime: podman（本机直跑） … ✓ 自检通过（宿主指纹不变）                     rc=0   # pkg/logs/22-…
$ TEAM_TMUX_RUNTIME=/nonexistent/rt bash skills/teamsmith/tests/container-tmux.sh --selftest
SKIP: 找不到可用的容器运行时（podman 直接不可用，distrobox-host-exec podman 也不通）—— 容器不可用时门禁跳过而不是红   rc=77  # pkg/logs/23-…
$ TEAM_TMUX_IMAGE=teamsmith-tmux-test:nope bash skills/teamsmith/tests/container-tmux.sh --selftest
SKIP: 镜像 teamsmith-tmux-test:nope 不存在（TEAM_TMUX_IMAGE 指定了名字就不会自动构建）  rc=77  # pkg/logs/24-…

$ # M25 形状的后台进程组 + tty（私有 socket 的 tmux 窗口里 `cmd &`，就是 review 门禁的跑法）
[selftest] 完成 rc=0 用时≈2s pane=zsh          # pkg/logs/25-bg-process-group-tty-selftest.log
[run]      完成 rc=0 用时≈7s pane=zsh          # pkg/logs/26-bg-process-group-tty-pmbox.log（没有被 SIGTTIN 停住）

$ bash skills/teamsmith/tests/flip-glue.sh          # 被改过的 5 个夹具之一（隔离块加上之后仍然通过）
✓ 隔离：team paths 指向临时根 … ✓ GREEN：草稿原样留在输入框；state/outbox/ 1 条；真项目未被写入   exit=0

$ TEAM_FLIP_BASE=b853dee~1 bash skills/teamsmith/tests/flip-m6.5.sh
✓ 修复前：up 没有启动 PM（旧输出：✓ PM 在运行（tmux）） / ✓ 修复后：up 真的启动了 PM
flip-m6.5：翻转已复现（红 → 绿）                rc=0（flip-m4.3/flip-m6.3/flip-m7.2 需要各自的 BASE，只做了 bash -n；见 Notes）
```

- Verdict: **pass**（四条验收命令全部实跑；`openspec validate` 14/14；FAST 1572/0；FULL 2005/0；容器自检 + 真 pi 体检通过）。
  最后一次 FAST（33-…）与 FULL（34-…）是在所有改动都提交完后的树上跑的（包括 harness 头部文档/`--keep-shim` 的改名）。
- Notes：
  * 未验证：`flip-m4.3 / flip-m6.3 / flip-m7.2` 的完整重跑（它们要求一个「修复前」的 BASE，默认 BASE 已是修复后 → 脚本自己 exit 2）；这三个只跑了 `bash -n` 与 lint。
  * 未验证：真正的「宿主机上没有 distrobox」场景（只有 `PATH` 里假 podman 走通直跑分支 + `TEAM_TMUX_RUNTIME` 不可用/镜像缺失两条 SKIP）。
  * 未验证：镜像**构建**失败路径（需要断网）；代码里是显式 `SKIP` + exit 77。
  * 判定器的已知盲区（写在 `tmux-lint.pl` 文件头，免得被当成保证）：非 shell 文件里用字符串对拼 argv 的调用
    （`["tmux","kill-server"]`）不在命令位判据内；`tmux new-window … "<窗口命令串>"` 里嵌的调用不递归扫描；
    `-L "$v"` 用变量时只能挡住字面 `default`。这三类都需要人工看（或以后加强）。

## Flip evidence

**① 门禁级翻转（真树塞一条裸调用 → 红 → 删 → 绿）**

```
$ printf '#!/usr/bin/env bash\n# M28 翻转探针（临时）\ntmux kill-server\n' > skills/teamsmith/tests/m28-flip-probe.sh
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
== 31 · … ==
  ✓ M28：tmux 隔离 lint 存在
  ✗ M28 真树有未隔离的 tmux 变更命令（见 …/m28-lint.log）
         RED  skills/teamsmith/tests/m28-flip-probe.sh:3  tmux kill-server
  ✓ M28 lint --selftest：双向夹具全部符合预期
== 结果 ==  ✓ 1571  ✗ 1                  smoke 有失败项   rc=1     # pkg/logs/10-flip-gate-red-with-probe.log（全文）

$ rm -f skills/teamsmith/tests/m28-flip-probe.sh
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
== 31 · … ==  ✓ M28 真树：变更类 tmux 调用全部有隔离证据 …
== 结果 ==  ✓ 1572  ✗ 0                  smoke 全绿       rc=0     # pkg/logs/30-…
```

**② 门禁内每次都会跑的三步翻转**（第 31a 节的 `翻转①②③`）：干净文件不红 → 塞裸 `kill-server` 红 → 同一个调用带 `-L <私有名>` 又变净
（证明它不是「见到 kill-server 就红」）。

**③ 判定器自带 25 个双向夹具**（`tmux-lint.pl --selftest`，每次门禁都跑）：

```
ok  bare / bare_new_session / unset_without_private / env_u_without_dir / minus_L_default
ok  wrapper_not_isolated / file_level_order / bash_c_string / if_then / unquoted_heredoc_code / inside_subst / shim_not_enough     ← 该红的红
ok  env_u_private_dir / minus_L / minus_S_private / wrapper / wrapper_L / file_level_unset_dir / bash_c_string_isolated / comment / doc_quoted_string / readonly_cmd / quoted_heredoc_data / flag_value_skip / multi_line_cont   ← 该净的净
ok  exempt_hash_pinned / exempt_bad_count / exempt_stale_hash                    ← 历史豁免机制（哈希锁定净；条数不符/文件改动红）
✓ tmux-lint --selftest：25 个夹具 + 历史豁免机制全部符合预期
```

**④ 5 个被改的 flip 夹具**：`bash -n` 全过；`flip-glue.sh` 与 `flip-m6.5.sh` 完整重跑仍复现翻转（见上）。
**⑤ 15b 容器不变量细化的双向夹具**（FULL 日志 1200–1201 行）：讲「产品跑在容器里」→ 红；讲「测试 harness 用容器」→ 净。


## Decisions and deviations

- **历史豁免（对任务书的偏离，必须由 PM 裁决）**：任务书要求 `docs/team/reports/*/pkg/` 里的裸调用也**红**。
  实测：M28 之前的 4 个证据包（V3.0 / M3.3-dev2 / V4.0 / M23-dev2）共 14 个文件 34 条不满足新纪律 ——
  它们写于隔离纪律成型之前（靠 PATH shim 或什么都没有），而它们是**别人验过的证据**，就地改等于改账本。
  本实现里这些**文件**按内容哈希冻结成显式豁免：每轮打印 `LEGACY <路径> ×N`、清单里条数与 sha256 都要对得上
  （对不上即红）、`--no-legacy` 可让它们全部报红。新增/改动的证据包不在豁免范围：写新 pkg 时调用点必须有证据。
  如果 PM 想要「连历史也必须红」，那就得先改那 14 个证据包（需要 PM 授权动别的 agent 的 report 目录）。
- **lint 比任务书更严**（见上）：`env -u TMUX` 单独不算，必须配私有 `TMUX_TMPDIR` 或 `-L/-S`。
- **容器里跑真 pi 的取舍（任务书要求写报告）**：走「真 pi」而不是「假 pi」，但**不挂 `$HOME`**：
  容器内 `pi` 是运行时生成的包装器（alpine 的 `node` 跑只读挂进来的 `@earendil-works` 包目录），
  于是容器里的 pi 拿不到 provider 配置/密钥（镜像层里也没有任何密钥），也写不到宿主的 `~/.pi`。
  代价：容器里的 pi 没有模型（启动时提示 `No models available`）——对这一类夹具正好，它只关心输入框的真实渲染，
  不需要模型。实测 `tests/pm-box-real.sh` 在容器里 6.2s 跑完，`verdict=EMPTY/BUSY`、`RETRACT=ok` 与宿主一致。
- **第 4 项文档（`references/troubleshooting.md` + PM 提示词模板）是 PM 目录**：本合同 `OWNERSHIP.md` 把
  `references/**`、`templates/**` 划给 PM（agent 只能建议）。所以我没有改这两个文件，而是在下面给出**可直接粘贴的文本**，
  并在 tests 侧把 15b 的旧不变量细化成「产品 vs 测试 harness」两分（带双向夹具），这样 PM 加文档时不会撞
  「文档不得把容器当依赖」那条老检查（`podman` 出现在讲 `container-tmux.sh` 的行上不再报红，讲产品依赖容器仍报红）。

## Suggested next steps
- `BLOCKED:`（**仅限任务书 Deliverables 第 4 项 —— 文档**）：`skills/teamsmith/references/troubleshooting.md` 与
  `skills/teamsmith/templates/pm-prompt.md.tmpl` 属 PM 目录（`OWNERSHIP.md`：agent 只能建议）。请 PM 落盘这两段文本，
  可直接粘贴的全文在 `docs/team/reports/M28-dev2/pkg/pm-docs-suggested.md`。除这两段文档外，其余交付项（1/2/3）
  均已实现并在冻结的树上跑完验收命令。
- **PM 需裁决**：① 14 个历史证据包的豁免（保留 / 授权清理）；② 上面两段文档的落盘（或授权我代改）。
- 复验时的建议命令（严格版）：
  `perl skills/teamsmith/tests/tmux-lint.pl --no-legacy`（看全部 34 条历史命中；tail 存档在 `pkg/logs/41-…`）
  `perl skills/teamsmith/tests/tmux-lint.pl --list`（列出每条变更命令与它的判定）
  `bash skills/teamsmith/tests/container-tmux.sh --selftest`
  `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh`
- 后续可做的（不在本任务范围）：把 `flip-m4.3/m6.3/m7.2` 改成不再依赖「修复前 BASE」也能跑（现在默认 BASE 已是修复后 → exit 2）。
