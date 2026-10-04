# P195 · `safe-signal-discipline` 返工：`bg list` 与 `bg stop` 必须**同一条规则**（读面不许说「身份成立」）

agent: dev-bob · status: DELIVERED（local 模式：分支留在本地、不 push；PM 复验后本地合并） · time: 2026-10-03
branch: `task/P195-rework` · base: `bfb41c3e`（派单时的分叉点）
任务书：`docs/team/tasks/P195-bg-list-read-consistency.md`
change: `safe-signal-discipline`（phase `apply`，`deltas: boundary`，anchor: change）
授权实现路径：`skills/teamsmith/scripts/lib/cmd-bg.sh` · `skills/teamsmith/tests/**` ·
`openspec/changes/safe-signal-discipline/**` · `docs/team/reports/P195-dev-bob.md` · `docs/team/reports/P195-dev-bob/**`

## 结论

| brief 项 | 状态 | 证据 |
|---|---|---|
| 1. `bg stop` 的记录校验抽成**一个函数**，`list` 与 `stop` 都调它（不许两份判断） | ✅ | `cmd-bg.sh` 的 `team_bg_check_record`（定义 123 行）；调用点只有两处：`list` 200 行、`stop` 215 行；身份原语（`pid_alive`/`start_of`/`pgid_of`）的判定调用只在这一处（165/168/173 行），`stop` 里其余调用是「发完信号等它死」的轮询 |
| 2. 读面如实：不可用**标出原因**，措辞与写面**一致**，不许写 `holds` | ✅ | 行内 `identity=unusable` / `identity=mismatch`；夹具三条形状各断言「list 的原因句 == stop 的原因句」逐字相等（`logs/20-green-after.txt` 的 ① ② ③）；探针逐条并排（`logs/40-read-side-probe.txt`） |
| 3. 红侧三条（逐字用验证者的形状）：非平坦 id / `pgid=0` / 实时组不符 → list 不再说「成立」且与 stop 一致；影子改回旧读法必红 | ✅ | `logs/10-red-before.txt`（未修实现：新节 6 红）· `logs/30-break-read-side-pid-only.txt`（影子：同样 6 红） |
| 4. 反向：正常记录 → list 显示成立且 stop 能收（不许误伤） | ✅ | 夹具 ④（`holds` + `stop` rc=0 + 进程真的停了）；探针 `normal-ok` 一条 |
| 5. 门禁：`openspec validate --all --strict` + 容器 `--select 58` + 容器 FAST；报告点名谁自己跑、谁引用 P189；复验换人 | ✅ | change 本身 validate ✓（两个别的 change 是**既有红**，与 main 逐字一致，见门禁节）；容器 `--select 58` ✓429 ✗0；容器 FAST ✓3791 ✗0（冻结树重跑） |

一句话：`bg stop` 的判定是「记录位置/类型 + pid/pgid 形状 + 启动指纹 + 实时进程组」，而 `bg list` 自己
只看了「pid 活着 + 指纹」——**同一份畸形记录，读面说 `identity=holds`，写面拒绝**，而读面正是操作者判断
「这条记录能不能收」的依据。现在两侧调**同一个** `team_bg_check_record`：判定一份、退出码一份
（0/2/3/4/5 与 `stop` 一一对应）、原因句**同一个字符串**，读面只剩渲染。

## 提交

| Commit | 内容 |
|---|---|
| `8dc927b2` | 夹具先落地：P189 · F1 节（三条形状 × stop 拒绝 + list 判定 + 原因逐字）+ `--break=read-side-pid-only` 影子 + 红侧原始输出 `logs/10-red-before.txt`（对未修实现 ✓75 ✗6） |
| `a43dfe2d` | 实现：`team_bg_check_record`（唯一判定）+ `list`/`stop` 同一收口 + 绿侧与四条 break 原始输出（`logs/20` · `logs/30-*`） |
| `213bd8d2` | 契约与文档：delta 要求句 + 新 scenario；design D6 的 P195 段；tasks Apply status (P195)；smoke §58 注释点名新覆盖；探针 `pkg/10-read-side.sh` + `logs/40`；`ct.sh`；门禁原始输出 |
| （本报告） | 报告 + `logs/60` · `logs/61`（冻结树重跑） |

## 交付物

| Path | 做了什么 |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-bg.sh` | 新增 `team_bg_check_record <id> <bg-dir>`：目录边界（P187）→ 平坦 id + 正规记录（P169）→ 读得开 → pid/pgid 正整数 + start 在场 → pid 活着（`gone`）→ 指纹一致 → 实时进程组一致（`mismatch`）；出口 0/2/3/4/5 与 `stop` 一一对应，出口变量 `TEAM_BG_VERDICT`（词表封闭：`holds`/`gone`/`unusable`/`mismatch`）与 `TEAM_BG_REASON`（两侧打印的同一个字符串）。`team_bg_list` 删掉自己的那套判断，改为逐行调用并把判定与原因渲染出来（`|| true`，一行不可用不中止视图）；`team_bg_stop` 删掉重复的校验与诊断，改为 `|| rc=$?` + `case` 映射退出码。行里的 id 改为记录自己的文件名（`stop` 接受的那个 id）。文件头补「读面 == 写面（P195 · F1）」段 |
| `skills/teamsmith/tests/team-bg-stop.sh` | 新 P189 · F1 节（15 条断言）：三条形状逐字用第三轮复验矩阵（`two words` / `pgid=0` / 实时组不符），每条都做「stop 拒绝且零信号 + 邻居活着 + list 行不是 `holds` + 两侧原因句逐字相等」，另加反向 ④；新 `--break=read-side-pid-only`（把 **list 的判定**换回旧读法的副本，写面不动）+ help/参数校验；`--break=no-identity` 的 sed 锚点跟着共享判定更新 |
| `openspec/changes/safe-signal-discipline/specs/boundary/spec.md` | ADDED 要求里的 `team bg list` 句改写：判定**必须**走 `stop` 的同一套校验、词表封闭（`holds`/`gone`/`unusable`/`mismatch` 与退出码 0/0/2·3·4/5 对应）、不可用的行**必须**带 `stop` 打印的同一句原因、行 id 是记录自己的名字；新增 scenario「The read side refuses what the write side refuses」 |
| `openspec/changes/safe-signal-discipline/design.md` · `tasks.md` | D6 的 P195 段（为什么「同一份判定」是修法：读面是操作者的依据、两份判断必然分叉、`set -e` 与默认 verdict 两个实现坑）；D6 里 P169 那句「list 也套同一形状」改成指向 P195；tasks 加 Apply status (P195) |
| `skills/teamsmith/tests/smoke.sh` | §58 段注释点名 P195 的读面覆盖（代码零改动） |
| `docs/team/reports/P195-dev-bob/` | `ct.sh`（容器入口）、`pkg/10-read-side.sh`（读面探针）、`logs/10`–`logs/61` 原始输出 |

## 验证证据（都实际跑过；命令 + 原始输出在 `logs/`）

### flip evidence：红 → 绿 → 影子红（同一节、同一批断言）

**① 红（未修实现，夹具先落地）** —— `logs/10-red-before.txt`，新节 6 条红（其余 75 条绿，说明夹具没写歪）：

```text
== P189 · F1：读面与写面同一条规则（list 不许说「成立」，原因句与 stop 逐字相同） ==
  ✓ ① stop 'two words' → 2（非平坦 id）
  ✓ ① 记录里的真进程没有被误杀
  ✗ ① list 对非平坦 id 说了 identity=holds（读面说谎）
  ✗ ① list 与 stop 打的是同一句原因（[job id 'two words' 不是平坦名字…] 里没有 …）
  ✓ ② stop pgid=0 → 4（pid/pgid 必须正整数）
  ✗ ② list 对 pgid=0 说了 identity=holds（读面说谎）
  ✗ ② list 与 stop 打的是同一句原因
  ✓ ③ stop 实时组不符 → 5（进程组身份对不上）
  ✗ ③ list 对实时组不符说了 identity=holds（读面说谎）
  ✗ ③ list 与 stop 打的是同一句原因
== team-bg-stop 结果 == ✓ 75  ✗ 6
```

（未修实现的 list 行：本轮断言「list 对 pgid=0 说了 identity=holds」为真；第三轮复验的原始视图逐字是
`pgid-bad-0  pid=47  pgid=0  identity=holds  cmd=sleep 300` 与 `group-mismatch  pid=47  pgid=48  identity=holds`，
见 `docs/team/reports/P189-verify/pkg/logs/pgid-zero-list-view.txt` · `group-mismatch-list-view.txt`（同一台夹具、
同一套形状）。）

**② 绿（实现落地后）** —— `logs/20-green-after.txt`，新节 15 条全绿、整夹具 ✓81 ✗0：

```text
== P189 · F1：读面与写面同一条规则（list 不许说「成立」，原因句与 stop 逐字相同） ==
  ✓ ① stop 'two words' → 2（非平坦 id）      ✓ ① list 标 identity=unusable（不再说成立）
  ✓ ① 记录里的真进程没有被误杀               ✓ ① list 与 stop 打的是同一句原因
  ✓ ② stop pgid=0 → 4（pid/pgid 必须正整数）  ✓ ② list 标 identity=unusable（不再说成立）
  ✓ ② 记录里的真进程没有被误杀               ✓ ② list 与 stop 打的是同一句原因
  ✓ ③ stop 实时组不符 → 5（进程组身份对不上） ✓ ③ list 标 identity=mismatch（与写面 rc=5 同一张表）
  ✓ ③ 记录里的真进程没有被误杀               ✓ ③ list 与 stop 打的是同一句原因
  ✓ ④ 反向：正规记录在 list 里仍是 identity=holds
  ✓ ④ 反向：正规记录照常收作业 → 0           ✓ ④ 反向：作业被停掉（新判定没有误伤）
== team-bg-stop 结果 == ✓ 81  ✗ 0
```

**③ 影子（把 **list 的判定**换回旧读法：只看 pid 活着 + 指纹；写面一个字节不动）** ——
`logs/30-break-read-side-pid-only.txt`：**同样那 6 条红**，方向与 ① 一致（行重新变成 `holds`、原因句
消失）；收尾行：

```text
红侧成立：6 条断言变红 —— ① list 对非平坦 id 说了 identity=holds（读面说谎）, ① list 与 stop 打的是同一句原因 …
（把 list 的判定换回旧读法后，非平坦 id / pgid=0 / 实时组不符 三条形状在 list 里又都变成 identity=holds）
```

**④ 旧断点未回归** —— `--break=no-identity` 9 条红、`--break=no-boundary` 20 条红、
`--break=no-dir-boundary` 7 条红（`logs/30-break-*.txt`）。红数比 P187 记录的多，是因为判定现在**只有
一份**：同一个断点同时打中读写两侧（这正是「同一套校验」的可观测后果，不是新回归）。

### 实现过程中夹具抓到的两个坑（都留在提交信息里）

1. **CLI 跑在 `set -e` 下**：`team_bg_check_record …; rc=$?` 这种写法会让非 0 返回**直接终止命令**，
   于是 `bg stop` 只退出码、不打印原因（夹具立刻红成一片）。两处调用点改成本文件既有的
   `|| rc=$?` / `|| true` 惯用法。
2. **`mismatch` 分支必须显式写 verdict**：默认值是 `unusable`，实时组不符的行会显示成 `identity=unusable`
   而不是 `mismatch`（夹具 ③ 抓住）。现在两条身份分支进门前就置 `mismatch`，通过后才置 `holds`。

### 读面探针（`logs/40-read-side-probe.txt`，`pkg/10-read-side.sh`）：同一份记录，stop 与 list 并排

```text
== pgid=0（验证者的 pgid-zero-list 形状） ==
  stop: ✗ bg stop: 记录 …/bg/pgid-zero-list.job 的 pgid 不是可取的正整数（'0'）—— 记录畸形，什么都没发
  stop rc=4
  pgid-zero-list   pid=807849   pgid=0        identity=unusable  cmd=sleep 300
  ! bg list: pgid-zero-list：记录 …/bg/pgid-zero-list.job 的 pgid 不是可取的正整数（'0'）—— 记录畸形，什么都没发
== 实时组不符（验证者的 group-mismatch 形状） ==
  stop rc=5
  group-mismatch   pid=807849   pgid=807850   identity=mismatch  cmd=sleep 300
  ! bg list: group-mismatch：pid 807849 现在的进程组是 '807839'，记录里是 807850 —— 进程组身份对不上，什么都没发
== 正常记录（反向） ==
  stop rc=0（result=stopped）
  normal-ok        pid=807849   pgid=807839   identity=gone      cmd=sleep 300
```

探针还把第三轮矩阵里 list 侧的 `two words` / `missing-start` / `empty` / `unreadable` 一并打印：全部
`unusable` + 与 stop 同一句原因，且没有权限/解析噪声（`unreadable` 在读取前就被 `-r` 挡住）。

### 门禁（都在容器里跑；`logs/60` · `logs/61`）

```text
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict          # 宿主（只读）
Totals: 17 passed, 2 failed (19 items)                                  # rc=1
Details: openspec validate meeting-liveness --type change
$ PATH="$HOME/.bun/bin:$PATH" openspec validate safe-signal-discipline --type change --strict
Change 'safe-signal-discipline' is valid                                # 本 change ✓

$ bash ct.sh 'bash skills/teamsmith/tests/smoke.sh --select 58 </dev/null'
#13 58 · 信号纪律：闸门 / 作业 pid / lint（P159） · 用时 11s · ✓13 ✗0 SKIP0 · ticks 13
  58 signal-gate 全绿（69 条断言）
  58 team-bg-stop 全绿（82 条断言）        # 81 条断言 + 收尾行
== 选段结果 ==  ✓ 429  ✗ 0                 # 13 段；账本自查「一致」（logs/61）

$ bash ct.sh 'TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null'
账本自查： 123 段收口 · 增量 ✓3791 ✗0 SKIP36 ｜ 结果行 ✓3791 ✗0 —— 一致
== 结果 ==  ✓ 3791  ✗ 0
smoke 全绿                                  # rc=0（logs/61）
```

**两次跑与为什么以第二次为准**：第一次 FAST（`logs/60-…-superseded.txt`）跑的时段里我改了
`smoke.sh` 的 §58 段注释 —— bash 增量读取脚本文件，改注释也可能让后续段错位，因此**判定作废**；
此后树冻结、重跑 `--select 58` + FAST 得到上面这份（`logs/61-…-frozen.txt`），两次都是 ✓0 ✗0，
但只有冻结树那次可以作为证据。

**`openspec validate --all --strict` 的两个红是既有的、与 main 逐字一致、与本返工无关**：
`meeting-liveness` 与 `pulse-nudge-key` 的 `specs/panel/spec.md` 里 MODIFIED 块漏掉了现 spec 仍有的两条
scenario（`git diff main -- openspec/changes/meeting-liveness openspec/changes/pulse-nudge-key` 为空）；
本 change（`safe-signal-discipline`，含本轮改写的 delta）单独 validate 通过。

## 自己跑 / 引用 / 没测到

- **自己跑的**：夹具五种模式（默认 + 四个 break）、读面探针、`openspec validate --all --strict`、
  容器 `--select 58`、容器 FAST（冻结树重跑一次）。原始输出全在 `logs/`。
- **引用 P189 的**（不重跑）：三条形状的**逐字形状**（`two words` / `pgid-zero-list` / `group-mismatch`）
  取自 `docs/team/reports/P189-verify/pkg/verify.py` 的矩阵；P169/P187 立的「stop 与 list 一条规则」。
  PM 评审 `docs/team/reviews/P189.md` 的判定（F1 裁为要修）本报告未重跑，作为范围依据引用。
- **没测到 / 没跑**：不带 `TEAM_SMOKE_FAST` 的全量 smoke（brief 的门禁是 select58 + FAST）；FAST 跳过的
  36 个真进程段；字符设备形态的记录（容器里没有 CAP_MKNOD，沿用 P175 的记录）；P189 矩阵里与本次改动
  无关的段落（dir-boundary 的 prefix-collision 等，由 P187 的夹具继续覆盖）。

## 决定与偏离

1. **判定函数的退出码沿用 `stop` 的 0/2/3/4/5**，而不是「永远返回 0、结论放全局变量」：这个文件既有
   惯例就是 `|| rc=$?`（`team_bg_record_resolve` / `team_bg_dir_resolve` 都这样），`stop` 的退出码表
   因此**逐字不变**；代价是调用点必须带 `||`（`set -e` 坑已由夹具钉住，两处都写了注释）。
2. **`list` 的不可用出口是「打出行 + 判定 + 原因，命令本身 rc=0」**：`stop` 是「拒绝就什么都不发」的
   写面，`list` 是只读视图 —— 让视图因为一条坏记录整个失败，会把「别的作业能不能收」也一起藏掉。
   契约里写明词表封闭与原因同句，读面因此不会说谎。
3. **行里的 id 用记录文件名，不读 payload 里的 `id=`**：`stop` 认的就是文件名那个平坦名字；读 payload
   会重新引入「读面与写面看不同东西」的形状（P169 的教训）。副作用：非平坦 id 的行 `pid=- pgid=-`
   （判定在读到记录之前就拒了），这是如实。
4. **原因句不进行内，跟在行的下一行**（`! bg list: <id>：<与 stop 逐字相同的整句>`）：行是定宽列
   （`id pid pgid identity cmd`），把整句塞进行里会破坏对齐、也会让「原因与 stop 一致」这条断言
   变成子串比对；现在两侧是**整句相等**。行内仍有一眼看出的判定词（`unusable` / `mismatch`）。
5. **不给 `list` 加 `--json` 或新词表**：brief 要的是「同一套校验 + 如实」，没有要求新接口；`mismatch`
   这个词本来就与写面 rc=5 同一张表。
6. **`smoke.sh` 只改注释**：§58 的段注释点名 P195 的覆盖，零代码改动（FAST 的段账本自检仍一致）。

## 建议下一步

1. PM 复验（**换人**，brief 已定）：重点看 ① 三条形状的红→绿→影子红，② `list` 的「行不可用但 rc=0」
   口径是否被接受，③ 原因句逐字相等这条断言是不是够强。
2. `safe-signal-discipline` 的归档条件（独立复验通过 + 用户确认）：本返工只补齐 F1 这一条；
   其余 finding 以 P175 的枚举与 PM 评审为准。
3. 既有红提醒（不是本任务造成）：`openspec validate --all --strict` 现在红在两个别的 change
   （`meeting-liveness` / `pulse-nudge-key` 的 panel delta MODIFIED 缺 scenario），它们与 main 逐字一致。
