# V191 · 0.4.8 五个公开 CI 失败作业核因

**结论：四片确实失败，覆盖作业只是承接四片失败，没有漏跑。§10 是 P459 修好路径显示后留下的误报；§28/§38 存在三类不同的检查问题，其中设置页的两条操作不能拿本次 CI 当正常证据；§67 两例都是真实 Pi 已跑起来、`doctor` 却报 PM 不在，问题落在识别 PM 的路径，不是提醒发送失败。** 已发布包和标签不动，原 CI 结论仍为 `failure`。

agent: verify   status: DELIVERED（只读诊断）   time: 2026-11-24 UTC

branch: `task/V191-release-048-public-ci-diagnosis`   PR/MR: -

## 根因表

| 段落与分类 | 原件及后果 | 最小修法与独立验收 |
|---|---|---|
| **§10 P440：CI 布局触发的检查误报，非 0.4.7 产品缺陷复发。** 片 3/4 重复两条。 | `138190141527.log:1914–1935`、片 4 同段：真实 review `rc=0/PASS`，绿侧、还原侧均 `absolute home remains`，兄弟目录、真实 HOME 子路径及四组 C/UTF-8 检查都过。`smoke.sh:6000–6024` 用 `grep -F "$HOME"`，而 CI `HOME=/tmp`、独立检出和命令在 `/var/tmp/...`，字符串匹配必然把合法路径当成 HOME。片 4 留存的 T1.1 记录内 `/tmp` 两个命中都来自 `/var/tmp`，真正的家目录摘录是 `<home>`；该记录后来被覆盖，不能冒充当时的逐字段快照。P440 独立日志仍有原绿/还原错误、故意取消净化则 `absolute main root remains`。 | 只改 §10 的路径断言，按完整路径边界判定，不动产品净化。用 CI 的两根目录实跑原 §10 对应场景：保留 `/var/tmp/...`、真正 HOME 改占位、兄弟前缀原样；取消净化仍红、还原同一副本绿。不要只换一个更长的 HOME 让误报消失。 |
| **§28-a2 / §38-e：旧全表标签与旧分组检查不再适用。** 属于新增检查不一致，不是缺少屏幕标签。 | `138190141503.log:3468–3478,4029–4045`：`panel-strings: ok`、`8 key labels; 76 displayed references`，外层却要求旧的 `contract-key labels` / `contract-group labels`。删真实 `label_TEAM_PULSE_INTERVAL` 仍被抓住；`TEAM_MEETING_KNOCK` 不是精选设置，所以删它的 schema 行返回 0。`group_workflow` 是已退场标签，插入 `group_zzz` 的旧 `settingsGroupUngrouped` 锚点也已退场；这两条 `sed` 不证明删/增了任何当前标签。`p38e_group_pin` 要求 `k.group` 和 `group_${token}`，而 `layout.ts:1630–1638` 按用户用途组织；正常树先已失败，注入旧词后红不算有效反证。§38 的滚轮分派原正反对照仍过。 | 去掉/替换§28/§38 对旧 stdout、schema 分组和旧代码形状的要求，复用现有字符串检查与真正的 settings/groups 行为；保留完整 CLI schema 检查。独立验两种语言的真实可见键与用途标签：从两表删一个实际显示的用途/入口标签必须点名失败，恢复通过；仅新增未展示的 CLI 键/组不得增加 UI 项或需要标签，滚轮仍不穿到背后的页面。 |
| **§38-b / §38-d：旧操作目标与检查自己的旧措辞。** 写入是否正确须分开验。 | `138190141503.log:3994–4028` 的选择场景 `43/29`，另一片相同。s4完整 `panel-p21-choices.log:54–74` 第一条等的是 `30 · 当前`；当前 `layout.ts:1924–1941` 会显示 `30 秒 · 当前`。旧目标未匹配却继续发键，随后进入数值输入（日志118–120）、迟到的危险确认出现在本打算保存模型规则的时候（285），并且无 `--allow-danger` 写调用、规则配置/审计没取得目标证据（124、289–303、471、547）。第一次等待不成立，后续失位不能当作二十多次独立产品失败，也不能把危险确认后一写或模型规则保存/冲突判正常。另一条 §38-d 只在源文件找原句 `按键→帧之间零读取`；真实布尔选择器从按键到显示零子进程、命令输入打开 `argv_reads=0` 都实际过（子日志4、53），说明缺句并非这两条行为丢失。`38-a` 完整 CLI 读候选值 38/0 不代替 UI 写。 | 就地修当前值及目标行选取，独立操作前先确认所在页，关键目标未到则停止该序列，不延长等待、不删危险确认。复验验收最长时间保留初值、第一次确认不写，第二次带 `--allow-danger`/同指纹/actor 落一笔；另从干净设置入口实际验规则字段、完整值一次保存、取消/冲突不覆盖。同步删过时的源码字句检查，保留原 argv 行为；若新入口下仍未到达或误写，按产品问题继续查。 |
| **§38-f：读屏脚本还认旧帧，不等于缺行或缩放失效。** 与 §38-b 走错交互序列不同。 | `138190141503.log:4048–4058`、s4 `panel-p21-view.log:23,39,58,81–115`：10/1/3 三项一律 `-3`；`panel-p21.sh:1429–1467` 任一卡片标记/页脚识别失败即输出四个 `-1`，前三个相加才是 `-3`。它要求页脚含 `写信/compose`，而留存的四个高度尾帧有设置专用 `Esc 返回 · ↑/↓ 行 · Enter 编辑 · / 筛选` 和 `↓31/43/46/51`，不是旧全局键栏。单击/二击进入项目命令、标签过滤及滚轮不穿透已由该子日志的其他操作支持；四个高度没有拿到检查认可的整帧，报告不把行数、填高或焦点全判正常。制品只有 smoke 子日志，独立 `default-count.txt`、`height45.txt` 等样本未保留。 | 修同一个读屏函数，按当前完整设置卡片和专用键栏稳定取帧，按当前操作行算可见加隐藏，不让 `-1` 参与行数相加。用原 settings/groups/wheel 的默认、过滤和命令页分别核 10/1/3，原 45/33/30/25 高度逐帧对总数68、完整边框、焦点与填高；保留窄屏返回和滚轮不穿透，不加截图批次。 |
| **§67：已证实 CI 中 `doctor` 报错状态；夹具绕过正式登记，具体进程识别失败仍需定点区分。** | `138190141568.log:3755–3772` 仅显示尾部；s1原 `p442-remind-tool-real.log` 确认失败是 `pm`（369，期望 `ready extension reported registered/active`）和 `noentry`（745，期望 `unknown evidence:ENOENT`），**不是** doctor 汇总的两项一般失败。两份原 `doctor-*.txt` 都报 `窗口 … 里不是 PM（sh）`、`not-running … (unknown:sh)`。对应 Pi 各已真实 `session_start`、有应答，启动 PID 回执和 `session-start` 一致；`pm`有11次 loopback 请求且到达 doctor 前已验注册、成功调用、到期观察、续期和无 key 的不同 ID，`noentry` 实际没有注册工具。`doctor: 2 项失败` 另指私有 HOME 无 magic-context、私有项目无 `openspec/`；其退出码不是失败断言，同样出现于配置不符、主动注入加载错误而通过的场景。 | 先用 CI 的 npm 安装形态、同一 Pi 版本及隔离 tmux，只验这两例；同刻留 pane PID、进程父子/argv/cwd、正式 `pm.pid` 与 spawn 回执、扩展证据、doctor 输出。先让夹具走正式启动登记路径或同一身份验证，不伪造 PID；随后独立证明活且已注册为 `ready`、活但无入口为 `unknown`、真正停止为 `not-running`，错误/外来窗口仍不会获 ready。若正式启动或受支持的人工启动形态也误报，再修产品的身份识别，保留归属核对；不能把 `sh` 当活或改期望为 `not-running`。 |

### §67 产品影响的证据边界

- `remind-tool-real.mjs:145–183` 使用真实启动命令文本，但外套 `launch.sh` 用 `tmux respawn-pane` 拉起；`publishLaunch` 只写 `pm-launch.env`，`no-entry` 连这一步也略过。制品中两例各有 `pm.pid.spawn`、都没有正式 `pm.pid`。正常 `team_pm_start` 则在 `common.sh:3822–3852` 用进程身份或 spawn 回执验证后把 PID 记入 `pm.pid`。`team_pm_state` 不把孤立的 `.spawn` 当作已登记：没有正式 `pm.pid` 时须在 pane 自身/直接子进程中匹配启动程序（`common.sh:2615–2639,2727–2785`）。`doctor` 先读取该状态；除能验证的显式错误外，一旦非 `running`，提醒诊断会报 `not-running`（`cmd-project.sh:793–834`）。这是已证实的误报路线。制品没有当时的完整进程树和 argv，不能裁定是外层 shell 多了一层、npm 启动名与 argv 不同，还是两者都有；不能据此定为 Pi 1.6.0 回归、P486 产品回归或生产必现。
- 若正式支持的启动也被同一判断漏掉，除了误导使用者，doctor 会提示 `team up` 可能替换窗口；本次未启动或替换任何现实进程。§67 八个通过包括 65537 字节原文、三种身份拒绝、换到错误窗口撤下工具、生成配置不符/删错误证据反证和显式加载错误。相邻 §68 真实无提示恢复、§69 事件顺序与死亡/重放均过（片1:3783、3790–3792），不等于为 §67 的活进程识别作证。

## 两次发布及旧证据能证明什么

| 项目 | 0.4.7：`fdd3247a`、run `43810623157` | 0.4.8：`c34e1468`、run `45318204605` |
|---|---|---|
| P440 | s3/4各三条，真实记录把 `/var/tmp` 错改为 `/var<home>`，兄弟路径也错；见 V164 和旧原日志 s3:1051–1066、s4:1538–1553。 | `7245bfef` P459 在标签祖先，至本版路径显示函数未改；V165 独立验的是显示矩阵与路径边界，不曾跑 CI 布局下整条 review 绿/红/还原。V174 本机整条通过（原日志1403、1419），不覆盖本次 `HOME=/tmp` 中的误报。旧兄弟错误本次未出现。 |
| Pulse 设置 | 原 s2/4 §38-b `110/0`、§38-f `97/0`；§28-a2 覆盖旧全表123键、§38-e旧12组。V174 本机前置版本 `532c8b47` 的 §28 和 §38-b 同样通过，但 §38-f 另有旧颜色/徽章失败（V174、P472），不是本次 `-3` 或四次缺完整帧。 | `967da984` P471 改设置页分组/文案/操作与子测试，`smoke.sh` 的 §28/§38 旧接入未同步。V177 的组合证据（原批 `177/16`、补验 `55/2` 保留，另有正常 policy `29/0`、真帧以及 merged 导航 `5/0`）已观察危险值 `1800→30` 的 `--allow-danger`、规则实际写及长表余量/轮动；不是当前 CI 原序列重新通过。`967da984..v0.4.8` 未改设置测试，两处 Panel 变更是队列阻碍显示源码及对应 bundle，不是设置页变化。 |
| 提醒 | 公开 s1 使用 Pi 1.5.2；§67 实际跳过找 Pi，§69 未取得初始应答。V164 单例重现旧 `$HOME/.bun/bin/pi` 失败，V165 证实按 PATH 发现和立即报启动错误；未覆盖这两个 doctor 断言的 CI 执行。V174 本机、P486 前的 §67 十例确实过（原日志5837）。 | CI 实录 npm Pi 1.6.0，实际用 `/usr/local/bin/pi`，两个旧断言首次在这两次公开运行中得到此失败，不是旧启动失败重现。`191e8097` P486 更换隔离运行/回收及 shell、Node 交接；两条 doctor 期望、外套启动和 PM 存活识别均非本版新逻辑。V185只实跑指定的大正文/回收等样本；V190 在标签上实跑 `adversarial-event-after` `1/0`，没有运行 `pm/noentry`。 |

0.4.7 另有 §39 安装样本差异；本版 s4 原日志3740明确 `install-shape.sh 全绿（204 条断言，含翻转绿/红两侧）`，不列为重复失败。覆盖作业 `138211083209.log:185–197`：`GATES_RESULT: failure`；四清单 `40/35/33/33` 各与重算逐字一致，去重并集141等于基线，`ok 6 bad 1`，唯一失败是矩阵不为 success。四片结果 `1941/3, 2455/9, 1285/2, 1992/11` 是外层计数，重复依赖段、嵌套操作失败和覆盖作业都不再作为独立缺陷相加。

## 交付物与实做收据

- 唯一仓内变更：`docs/team/reports/V191-verify.md`。锚点 `openspec/specs/verification/spec.md` 的“CI runs the two gates separately and performance does not block”已查；这是 `opsx-explore` 只读诊断，不是 OpenSpec 变更实现/验收。设置修复边界以同文件1354–1379的保留行为和 `openspec/specs/panel/spec.md:2343–2416` 为准。
- `git rev-parse 'refs/tags/v0.4.8^{}' 'refs/tags/v0.4.7^{}'` 返回 `c34e1468ea2ab76bdff9cd2bbef0db650604d151`、`fdd3247a451eeeec37985af73d2267b74790058b`；用 `git show <tag>:<path>`、`git diff` 查冻结对象。原日志及 JSON 从私有 `.pi/team/state/release-0.4.8/` 和 `release-0.4.7/` 读取；未改动。V174 行号取保留的完整 `V174-verify.log`，不是事后重造。
- 只在日志不足时用 `gh api repos/Track07-cda/teamsmith/actions/artifacts/<id>/zip` 只读下载 s1/s4；s4 首次未完成，重试后两份 `sha256` 和字节数均与索引一致：`14887455085` 29,911,398 字节 `f32d1cc9f98b20be1c60bb44c3b80ebb985306d9eb484cb643ab7880cd17a548`；`14887459495` 19,709,258 字节 `1baa0c3dc477e44f96597551837b81a8512d0539294329d326fb278160f53807`。用 Python `zipfile`/`tarfile` 只读对应文件；没有从其它片下载相同证据。两份原 ZIP 留 `/var/tmp/v191-scenes.BHOXPz4i/{s1,s4}.zip` 供 PM 核收，原件不纳入 Git。
- 未重跑 CI、任何产品检查批次、Pi/模型、安装或复现场景；未更改产品、测试、标签、包、共享配置、现实会话或远端。不是缺陷修复，未制造事后通过；原 P440 抑制净化时失败、当前显示标签被删除时失败、提醒配置错误证据删除后失败均按原件报告。

### 报告检查

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify scope=published files=3018 hits=0 names=ok user=resolved
ledger-ban rc=0
```

**交 PM：** §10 和过时设置检查可直接分派给测试维护者，不动发布物；§38 两个实际写入序列和 §67 两例按表独立复验后再判是否需要产品修复。保留覆盖作业现有判定，四片没有通过时不得改报成功。
