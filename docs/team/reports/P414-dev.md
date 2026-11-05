# P414 · 搬进 lib 的 PM 窗口助手用的是裸 tmux，静态隔离 lint 判红

agent: dev   status: delivered   time: 2026-11-05T03:30:00Z
branch: `task/P414-lib-tmux-guard`   PR/MR: -

## 结论

`skills/teamsmith/tests/lib/pm-window.sh` 的 tmux 调用现在都经**专用名**包装 `pmw_tmux`，把隔离写进文本
（`env -u TMUX` + 本轮私有 `TMUX_TMPDIR`）、缺私有目录就响失败；kill 类调用仍先过 P162 的三条件前置
（复用套件壳同一份 `tmux_iso_require`，没有第二份判定）。lint 改前 4 条红 → 改后干净，红侧点名新放回的
那一行。两个选段验收全绿：`--select 31` ✓33 ✗0、`--select 11b4` ✓96 ✗0。

一条与简报的差异（不是范围变化，是数量）：红的是 **4 条不是 3 条** —— CI 现场里 `§31` 只打印
`grep '^  RED' | head -3`，第 4 条 `pm-window.sh:103`（建 PM 窗口那条 `new-window`）被截掉了；改前同一条
lint 在本树上就是 4 条红（下文的「改前」是真跑）。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/lib/pm-window.sh` | 文件头加「为什么不裸调」；新增 `pmw_tmux` / `pmw_tmux_require`；`wait_session_gone` / `wait_window_gone` / `make_pm_idle` 里的 6 处 tmux 调用全部改走 `pmw_tmux` |

没有改 lint 判据、没有白名单、没有 `command tmux`、没有 `|| true` 掩盖，只动了这一个文件。

## Verification evidence（全部在本 worktree、本分支树上实跑）

### 1. lint 改前（真树，改前那一刻的树；与公开 CI 同一条判据）

```
$ perl skills/teamsmith/tests/tmux-lint.pl
  RED  skills/teamsmith/tests/lib/pm-window.sh:90  tmux new-window -t $SESSION -n keep -d -c $REPO /dev/null 2 1
       缺：-L/-S + unset TMUX + 私有 TMUX_TMPDIR
  RED  skills/teamsmith/tests/lib/pm-window.sh:92  tmux new-session -d -s $SESSION -n keep -c $REPO /dev/null 2 1
       缺：-L/-S + unset TMUX + 私有 TMUX_TMPDIR
  RED  skills/teamsmith/tests/lib/pm-window.sh:96  tmux kill-window -t $wid 2 /dev/null
       缺：-L/-S + unset TMUX + 私有 TMUX_TMPDIR
  RED  skills/teamsmith/tests/lib/pm-window.sh:103  tmux new-window -t $SESSION -n $PMW -d -c $REPO bash --noprofile --norc /dev/null 2 1
       缺：-L/-S + unset TMUX + 私有 TMUX_TMPDIR
tmux-lint：4 条变更命令没有隔离证据（扫描 71 个脚本，其中 181 条变更命令；历史豁免另算 0 条）
```

（同一份「改前」也可以从提交里复现：`git show HEAD~1:skills/teamsmith/tests/lib/pm-window.sh` 放进一个
空目录，`perl …/tmux-lint.pl --root <那个目录>` → 同样 4 条 RED、`扫描 1 个脚本，其中 4 条变更命令`。）

### 2. lint 改后

```
$ perl skills/teamsmith/tests/tmux-lint.pl
tmux-lint：干净（扫描 71 个脚本，181 条变更命令全部有隔离证据）
$ echo $?
0
```

条数仍是 181（不是 177）：这 4 条调用**没有**从判据里消失，而是从「无证据」变成了「经带证据的专用名包装
`pmw_tmux`」（lint 的规则 C）——`pmw_tmux` 的函数体在它的 7 行窗口内带 `env -u TMUX` + `TMUX_TMPDIR=`。

### 3. 红侧（简报第 3 条）：放回一条裸调用 → 必须红并点名

```
$ # 在 make_pm_idle 的 kill 循环后临时插入一行裸调用
$ tmux kill-window -t "$PMW" 2>/dev/null || true   # P414 红侧：放回一条裸调用
$ perl skills/teamsmith/tests/tmux-lint.pl
  RED  skills/teamsmith/tests/lib/pm-window.sh:113  tmux kill-window -t $PMW 2 /dev/null
       缺：-L/-S + unset TMUX
tmux-lint：1 条变更命令没有隔离证据（扫描 71 个脚本，其中 182 条变更命令；历史豁免另算 0 条）
$ echo $?          # 1
$ cp <green 副本> skills/teamsmith/tests/lib/pm-window.sh
$ cmp <green 副本> skills/teamsmith/tests/lib/pm-window.sh && echo 'restored byte-identical'
restored byte-identical
$ perl skills/teamsmith/tests/tmux-lint.pl
tmux-lint：干净（扫描 71 个脚本，181 条变更命令全部有隔离证据）
```

点名的行号就是新插入的那一行（113），不是文件里任何旧行。

### 4. `--select 31`（tmux 接触面：隔离 lint + 双向夹具 + 翻转）

```
$ bash skills/teamsmith/tests/smoke.sh --select 31 </dev/null
== #5 31 · tmux 接触面：隔离 lint + 容器跑法（M28） ==
  ✓ M28：tmux 隔离 lint 存在
  ✓ M28：豁免清单存在
  SKIP（条件不满足） M28 真树：变更类 tmux 调用全部有隔离证据（豁免清单） —— 检出形状 internal：豁免清单注册的路径逐条不在（冻结的证据层） docs/team/reports/*/pkg/** 在检出里不存在（跳过不是通过）
  ✓ M28 真树：变更类 tmux 调用全部有隔离证据（另有 0 个历史豁免文件，逐条打印在 …/m28-lint.log）
  ✓ M28 lint --selftest：双向夹具全部符合预期（检查器这两方向都可信）
  ✓ M28 翻转①：干净文件（没有 tmux 调用）不报红
  ✓ M28 翻转②：塞一条裸 tmux kill-server → 红
  ✓ M28 翻转③：同一个 kill-server 带私有 -L → 不报红（不是见 kill-server 就红）
  ✓ M41 翻转④：字面绝对路径 kill-server（即使带私有 -L）→ 红（网关看不到它）
  ✓ M41 翻转⑤：变量形式（"$REAL_TMUX" + 私有 -L）照旧不红（REAL_TMUX 解析类例外）
  SKIP（条件不满足） 31b·容器 tmux 自检（podman） —— 找不到可用的容器运行时（podman 直接不可用，distrobox-host-exec podman 也不通）——容器不可用时门禁跳过而不是红
#5 31 · … · 参考 用时 4s · ✓9 ✗0 SKIP2
账本自查： 5 段收口 · 增量 ✓33 ✗0 SKIP2 ｜ 结果行 ✓33 ✗0 —— 一致
== 选段结果 ==  ✓ 33  ✗ 0
rc31=0
```

### 5. `--select 11b4`（搬走之后功能不能坏）

```
$ bash skills/teamsmith/tests/smoke.sh --select 11b4 </dev/null
  ✓ P36 ②：--fresh-pm 真的把 PM 拉起来了
  ✓ P36 ②：--fresh-pm 起出的 PM 判定为 running（running:1870102）
  ✓ P36 ③：默认那一轮真的带 -c（②的对照）
  ✓ P36 ④：同 cwd 有活 PM CLI 会话 → 打提示
  ✓ P36 ⑤：没有同 cwd 活会话时不打提示
#6 11b4 · PM 交接：--fresh-pm 与同 cwd 活会话提示（P36） · 参考 用时 17s · ✓33 ✗0 SKIP0
账本自查： 6 段收口 · 增量 ✓96 ✗0 SKIP0 ｜ 结果行 ✓96 ✗0 —— 一致
== 选段结果 ==  ✓ 96  ✗ 0
rc11b4=0
```

### 6. 段映射与账本

```
$ bash skills/teamsmith/tests/section-select.sh --check
ok: 分片是地板的精确划分（N=2 3 4 5 6 8 12：129 段，每片非空、无重复、无遗漏）
ok: 分片只依赖 key：(a) …(b) …(c) …片号都不变…
ok: 表里每一行的 key 都能被哈希（139 个 key × 7 个 N 都在 0..N-1 内）
ok: 两阶段是全部段的精确划分（一阶 133 + 二阶 6 = 表 139 行；二阶每段有理由、都是 gate-self-check 段）
SKIP（条件不满足）: 行 19 的字面模式在检出里不存在（检出形状 internal …）：.pi/skills
== 选段自检 ==  ok 13  bad 0  SKIP 1      （rc=0）

$ bash skills/teamsmith/tests/section-select.sh --self-sufficient
== 段副本自足 == ok 139 bad 0（139 个键；段体函数 438 个，assert_* 未定义 0 个，整份套件的命令词 821 个）   （rc=0）

$ git diff --check
（无输出；rc=0）
```

- Ledger ban（模板的固定验收行，在本 worktree、本分支树上跑）：

  ```
  $ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
  ledger-ban: names：名单已配置（/home/<user>/…/pm-skills/.git/../.pi/team/forbidden-names.txt，命中即红）
  ledger-ban: root=/home/<user>/…/.worktrees/dev scope=published files=2380 hits=0 names=ok user=resolved
  $ echo $?
  0
  ```

  简报写的字面形式 `--names-file .pi/team/forbidden-names.txt` 在**这个 worktree** 里是
  `SKIP names —— 禁令名单未配置`（`.pi/team/` 下只有 `state/`，名单只在主检出里存在；这是一条 skip，不是通过），
  所以上面贴的是模板那条能真正读到名单的形式。

### 7. 运行行为（自己造的探针，不落仓库；`/var/tmp/p414/probe-runtime.log`）

```
① 正常：私有目录 → 建会话成功，socket 就是本轮私有那条
   rc=0
   socket=/var/tmp/p414/probe/priv/tmux-1000/default
② 破坏形状：TMUX_TMPDIR 指向不存在的目录 → kill 类硬停（不执行）
   裸调解析=/tmp/tmux-1000/default
   pmw_tmux kill-window 退出码=2
   ✗ 隔离前置不成立：TMUX_TMPDIR=/var/tmp/p414/probe/nope 指向不存在的目录（真 tmux 会静默回退默认 socket）
     段 pm-window · 用途 PM 窗口现场：kill-window · 实际 socket /tmp/tmux-1000/default（期望 …/nope/tmux-1000/default）
     硬停（exit 2）：这条破坏性 tmux 调用绝不执行
   SKIP（前置不成立：…） pm-window
   本轮私有 server 上 keep 窗口还在吗： keep        ← 调用确实没执行
③ TMUX_TMPDIR 未设 → 响失败（rc≠0），且不发 tmux 调用
   rc=1
   ✗ pm-window 夹具：TMUX_TMPDIR 未设 —— 拒绝回落调用者的默认 server
```

### 没验到的（如实）

- **没跑全量 smoke**（简报要求），也没跑 FAST；上面两个选段只覆盖 `0` / `0b` / `0c` / `0d` / `2` / `31` 与
  `11b4`，报告尾部那 133 / 134 个键**这次没跑**（连带的 §11b / §11b2 / §11b3 / §11c 也都在没跑的清单里）。
- **§31 里的容器自检（31b）SKIP**：本机 podman 直接不可用、`distrobox-host-exec podman` 也不通 —— 与本次
  改动无关，但它意味着「容器里跑 tmux 夹具」这条这次没有证据。
- 内部检出上 §31 的「真树带豁免清单」那条是 **SKIP 不是通过**（`docs/team/reports/*/pkg/**` 在检出里不存在）；
  真树 lint 本身（不带豁免）是绿。
- 运行行为探针是我自己写的临时脚本（`/var/tmp/p414/`），**不是**门禁的一部分；它证明的是「包装仍保留
  改动前套件壳在这三处做过的前置」，不是新增断言。

## Flip evidence

```
$ # 先复现缺陷（改前）
  RED  …/lib/pm-window.sh:90  tmux new-window -t $SESSION -n keep -d -c $REPO …
  RED  …/lib/pm-window.sh:92  tmux new-session -d -s $SESSION -n keep -c $REPO …
  RED  …/lib/pm-window.sh:96  tmux kill-window -t $wid 2 /dev/null
  RED  …/lib/pm-window.sh:103 tmux new-window -t $SESSION -n $PMW -d -c $REPO bash --noprofile --norc …
  tmux-lint：4 条变更命令没有隔离证据（扫描 71 个脚本，其中 181 条变更命令）   rc=1

$ # 改后
  tmux-lint：干净（扫描 71 个脚本，181 条变更命令全部有隔离证据）              rc=0

$ # 再故意破坏（往同一个文件放回一条裸 kill-window）→ 守卫必须红且点名
  RED  …/lib/pm-window.sh:113  tmux kill-window -t $PMW 2 /dev/null
       缺：-L/-S + unset TMUX
  tmux-lint：1 条变更命令没有隔离证据（扫描 71 个脚本，其中 182 条变更命令）   rc=1

$ # 还原（逐字节 cmp 相同）→ 再绿
  restored byte-identical
  tmux-lint：干净（扫描 71 个脚本，181 条变更命令全部有隔离证据）              rc=0
```

## Decisions and deviations

1. **包装放在 `pm-window.sh` 自己文件里**（`pmw_tmux` / `pmw_tmux_require`），没有从 `tmux-iso.sh` 另取一个通用名：
   这两个助手只服务本文件的场景（PM 空窗准备），名字带 `pmw_` 前缀不会被别处顺手抄走；lint 的规则 C 按
   「本文件定义的专用名包装」认它，正好是 P173 要求的那种不带歧义的证据。
2. **kill 类仍然前置证明**：如果只写 `env -u TMUX … tmux "$@"`，这 3 处 kill 类调用就从「套件壳的三条件
   前置」退化成「只要 TMUX_TMPDIR 非空就执行」——那是**削弱**改动前的运行时行为（探针②就是这个形状：
   目录不存在时裸调会落到 `/tmp/tmux-<uid>/default`）。所以包装里对 kill 类调用 `tmux_iso_require`，
   参数（`--tmpdir` / 两个 `--own-root` / `--caller-tmpdir`）与套件壳同一批来源，判定函数也是同一份。
   非 kill 类（`has-session` / `list-windows` / `display-message` / `new-window` / `new-session`）不做前置，
   与改动前套件壳一致 —— 共享分类器的「破坏性」集合本来就只有 kill-server/session/window/pane，
   `new-window`/`new-session` 从来不过前置。
3. 简报说 CI 红了 3 条，实际是 4 条（第 4 条被 `head -3` 截掉）。这不是判据变化，是同一缺陷的第 4 个实例；
   改后的 lint 计数（181）不变可以证明它也被算进去、也被判绿。
4. 没有新增任何永久夹具/断言：简报只要「红侧一次」，额外加一条「前置仍在」的断言会扩大范围；这项保证用
   上面的临时探针证明，并写在 Decisions 里以便复验者按需重跑。

## Suggested next steps

- PM 复验（独立 worktree）：`perl skills/teamsmith/tests/tmux-lint.pl`、`smoke.sh --select 31`、
  `smoke.sh --select 11b4`，以及红侧（放回一条裸 `tmux kill-window` → 红且点名 → 还原）。
- 复验若要复核「前置仍在」，探针脚本在 `/var/tmp/p414/probe-runtime.sh`（输出 `/var/tmp/p414/probe-runtime.log`，
  探针自己的私有 server 在收尾里已经杀掉，`/var/tmp` 下只留日志）。
- 与本次缺陷同族的下一次自查：`tests/lib/` 里新搬进来的助手只要碰 tmux，就必须经专用名包装（lint 会判）。
