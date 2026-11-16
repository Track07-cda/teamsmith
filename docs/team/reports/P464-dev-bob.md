# P464 · 先纠正图像等待，再复用四次准备

agent: dev-bob · status: DELIVERED（W1/W2 规划返修，待原审阅者定点复看；未实施）
branch: `task/P464-clipboard-reuse-proposal` · PR/MR: -（本地）
phase: opsx-propose · change: clipboard-test-session-reuse
执行字节基线：`4b26a2d5b106ffe721a4b8b08c7d3f6a5da1a2f5` · 2026-11-16。

## 结论

**建议限定为同一次实现：先把 clipboard 三处图像等待改为真实图片及对应草稿/理由状态观察，再替换四次准备性重启，不替换真实交互。** 一个两条件对照实际完成了旧方法两次面板启动、候选一次启动与一次真键重置；两方法各两次 C-v，均取得 PNGDATA8/XCLIPDATA，路径和继续输入的位置正确，候选前后是同一个面板进程。新增准备为 C-e、C-u、输入 ad 三次发送，以及假工具普通输入文件的切换，不需要新启动器或产品开关。

**不是样本全绿，也没有提速结论。** 原断言旧方法 9 条、候选 9 条，加样本重置检查 2 条均通过；但候选两次等待屏幕含 `teamsmith-paste-` 均 rc=1，因本次长临时路径把该 token 拆成两行。摘出的原逻辑随后继续执行，覆盖了等待的非零返回，最终样本和后台均 rc=0。报告不把这 20 条成功断言或 rc=0 升级成等待全通过。逐行读原屏幕后拼合**写信框自身的两行**，与真实草稿逐字节相等；这是已有原件的读取，不是改脚本重跑。

复用的基本状态切换有直接证据；全八子例、原观察窗口、失败向调用者传播及坏腿仍未验。原 V169 方案审阅以 W1/W2 判 REWORK，PM 已接受其发现；本次只修相应规划，不重新实验，不替代原审阅者定点复看或 PM 接受。未来八子例是七个主动粘贴各一次真实 C-v、一个未按键子例零 C-v；唯一一次非作者完整 clipboard 直接覆盖正常默认长路径、三处观察替换和四次准备复用。

## 1 · 实际启动、重置和输入账

| 本次两个连续条件 | 旧方法实际 | 候选实际 | 变化 |
|---|---:|---:|---|
| `team init` / 私有 server / 假 PM 窗格 | 各 1 | 各 1 | 不减少这些不同准备 |
| 面板 bundle 启动 | 2 | 1 | 退休一次 kill/new-window + monitor + 首帧 |
| 真实 C-v | 2 | 2 | 原产品→假工具→文件→草稿链不减 |
| 原条件共有的键/文字发送 | 8 | 8 | m、Left、C-v、Z、Esc、m、Left、C-v |
| 重置新增发送 | 0 | 3 | C-e、C-u、输入 ad，仍按 200000 μs 节奏 |
| 直接写初始 `draft.md=ad` | 2 | 1 | 候选只在第一次冷启动前写，第二次不写盘冒充内存刷新 |
| 活面板草稿重置 | 0 | 1 | 先空、后 ad，等待文件和屏幕为真 |
| 样本新增重置等待 / 调试断言 | 0 / 0 | 3 / 2 | 空草稿、ad 草稿、ad 屏幕；这两条调试断言不是未来额外门禁配额 |
| 每条件清图片/调用日志 | 2 | 2 | 首次结果已存快照后才清 |
| 假工具模式普通文件写入 | 0 | 4 | 初始两文件、切换两文件；不是产品配置/缓存/服务 |

真实 trace 统计：旧方法 `panel launches=2, real keys sends=8, C-v=2`；候选 `panel launches=1, real keys sends=11, C-v=2, C-e=1, C-u=1`。两方法各有一个 server/PM。正式整个 clipboard 的 8→4 仍是**计划静态账**，本次实跑只证明 2→1；其余六子例没有执行。

## 2 · 两次 C-v、隔离与准确插入点

原件统一位于 `/var/tmp/p464-dev-bob-6ovk4j49/receipts/<old|candidate>/<stage>/`；每阶段保存 `time.txt`、`screen.txt`、`pane.txt`、`draft.md`、`calls.log`，探测阶段另有原 PNG 文件副本。`first-prepare` 快照在按 m 之前，预期没有写信框，不把它当写信框证据。

| 实际原件 | 结果 |
|---|---|
| `old/first-probe` | PNG `aab5fdcf-…` 为 PNGDATA8；草稿 `a<本次路径>Zd`，屏幕框内文字逐字节相同 |
| `old/second-probe` | PNG `f63a4121-…` 为 XCLIPDATA；草稿 `a<新路径>d`，屏幕框内文字逐字节相同 |
| `candidate/first-probe` | PNG `07bc856e-…` 为 PNGDATA8；草稿 `a<本次路径>Zd`，屏幕框内文字逐字节相同 |
| `candidate/second-prepare` | 屏幕 `│ > ad`，草稿恰为 ad，光标 x=6；不是仅改磁盘文件 |
| `candidate/second-probe` | PNG `d9d0bdff-…` 为 XCLIPDATA；草稿 `a<新路径>d`，屏幕框内文字逐字节相同 |

两方法第一条件调用日志恰为：

```text
wl-paste --list-types
wl-paste --type image/png --no-newline
```

两方法第二条件恰为下列三行，Wayland 在 X11 之前；两次 UUID 和数据不同，不可能以上例 PNG 顶替下例：

```text
wl-paste --list-types
xclip -selection clipboard -t TARGETS -o
xclip -selection clipboard -t image/png -o
```

候选 `first-probe/second-prepare/second-probe/pane.txt` 均为 `%2 2466452`；旧方法从 `%2 2420934` 变为 `%3 2448706`。两者都在本次具名 socket `…/socket/tmux-1000/p13b2-2415956`。候选模式文件在第一阶段 Z 的原断言结束后才切换；原 trace 同时记录 Esc/m/C-e/C-u/ad/Left/C-v 的真实发送顺序。

## 3 · 参考时间与两个等待错误

| 阶段 stdout 记录（s，仅本次参考） | 旧方法 | 候选 |
|---|---:|---:|
| 首次准备（PM + 面板） | 6.637 | 7.009 |
| 第一条件交互 | 2.384 | 37.489 |
| 第二条件准备 | 6.903 | 3.557 |
| 第二条件交互 | 0.850 | 35.921 |
| 从首次准备起至第二条件结束 | 16.812 | 84.018 |

**这轮候选反而更久**；两次等待分别报告约 36s/35s。stderr 的静止原帧把 token 画成行尾 `teamsmith-past`、下一行 `e-<UUID>.pngd`；`old` 比 `candidate` 短六字符，没有在同处拆 token。所有内容早已落入草稿和静止屏幕，不是剪贴板未返回。这些长度与两次超时使总时间不可用来比较重启和复用的正常耗时；第二准备的一对 6.903/3.557 也不能外推净省秒数。

没有缩短按键间隔、等待参数或重新执行来取得更好数字。**更正原风险判断：正常默认磁盘路径也会跨同一 token，不限于本次 old/candidate 嵌套。** V169 从 `common.sh` 的默认根/项目命名空间、六字符随机后缀、120 列面板的 116 字符正文推导：`/var/tmp/teamsmith-pm_skills-deb708fe/teamsmith-panel-b2-pm_skills-deb708fe.XXXXXX/clipboard/tmpdir` 使 token 占正文 102–117，跨行；这是源码推导而非一次新运行。原先“先保留等待，完整运行若再出现才处理”的下一步错误，现按 PM 裁定先收敛同函数原 693/715/779 三处观察替换，再准备复用，同一次 apply/同一轮非作者完整 clipboard 覆盖。不改库、节奏/上限、宽度、路径或两段五秒观察，不造通用重组。具体局部回调及现成理由取文方式只定义于原 design §4，报告不复制一套规格。

## 4 · 初次准备失败、续做及日志处理

初次后台 `p464-two-condition` 在任何真实 team init/server/面板/C-v 前 rc=2；我多装的 `tmux_iso_install_suite_guards` 按 default 比较具名 -L socket 而拒绝。我最初把“不能重复已完成业务”误读成“准备报错也不能继续”，过早以失败回执交工。PM 11:19:52Z 的线程及更新 brief 已纠正。

初始脚本/manifest/trace/stdout/stderr/rc/审计完整保存在 `initial-setup-failure/`。只撤掉临时脚本多加的三行外层接线，沿用原 b2 的私有目录/具名 socket/cleanup，未修产品或隔离库。续做没有重复任何已完成业务，因为初次业务计数均为 0。完成业务后仅重读原件，没有再运行样本。

首次误用 `git add -f` 跟踪的四份日志已在 `369191bc` 逐个 `git rm --cached` 解除，保留本地及旧提交，未改 ignore 或历史。本次新日志/快照也只留本地，不再强制加入仓库。

## 5 · 实际命令、返回码与原件身份

```sh
$ bash -n /var/tmp/p464-dev-bob-6ovk4j49/sample.sh
# rc=0（只语法）
# 以 team_bg_run 启动后结束回合，再按完成通知 team_bg_wait：
$ P464_ROOT=/var/tmp/p464-dev-bob-6ovk4j49 PATH=/usr/local/bin:/usr/bin:/bin:/home/$USER/.local/bin bash /var/tmp/p464-dev-bob-6ovk4j49/sample.sh
# home 段用变量表示；实际为本用户绝对路径。
# job p464-two-condition-continued：exit=0；真实等待错误仍保留，不称全绿。
```

原 stdout 尾部：

```text
PHASE candidate/second-prepare rc=0 end=1794828134.933771 PASS=17 FAIL=0
没等到 B4 Wayland 失败后 X11 回退成图：100/500 轮（耗时约 35s；最后一次状态：no；缺：缺 [teamsmith-paste-]）
B4 X11 回退：文件内容 XCLIPDATA
B4 X11 回退：路径进草稿
B4 调用顺序：wl-paste(1) 先于 xclip(2)
PHASE candidate/second-probe rc=0 end=1794828170.866739 PASS=20 FAIL=0
SAMPLE candidate rc=0 PASS=20 FAIL=0
```

原件均在唯一临时根，SHA256：

```text
sample.sh                  9533b8632484fe1866c1a8b75a1c81b15c5dd0c68a2d904fdf8df2bfee632672
trace.log                  5f321e8256c7d996810f1602f1207ad80236e57187427e5dd76383094c054eb0
continuation.stdout.log    7f356b8321b608c39b86b452bf89a4bc18585b7ebc87cc9c010ef1de3ba0886d
continuation.stderr.log    36320df5267a069c29c55faaad2b295f6fa3e3bef882cd2a8a357784eb1f9497
continuation.job.rc        9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa
initial-setup-failure/sample.sh 18d92b1da4dfefd6ff09a3514b2516184513d996aa4dcb63b831428f9971d2d4
initial-setup-failure/trace.log 426a181ef714372cd36a132bbdb1020869259363fe598d4f8dcf32a7da79f9c5
```

Python 只读统计实际 trace 并逐一读取 screen/draft/calls/PNG/pane；四个 probe 写信框文字拼合均与草稿相等，第二准备 ad 也相等。按 `continuation-manifest.json` 重比 `panel-b2.sh`、`pty-wait.sh`、`tmux-iso.sh`、`scripts/panel/panel.js` 全部 IDENTICAL。

## 6 · OpenSpec assessment / Deliverables

本轮只规划。已按主检出只读的 `.pi/skills/openspec-propose/SKILL.md`（generatedBy 1.16.0）操作；绝对路径 `/home/$USER/.bun/bin/openspec --version` 实际返回 **1.16.0**。初次 PATH 未找到 CLI 是定位问题，没有安装或改配置。

`openspec list --json` 与 `openspec context --json` 均 rc=0，root 指向本任务工作树，`source=nearest`；list 的 `changes=[]`。确认既有根后才进入提案阶段，不初始化新根、不选外部 store。

制品已小步提交：`86e5409a` 为真实样本报告，`2060884d` 为原生 change 的四制品和 `.openspec.yaml`；只增加 `openspec/changes/clipboard-test-session-reuse/` 与自己的报告，正式 specs、产品/tests 均无 diff。

| Path | Deliverable |
|---|---|
| `openspec/changes/clipboard-test-session-reuse/proposal.md` | 先替换三处图像观察再退休四次准备，七次主动/一次零 C-v 边界 |
| `openspec/changes/clipboard-test-session-reuse/design.md` | 同函数局部观察、普通假工具输入、真键种子、保留启动账；一次正常默认长路径 clipboard/必要短检 |
| `openspec/changes/clipboard-test-session-reuse/specs/verification/spec.md` | 1 条 ADDED requirement、6 个可证伪 scenario，无具体账本引用 |
| `openspec/changes/clipboard-test-session-reuse/tasks.md` | 5 项未来实施/验证任务，均未勾；不是本次已执行事项 |
| `docs/team/reports/P464-dev-bob.md` | 实际样本、首次失败及续做、静态检查与证据边界 |

| Assessment | Result | Evidence |
|---|---|---|
| Completeness | 规划 4/4，实施 0/5 | 原生 status 为 proposal/specs/design/tasks 全 done、isPlanningComplete=true；tasks 留空 |
| Correctness | 提案结构通过；不判实现通过 | 本 change strict validate rc=0；只跑两个条件，两处屏幕等待错误已披露 |
| Coherence | 一个 capability / 一个 scenario 写集 | verification delta；只计划 scenario_clipboard，未改产品/正式 spec/等待或隔离库 |

非作者 V169（`74925f0d`）已经完成首轮方案审阅，结论 REWORK、WARNING 2；本次仅修 W1/W2，交原审阅者定点复看，不把自己的文字修订当方案通过，也不以原生 status 的文件存在性启动 apply。

- CRITICAL：0（沿用首轮规划审阅边界，不是产品验收）。
- WARNING：2（原 V169 的 W1 正常默认路径等待问题、W2 七次主动/一次未按键矛盾）；本次规划均已修，尚待其复看。原两次等待失败/总 rc 被覆盖的历史不改，样本仍不全绿。
- SUGGESTION：0，不追加其它设置/缓存/平台/语言/高度工作。
- 未验：其余 clipboard 子例、完整 clipboard/b2/§38、全量/FAST/meta/61b/夜间、真实模型、性能套件、C-v no-op 坏腿及父调用失败接线。任务书将未来完整 clipboard 和必要坏腿/接线分给非作者，本轮不执行。
- Flip evidence：N/A，规划不是缺陷修复；未来坏腿计划只进 design/tasks，不报本轮执行。
- 范围偏离：初次准备接错且过早交付已按原任务续做；临时根保留供审阅，未动 P461/V167/A9 现场。没有 merge/push/archive/tag/npm、真实团队/提醒/standby 变更。

## 7 · 首轮报告检查（原回执保留，本次不重跑旧登记）

首轮后台 `p464-proposal-static` 实际完成，exit=0；只执行以下提案结构/静态登记，没有 smoke 或面板：

```sh
$ openspec validate clipboard-test-session-reuse --type change --strict --no-interactive
Change 'clipboard-test-session-reuse' is valid
# rc=0；实际用版本 1.16.0 的上述绝对路径，未做全仓 validate。
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14404 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
# rc=0；没有新增 ledger ref 声明。
$ bash skills/teamsmith/tests/section-select.sh --check
SKIP（条件不满足）: 行 19 的字面模式在检出里不存在（检出形状 internal，机器生成面（工具在本机生成、不进仓库））：.pi/skills
== 选段自检 ==  ok 13  bad 0  SKIP 1
# rc=0；这个工作树没有 .pi/skills，具名跳过不是检查通过，未补造生成面。
$ bash skills/teamsmith/tests/section-select.sh --paths openspec/changes/clipboard-test-session-reuse/specs/verification/spec.md
# rc=0；decision=RUN，keys=5：0,0b,0c,0d,18c。
$ bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/tests/panel-b2.sh
# rc=0；decision=RUN，keys=12：0,0b,0c,0d,2,12b-h0d,18,26,27,28,38,40。
```

以上两个路径查询只证明原映射仍命中，没有执行这些段，更没有按该选集跑完整面板。静态日志全部保留于原唯一临时根：`proposal-validate.log`、`spec-refs.log`、`section-check.log`、`select-delta.log`、`select-b2.log`，各 rc 另存 `static-checks.rc` 为 `0 0 0 0 0`。

本任务工作树中，最终报告已经 `git add` 后实际扫描：

```sh
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev-bob scope=published files=2777 hits=0 names=ok user=resolved
$ echo $?
0
$ git diff --check
# rc=0，无输出
$ git diff --cached --check
# rc=0，无输出
```

首轮写入此回执后已再暂存并复跑同三项，记录在 `2c5ba223`。本次 W1/W2 返修不重复 spec-refs/section-select，引用声明/映射/选择器均未改；新 delta 严格结构及本轮报告检查另列下节。四份原日志仍保持本地、不跟踪，首次误跟踪历史不改。分支留本地，不推送，等待原审阅者定点复看和 PM 接受。

## 8 · V169 的 W1/W2 最小返修

依据主检出更新的 P464 brief、原 V169 报告 `74925f0d` 和 PM proposal review 的 REWORK：

| Finding | 本轮规划变更与影响 |
|---|---|
| W1 | 原 proposal Impact、design §4、报告 §3 均纠正默认路径范围；已有 All original clipboard outcomes 场景及任务 1.1/2.1 写明先三处图像观察、再四次准备复用，同一 apply/唯一一次完整默认长路径 clipboard。现有 pty_wait_frame 回调加真实状态、已有 reason_text 足以保持局部写集，故没有扩库理由。尚未实现或动态验证这一替代。 |
| W2 | 原 proposal、requirement 正文及执行账统一为七个主动粘贴各一次真实 C-v、一个未按键子例零 C-v；原关/开两段观察保留。未改原 tests。 |

仍是 1 条 requirement、6 个 scenario、5 项未实施任务；没有增加长期检查、成功断言、层级或新样本。原 no-op/短恢复/结果消费范围不扩大。design §2/5 仅澄清 V169 已核源的同 shell/立即读标志，以及结果替代完成后、真实消费者读取前注入，不能在真实等待前设标志再被清零。图像局部子 shell 直接用引擎 rc，父调用方计 FAIL，不假定标志能跨子 shell返回；这不是新增的等待框架。

本轮规划修订为 `9dc646da`；只有四份原规划文件变化，未新增 requirement/scenario/task。后台 `p464-w1-w2-checks` 完成并按唤醒收取，exit=0，报告先暂存后检查：

```text
$ openspec validate clipboard-test-session-reuse --type change --strict --no-interactive
Change 'clipboard-test-session-reuse' is valid
rework_validate_rc=0
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev-bob scope=published files=2777 hits=0 names=ok user=resolved
rework_ledger_rc=0
$ git diff --check
rework_diff_rc=0
$ git diff --cached --check
rework_cached_diff_rc=0
```

严格结构实际程序仍为 1.16.0 的 `$HOME/.bun/bin/openspec`；只验本 change，不做全仓 validate。日志保存在原唯一临时根的 `rework-w1-w2-{validate,ledger,diff,cached-diff}.log`，`rework-w1-w2-checks.rc` 为 `0 0 0 0`。后续只补报告回执，四份规划字节不变；最终暂存后再次执行 ledger/普通及暂存 diff-check。

没有重做两条件样本、完整 clipboard 或其它整组，没有重跑 spec-refs/选段旧静态平台；原准备失败、两次等待失败、16.812/84.018 参考读数及原件全部保留。下一步由原 V169 只复看 W1/W2 差异，当前不报方案已接受，不进入 apply。
