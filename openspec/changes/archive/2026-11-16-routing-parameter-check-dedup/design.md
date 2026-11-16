# Design

## Context

动机见 proposal.md。源码定位以 `a7dd6297` 为基准，下文 `tests/`、`scripts/` 均相对 `skills/teamsmith/`。

- `tests/task-model-routing.sh:453–461` 的 boundary 调用七个子夹具，`:915–991` 还执行 PM 参数/metadata/撤销检查。五条剩余参数变异在 `:1447` 全选 boundary。
- 对比 P454 基准 `7657eaaa`，这四份目标文件仅前门和 expansion 助手因 P457 改动：增加真实 Bash argv 短样本，两条 resplit 改选 `argv-worker/argv-pm`，删除结尾第二 CORE。boundary/roles 未变；不重做已删除三处。
- 现成产品边界是 `common.sh:1866/1912/1935/1943/3238` 的 literal、role、extra、template、PM resume 检查。这些函数按传入字符串/数组和显式变量判定，不需要 git、CLI、进程或可信 launch 记录。
- 真实调用分布在 `cmd-agents.sh:1162` 的选择前检查、`:1359` 的交付字段判定、`:1387` 的模板预检，`common.sh:6416–6418` 的最终 worker renderer，以及 `:3264` 的 PM identity 检查；PM 的 preview 在 `cmd-watch.sh:338` 预检，real-up 则在 `:373` 先预检，才到 `common.sh:3798` 的 start 首道检查，之后 `:3806` 写 prompt、`:3662` 的最终 renderer 再检查。`:1359` 的字段判定也调用 template guard，因此不能承诺单删 `:1387` 必红；可观察对象是写 prompt 之前的整个模板拒绝边界，不是每条冗余函数调用。
- 实际故障依据为 P228 作者报告的 F3/F4/F5 追加段：cwd 的 `--model=wrong:low` 曾经由 `--mod*` 进入真实 argv；F4 记录旧实现 24 次真实启动产生 argv/记录不一致；F5 的 `--skill` 消费身份选项。它们不是可整体删除的假想攻击字符串。

## Goals / Non-Goals

**Goals:** 把规则输入的排列放到现有产品函数上判定一次，把 CLI、实际 shell argv、记录和撤销留给能证明独立事实的样本；正常 boundary 和五条故障检查共同受益。

**Non-Goals:** 不改产品函数或参数规则，不建立 Pi 参数表，不改模型/真实团队，不改等待上限/窗口，不重启 29×4 收窄，不改变 smoke/CI/夜间编排，不增加永久计数或删除守卫。P457 的两个 argv 样本及其它 24 条变异组原样保留。

## Decisions

### 1. 一个共用规则判定，两个现有执行层级

沿用三份助手里的原 faults 数据和 `check`/PASS/FAIL 输出。将负向循环的产品规则调用与真实 CLI 调用分开，在 boundary 助手中以一个普通函数组织共享规则；不复制 tokenizer 或另建用例登记表。

在现有 `--select` 白名单增加唯一 `parameters` 组。它与 `argv-*` 同样在完整项目准备之前分支：沿用现有身份清理/私有 HOME 和临时根，只加载所选 `$TREE` 的真实 `common.sh`，不 `team_load_config`，不建 git/worktree/BOARD，不运行 writer/dispatch/up/tmux。`TEAM_EXTRA_PI_ARGS`、`TEAM_PM_EXTRA_PI_ARGS`、`TEAM_PM_RESUME_ARGS` 等输入在每项的子 shell 中显式设置，产品数组/错误状态不串到下一项。子 shell 只调用产品和输出观察值，原 `check` 在调用 shell 消费 rc/固定期望并累计结果，避免子 shell 吃掉 PASS/FAIL。

正常 boundary 在原位置调用同一个规则函数，再执行下表的真实见证和原合法控制；不额外选 `parameters` 以免跑两次。五条原变异只改 `groups=parameters`。保留原变异器、匹配检查和语法检查，在同一副本补齐 healthy → 原变异 → 字节恢复 → restored；恢复的是该变异实际修改的 scripts 文件。

**为何不是另外两个方案：** 仅为五条故障加快入口不改善正常 §61；将完整 boundary 改成纯函数又会丢真实接线和状态事实。一个已有前门分组可以复用同一断言，不需要新 runner、产品开关、缓存或五套选择器。

### 2. 规则输入按事实而非 CLI 模式计数

直接判定采用固定成功/失败期望；成功时仅对声明的 bound fields 或固定 literal 值核对，绝不拿产品算法输出反推期望。实际 argv 的 oracle 继续使用原 `routing_identity_argv_check` 和固定 Python 期望。

| 原负向来源 | 拟直接规则输入 | 原重复为何可退 |
|---|---|---|
| worker template 29 项 | fresh/continued 两种语义；missing-sid-selector 的 fresh 是允许的部分绑定正例，其余 57 个负例调用 template guard | preview/launch 是调用方式，不改变字符串是否合法；fresh/continued 的完整性差异不能合并 |
| PM fresh 21 项、continued missing 7 项 | 21 个 fresh、7 个 continued 负例调用同一 template guard；显式设置 resume/extra 内容 | PM fresh 不允许模板自带 SID，continued 要求完整绑定，二者仍独立 |
| expansion 两席位×template/extra×13，PM resume 2×7 | 两种 template 各 13、共用 extra 13、PM resume 7：共 46 个负例 | extra 和 resume 的产品判定不依赖 builtin/custom 或 preview/launch；真实调用差异留给见证 |
| worker/PM roles 25/26，resume roles 7 | worker 25、PM 26 个 continued template 输入及 resume 7，合计 58 | 角色证明在 fresh/continued 分歧前运行；不再给同一角色四次完整 CLI；fresh 的真实拒绝另有见证 |
| extra 所有权 | 复用 PM 参数尾部已有八类 extra 形状，直接调用共用 extra guard，另保留 harmless 正例 | 原 PM identity 尾部八条检查照旧保留；这里是脱离 policy/metadata 的函数边界，不替代它们 |

这给出 **197 个直接负例输入**（57+28+46+58+8），是实施输入盘点，不是要求固定 197 个 PASS 的新守卫。合法 separate/equals/short/attached、完整/部分/opaque fresh 与 continued 差异、tool data/unknown suffix、引用 wildcard/brace/tilde/反斜杠的固定正例仍在同一规则入口。原合法启动控制不因这里的正例而取消。

不再保留的模式排列有明确代价：不会逐一证明每个非法拼写在每种 CLI 模式下都无副作用。未列入下表真实见证的 `--unknown`、等号和引用形状只在直接角色输入中各一次，不再跨全部进程入口。其它输入未被判作“无对象”而删除；本批不借此扩大或收紧产品拒绝范围。

### 3. 负向真实见证清单：21 个 tag 各一次 launch，加一个 PM preview

每行所列每个 tag 只执行一次 launch；另用 PM fresh `provider` 坏模板执行一次 `up --fresh-pm --print`，覆盖 `cmd-watch.sh:338` 的独立 preview 入口。这给出本次 22 次 CLI 的安排，不设永久次数/PASS 配额，不再将所有 tag 乘 preview/launch。worker 在两种模式分歧前已拒绝，PM 两条入口各有具名见证即可。沿用原 writer 建立合法私有配置、原 `routing_binding_capture`/observable snapshot；每次要求**特定参数错误诊断**、rc=1、argv 无增量、config/BOARD/state/prompt/window/PID/worktree 状态不变。配置失败是 setup 红，不是“安全拒绝”或 SKIP。每个见证先有对应合法前提，PM continued 由原 metadata publisher/loader 建真实同 resume-key 记录；不能因 fresh 抹掉 resume 参数冒充拒绝。

| 来源/入口 | 保留 tag | 身份模式 | tag 数 |
|---|---|---|---:|
| worker template | all-hardcoded、positional-model、data-sid、missing-sid-selector | continued | 4 |
| PM template | provider、data-provider | fresh | 2 |
| PM custom missing | positional-model | continued | 1 |
| worker role | model:--skill | continued | 1 |
| worker role | extra-unknown-before-model | fresh | 1 |
| PM role | provider:--skill | fresh | 1 |
| PM role | extra-unknown-before-resume | continued | 1 |
| PM resume role | builtin `--skill --continue` | continued | 1 |
| PM resume role | custom `-e -c` | fresh（仍须拒绝坏的配置） | 1 |
| worker expansion | template:model-glob、extra:model-glob | continued | 2 |
| PM expansion | template:model-glob、extra:model-glob | fresh | 2 |
| PM resume expansion | builtin/custom `--mod*` | continued | 2 |
| worker/PM builtin extra | 各一个 `--model wrong:low` | worker continued / PM fresh | 2 |
| **合计** | | | **21** |

两个 list 见证只换用 `model-routing-roles.sh:43–64` 的旧输入，不增加 197 个直接负例输入：

- worker fresh `extra-unknown-before-model`：`TEAM_EXTRA_PI_ARGS=' --unknown harmless'`，模板固定为 `$TMP/recording-pi --provider {provider} {extra_args} --model {model} --session-id {session_id} {prompt}`；预期现有诊断为 `identity argv role unprovable: unknown arity --unknown before protected --model`。
- PM continued `extra-unknown-before-resume`：`TEAM_PM_EXTRA_PI_ARGS=' --unknown harmless'`、`TEAM_PM_RESUME_ARGS=' --continue'`，模板固定为 `$TMP/recording-pi --provider {provider} --model {model} {extra_args} {resume_args} {prompt}`；用同 resume-key 可信 metadata，预期现有诊断为 `identity argv role unprovable: unknown arity --unknown before protected {resume_args}`。

源依据是 `common.sh:1927–1930/1935–1941/1956–1969`：standalone extra `--unknown harmless` 后面没有受保护参数，也不含 owned selector，现有 extra guard 可以接受；只有把它放回周围模板，才在未知参数后看到 `--model` 或 `{resume_args}` 并拒绝。旧 `extra-consumes-*` 的孤立 `--skill` 则先在 standalone extra 缺值处拒绝，不能承担 list 接线见证；不保留它们的真实 CLI 执行，但原直接规则输入不扩不减。以上均是源码结论，替换样本尚未实跑。

其中 F4 的 positional-model/data-sid、PM fresh data-provider/continued positional-model，F5 的两席位 selector-as-data、上述 list 与 resume-role，以及 F3 四个 template/extra 调用点，都有原对象对应。worker/PM expansion 保留 cwd decoy 和原合法 literal 启动；不是只检查 `grep '--mod*'`。

另外在同一私有 fixture 对真实 `team_agent_launch_cmd` / `team_pm_launch_cmd` 直接做 builtin-extra 和 custom-template 拒绝见证，确认最终 renderer 仍调用 guard；这不是完整 CLI 次数，也不替代上述预检/状态见证。输入、错误和 bound-field 期望固定，不把 guard stub 成成功。PM 的这些见证仍用真实 identity guard、合法 policy 和 continuation metadata。

**为什么还需要最终 renderer 见证：** 预检仍在时，单删 renderer 的 guard 不会让 CLI 误放行；只留 CLI 负例就观察不到这个真实独立调用点。反向地，绕过整个早期拒绝边界但保留末端 guard 时，worker 已写 prompt（`cmd-agents.sh:1427–1430`），状态不变检查会红；不能只用最终 rc 判断早期拒绝没断。template 的早期边界同时包括交付字段判定和显式预检，单删其中一条仍被另一条拦住不是失去行为，不为它增加文字存在性守卫。

### 4. 实际退休账与明确保留项

以下均是源码展开量，尚无本批行为或耗时测量。562 以 writer 未提前拒绝为前提，不能称旧运行实际发起了 562 次。

| 当前执行点/次数 | 替换/退休 | 具体保留 | 正常 boundary / 五臂 | 未知 |
|---|---|---|---|---|
| worker template：29×4−2=114 次负向 CLI | 4 次真实 launch＋直接规则；删除其余排列/捕获 | 4 个 continued 见证；原 6 类合法模板 preview/真启动/fresh/录参 | 都受益；五臂不再调用任何 CLI | 原 writer 提前拒绝的实际数量未测 |
| PM template：21×2＋7×2=56 | 3 次真实 launch＋provider 的1次 preview＋直接规则 | fresh 和 continued 未绑定见证、独立 PM preview；lost-history/四种合法 selector/内建继续控制不动 | 同上 | 实际4次调用的配置前提待独立执行 |
| worker expansion：13×2×2=52；PM：52＋7×2×2=80 | 各 2/4 次真实 launch＋共用规则 | 四个 template/extra 调用点、PM builtin/custom resume、原六类真实 literal argv 控制 | 同上 | glob 具名失败与恢复本批未跑 |
| roles：worker25×4=100；PM26×4=104；resume7×2×4=56 | 2/2/2 次真实 launch＋直接规则 | scalar/list 角色、PM fresh 仍检查坏 resume；原全部合法 role 真启动不动 | 同上 | 削去模式的逐串纯净性有意不再观察 |
| 新的 worker/PM extra 实际接线 | 增加 2 次真实 launch，替代原排列不能单独证明的 extra 接线 | worker 选择和 PM identity 的实际拒绝 | 正常；五臂走同一 direct extra 断言 | 后续确认准确诊断，不容许无关拒绝顶替 |
| 五条变异各 `groups=boundary` | 各一次完整 boundary→同一 parameters；各补同副本 healthy/restored 短执行 | 原产品变异、匹配/语法/恢复哈希、具名规则失败及父结果 | 正常的共用层也改变；不是仅元套件优化 | 5 次完整执行的替换净耗时未测 |
| 六组共用准备、PM 参数/14 类 metadata/撤销尾部 | 正常位置保持；从五臂移除附带执行 | 实际 worker 首启、合法 fresh/continued、PM 记录坏/恢复、未提交进程撤销 | 正常保留；五臂不再重复 | 不声称五棵坏树上仍观察过这些事务 |

正常负向 CLI 计划为 `4+(3+1)+2+4+2+2+2+2=22`（21 次 launch＋PM provider 的1次 preview）；旧潜在总量为 562，减少潜在 540 次完整 CLI，但增加直接规则/renderer 见证。五条旧边界子运行的潜在负向调用另为 `5×562`，改后为零；它们不是正常 boundary 的 540，也不是耗时。保留正常准备/所有合法控制/PM 尾部，因此不承诺正常 §61 的 575s 降到某个值。

### 5. 原故障与父级结果沿用一条链

五臂父级改消费明确的 `parameter-*` 规则失败名，不能继续拿 `...:launch` 等旧 CLI 名给纯函数结果命名：

| 原变异 | 原 parent 目标或来源 | 新直接断言的必需失败 |
|---|---|---|
| extra-shadow | 原仅检查任意 FAIL；PM 尾部 `boundary-reject:*` | `parameter-extra-refused:model` |
| template-shadow | worker all-hardcoded:preview；PM provider:launch | `parameter-template-refused:worker:all-hardcoded:continued`、`parameter-template-refused:pm:provider:fresh` |
| template-unbound | worker positional-model/data-sid；PM continued positional-model/fresh data-provider | `parameter-template-refused:worker:positional-model:continued`、`:worker:data-sid:continued`、`:pm:positional-model:continued`、`:pm:data-provider:fresh`（后四项共用同一前缀） |
| template-roles | worker model:--skill；PM provider:--skill；builtin --skill --continue | `parameter-role-refused:worker:model:--skill`、`:pm:provider:--skill`、`parameter-resume-role-refused:--skill --continue` |
| literal-shell-expansion | worker/PM template/extra 的 model-glob:launch | `parameter-expansion-refused:worker-template:model-glob`、`:pm-template:model-glob`、`:shared-extra:model-glob` |

新共享 extra 规则的一条失败不冒称四个实际 caller 都执行了；它们由正常 boundary 的四个原 model-glob 见证承担。原 `FLIP_ARM_BUDGET`、child rc=1、目标匹配/语法、失败名和恢复检查仍决定父级结果；禁止任意非零/任意 FAIL 代替具名规则失败。

## Risks / Trade-offs

- **纯规则正确但接线失效** → 保留 22 次 CLI、直接最终 renderer 拒绝和正常真实录参；独立验收对早期拒绝边界/最终 renderer/PM 调用边各做最小旁路反例，不改产品交付代码，不要求每条冗余调用单删必红。
- **大量旧 PASS/capture 消失** → 退休表只覆盖负向排列和五棵坏树的附带观察，直接判定不再声称逐次无副作用；其它正常合法、恢复/事务和两条 P457 argv 样本按源清单保持，不用新 PASS 填旧计数。
- **直接模板/角色调用顺序造成串值** → 每个输入隔离变量和 product scratch arrays；正常/坏/恢复采用同样固定输入。无需新状态服务。
- **短入口仍偷偷准备完整项目，或另留 slow boundary** → 交付时读差异及真实调用记录，证明退休调用不在了；不新增永久 lint/计数守卫。197/22 都是这次迁移盘点，不是长久冻结配额。
- **新短样本不能在真实产品函数上产生所需红** → 按具名项退回，不扩面、不 stub guard、不缩等待凑通过；这会阻止该批实施被接受。当前只是静态可行判断，无实验成功主张。

## Migration Plan

### 实施与一次独立验收

一个 apply 批次修改上述四个测试文件即可。作者先搬共享规则/压缩真实循环，再改五臂分组/失败名/同副本恢复；只做静态检查和提交，不运行行为。没有配置迁移。正式 spec 的完整 MODIFIED 块保留原 17 个场景，新增六个场景；仅更新与本例外直接冲突的清单措辞，不整理全仓长需求。

非作者在 PM 准备的冻结独立检出执行一次以下**受影响**证据，详细结果/实际计数保存在自己的验证包；下列是未来实施后命令，不是本提案已经执行：

1. `bash skills/teamsmith/tests/task-model-routing.sh --select boundary` 一次；包含同一 direct 规则、21 次负向 launch 加 PM provider 的1次 preview、原合法启动/quoted literal/PM continued 和 PM metadata/撤销。源码核对未改的 resume/transaction/limits/publication 组及 P457 两样本，复用已接受证据，不重跑完整 CORE。
2. 原变异器建立五个副本，各一次 healthy、原故障、同副本字节恢复后 `--select parameters`；实际由下面的 bounded parent 执行，**不先单独跑完又跑 parent 一遍**。失败名按上表，不新增一套坏产品算法。
3. 验证包仅在私有副本收窄现有 flip loop 到五个 id、将 baseline 选择改成 parameters，其余父级执行/消费代码逐字节保持；跑这一次真实 bounded parent 即取得第2项。它不是完整 `--flip`/61b。随后提取同一份实际结果消费代码，用已取得日志/rc 做短回放：unexpected rc0、rc124、缺必需名、healthy 失败、restored 失败各令父 FAIL/非零；原实测结果回放为成功。人为改动的回放输入单独标注，不能冒称又跑过五条行为。
4. 在已有私有 fixture 做调用边旁路：worker extra 的选择前检查；worker template 的整个写前拒绝边界（让 `:1359` 的字段计算错误不再阻塞，并删除 `:1387` 的预检调用）；最终 worker renderer。PM 只采用 real-up 写前边界方案：沿用合法 policy、PM 已停止的既有私有场地，在同一副本一起旁路 `cmd-watch.sh:373` 的 real-up identity 预检和 `common.sh:3798` 的 `team_pm_start` 首道 identity 检查，保留真实 guard 函数和 `:3662` 的最终 renderer；用已有 PM fresh `provider` 坏 custom 模板，从真实 `up --fresh-pm` 观察 `:3806` 的 prompt 写入或拒绝诊断位置变化。只删 start 内部检查仍会被 up 更早拒绝，不能作为这条反例；不再另做直接 `team_pm_start` 实验。最终 renderer 的原拒绝见证保持，不是第二套直接 start 实验。纯函数本身不改、不 stub 成成功；早期边界遗漏由特定预检诊断/实际 prompt 变化暴露，末端遗漏由直接 renderer 见证暴露。只删冗余 template 预检而字段判定仍拦住不算缺陷，不新增这种自检；其余指定边如仍被别层提前拦住，标未观察并交回，不认作旁路必红。
5. 同一性与迁移盘点：旧清单来自已冻结源码/已有日志；新正常/纯规则/parent 各自归属实际计数，说明 562 是潜在量、22 为本次执行安排而非配额，逐条解释退休 captures。合并后同一 verifier 只核四个执行文件与已验 SHA 的字节同一性及一条短 parameters 接入；证据前提改变时才补对应行为。

不在本批再跑作者正常组、完整 61b、meta/FAST/smoke、其它功能矩阵或性能。既有 routing-argv 完整61b义务属于 P457/V163 已接受的前批原件（出处按 V172 的 W2，未重审长原件）；本批新增场景只取得变更后的受影响事实，未改部分引用该记录，不要求本候选重交完整61b或为旧三处再次支付整轮。

### 回退

若共享判定无法命中原五个故障、真实 caller 旁路不红或父级吞失败，候选不接受，修正本批或撤销本批四文件提交；不复活 P457 已退休的三处。出现写集外产品改动/真实团队写入立即停止交 PM。无用户数据、生产配置或发布对象需要回滚。
