# P325 · 提案（rev 2）：按实际调用区分「已交付的行为」和「门禁自己的自证」，减掉探针里的重复执行，把一个 verification delta 对齐到代码

agent: dev-bob   status: delivered（rev 2，仅 propose，无实现）   time: 2026-10-20
branch: `task/P325-ci-scope-proposal`   change: `behavior-focused-ci`   phase: propose
reviewed at rev 1: `748172b0`（PM 的预审 `docs/team/reviews/behavior-focused-ci-proposal.md` 判 NEEDS-CHANGES）

## 结论（先看这一段）

PM 的四项都改了，方向不变；rev 2 的核心修正是**算出成本**、而不是只把「门禁自检」这两个字的名单换一换：

1. **R1 · 61b 不再是基线。** `61b`（路由翻转变异，22 臂，**记录在案的 4946 秒 ≈ 82 分**）写进表头的
   `# gate-self-check:` 行 —— 它的主体是「§61 的断言会不会咬人」，也就是夹具自己的牙齿（D147 的原话）。依据不是
   体感：它是套件**第 #128 段**，而最后一次公开 CI 运行死在 **#110**（其日志最后一条段头），所以那 3544 秒里根本没有
   它；谁把它算进基线，第一次跑到它就要多付 82 分钟。**§61 留在产品基线**（路由决策与拒绝的真实契约，容器实测 FAST
   121 秒 / live 约 505 秒）。完整矩阵的入口一条不少：改夹具源会选中它（它那行 patterns 就是夹具与变异器）、显式
   `--select 61b` / `task-model-routing.sh --flip`、以及合并/里程碑/release 的完整门禁 —— 这正是 D147 已裁定的实践，
   本 change 只是把这条裁定落到 CI 入口上。牙齿证据引用 V62 那次完整运行（31 臂、基线 `pass=3141`），不重跑。
2. **R2 · 验收改成定点 + 一次整体运行。** 44 条场景逐条翻转、多次大基线、`FULL` 再跑一次产品基线：全部删掉。选择器的
   `FULL/NONE/RUN` 与键集合走纯逻辑；合并后的断言共用**一次**实际运行；最终**一次钉死镜像里的整体运行**是交付门槛，
   它同时给出基线的实测墙钟。未改变的 perf / 锁 / 等待行为引用 P316、V65、V66 的既成独立证据。
3. **R3 · 不出按行文件接口。** `--paths-from` 去掉。整链是 `git diff --name-only -z` → `while IFS= read -r -d ''` →
   bash 数组 → 容器命令的 `--paths "$@"`；工作区是只读挂载，所以路径本来也只能走参数。理由写进规格：路径里可以有换行，
   而 git 默认列表会把引号与反斜杠 C 转义。
4. **R4 · 同一轮关掉已退场的东西，不留悬空引用。** 负载实验室的专属要求
   （`A load experiment signals only the processes it started`）在同一 delta 里退场 —— 它的夹具
   `tests/load-experiment.sh` 随 P316 的实验室一起没了；通用规则由既有 `boundary#Signals go to a recorded pid…` 等三条
   与仍在跑的 `signal-gate.sh`/`team-bg-stop.sh` 承接，**不恢复实验室、不留尾巴单**。三处被退场的引用改成新标题（我
   rev 1 里那条跨行断开的 `stuck section` 引用就是 PM 指出的悬空引用，已修）；现场段改成真实解析器
   （`team_tmp_root`：`TMPDIR` → `TEAM_TMP_ROOT` → 磁盘默认）与真实收集入口（`ci/collect-scene.sh`，不再写
   `docker cp …:/tmp/.`）；`SKILL.md` / `references/protocol.md` 的旧红线进最小写集；删掉「两次读数必须相同」这条无依据
   承诺。

**没有承诺的**：基线在 CI 的墙钟。要 apply 在钉死镜像里实测一次才作数（109 段子集里的产品块 2113 秒，另有几段在 CI 走
非 FAST 档会更长）。也不提高 60 分钟上限、不恢复墙钟门槛、不新建调度器/预算表/扫描平台/钩子/新守卫。

## 制品

| 文件 | 大小 | 作用 |
|---|---|---|
| `openspec/changes/behavior-focused-ci/proposal.md` | 106 行 | Why / 四件事 / 写集与验收口径 / 不做什么 / 未知项 |
| `openspec/changes/behavior-focused-ci/design.md` | 298 行 | §0 rev1 错在哪；§1 事实表（含 61b 的 #128 位置）；§3 基线声明与成本表；§4 探针逐案合并与 58 的反例对；§5 为什么必须换标题（贴工具真实报错）与四组退场；§6 定点证据；§7 边界与 D147 |
| `openspec/changes/behavior-focused-ci/specs/verification/spec.md` | 684 行 / 13 块 / 45 场景 | 合同（**4 REMOVED + 3 ADDED + 6 MODIFIED**） |
| `openspec/changes/behavior-focused-ci/tasks.md` | 106 行 | A/B/C/D 四张 apply 单 + 最终一次运行 + verify（定点 + 少量反例） |

## 逐项回答 PM 的四个必改

### R1 · 61b 和「必要的小反例 vs 完整矩阵」

| 项 | rev 2 的答案 | 依据 |
|---|---|---|
| 61b 仍在每次 CI？ | **不再**：它在 `# gate-self-check:` 行里，普通入口（`--floor ∪ 改动`）不含它 | `design.md` §3.2 的分类表；成本表 §3.4 |
| 61b 的成本 | **4946 秒 ≈ 82 分**，22 臂（V28 实测；表内 61 行 basis 也记着这个数；V62 那次完整跑 31 臂、基线 `pass=3141`） | 记录，不是本轮计时 |
| 它为什么不在 3544 秒里 | 它是**第 #128 段**，那次运行死在 **#110**（日志最后一条段头 `== #110 46 · … ==`） | 本会话实测：源码顺序 110 号 = 日志里的 #110 |
| 61 的真实契约 | 留在产品基线：路由分组决策 + 拒绝 + 续跑复用（容器实测 FAST 121 s，live 约 505 s） | P243 / V28 |
| 完整矩阵的入口 | 三条：改夹具源（patterns = `task-model-routing.sh` + `model-routing-flips.py`）、显式 `--select 61b` / `--flip`、合并/里程碑/release 的完整门禁 | D147 的「配套实践」原文 |
| 「必要的小反例」 | 本 change 的「小反例」落在**探针**那一侧（§58 的反例对，见 R2 表）与 §61 自身的拒绝断言；61b 的臂级子集**不做**：单臂成本 ≈ 基线 495 s + 变异 495 s ≈ 16 分，比它要证的东西贵，把价格写进 `design.md` §3.4 让 PM 自己裁 | V28 的 495 s/次 |
| 不搬进每次本地 review | 完整入口仍是 `team review`（全量）与发布清单；CI 是被披露的选集 | `proposal.md`「不做的事」 |

### R2 · 验收变成定点 + 一次整体

| 原来的（rev 1） | 现在的（rev 2） |
|---|---|
| 44 条场景逐条破坏 → 翻转 | 只对**新增/改变的入口**给证据：`--check` 新规则两向（纯逻辑）、`--floor` 的 FULL/RUN/空基线（纯逻辑）、CI 的 NUL 链与三形状、合并后各段行级断言仍在、两份文档无旧红线 |
| 每张单都跑大选集 / 全基线 | 每张单只跑自己的定点证据；`--select 36` 是唯一需要跑重段的地方（合并的正确性） |
| `--paths` 未声明路径再跑一次全套 | 未声明路径用**纯逻辑**回答（`FULL`），不起容器 |
| 合并断言各跑一次 | 合并后的断言**共用一次**运行（`tasks.md` 3.4 / 5.1） |
| 最终整体 = 多条基线 | 最终**一次**钉死镜像运行（`tasks.md` §5），同时是基线的实测墙钟 |
| 未改变的 perf/锁/等待要再证 | 引用 P316 / V65 / V66 的既成独立证据，记录里写明「本次未重测」 |

### R3 · 路径走原始字节

`--paths-from` 从规格与任务里删掉了。规格原文现在说：整链 NUL 分隔 + bash 数组 + 既有 `--paths`，并且**写明了原因**
（路径可含换行；git 默认列表 C 转义引号与反斜杠），还有一条专门的场景（含引号/反斜杠/换行的文件名必须逐字节到达）。
工作区只读挂载是第二个理由：路径不能写成检出里的文件，只能进 argv。保守回退（未声明路径 / 不可解析基点 → 全套）、
披露、真实失败仍阻塞，三条都保留。

### R4 · 规格与生效文档

- **工具是否支持「MODIFIED 里丢场景」——有实测报错**，不是假定。在 `openspec/` 的轻量副本里，把一个 MODIFIED 块按基线
  原文保留、只删最后一条场景，`~/.bun/bin/openspec validate zz-mod --type change --strict` 报：
  `✗ [ERROR] verification/spec.md: MODIFIED "Every gate section accounts for itself, and a stuck section is named" omits scenario(s) the current spec still has: "A run that an outer clock kills can still say where it was". Copy them into the MODIFIED block …`
  所以「场景标题本身就是被取消的承诺」的那三个要求只能整块退场 + 以**保留原词干的新标题**重加；**其余六块全部按原标题
  MODIFIED**（它们仍是原题：门禁只判正确性、性能套件独立且不阻塞、段落自述、选段器、判不了就说、等待有界）。
  三条被退场的对应场景（“A machine over the premise skips visibly…”“The premise's readings stay real…”、
  “A slow frame is red with its numbers”“A busy machine skips visibly…”、“The budget table has a measured basis…”）
  在 `**Migration**` 里逐条点名接手者。
- **负载实验室退场**：`A load experiment signals only the processes it started` 整块 REMOVED，`**Reason**` 点名夹具已删、
  `**Migration**` 点名三条既有 boundary 契约与仍在跑的守护夹具；不恢复实验室、不留尾巴单。归档后的规范里
  `grep -c "A load experiment"` = 0（实测）。
- **悬空引用**：改成新标题后，delta 里对旧标题的引用为 0（跨行断开的那处也修了）；归档后的规范里三条新标题都被正文引用。
- **临时根与现场收集**：现场段改写成「`team_tmp_root` 解析出的根（`TMPDIR` → `TEAM_TMP_ROOT` → 磁盘默认）」+「把现场带出
  容器是收集步的契约：CI 把现场作为家族交给 `ci/collect-scene.sh`，由它的前缀表与暂存路径负责，没家族到场就红」——
  不再写 `${TMPDIR:-/tmp}` 与 `docker cp <container>:/tmp/.`。
- **生效文档进写集**：`skills/teamsmith/SKILL.md`（Performance 行的 2000 ms / 前提因子 / 退出码 0/2/4/3）与
  `skills/teamsmith/references/protocol.md`（§9b-2 的 “measurement premise”、perf 段的阈值与 “skips visibly”）列入
  D 单，与代码同一轮改。
- **删掉无依据的承诺**：`A measuring fixture…` 不再说「两次运行必须读到相同数值」，只说「同一个固定目标、输出点名它」。

## 校验（本会话实际跑过，rev 2 树上）

```
$ ~/.bun/bin/openspec validate --all --strict
Totals: 20 passed, 0 failed (20 items)                        # rc=0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 111 reference(s) (49 distinct) in 12818 effective line(s); retired 2; undeclared 0;
           id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]  # rc=0

$ cp -r openspec /var/tmp/p325-v3/openspec && cd /var/tmp/p325-v3 && ~/.bun/bin/openspec archive -y behavior-focused-ci
Totals: + 3, ~ 6, - 4, → 0
Change 'behavior-focused-ci' archived as '2026-10-20-behavior-focused-ci'.
$ ~/.bun/bin/openspec validate --all --strict                  # 归档之后的那份文本
Totals: 19 passed, 0 failed (19 items)                        # rc=0
# 归档后：34 条要求（原 35 − 负载实验室 1）；grep A load experiment / load-experiment.sh /
# 2000 ms / section-budgets / PUBLISH.md 全为 0

$ ~/.bun/bin/openspec validate zz-mod --type change --strict   # 「MODIFIED 里丢场景」的实测报错
✗ [ERROR] verification/spec.md: MODIFIED "Every gate section accounts for itself, and a stuck section is named"
  omits scenario(s) the current spec still has: "A run that an outer clock kills can still say where it was". …
                                                                # 这就是 §5 里「只能整块退场」的依据

$ git diff --cached --check                                     # rc=0
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: … files=1817 hits=0 names=ok user=resolved          # rc=0

# 本会话的纯逻辑测量（选择器，两次；没有跑套件）
$ bash skills/teamsmith/tests/section-select.sh --select 58 | head -2
decision=RUN / sections=… / keys=13          # 带闭包
# 同一命令在把 58 的 needs 改成 - 的表副本上：keys=5；--check 仍 ok 8 bad 0 SKIP 1
```

`spec-refs` 里那两行 `retired …:371 docs/team/reviews/<ID>.md` / `retired …:398 docs/team/PUBLISH.md` 是它按**基线行号**
记账的产物：前者基线 4 处、归档后仍 4 处（`grep -c` 各 4），后者是本 change 有意去掉的失效引用（`docs/team/PUBLISH.md`
不存在）。两条都不判失败（rc=0），记在这里是为了让复验者不必自己追。

## 未验 / 未证实（rev 2 也要写清）

1. **61b 未重跑**（本轮按任务书禁止），它 82 分钟的数字引 V28/P243 与表内记录，完整运行的证据引 V62。
2. **基线在 CI 的墙钟未知**：2113 秒是 109 段子集的求和，CI 非 FAST 档还有几段会更长；`tasks.md` §5 要求在钉死镜像里
   实测一次并写进报告。
3. **`58` 那一行的行为反例对**（A：无闭包仍全绿；B：§17 去掉 §15b 必红）是 apply 的 3.1，本阶段只给了纯逻辑的键集合；
   B 若不成立 → 停手写 `BLOCKED:`（`needs` 机制本身坏了，不属本 change）。
4. **探针改动后的时长**全是投影（`design.md` §4.4），实现后实测。

## 交回 PM 的边界

- **P324 冻结**：`gates.yml` 与 `smoke.sh` 现在是 dev2 的临时借用，B 单必须等它冻结并合入。
- **`docs/team/RELEASE-PUBLIC.md` 的写权**是 PM 的（`docs/**`）；B3 写明未明授 → `BLOCKED:`。
- **D147**：61b 与完整门禁留给合并/里程碑/release 是既有裁定，本 change 不改它，只是不让**普通 CI 入口**替它付钱。
  如果 PM 认为「普通入口连一个臂都不跑」还不够，单臂价格（约 16 分）已在 `design.md` §3.4 摆出来供裁定。
- **rev 1 的提交 `748172b0` 保留在分支上**（PM 明确要求），rev 2 在其之上追加。
