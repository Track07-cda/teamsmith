# Design

## Context

动机见 proposal.md。当前 `scenario_clipboard` 已只有一个项目、一个私有 server 和一个假 PM；八次面板启动中，第二至第五次仅把 `P20_WL_MODE/P20_X_MODE` 和磁盘种子换掉，重起后重新加载。已有 `keys/type_text` 统一保留 200000 μs 最小间隔，`wait_frame/wait_draft` 使用原 pty 等待库。

先核的两条件原件见 `docs/team/reports/P464-dev-bob.md`：旧方法 2 次启动、候选 1 次；同一 `%2/pid=2466452` 经 C-e/C-u/ad 后分别得到 PNGDATA8/XCLIPDATA。候选新增 3 次发送，第二准备本次参考 3.557s；不是无成本复用。两个屏幕 token 等待被路径换行误伤，样本不能称全绿或整体更快；只读原画面/草稿证明交互，并未修脚本补跑。独立审阅已由源码推导出正常默认磁盘路径也会跨同一 token，所以不能只移除样本嵌套、把原等待留到下轮再看。先按 §4 收敛三处局部观察替换，再做准备复用；同一次 apply 和唯一一次完整 clipboard 覆盖两者。

既有 verification 的异步状态等待、等待耗尽失败、全部原断言保留和性能只作参考仍适用；新增的唯一 requirement 约束这次准备退休的边界，不修改那些通则。产品的 `panel#` 剪贴板行为保持原样。

## Goals / Non-Goals

**Goals:**

- 以一个函数内的普通假工具输入替换四次重启；下一例实际从正确草稿开始，同一次 C-v 仍走产品工具进程。
- 只退休准备调用，不退休行为/断言；不增加永久验证段或通用运行平台。

**Non-Goals:**

- 不改变产品、bundle、剪贴板支持/MIME/超时、配置、缓存或用户接口。
- 不改等待/隔离库、按键间隔、其它设置场景、语言/高度/平台、CI 或选段表；不把完整 b2/§38 当此次交付必跑项。
- 不修本次临时驱动的通用框架，不把它提交进 tests 或移植成新 runner；其中两条清空/种子调试断言也不新增为长期计数。

## Decisions

### 1. 模式是本次假工具的普通输入，不是活面板环境更新

继续在现有 `fx/fakebin` 建立两个原假工具；两个模式文件也在同一个 `fx` 内。环境只给假工具输入文件路径，假工具每次实际调用时读取文件值。模式值仍是原 image/text/fail/hang，返回值、日志和真实工具执行顺序不变。`clip_env` 对保留的四个启动均传相同文件路径；每个所需模式在对应启动或探测前按原流程写入。

只在前例真实 C-v 结果和后续交互已完成、Esc 收起后切换输入；原 `reset_clip` 仍清本例图片/调用日志。没有结果缓存或后台服务，不使用 tmux 环境更新冒充已启动面板的进程环境变化。另一选择是改产品读取可热更新配置，因把测试准备推入产品而拒绝；保留全部重启则是本 change 的简单回退，不是失败时静默走的第二条路径。

### 2. 只在四个过渡处真实编辑种子

保留第一次启动前的磁盘 `ad` 种子。四次过渡用原 Esc 和 m/等待打开写信框，按 C-e、C-u，再由 `type_text` 输入本例种子：第二/第三例为 ad，第四/第五例为 half a thought。通过原 `wait_draft` 机制观察**完整目标正文**，再执行原 Left（有的条件）和 C-v；按键发送仍各自经过 `_b2_send`。

这些步骤替换原 `printf > draft.md` 和四次 `start_panel`/首帧准备，不与它们叠加。不要保留“写磁盘再按几个键”的双重种子；活面板内存是后续编辑的依据。一个完整种子观察就可揭穿残留路径/旧文字，不必把样本的空草稿、最终种子两个调试 assertion 全加回正式计数。现有 `wait_draft → wait_state` 会丢掉返回码，因此新准备不能只接 `wait_draft || return`：应在同 shell 普通调用 `wait_draft` 后立即读该次 `PTY_WAIT_FAILED`；非零时在调用方 `bad` 后显式返回失败，不能执行下一例 C-v，也不能先跑另一等待把标志清零。原引擎每次先置 0、真正耗尽才置 1；等待本身不能放到命令替换或子 shell。旧 start_panel 返回本身也不会自动中止 scenario，不能据此声称新传播已验。不加成功 assertion、等待引擎或库补丁。

### 3. 启动退休表与必须保留的真实行为

| 原准备 | 处置 | 仍逐例执行的行为 |
|---|---|---|
| 首次 image/image | 保留冷启动 | 真 C-v、PNGDATA8、Wayland 优先/无 X11、插入点、Z |
| fail/image | 退休重启，真键设 ad | 真 C-v、XCLIPDATA、新文件/草稿、wl→xclip |
| text/image | 退休重启，真键设 ad | 真 C-v、afrom the clipboardd、零图文件、无 X11 |
| fail/fail | 退休重启，真键设 half a thought | 真 C-v、无文件/无变化、仍可 Z |
| hang/fail | 退休重启，真键设 half a thought | 真挂起、原 5s、Z、Esc/草稿保留 |
| 理由模式 image/image | 保留冷启动 | 原理由路径、消息草稿不变 |
| 另一个 team-cli 接口 | 保留直接 new-window | 真 C-v、无 team 动作、原无 temp_root 的 no-op 前提 |
| 未按 C-v | 保留冷启动 | 写信关/开各 5s，无工具调用 |

总数是 8→4 面板启动、8→8 子例，七个主动粘贴子例各一次真实 C-v，第八个未按键子例零 C-v；项目/server/PM 仍各一次。主动子例内部更多工具调用仍由产品实际探测决定，不把工具调用数当新固定阈值。原 headless 模型 sibling、所有原行为 assertion、`scenario_draft`/`scenario_settle` 的恢复和其它场景逐字节不动。

### 4. 先替换三处图像观察，复用准备在后

本次候选原画面在行尾为 `teamsmith-past`、下一行为 `e-UUID.pngd`；正常默认路径 `/var/tmp/teamsmith-pm_skills-deb708fe/teamsmith-panel-b2-pm_skills-deb708fe.XXXXXX/clipboard/tmpdir` 同样使 token 跨正文第 116 字符边界。后者由 120 列面板、116 字符正文宽度、六字符随机后缀及原磁盘根解析直接推导，不是新增实跑。原 693/715 的消息模式及 779 的理由模式均依赖连续屏幕 token，后续断言会覆盖等待失败；这是已知缺陷，不能以“保持原等待”或先跑正常完整再看处理。

局部处理只在 `scenario_clipboard` 内，先完成下列替代，再做四次准备复用；不改共享 `pty_cap`、等待库或其它函数的行为：

- 继续使用 `pty_wait_frame` 的既有 caller-supplied `pty_cap` 接口。给三处一个本 scenario 的薄适配：在函数子 shell 内局部绑定该回调，原可见区 capture 原样输出，附上由真实状态决定的 ready 行；复用原 `pasted_file`/`draft` 读取，既有引擎仍负责轮询、两帧稳定和上限。不是另一套捕获/等待框架。
- 第一、第二处只有实际 PNG 文件存在、内容分别为 PNGDATA8/XCLIPDATA，且实际消息草稿恰为 `a<本例文件路径>d` 时才产生 ready。未落图是继续等待，不能先读取空路径、把 ad 误当成功。原文件数量/内容/插入点/工具顺序/后续 Z 具名断言照旧执行，不由 ready 计数替代。
- 第三处同样观察真实 PNG；理由须为 `why<本例文件路径>`，消息草稿仍为 half a thought。只把已有 `reason_text()` 定义移到等待之前，复用它对**同次可见帧的理由框**取文；不新增通用跨行重组、不用消息草稿冒充理由、不把框外或滚屏历史拼入。原理由路径和草稿不变的具名断言保留。
- 局部适配直接返回该次原引擎 rc；调用方非零记 `bad`，并继续执行本例原具名图片/内容/理由断言，因此缺状态不能被后续成功覆盖，no-op 短坏腿也仍能落到 intended red。子 shell 内不累计 PASS/FAIL，父调用方负责失败计数，不假定子 shell 的 PTY_WAIT_FAILED 能带回父 shell。新种子准备则沿用 §2 的同 shell、立即读标志，不能混用两种返回接法。

三处原等待被逐个替换，不新增等待次数或成功断言；原稳定性、轮数/扩展/时限、键节奏、挂起五秒和未按键关/开各五秒均不变。保留默认长路径和 120 列，不靠缩路径、改宽度、删等待换绿。本次不实现、不再跑样本；未来同一轮完整 clipboard 验这一局部处理与准备复用。如果实现时上述现有回调/理由取文接口确实不足，只报告具体缺口交 PM，不私扩库。

### 5. 验证只支付一个正常 clipboard，短坏腿证明调用链

提案首次阶段已做本 change 的结构检查与适用静态登记；本次仅修观察条件/七次 C-v 的规划，改 delta 后只重跑本 change strict 和报告 ledger/diff，未变的引用声明/映射/选择器复用旧回执，不重跑旧静态平台；不执行实现。后续角色与证据如下：

1. **实现者**只在获授权后改一个 scenario，提交静态 source diff、八子例原 assertion inventory、8→4 调用账及 `bash -n`，不跑完整 clipboard/b2/§38。
2. **非作者 verifier**在 PM 准备的独立检出用原入口跑一次：
   ```sh
   env -u TMPDIR -u TEAM_TMP_ROOT TEAM_B2_KEEP=1 bash skills/teamsmith/tests/panel-b2.sh clipboard
   ```
   PM 的独立检出使用本项目公共 git 目录的另一工作树，保持 `team_project_ns` 的真实项目身份，不从作者工作树执行，也不靠另起短命名 clone 或改 TEAM_PROJECT 凑路径。执行前在相同子命令环境用 `common.sh` 的纯解析函数 `team_tmp_root` 只读确认 source=default、根为本项目 `/var/tmp/teamsmith-pm_skills-deb708fe`（/var/tmp 可写），并在日志记录实际本轮根；若解析不在 /var/tmp 则不启动整组，交 PM 处理，不默退 /tmp。只对子命令取消 TMPDIR/TEAM_TMP_ROOT，不改机器环境、目录名或路径长度。使用现有私有 tmux，不安装本次误接的外层检查。这**唯一一次**正常完整 clipboard 直接覆盖默认长路径的三处替换与四次准备复用，不先跑短路径再补一轮。各例文件/草稿/工具顺序、七次主动 C-v/一个零 C-v 子例、原 5s 观察、四个实际面板启动及原 assertion 均为验收对象；没有等待错误才称正常通过。普通/暂存 diff-check 和本 change OpenSpec/既有静态登记不需要触发完整面板。
3. **同一 verifier**在自己的磁盘副本，把 `src/App.tsx` 唯一 `key.ctrl && input === 'v'` 分支中 `void pasteClipboard()` 改为直接 return，构建该副本 bundle，利用既有 `TEAM_B2_PANEL`。只摘出原 B4 首例的既有函数/工具准备和真实 m/Left/C-v/文件/草稿断言（没有新的 `--first` 产品或测试入口），记录坏腿是 `B4 TMPDIR 里恰好一个 teamsmith-paste-*.png` 或原文件内容 assertion 红、child rc=1，不以构建失败或等帧超时单独当坏腿通过。
4. 将**这个实际坏腿的 log 和 rc**送给从原 smoke 源码摘出的 `p38_verdict`，观察原 `bad` 计数/具名 `38-h ... 有失败`。同时静态核实未变的 `38-h` 调用仍把 b2 child 的退出码交给该函数。新种子准备的失败接线仅在同一短检查的 subshell 中，在替代的该次等待完成处、实际准备代码消费结果之前设 `PTY_WAIT_FAILED=1`，随即由实际消费者检查，并观察原准备路径记 bad、返回非零且不发送下次 C-v；不能在真实等待前注入再被其开头的置 0 清掉。这是结果消费检查，不冒称真实等待引擎故障或再跑两条件。此记录只证明准备/父结果消费，不声称完整 smoke 调度或 §38 已跑；不执行 b2 的另外十个场景。
5. 恢复副本字节并只做必要首例短恢复检查；不再重复正常完整 clipboard。保留 baseline/candidate/restored 的来源，样本输出不并入父计数凑数。
6. 合并后同一 verifier 比较已验可执行文件字节，在合并 SHA 上做适用静态/必要短检；相同字节不重复完整 clipboard/b2/38。出现相关字节变化先由 PM 收敛修改范围，再定必要补验，不默认追加整套。

以上临时坏腿/接线脚本属于 verifier 自己的具体临时根；本 change 不新增永久 fixture/guard/拒绝项。唯一增加的输入/种子准备替换四次旧执行，不将原启动成功行伪报成执行过。

静态登记使用既有路径，不改映射表或引用声明：

```sh
openspec validate clipboard-test-session-reuse --type change --strict --no-interactive
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --paths openspec/changes/clipboard-test-session-reuse/specs/verification/spec.md
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/tests/panel-b2.sh
```

前一选择应由现有 openspec/changes 模式命中 18c，后一个应仍点到 38（可能含其它原行/前导/needs）；这些是只读选择，不是执行 smoke。spec delta 不引用具体账本，故无新 ledger ref 注册。

## Risks / Trade-offs

- [活草稿残留] → 真键设种子并观察目标全文；随后原插入点/草稿 assertion 仍负责验证，不靠只改磁盘。
- [输入切换串例] → 前例完成后切换并清本例文件/日志；原 XCLIPDATA、文本和无文件结果会揭穿旧输出，不再添独立模式文件存在检查。
- [准备动作抵消重启收益] → 报实际按键/输入/等待账，不承诺秒数；本轮第二准备 6.903/3.557 不是普遍性能结论，总计 16.812/84.018 还含已说明的观察错误。
- [两条件不能代表八子例] → 正常完整 clipboard 留给非作者一次；挂起/理由/只读/未按键及恢复没有被本次样本验过。

## Migration Plan

无需产品、配置或数据迁移。非作者方案审阅及 PM 接受后，再派单授予 `panel-b2.sh` 中上述函数的写权；原路径表无需改变。验证失败则保留原日志并交回原实现者定点修正，不能靠删子例/缩等待过关。回退为撤销该函数的输入文件/真键准备修改，恢复四次原重启；不回退产品或其它场景，也没有外部状态需清理。
