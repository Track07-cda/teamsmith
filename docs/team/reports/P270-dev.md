# P270 · `/team` slash command — apply (change: slash-team)

**答案先说**：change `slash-team` 的两条 delta 已在 `task/P270-slash-team-apply` 上落地并跑过门禁 —— 扩展
`skills/teamsmith/extension/team.ts`（一条 `/team` 命令、白名单表、真 CLI 透传、无模型可调工具、无自己的确认）、
项目本地安装（`.pi/extensions/team.ts`，与技能同一步、同一张冲突表）、`team doctor` 的 `/team` 行、以及两层夹具
（假 pi 纯逻辑层 151 断言 + 8 条翻转臂；真 pi RPC 端到端层 34 断言 + 翻转臂；`install-shape.sh` 扩展到 136 断言）。
交付轮全量选段门禁 **✓2597 ✗10**，**10 条红全部落地在别处、且都在干净 main 上同样红**（见「门禁的 10 条红」一节，
每条都有对照命令与输出）。分支留在本地（local 模式），工作树干净。

## 交付物

| 提交 | 内容 |
|---|---|
| `522cc24b` | 扩展 `skills/teamsmith/extension/team.ts`（新文件，438 行，纯逻辑导出 + 只 `registerCommand` 一次） |
| `6dd7c09b` | `tests/slash-team.sh`：假 pi 纯逻辑层夹具 + 具名翻转臂 + `--flip` |
| `625f2230` | `tests/slash-team-e2e.sh`：真 pi RPC 端到端层 + 记录桩 + `--flip` |
| `52373d0d` | 安装面：`cmd-init.sh` 装扩展、`cmd-project.sh` 的 doctor 行、`cmd-bootstrap.sh` 的 `--print` 计划行、`install-shape.sh` 的 extension 段 |
| `26731d00` | 两层夹具进门禁（smoke §65）、两张段表、`teamsmith-init` 与 `troubleshooting` 文档 |
| `a9054126` | 扩展头注释改成「不许 X」的写法（源码里不再出现那两个调用名） |
| `e711b7d5` | 补 delta 点名的「用户自己的 `--yes`」与「真 CLI dry-run 不动字节」两条端到端断言 |
| `838c6ac1` | 修本轮暴露的两个夹具缺陷（下节 f1/f2）+ 门禁侧钉住翻转臂真跑过 |
| （合并） `f65adbb1` | `main` 合入；段号 64 冲突按双方保留 + 本段改 65 |
| （本次） | 段 65 的预算行按实测重标 + 本报告 |

改动 14 个文件：产品面 8 个（扩展、`cmd-init.sh`、`cmd-project.sh`、`cmd-bootstrap.sh`、`skills/teamsmith/SKILL.md`、
`skills/teamsmith-init/SKILL.md`、`skills/teamsmith-init/references/bootstrap.md`、
`skills/teamsmith/references/troubleshooting.md`），夹具与段表 6 个（`smoke.sh`、`slash-team.sh`、
`slash-team-e2e.sh`、`install-shape.sh`、`section-paths.tsv`、`section-budgets.tsv`）。

## 验收命令（全部实际跑过，命令与输出尾巴在下）

| 命令 | 结果 |
|---|---|
| `bash skills/teamsmith/tests/slash-team.sh --all --flip` | `RESULT pass=151 fail=0`（8 条翻转臂全红到位） |
| `bash skills/teamsmith/tests/slash-team-e2e.sh --flip` | `== 结果 == ✓ 34 ✗ 0`（含 2 条翻转臂） |
| `bash skills/teamsmith/tests/install-shape.sh` | `✓ 136 ✗ 0 SKIP 0`（含 ⑧a/⑧b 两条新翻转臂） |
| `bash skills/teamsmith/tests/smoke.sh --paths <交付树 15 个路径>` | `✓ 2614 ✗ 11`（66 段，rc=1；11 条红的分类见「门禁跑了三次」） |
| `bash skills/teamsmith/tests/smoke.sh --select 65` | `#5 65 … · 用时 31s · ✓2 ✗0 SKIP0` |
| `openspec validate --all --strict` | `Totals: 22 passed, 0 failed` |
| `bash skills/teamsmith/tests/section-select.sh --check` | `ok 8 bad 0 SKIP 1` |
| `bash skills/teamsmith/tests/section-guard.sh --budget-check` / `--loop-check` | 两条都「全过」（预算表 132/132） |
| 固定镜像 `localhost/teamsmith-gate:local` 上同样两条夹具 | `--all --flip` 全绿；e2e 34 ✓；段 65 用时 40/42/44s |

```
$ bash skills/teamsmith/tests/slash-team.sh --all --flip | tail -1
RESULT pass=151 fail=0

$ bash skills/teamsmith/tests/slash-team-e2e.sh --flip | tail -1
== 结果 ==  ✓ 34  ✗ 0

$ bash skills/teamsmith/tests/install-shape.sh | tail -1
== 结果 ==  ✓ 136  ✗ 0  SKIP 0

$ bash skills/teamsmith/tests/smoke.sh --paths <14 个路径> | tail -3
账本自查： 65 段收口 · 增量 ✓2597 ✗10 SKIP13 ｜ 结果行 ✓2597 ✗10 —— 一致
== 选段结果 ==  ✓ 2597  ✗ 10
smoke 有失败项（--keep 保留现场）
```

## 门禁跑了三次：交付树那次跑完了 66 段

| 次 | 树 | 结果 |
|---|---|---|
| 交付轮 | `f5cf8503^`（只有预算行与报告尚未落） | **跑完 65 段**：`✓2597 ✗10 SKIP13`，48.5 分钟（其中 24 分钟在等另一席位的门禁锁） |
| 第二次 | `f5cf8503` | **停在段 19**（`6f · agent adapter` 撞 76s 预算，`exit 2`），load1 44.6；同一段在交付轮里 `用时 24s · ✓125 ✗0` |
| 第三次 | `f5f3ece`（交付树 + 上面那行记录） | **跑完 66 段**：`✓2614 ✗11 SKIP14`，63.7 分钟，`账本自查： 66 段收口 · 增量 ✓2614 ✗11 … 一致` |

第三次的 11 条红，按类：

| 类 | 条数 | 定性 |
|---|---|---|
| `P67 生产路径` | 9 | 干净 main 上逐字同红（见下节） |
| `36⑧ 产品面检出探针` | 1 | 探针内部那条嵌套跑 `--select 12k` 停在第 5 段：段 33 撞 164s 预算（`config-cli.sh` 实测 202s @load1 36）；探针自己的日志逐字给出这条 |
| `26-m tick` | 1 | 面板那一拍「等满 10s 也没按周期 tick」，同一窗口的日志里 `p10-tick-state/capacity.log` 被删（段 34b 的嵌套运行收尾守卫在那一刻对登记的 pid 发了信号，见日志 `✗ 嵌套运行在生它的那一段收口后仍活着：pid=3883089 … 已跑 5s`）——负载下跨段互扰，与本次改动无关 |
| 段 34b 的收尾警告 | 1 行 | 同上那行；它是警告类，不计入选段结果的两个计数 |

三类的共同前提是这台机器当时被压满（load1 36–46，32 核；同时有 dev-bob 的两套长跑与另一赛道的固定镜像对照），
且都不在本 change 触及的段里。**这次跑前已把段 36 单独验过一次**（`section-guard --budget-check` 全过、
`smoke --select 36` 绿），所以预算行的改动本身有独立证据。

## 门禁的红：P67 那 9 条在干净 main 上逐字同红

**9 条**在同一段：`42 · P67 输入框判据`（`✓46 ✗9`，用时 5s）。判据形态是 `delivery_verdict=NOPANE`、
`input_box_state=UNKNOWN` —— 生产路径那一组拿不到真 pane。**干净 main 上同样红（9 条逐字相同，只差消息里夹具的临时目录名）**：

```
$ mkdir /tmp/p270-baseline && git archive main | tar -x -C /tmp/p270-baseline && cd /tmp/p270-baseline
$ TEAM_SMOKE_NO_LOCK=1 bash skills/teamsmith/tests/smoke.sh --select 42 | grep '✗ P67'
  ✗ P67 生产路径：dev 窗口画的正是 0.87.0 单行草稿帧（期望 [1]，实际 [0]）
  ✗ P67 生产路径：team_input_box_state 报 BUSY（[input_box_state=UNKNOWN …

$ diff <(grep '^  ✗' 我的树.log | sort) <(grep '^  ✗' 基线.log | sort)   # 只差夹具临时目录名
9 条 P67 全同（基线那边多 1 条「冲突标记守卫找不到 git 工作树」——git archive 解出的树没有 .git，与产品无关）
```

**另外 2 条**（36⑧ 的探针与段 26 的面板 tick）都在别处、都是负载引起的，逐条说明：

段 36⑧ 的产品面检出探针：它内嵌跑 `--select 12k`，而那个子跑里红的**不是** 12k，
而是被 `needs:` 拉进来的段 33 撞了预算（同一个根因在交付轮里出现于 `--select 12k,31` 那条，两次都指向段 33）：

```
$ sed -n '$p' /tmp/p148-shape-probe.*/nest-po2.log
  ✗ 段落 #6（33 · 项目契约的读写面（P22/B1：team config 单一写入口 + schema））超时：预算 164s，实际 164s，最后进度 0s → 停跑（exit 2）

$ time (bash skills/teamsmith/tests/config-cli.sh)     # 段 33 的段内夹具，当时 load1=36.23
real  3m22.056s          # 202s > 段 33 的 164s 预算
```

同一段在交付轮（load 更低）`✓`、用时 119s（< 164s）。这是负载敏感的预算问题，落在段 33 的夹具与预算行上，
不在本 change 的文件里；我没有改它们（段 33 的预算归属 P22/D37 的账），仅在报告里点名。

段 26 的面板 tick（`✗ 26-m tick：等满 10s 也没按周期 tick（capacity 行=1）`）：同一窗口的日志里
`/tmp/teamsmith-smoke.yWw1nD/p10-tick-state/capacity.log: No such file or directory` 刷了多次 —— 那个文件被删的
时刻，正是段 34b 的收尾守卫对登记的嵌套 pid 发信号的那一行（`✗ 嵌套运行在生它的那一段收口后仍活着：pid=3883089
… 已跑 5s`）。两段各自在自己的预算里都过（段 34b `✓97 ✗0`），红出现在它们交叠的那一拍。

## Flip evidence（三层红侧：破坏实现/判据 → 变红 → 还原 → 复绿）

### 第一层 · 假 pi 纯逻辑层（8 条具名翻转臂）

`tests/slash-team.sh --flip` 逐条把实现改坏（scratch 副本），要求**对照绿 → 变异红**，且红的是它点名的组：

| 翻转臂 | 改坏什么 | 要求变红的组 |
|---|---|---|
| `menu-decoupled` | 菜单改成写死的列表 | `menu` |
| `unset-empty` | 剥离包装改成空实现 | `env` |
| `refuse-short-circuit` | 拒绝路径短路成直接执行 | `refuse` / `whitelist` |
| `no-failure-notify` | 非 0 退出不再发失败通知 | `output` |
| `entry-to-notify` | 正文落点改成通知 | `output` |
| `no-fuse` | 去掉等待上限 | `output` |
| `table-frobnicate` | 表里塞一条 CLI 不认的命令 | `probe` |
| `args`（本轮新增） | e2e 的 `--keep` 分支拿掉 `shift` | 前进守卫（该副本必须秒级 rc=2） |

```
$ bash skills/teamsmith/tests/slash-team.sh --all --flip | tail -1
RESULT pass=151 fail=0        # 对照全绿 + 7 条变异全红 + args 组的 5 条断言
```

### 第二层 · 真 pi RPC 端到端层

`tests/slash-team-e2e.sh --flip` 把正文落点改成 `notify`（scratch 副本装进第二个夹具），要求「多行结果进正文」变红、
结果改走通知可见：

```
$ bash skills/teamsmith/tests/slash-team-e2e.sh --flip | tail -3
  ✓ flip：正文落点改成 notify ⇒ 多行结果不再进正文（判据会红）
  ✓ flip：结果改走通知（现场证据）
== 结果 ==  ✓ 34  ✗ 0
```

### 第三层 · 安装层（`tests/install-shape.sh`）

本轮新增两条翻转臂（⑧a 红线函数 / ⑧b doctor 行），与既有的 7 条（①–⑦b）同构：破坏 scratch 实现 → 判据必须红 →
真实树仍绿。

```
$ bash skills/teamsmith/tests/install-shape.sh | tail -1
== 结果 ==  ✓ 136  ✗ 0  SKIP 0
$ bash skills/teamsmith/tests/install-shape.sh flip | grep ⑧
  ✓ ⑧a 对照：真实树拒绝未标记的扩展文件
  ✓ ⑧a 翻转：红线函数改成 rm -f（未标记的文件被删）
  ✓ ⑧b 对照：真实树报扩展缺失
  ✓ ⑧b 翻转：/team 的 doctor 行被静默
```

### 本分支自己修掉的两个夹具缺陷（PM 报的 1h35m 空转）

PM 在 2026-10-16 收掉了一个挂了 1h35m 的 `slash-team-e2e.sh --keep`（pid 324481，无输出、CPU 空转），
要求我用超时包住并把它当发现记下来。查下去是两个缺陷，都在本分支的夹具里：

**f1（就是那个空转）**：`--keep` 分支漏了 `shift`，参数循环于是永不退出 —— 只有 `--keep` 会挂、零输出，
与 PM 观察到的现象一致。红侧复现（把 `shift` 去掉的副本）：

```
$ timeout 5 bash /tmp/p270-red/keep-noshift.sh --keep; echo "rc=$?"
rc=124          # 就是那个死循环
```

修法两条：`--keep` 补 `shift`；并且**每条分支都必须消耗一个实参，否则 rc=2 点名缺 shift**。第三腿证据：
拿掉 `shift` 但保留守卫的副本 → `rc=2`，输出 `slash-team-e2e: 参数循环没有前进（分支缺 shift？）：--keep`。
绿侧（PM 给的那条命令）：

```
$ time (timeout 300 bash skills/teamsmith/tests/slash-team-e2e.sh --keep)
real  0m1.595s
== 结果 ==  ✓ 32  ✗ 0
保留临时根：/tmp/teamsmith-slash-team-e2e.llcsIq（TEAM_TMP_KEEP=1）
```

**f2（修 f1 时抓到的）**：我按 PM 要求加的兜底超时用 `"$@"` 重开脚本，而那时参数已被循环 `shift` 消耗光 ⇒
`--flip` 静默丢失，端到端段**照样全绿、却少跑两条翻转臂**。修法是循环前存档 `ORIG_ARGS`；三档各自验过
（`--flip` 34 ✓ / 无参 32 ✓ / `--keep` 32 ✓ + 保留行）。两条防「假绿」的钉子：夹具侧（`--flip` 那一轮必须
多出断言）与门禁侧（段 65 的日志里必须有 `e2e · flip` 组）；夹具侧那条非空洞——把 e2e 改回 `e2e_guard "$@"`
它立刻变红、还原后复绿。

```
$ bash skills/teamsmith/tests/slash-team.sh --select args                      # 含那条守卫断言
  ✓ 漏 shift 的副本：前进守卫立刻 rc=2（不是空转）
  ✓ 守卫点名「参数循环没有前进」
  ✓ 守卫秒级返回（原始缺陷会转 1h35m）
  ✓ e2e 存了原始 argv 再交守卫（re-exec 不丢 --flip）
RESULT pass=5 fail=0

$ sed 's|e2e_guard "${ORIG_ARGS\[@\]}"|e2e_guard "$@"|' -i skills/teamsmith/tests/slash-team-e2e.sh
$ bash skills/teamsmith/tests/slash-team.sh --select args | tail -3
RESULT pass=4 fail=1
FAILED:
  - args: e2e 存了原始 argv 再交守卫（re-exec 不丢 --flip）
```

## 本轮改过、与提案意图有出入的两处

**段号 64 → 65**。合并 main 时发现两边都占用了段 64（main 的 P255 升级配方先落），两张段表与 `smoke.sh`
三处真冲突。按「双方保留」处理：main 的 64 不动，本分支的段改到下一个空号 65（main 的上限就是 64），
预算行、路径行、段头与段内注释同步改。`section-select.sh --check` 与 `section-guard.sh --budget-check`
都复核过（132 段配平）。

**段 65 的预算行按实测重标**：原值 band 15 / budget 60 是端到端层**还没真跑**时量的（那时夹具里的 pi 是门禁的
假 pi，段内只有纯逻辑层的 14s）。交付轮门禁里它真跑了真 pi，实测 host 31s（load 46.1）、固定镜像 44s（load 23.6），
按 `band = max(host, container) = 44`、`budget = max(ceil(44×4), 60) = 176` 重标，provenance 列写明两个端的三次测量。

```
$ grep '^65 ·' skills/teamsmith/tests/section-budgets.tsv | cut -f1-7
65 · /team 斜杠命令（change: slash-team · P270）	44	176	31	46.1	44	23.6
$ bash skills/teamsmith/tests/section-guard.sh --budget-check --tree skills/teamsmith/tests | tail -2
ok: 预算表覆盖 132/132 个 section 且每行都满足 max(ceil(band×4), 60)
section-guard --budget-check: 全过
```

## 逐条 requirement 对照（两条 delta）

断言名就是夹具里逐字打印的那句（层：**纯** = `tests/slash-team.sh`，**端** = `tests/slash-team-e2e.sh`，
**装** = `tests/install-shape.sh`，**段39** = 该脚本既有的安装面断言，**smoke** = 门禁段）。

### `extension-slash`

| requirement · scenario | 覆盖它的断言（层） |
|---|---|
| **R1** runs the real CLI, and it is user input rather than a tool · *It is a command, and nothing else* | 「注册的命令恰好一条且名字是 team」「零模型可调用的工具注册」「零自己的确认框」「源文件里没有工具注册的调用点」（纯）；真 pi 加载扩展后 `/team …` 被当命令执行（端：「pi RPC 退出码 0」） |
| R1 · *The user's tokens are exactly what the CLI receives* | 「argv 逐字：/team ps → [ps]」「双引号里的空格是一个 token」「单引号原样」「引号外反斜杠转义」「cwd = 项目根」「子进程是 bash -c」（纯）；「meeting say 的 argv 逐字（含双引号里的 two words）」「每次调用的 cwd 都是项目根」（端） |
| **R2** the whitelist is one table · *A command outside the table is refused by name, and nothing runs* | 「表外拒绝且零进程」逐条（dispatch / config set / say / notify / close / teardown / smoke / review / change status / archive / bg list / add-agent / init / bootstrap / draft / outbox flush / inbox / thread / monitor / pr / gh / frobnicate）＋「拒绝文案点名被拒的命令 config set」（纯）；「拒绝文案点名 dispatch」「拒绝文案说明这是 PM / 席位的命令」「表外命令一个子进程都没起」（端） |
| R2 · *A read row accepts only its own shape* | 「读行多余 token 拒绝且零进程：team config list --json」「读行多余 token 被点名：--json」以及 `--check` 同两条（纯） |
| R2 · *The menu and the accepted set are the same list* | 「菜单与『从同一张表独立重算』逐字相同」＋逐行「菜单列出表里这一行：…」＋「菜单的命令行列数 = 表里的行数」（纯） |
| R2 · *Every row names a command the CLI dispatches* | `probe` 组 18 条「表里这一行 CLI 真的分发：team …」＋「探针非空洞：至少 5 行得到 CLI 自己的参数/子命令拒绝」＋红侧样本「未知子命令：frobnicate」（纯，跑真 CLI） |
| **R3** the PM-restarting invocation is refused · *Restarting the PM from its own conversation is refused with the reason* | 「up / --fresh-pm 拒绝且零进程：team up / up --fresh-pm / status --fresh-pm」＋「PM 会话原因 + 终端出路」＋「拒绝路径零副作用（无 exec、无窗口、无文件）」（纯） |
| R3 · *A child that does not exit is killed and reported, not waited on* | 「被杀 ⇒ 失败通知点名等待上限」「被杀 ⇒ 正文写明被杀原因」（纯；假 exec 模拟超时，真进程那一半见「没验到的」） |
| **R4** the result is written where it is visible · *A multi-line success arrives in the conversation* | 「多行成功 ⇒ 进正文且 display」「正文头是命令行与退出码」（纯）；「多行成功的正文 display 打开」「正文写明退出码 0」「正文带 stdout 段」「正文带输出」（端） |
| R4 · *A single short line is a notification only* | 「短成功 ⇒ 通知（info）且不进正文」「通知内容就是那一行」（纯）；「短成功是 info 通知」「短成功没有加正文条目」（端） |
| R4 · 非 0 / 超量两族 | 「非 0 ⇒ 失败通知点名退出码 3」「非 0 ⇒ 正文带两路流与同一个码」「超量 ⇒ 保留首行」「超量 ⇒ 保留末行」「超量 ⇒ 显式说明省略与去哪看全文」「超量 ⇒ 中间行确实被删」（纯）；「失败是 error 通知」「失败正文带 stderr 段」「失败正文带 stderr 内容」（端） |
| delta 的环境纪律（用户自己的 `--yes`；三个「替你说 yes」的变量） | 「剥离包装点名三个『替你说 yes』的变量」「用户没打 --yes 就不注入 --yes」「用户自己打的 --yes 原样到达」「UNSET_VARS 就是那三个（单一来源）」（纯）；「会话里的 TEAM_ASSUME_YES 没进子进程」「TEAM_UPGRADE_CONFIRMED / TEAM_ALLOW_FOREIGN_SESSION 没进子进程」「没有注入的 --yes」「用户自己的 --yes 逐字过去」（端） |

### `init-skill`

| requirement · scenario | 覆盖它的断言（层） |
|---|---|
| **R** the install names Pi's trust consequence · *A fresh init prints the consequence, --no-skills stays silent* | 段39「--no-skills 安静（没打信任提示行）」＋本轮把提示行文案扩到两个目录（`--no-skills` 时两个目录都不建、`.gitignore` 两条都不写） |
| R · *The rerun and the bootstrap upgrade path say it too* | 段39「bootstrap 对已存在的项目跑同一实现…信任提示行也在」＋本轮「bootstrap 对已存在的项目装回扩展」（config.sh 未动） |
| R · *The documentation carries the fact* | 段39 的文档断言（`teamsmith-init/SKILL.md` ≤100 行、点名 `.pi/skills/`、两条替代路线）＋本轮把扩展与信任三条出路写进 `SKILL.md` 与 `references/bootstrap.md` |
| **R** team init installs the project skills — 扩展那一半 | 「输出逐条一行：扩展 link 行（含目标与源）」「扩展装成指向运行树的软链」「.gitignore 有 .pi/extensions/ 且只一条」「第二次 init 报扩展 skip」「--copy 对着已有扩展软链退出 0（skip，不覆盖）」「--copy 装的是真文件」「--copy 的扩展与源逐字节相等」「--no-skills 也没建 .pi/extensions/」（装） |
| 同上 · *A conflicting entry is announced, and --force replaces only what it recognises* | 「未标记的普通文件：拒绝且连 --force 都不删」「带标记的漂移副本：默认拒绝、--force 换源」「别源软链：默认拒绝、--force 重指」（装，含 ⑧a/⑧b 翻转） |
| 同上 · *bootstrap runs the install step on an existing project too, and --print writes nothing* | 「bootstrap 对已存在的项目装回扩展」「--print 的计划同时点名 /team 扩展一步」（装） |
| **R** the install is visible in team doctor · *The extension entry's absence and drift are warned with a repair that runs* | 「/team 扩展 link：pass 行点名入口与源」「扩展缺失：warn 点名路径与修法 team init」「扩展漂移：warn 点名路径与修法 team init --force」「没有项目本地安装：/team 行一行都不打」，三态各自「修复后回到 pass」（装） |
| 同上 · 既有三条（linked 命名 / 别的版本 copy / 别源软链） | 段39 既有断言不动，本轮只加 `/team` 那一行 |

## 没验到的（明说）

- **`/team` 在真实交互 TUI 里的补全下拉与菜单渲染**：`getArgumentCompletions` 与菜单文本由纯逻辑层按表核对
  （表 ↔ 菜单 ↔ 补全同源、独立重算），端到端层跑的是 `--mode rpc`；真人在 TUI 里敲 `/team ` 时的下拉是
  Pi 的渲染，本任务的两层夹具都读不到它。
- **`team init` 装出来的扩展被真人第一次 `pi` 启动时的信任弹窗**：夹具只断言安装面（逐条一行、
  `.gitignore`、冲突表、doctor 行）与信任提示文案，没有起真交互 TUI 去点那个弹窗。
- 段 33 的预算余量（202s 实测 vs 164s 预算）只在报告里点名，没有改——它属于 P22/D37 的账。
