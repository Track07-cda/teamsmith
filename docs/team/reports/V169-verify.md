# V169 · REWORK：复用准备可行，先处理已查明的无效等待

agent: verify · status: DELIVERED / REWORK（独立方案审阅，不是实现验收）
time: 2026-11-16T11:51:04Z
branch: `task/V169-clipboard-reuse-proposal-review` · PR/MR: -（本地）

## 结论

**REWORK，不按当前“保持原等待不动、下次完整运行再看”的方案直接进入 apply。** 四次准备重启换成普通工具输入文件和真实草稿编辑仍是小改动，两个条件共享进程的证据成立；但原样本已有两次约 36s/35s 的无效等待，且源码表明本项目的正常默认临时路径也能把同一 token 拆开，不限于样本额外嵌套。最小下一步是先由 PM 收敛这三处图像等待的局部处理与先后顺序，再修提案文字；不重跑样本、不改等待库、不造通用屏幕重组或新增永久检查。

- 已实证的是旧/候选 **2→1 次面板启动、各两次真实 C-v**，不是完整八子例的 8→4 已验。
- 原始 stdout 的总时长为 **16.812s / 84.018s**；候选虽以 20 个累计成功断言和 rc=0 收口，两次等待均失败，不能称样本全绿或实际提速。
- 另有一处规格直接矛盾：八子例包含“不按 C-v”的观察，proposal/delta 却要求每个子例都按 C-v，须限定为七个主动粘贴子例。

## Deliverables / 受检身份

| 路径或对象 | 本轮结果 |
|---|---|
| `docs/team/reports/V169-verify.md` | 本席位唯一写入，含原件核对、两项修订与实际结构/报告检查 |
| `/var/tmp/p464-review-2c5ba223` | PM 准备的干净独立检出，HEAD=`2c5ba2234cb8cc9ecfbb7d2849c84f3812ee45c3`；只读 |
| `openspec/changes/clipboard-test-session-reuse/` | 已读 proposal/design/tasks/verification delta 和 `.openspec.yaml`；未修改 |
| `/var/tmp/p464-dev-bob-6ovk4j49` | 只读 sample、trace、stdout/stderr、receipts、manifest、初次失败和静态登记；未执行脚本 |

`git diff --name-only 4b26a2d5..2c5ba223` 只有作者报告和上述 change 的五文件；产品、tests、正式 spec、配置与 CI 无净改动。本席位未参与样本/提案写作，未操作真实团队、提醒或 standby。

## OpenSpec assessment

已读取项目生成的 OpenSpec 1.16.0 `openspec-verify-change/SKILL.md`。按本 brief 仅审规划：读取原生 context/status/instructions apply 的真实输出，但不执行其中的实施指令，也不把未来未完成任务逐项判成当前交付缺陷。

| Dimension | 结果 | Evidence |
|---|---|---|
| Completeness | 规划 4/4；未来实施 0/5 正确 | 原生 status 四制品 done；instructions apply 明示 total=5 / complete=0 / remaining=5；1 条 ADDED requirement、6 个 scenario |
| Correctness | 本 change 严格结构通过；规划存在 W1/W2 | 独立 validate rc=0；原件支持两条件状态切换；正常默认路径反例及未按键矛盾见下文；未来完整场景/坏腿未验 |
| Coherence | 一个 scenario 内的准备替换可保持简单；等待处理优先级须修 | design §1–3 保留四个独立启动与全部原行为；§4 暂留已可静态确定的正常路径风险，见 W1 |

实施完成性、Requirement Implementation Mapping、全部 Scenario Coverage、实现 Code Pattern Consistency 均未验证：当前只有规划、未授实施。此报告不作 archive 就绪判断；原生 `isComplete=true` / `state=ready` 不是方案接受或实现通过。

## CRITICAL

None（限定为本次规划审阅；不将 0/5 未来任务误报为五项缺陷）。

## WARNING

### W1 · 无效等待不限于样本嵌套，下一步不应再盲付一次完整运行

**证据与影响。** `panel-b2.sh:693,715` 对整段捕获寻找连续 `teamsmith-paste-`；`:779` 的理由模式也使用同一等待。`lib/pty-wait.sh:94–99,177–222` 按原字符串匹配，换行不会被忽略，静止且缺串时在 100 轮左右返回 1。样本候选屏幕实际是第一行末 `teamsmith-past`、第二行首 `e-UUID.pngd`；两次超时 stderr 均确认静止，草稿及文件又确实正确，见下文原件表。

这不是产品没完成粘贴。trace 第 3469/10597 行已分别在 epoch `1794828095.077896` / `1794828135.518170` 捕到分行后的正确路径，直到 `1794828130.436377` / `1794828170.849509` 才记 `PTY_WAIT_FAILED=1`；剩余约 35s 各自花在等一个不会以连续字符出现的 token。这里只报告已有捕获的时间差，不外推正常整组节省。

**正常路径的静态反例。** `server_up` 固定 120 列（`:165`），`App.tsx:1771–1776` 扣两列边框，`compose.ts:22,447–456` 再扣两列提示，因此本画面每行正文容纳 116 个 ASCII 字符。`common.sh:83–101` 令本项目各 worktree 共用 `pm_skills-deb708fe` 命名空间；`:4196–4240` 的默认基址与 `tmp-root.sh:229–235` 的六字符随机根名可直接推导路径，不需启动任何场景。

以下列号从草稿首字符计数，非屏幕绝对 x；`XXXXXX` 仅等长代表已有六字符随机后缀：

| 路径生成方式 | `tmpdir` 路径长度 | `a<path>d` 中 token 所占正文位置 | 是否跨 116 字符边界 |
|---|---:|---:|---|
| 本次 sample `…/scratch/teamsmith-panel-b2-pm_skills-deb708fe.XXXXXX/old/tmpdir` | 94 | 97–112 | 否，之后的 UUID 换行不影响 token |
| 同次 sample `/candidate/tmpdir` | 100 | 103–118 | 是；原屏幕恰为 `teamsmith-past` / `e-…` |
| 原 b2，调用环境 `TMPDIR=/var/tmp`，`/var/tmp/teamsmith-panel-b2-pm_skills-deb708fe.XXXXXX/clipboard/tmpdir` | 70 | 73–88 | 否 |
| 原 b2，未设 TMPDIR/TEAM_TMP_ROOT，正常磁盘默认 `/var/tmp/teamsmith-pm_skills-deb708fe/teamsmith-panel-b2-pm_skills-deb708fe.XXXXXX/clipboard/tmpdir` | 99 | 102–117 | 是；最后一个 `-` 到下一行 |

本席位实际环境为 `TMPDIR=/var/tmp`，但这不能代表所有正常调用；上表最后一行是本项目合法默认输入的**源码推导**，不是另一次运行的测量。理由模式在路径前有 `why` 而非 `a`，又沿用同一 token，亦不能靠后面已经存在的 `reason_text()` 断言重组来避免前面等待耗尽（`:779` 在 `:786–799` 重组之前）。

样本 `first_probe/second_probe` 不接等待的失败返回，后续文件/草稿断言成功让函数以 0 退出；`wait_state` 另在 `:136` 明确吞掉等待返回。runner `:1252–1262` 看 FAIL/最终 rc，父 `p38_verdict` 又只消费 child rc，均不会从这些已吞掉的返回自动恢复失败。因此人工拒绝含等待诊断的交付是必要的，但不解决这三处现有等待本身。

**最小修订与对结论的改变。** 请作者修正 design §4、proposal Impact 和报告 §3 的风险范围，把正常默认路径列为已识别问题；PM 在派 apply 前先安排或明确收敛 `scenario_clipboard` 这三处等待的局部替代，使其观察实际图片/对应草稿状态，不以路径恰好没跨行作为前提。保留具名图片/内容/插入点断言、原等待引擎及上限、原 5s 观察，不靠缩路径、改宽度、删等待或新通用重组框架换绿。本轮不实现该修订、不要求再跑全场景；修订只静态复看。该发现使建议从“直接实现准备复用”改为“先收敛等待问题，再决定同一小改动的实施顺序”。

### W2 · “每个子例都按 C-v”与未按键观察直接冲突

`proposal.md:10` 写“原八个子例逐个真实 C-v”，delta `specs/verification/spec.md:5` 写 `Each condition SHALL use a fresh real C-v`；同一 delta `:28–32` 和 design 启动表却保留未按键观察。原 `panel-b2.sh:830–839` 只执行关/开写信各 5s、两处零调用断言，没有 C-v；整个原 scenario 是 **八子例、七次主动 C-v**。

最小修订：将上述泛指限定为“七个主动粘贴子例各执行真实 C-v；未按键子例保持零 C-v 和两段观察”，不改测试、不增加断言或任务。这会消除验收文字要求主动破坏原未按键行为的矛盾；不要求重跑样本。

## SUGGESTION

None。不另加长期调试断言、成功计数、组合矩阵、模型调用或性能门槛。

## 样本原件复核：哪些成立，哪些没成立

### 1. 确实是同进程、真输入、分别取新结果

独立读取 receipts 中的 `screen.txt/draft.md/calls.log/*.png/pane.txt`；只拼合写信框自身的 `│ > ` 和连续 `│   ` 两行，没有拼其它区域或改任何文件：

| 原件 | pane / pid | 草稿、框内文字、图片、工具记录 |
|---|---|---|
| old/first-probe | `%2 / 2420934` | `a<old 路径>Zd`，屏幕正文与草稿逐字相等；PNG `aab5fdcf-…` 内容 `PNGDATA8`；wl list-types → image/png，无 xclip |
| old/second-prepare → second-probe | `%3 / 2448706` | 准备为 ad；结果 `a<新 old 路径>d`，屏幕相等；PNG `f63a4121-…` 为 `XCLIPDATA`；wl list-types → xclip TARGETS → xclip image/png |
| candidate/first-probe | `%2 / 2466452` | `a<candidate 路径>Zd`，屏幕分行拼合与草稿相等；PNG `07bc856e-…` 为 `PNGDATA8`，无 xclip |
| candidate/second-prepare | `%2 / 2466452` | 草稿恰为 ad，屏幕 `│ > ad`，cursor_x=6；调用日志和图片已清，非只写磁盘冒充刷新 |
| candidate/second-probe | `%2 / 2466452` | `a<新 candidate 路径>d`，屏幕相等；PNG `d9d0bdff-…` 为 `XCLIPDATA`；三行调用顺序同上 |

first-prepare 均在按 m 前，屏幕没有写信框，不能把那两份当作正文显示证据。两种方法每种各一次 team init/server/假 PM；trace 的实际 `send-keys` 分别为 8 / 11，其中 C-v 各 2 次。候选在第一次 Z 的原断言之后，顺序为 Esc → 清图/日志 → 写 fail/image 两个模式文件 → m → C-e → C-u → 等空草稿 → 输入 ad → 等正文/屏幕 → Left → C-v；trace 行 9560–10505 与 receipts 一致，没有第二次磁盘种子重置或 panel new-window。

普通文件输入只供假工具每次启动读取，不是给运行中面板热改环境；四种工具模式可继续沿原 case 分支，保留的四个启动也可传相同输入路径。design 启动退休表逐项对应原 source 的首次、理由、独立 team-cli、未按键四个保留启动。这个做法本身仍简单；样本多出的空草稿/种子两条调试断言没有必要永久加入。

### 2. 等待失败历史与参考时间不能被 rc=0 覆盖

| 原 stdout 阶段（s，保留到三位） | old | candidate |
|---|---:|---:|
| 首次准备 | 6.637 | 7.009 |
| 首次交互 | 2.384 | 37.489 |
| 第二准备 | 6.903 | 3.557 |
| 第二交互 | 0.850 | 35.921 |
| 总计 | 16.812 | 84.018 |

候选第一/第二次等待均 `100/500`、缺 `teamsmith-paste-`，stderr 报静止画面；原 assertion 为旧 9 条/候选 9 条，另加候选调试 2 条，PASS=20 是累计数。第二准备差值只是一对含不同准备动作的参考读数，不能当整组净提速；8→4 仍仅是未来静态调用账。

初次 `initial-setup-failure/job.rc=2` 的 trace 证明 `scripts/team init`、new-session、PM/panel 启动和 send-keys 均为 0；之前创建了临时 git 项目。stdout 的报错是额外 tmux 检查把具名 `-L` 与 default 比较而拒绝，不是复用交互失败。续做原件及最后 rc=0 全部保留，两次等待失败也保留；本轮没有重执行或调输入。

### 3. 新准备的失败返回：方案可用，但不能照抄样本的被吞 return

源码依据是：`wait_draft:145 → wait_state:133–138 → pty_wait_frame` 为同 shell 的普通函数调用；只有捕获文本本身用了命令替换。每次 `pty_wait_frame:189` 先把 `PTY_WAIT_FAILED=0`，真正耗尽后 `pty_wait_scene:248` 设 1，调用回到 wait_state 后只恢复 `b2_wait_state`，不清失败标志。故 design §2 的方式可行：普通调用目标全文 `wait_draft` 后**立即**检查该次标志，非零 `bad` 后显式 `return 1`；不能先运行另一等待、把 wait 放进子 shell/命令替换，或只接已经被 wait_state 吞掉的返回。

`bad()` 增加 FAIL；runner `case … esac || rc=$?` 保留非零，FAIL 非零最终固定 exit 1。新出口须替代四个旧准备的检查，不添加成功断言。旧 start_panel 的函数返回本身不等于 scenario 会自动中止，不能拿它当新路径失败传播已验。

tasks 2.2 的注入必须发生在“该次等待的结果交给消费者”这一位置；若在真实 wait_draft 之前仅设 `PTY_WAIT_FAILED=1`，会被 `:189` 清零，不构成结果消费检查。测试只替代该次等待结果后调用实际准备代码，并观察 FAIL、非零返回、未发送下次 C-v；这是允许的局部结果消费，不是等待引擎故障已复现。当前没有实现，不声称该失败出口已经跑过。

### 4. 后续验证规模足够，不须加全量

design §5/tasks 2.1–2.3 的一次非作者完整 clipboard，加真实 C-v no-op 首例短坏腿/短恢复/实际父结果消费，足以覆盖这次一个 scenario 的准备替换；前提为 W1/W2 先修正，而非加第二次完整运行。

- App.tsx:2085–2088 的真实 C-v 分支可在自有副本作 no-op；必须以原具名图片/内容 assertion 失败且 child rc=1 为证，不能只凭构建失败、搭建失败、提取错误或等待超时。
- 只摘取实际源函数/真实首例操作及原断言，不复制比较答案；父消费必须使用该次真实坏日志/rc，以及原 `smoke.sh:20788` 的 p38_verdict。
- `smoke.sh:20969–20971` 确将 b2 child 的 `$?` 交给同函数，`:20798` 的 rc=1 分支调用 bad；本轮仅静态核实，没有运行 §38 或冒称完整调度已验。
- 同一已验可执行字节合并后只核同一性和必要短检，不重复完整 clipboard/b2/38；作者只实现/静态。准备失败注入不另造通用 runner，不把两个样本或成功计数凑进父结果。

## Verification evidence（本轮实际执行）

### 独立原生结构与上下文

后台 `v169-proposal-structure` 已按完成通知收取，exit=0。以下命令运行目标均为 PM 固定检出；OpenSpec 实际程序为 `$HOME/.bun/bin/openspec`，版本 1.16.0：

```text
$ openspec --version
1.16.0
$ openspec context --json
root.path=/var/tmp/p464-review-2c5ba223; source=nearest; role=openspec_root
$ openspec status --change clipboard-test-session-reuse --json
schemaName=spec-driven; proposal/specs/design/tasks=done; isPlanningComplete=true
$ openspec instructions apply --change clipboard-test-session-reuse --json
progress: total=5 complete=0 remaining=5; taskTrackingConfigured=true; state=ready
$ openspec validate clipboard-test-session-reuse --type change --strict --no-interactive
Change 'clipboard-test-session-reuse' is valid
STRUCTURE_RC=0
END 2026-11-16T11:50:26Z
```

没有执行 apply 行为；原生 status/apply 的工作建议只作上下文，未当作接受结论。

### 只读原件校验与静态登记复用

执行只读 Python（hashlib/pathlib/re）核对 manifest、遍读八份阶段 receipts、统计实际 trace、按源码计算上述正文位置；没有 source/run 任一样本、测试或产品程序。

```text
SOURCE panel-b2.sh     d757dc2ff58aaebb6adb537abcf0f9cff68b493a166e7fbbdd184af337f49494 IDENTICAL
SOURCE lib/pty-wait.sh 6fb1686661a073f4e83aaa9869f09d93fb8b292a4970292eaa650ad0550b8f72 IDENTICAL
SOURCE lib/tmux-iso.sh 555d4f0c3a56d3b1f755a0d00acdb155d3f2dfd014f8e6f117e20c981a144f8a IDENTICAL
SOURCE panel/panel.js  55f51002e4cdd055b5f542bf09face626a2bff32aa8312a4454e1dd4c0fa52b4 IDENTICAL
TRACE_COUNT old       servers=1 pm=1 panel=2 real_sends=8  C-v=2
TRACE_COUNT candidate servers=1 pm=1 panel=1 real_sends=11 C-v=2
INITIAL_RC=2; initial_business_counts=0; CONTINUED_RC=0
```

重算出的原件 SHA256 与作者报告一致：

```text
sample.sh                       9533b8632484fe1866c1a8b75a1c81b15c5dd0c68a2d904fdf8df2bfee632672
trace.log                       5f321e8256c7d996810f1602f1207ad80236e57187427e5dd76383094c054eb0
continuation.stdout.log         7f356b8321b608c39b86b452bf89a4bc18585b7ebc87cc9c010ef1de3ba0886d
continuation.stderr.log         36320df5267a069c29c55faaad2b295f6fa3e3bef882cd2a8a357784eb1f9497
initial-setup-failure/sample.sh  18d92b1da4dfefd6ff09a3514b2516184513d996aa4dcb63b831428f9971d2d4
initial-setup-failure/trace.log  426a181ef714372cd36a132bbdb1020869259363fe598d4f8dcf32a7da79f9c5
```

静态登记**复用作者原始回执，不称本席位重新执行**：`static-checks.rc=0 0 0 0 0`；spec-refs 为 122 references / 49 distinct / undeclared=0；selector 自检 ok=13 bad=0 SKIP=1（缺生成的 `.pi/skills`，并非检查通过）；两个路径查询分别命中 18c 和 38，共 5/12 keys，均不是 smoke 行为执行。

已实际运行 `git diff --quiet 2c5ba223 -- skills/teamsmith/tests/section-paths.tsv skills/teamsmith/tests/spec-refs.sh skills/teamsmith/tests/section-select.sh`，rc=0；sha256sum 对应目标/本席位字节相同，其中路径表为 `35ebe0e8467f26528ac87a169621929e4655cb1c97c8fb6ea0e0addad7d54908`。未再跑选择自检或 spec-refs。

### 本席位报告检查

以下均在本席位/本分支运行，报告已先暂存；使用主 git 公共目录的名单，不在主检出扫描替代。工具输出中的 `<user>` 是扫描器原有的账号隐去形式。

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify scope=published files=2787 hits=0 names=ok user=resolved
LEDGER_RC=0
$ git diff --check
DIFF_CHECK_RC=0
$ git diff --cached --check
CACHED_DIFF_CHECK_RC=0
```

首次暂存差异检查 rc=2，点名本报告开头两行 Markdown 行尾双空格；已删除，重新暂存后以上三项均为 0。写入本回执后再暂存并重检，提交只包含本报告。

## Flip evidence

N/A——本轮是规划审阅，未修改实现。未来 no-op 红/恢复及失败结果消费仅审计划，没有报告成已运行。

## Final assessment / 未验边界

- Counts: CRITICAL 0 · WARNING 2 · SUGGESTION 0。
- 方案结论：REWORK；普通输入/真键复用机制值得保留，W1 改变实施优先级，W2 需修规格矛盾。两项均只需先改规划，不需新场景或完整重跑来决定。
- 未验：完整八子例、正常完整 clipboard、其它 b2/§38/其它面板帮助组、smoke 真实段、全量/FAST/meta/61b/夜间、安装/构建/性能/真实模型、真实 C-v no-op/短恢复、新准备实际失败传播及合并字节。本 brief 禁止执行，当前也没有实现；不作这些项目 PASS 或收尾定稿声明。
- 源码推导的正常默认路径跨行不是一次新的真实运行；当前 `TMPDIR=/var/tmp` 没跨该 token 也不是该路径已实测无等待问题。

## Decisions and deviations / 最小下一步

- 无执行范围偏离；所有证据原件留本地，没有 `git add -f`、merge/push/archive 或真实团队修改。
- PM 将 W1/W2 一次交回作者：先记录正常默认路径反例并收敛局部等待的先后关系，再修七次 C-v/未按键文字；本席位后续只静态复看这些差异，不重开整体方案或追加长套件。
- 当前不派 apply；正式 proposal review 仍由 PM 接受证据后记录。
