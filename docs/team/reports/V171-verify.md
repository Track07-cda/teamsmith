# V171 · 剪贴板准备复用独立验证

agent: verify · status: STAGE-A-PASS（合并后复核未执行） · time: 2026-11-16T13:06:39Z
branch: `task/V171-clipboard-session-reuse-verify` · PR/MR: -（本地）

## 结论

**阶段 A 的实际行为通过。** 固定候选 `790bfb35c9aadfdd8bc9389eb8c7fb5d138d40a6`（实现 `60907db2`）只运行了一次完整 clipboard：26 成功、0 失败、child rc=0，没有等待耗尽。真实 C-v 改成 no-op 后，原具名图片数量/内容断言失败，child rc=1；原 `p38_verdict` 收到该真实 log/rc 后记父失败。恢复原字节仅验首例为 6/0、rc=0；真实目标种子等待成功后注入失败标志，实际消费者记 bad、返回 1，未发送下一次 C-v。

**候选原生清单仍为 2/5，不作归档就绪结论。** 2.1/2.2 的本轮行为证据已具备；2.3 的 merged 输入尚未由 PM 提供，按 brief 暂不改勾选。以下 3 个 CRITICAL 是清单/阶段未收口，不是已发现的实现缺陷。阶段 A 没有未解决的实现缺陷；阶段 B 完成之前不能将本报告当作最终合并验证或归档许可。

## Deliverables 与来源

| Path | What |
|---|---|
| `docs/team/reports/V171-verify.md` | 唯一仓库写入；独立行为、短反例、OpenSpec 评估及边界 |
| `/var/tmp/v171-verify.plU7KA/` | 本席位唯一驱动/副本/证据根，原件保留，不强制加入 git |
| `/var/tmp/p466-review-790bfb35` | PM 准备的公共 git 根独立候选，起止 HEAD 相同，普通/ignored 状态均为空，始终只读 |
| `docs/team/reviews/P466.md`、`P466-verify.log` | 仅通过获授 `team review` 写入中央记录，实际执行者 verify、候选 SHA 绑定正确 |

使用 change `clipboard-test-session-reuse`；按主检出的原生 `openspec-verify-change` skill 执行。OpenSpec **1.16.0**，候选实际 `status.json`/`apply.json` 为 `spec-driven`、nearest root 为候选，读取 contextFiles 中 proposal/specs/design/tasks 全四项。规划依据为候选 proposal review 的 ACCEPTED、D252；未以 planning 的 isComplete 或自己分支的旧 0/5 代替执行评估。

## OpenSpec assessment

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | 原生 **2/5**；1/1 requirement 已映射；2.1/2.2 本轮行为已覆盖，2.3 未完成 | `apply.json`、原 tasks 7/8/12–14 行；不提前改勾选 |
| Correctness | 1/1 requirement 的阶段 A 行为成立；6 个场景逐项见下表，最后一项 merged 部分 **Not verified** | 正常 26/0、实际坏腿 rc1、恢复 6/0、父 bad1、种子消费者 rc1/无后续 C-v |
| Coherence | design §1–5 的本轮步骤一致；Code Pattern Consistency 无实质偏差；merged 同一性 **Not verified** | 三处函数内图像观察、四次真实编辑、未改共享引擎/产品；`source.diff`、101 文件执行/规划 manifest |

### 需求与 6 场景映射

需求：**Clipboard condition changes reuse the panel without replacing live evidence**。实现集中在 `panel-b2.sh:622–900`，测试入口及其它 scenario 不变。

| 场景 | 实证与覆盖边界 |
|---|---|
| Changed tool input is observed by the same live panel | 正常快照 03/07：同 `%2 / pid=2359134`；不同实际 PNG，分别 PNGDATA8/XCLIPDATA；前例无 xclip，后例 wl→xclip；各有自己 a<path>d 与首例后续 Z |
| A reused panel receives its next seed through real keys | 原 trace 4 组 C-e/C-u/type_text，目标 ad/ad/half a thought/half a thought；4 次实际 wait_draft 成功。恢复短例中的真实目标等待后 beforeflag=0、正文 ad，随即注入 1，由原条件 bad+return1；消费者 trace 无下一次 C-v |
| All original clipboard outcomes still execute | 唯一完整入口八子例全部执行，26/0；三处图像等待均 rounds=1 settled=1；长路径可见帧确有折行，正常无等待错误；四个面板实际启动均有首帧通过记录 |
| Idle observation and recovery coverage do not become setup savings | 三段原 sleep 5 实际保留：挂起、写信关/开；挂起/无工具仍可 Z、Esc 保留草稿。其它场景（含 draft/settle）前后字节相同，本轮未运行其它场景 |
| A broken C-v and its failed child cannot look successful | 自有普通副本真实 App C-v 分支去掉 pasteClipboard 并构建；坏腿原数量/内容断言红、真实 child rc1；原父函数消费该 log/rc 得 bad1/pass0；原 App/正常 bundle 恢复字节一致后仅首例 6/0 |
| Evidence distinguishes preparation reduction from runtime improvement | 实际调用账与等待记录如下，不声称净提速；实现者未跑行为，本席位一次完整入口加短反例；**merged 字节/短检尚未执行**，待 PM 固定输入 |

### 5 项任务

| 任务 | 候选勾选 | 实际证据 |
|---|---|---|
| 1.1 | x | 独立静态核三处观察、同次可见帧理由、图像父 rc、模式普通输入与切换顺序；正常三处实测通过 |
| 1.2 | x | 31/31 原具名断言/分支源码行保留；四组同 shell flag 紧邻读取，原共享库/产品/bundle 相同；实际启动 4 次 |
| 2.1 | 未勾 | 本轮唯一完整八子例 26/0、默认长根、实际输入/文件/草稿/调用记录均保留；按 brief 等 B 后统一勾选 |
| 2.2 | 未勾 | 实际 no-op/父消费/恢复/准备失败消费全部覆盖；按 brief 等 B 后统一勾选 |
| 2.3 | 未勾 | 本 change strict 已通过；merged SHA、同一性与必要短检未执行。旧 spec-refs/选择器平台未变，按 brief 复用接受回执而未重跑 |

## CRITICAL（流程未收口，非实现缺陷）

1. C1：原生任务 2.1 仍未勾选。行为证据为 `normal.log`/`normal.rc`/`snapshots/`；完成 B 后按授权精确同步原 tasks，仅改勾选。
2. C2：原生任务 2.2 仍未勾选。行为证据为 `bad.log`/`bad.rc`、`p38-consumption.log`、`restored.log`/`restored.rc`、`seed-consumer.log`；完成 B 后按授权精确同步原 tasks，仅改勾选。
3. C3：原生任务 2.3 未完成，未收到固定 merged 输入。PM 接受 A 并准备干净 merged 检出后，由同一 verifier 读取 merged 实际源、比较已验依赖及必要短检；相同字节不再起面板/构建/完整 clipboard。

## WARNING

None in executed stage-A implementation checks。未验 merged 已列 C3，不重复计为 WARNING。

## SUGGESTION

None。

## 正常一次完整流程：实际清单

相同子命令环境下，用原 `team_tmp_root_source` 与 `team_tmp_root` **分别**只读解析：

```text
source=default
root=/var/tmp/teamsmith-pm_skills-deb708fe
ns=pm_skills-deb708fe
```

仅对子命令取消 TMPDIR/TEAM_TMP_ROOT，父 runner 的 TMPDIR 仍为本席位 `/var/tmp/v171-verify.plU7KA/parent-tmp`。没有改 TEAM_PROJECT、用短命 clone 缩路径或默退 /tmp。完整正常使用候选原 bundle，SHA-256 `55f51002e4cdd055b5f542bf09face626a2bff32aa8312a4454e1dd4c0fa52b4`。

实际保留根：`/var/tmp/teamsmith-pm_skills-deb708fe/teamsmith-panel-b2-pm_skills-deb708fe.WHZ5Wo`。

| 八子例 | 原断言实际通过数 | 关键原件 |
|---|---:|---|
| Wayland 图片 | 6 | snapshots 03/05：PNGDATA8、a<本例路径>d / a<本例路径>Zd、wl 两条无 xclip |
| X11 回退 | 3 | snapshot 07：XCLIPDATA、自己的 a<path>d、wl 第 1 行/xclip 第 2 行 |
| 文本回退 | 3 | snapshot 11：afrom the clipboardd、0 文件、无 xclip |
| 无数据 | 4 | snapshots 15/17：half a thought → half a thoughtZ、0 文件、帧正常 |
| 工具挂起 | 4 | snapshot 19、normal.log/trace：原 5s，0 文件、可输入 Z、Esc 保留草稿 |
| 待命理由 | 2 | snapshot 23：PNGDATA8、同次可见理由 why<本例路径>；原 reason.joined 完整，消息草稿仍 half a thought |
| 另一 CLI | 1 | snapshot 27：独立 `%4 / pid=2481877`、team.log 空、原 no-temp-root/草稿 ad 语义；不是虚构的图片落地能力 |
| 未按键观察 | 1 | 原两段 sleep 5、调用计数 0\|0，无 C-v；最后独立冷启动有首帧成功记录 |

另有原 headless sibling 的构建/9-of-9 模型结果 2 个成功，总计 **26**；坏腿/恢复没有重跑该 sibling。源码的 **31/31** 包括条件与成功/失败分支，不冒充运行 31 项。

`normal-events.json`/`normal.xtrace` 核实：7 次真实 C-v、末例 0 次；实际 3 次 start_panel 加 1 次另一 CLI 直接 new-window，共 4 次；前五例同 `%2 / pid=2359134`，理由另 `%3 / pid=2441779`。项目/server 准备和假 PM 各 1 次；reset_clip 8 次，clip_modes 8×2=16 次模式文件写；4 组 C-e/C-u/type_text 共 12 次新增发送。4 个实际完整种子等待及三段原 sleep 5 保留。**8→4 是准备调用账，不是测得的总耗时收益；完整耗时比较/净提速未测。**

为在 reset 前保存原件，正常入口仅加私有 `BASH_ENV=observe.sh` 读侧快照/xtrace 和 `PTY_TRACE=1`，不修改候选源、等待参数、按键、节奏或断言。两行 `can't find window: panel` 来自首例面板尚未创建时的读侧快照，非原引擎等待错误；原 normal.log 所有等待均 settled=1。原 trace 并发写有 UTF-8 字节交错，派生索引只对解码使用 replacement，原二进制 trace 未重写。

## Verification evidence（真实执行）

后台 `V171-stage-a` 后由 `team_bg_wait` 收取；之后仅短检查 `V171-short-legs`，同样收取。正式中央记录最终 PASS，执行者 verify，SHA `790bfb35c`。

```text
$ TEAM_GATES='bash /var/tmp/v171-verify.plU7KA/batch-a.sh' ... team review P466 --dir /var/tmp/p466-review-790bfb35 --branch 790bfb35
# runner 内：
$ bash -n skills/teamsmith/tests/panel-b2.sh
rc=0
$ openspec validate clipboard-test-session-reuse --type change --strict --no-interactive
Change 'clipboard-test-session-reuse' is valid
rc=0
$ env -u TMPDIR -u TEAM_TMP_ROOT BASH_ENV=<本根>/observe.sh PTY_TRACE=1 TEAM_B2_KEEP=1 bash skills/teamsmith/tests/panel-b2.sh clipboard
== 结果 == ✓ 26 ✗ 0
panel-b2 全绿
normal actual rc=0

$ TEAM_GATES='bash /var/tmp/v171-verify.plU7KA/continue-a.sh' ... team review P466 --dir /var/tmp/p466-review-790bfb35 --branch 790bfb35
REUSE actual normal.log: 26/0, child rc0; no normal entry is called here
bad actual child rc=1
restored actual first-case child rc=0
candidate read-only: all manifest bytes unchanged; actual seed consumer returns1, no later C-v
STAGE A scoped batch PASS; merged follow-up NOT RUN; checklist remains 2/5
# team review rc=0；中央记录 ran=72s 仅本次续短检查，不是完整 clipboard 耗时。

$ python3 /var/tmp/v171-verify.plU7KA/finalize-a.py
normal actual child rc=0
bad actual child rc=1
restored actual child rc=0
dependency manifest 101 files; HEAD bytes verified; read-only checkout clean/ignored=0
bad intended red / original p38 consumption / restored / post-wait seed consumption: PASS
```

### Flip evidence

自有 `panel-copy/src/App.tsx` 唯一真实 `key.ctrl && input === 'v'` 分支去掉 `void pasteClipboard()`，保留 return；Bun 1.3.14、原 frozen lockfile 构建成功（45 依赖、561 modules），坏 bundle SHA-256 `a6041795d313db7bd63e026c62f3224ca53c4b7db077c55eef4ef0fd3795431f`。没有新增产品/测试入口；`short-functions.sh` 从候选摘出原工具准备/首例，去掉未改的模型 sibling 及其它七例。

```text
# 实际坏首例（非搭建失败）：
✗ B4 图片落成临时文件路径：未等到 PNGDATA8 和 a<path>d
✗ B4 TMPDIR 里恰好一个 teamsmith-paste-*.png（期望 [1]，实际 [0]）
✗ B4 文件内容就是剪贴板的 8 字节（期望 [PNGDATA8]，实际 []）
== 结果 == ✓ 3 ✗ 4
bad.rc=1
# 有原引擎耗尽，但判定依赖原数量/内容具名红及实际 rc，不只靠超时。

# 将上述实际 bad.log/bad.rc 交候选原 smoke 的 p38_verdict：
✗ 38-h panel-b2.sh 写信面（11 场景） 有失败
parent bad=1 pass=0
# “11 场景”是原函数调用标签，不是本次跑了 11 场景。

# App.tsx 与正常 bundle 原字节恢复（两次 cmp 成功），只恢复首例：
== 结果 == ✓ 6 ✗ 0
restored.rc=0

# 同一恢复检查进程的 subshell：真实 wait_draft 完成后、实际 if 消费之前注入：
· pty-wait: wait B4 X11 准备：完整草稿 ad rounds=1 settled=1
INJECT after real wait: beforeflag=0 actualdraft=[ad]
✗ B4 X11 准备：未等到完整草稿 ad
seed consumer rc=1 bad=1 pass=0
# 实际 consumer trace 有 PTY_WAIT_FAILED=1 / return 1，无后续 keys C-v。
```

原 `smoke.sh:20969–20971` 仍立即取 child 的 `$?` 并交给原 `p38_verdict`（20788 行）；本次只证明结果消费，**没有运行完整 smoke 调度或 §38**。四块种子消费者源码均为同 shell wait 后紧邻读 flag、bad 后 return1，只实际注入其中一块，不重复四次；不冒称真实等待引擎故障。

### 首次私有准备错误与正式记录修正

首次完整正常已运行后，私有短驱动的原 init 因 `TEAM_B2_PANEL` 单 skill 副本没有三个声明技能的 sibling 布局而 rc3，尚未发送短例 C-v，**不计 intended red**。原件为 `bad-setup.{log,rc,xtrace}`。仅在自有临时根补普通 sibling 副本及 teamsmith 链接后续跑短例；不改候选/产品、不重跑正常入口。

首次正式 review 还因父 TMPDIR 当时未创建、queue marker 未建立，把已经实际跑过的 runner 误记为 queuecap/未跑；原记录/输出保存 `review-initial.{md,log}`，不当“完整入口未跑”的依据。后续先建私有父目录再以 `continue-a.sh` 生成正式实际 PASS。此项是验证准备限制，不扩本 change 修 review 产品；中央最终记录 `review-candidate.{md,log}` 与完整正常原件共同构成 A 证据。

### Ledger / diff checks

最终报告暂存后，在本席位工作树/任务分支执行下列命令；回执见本报告交付提交前的本地证据 `final-ledger-a.log`：

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify scope=published files=2807 hits=0 names=ok user=resolved
ledger-ban rc=0
$ git diff --check
diff-check rc=0
$ git diff --cached --check
cached-diff-check rc=0
```

## Final assessment

- Counts: **CRITICAL 3（全为原生清单/merged 阶段未收口）· WARNING 0 · SUGGESTION 0**；本轮未发现实现缺陷。
- Readiness: **阶段 A PASS，整体未归档就绪**。本报告不替代尚未运行的 B，不改候选 tasks 2/5。
- Reuse：未变的 spec-refs/选择器/已接受规划回执按 brief 复用；101 文件执行/规划 manifest 已与候选 HEAD 字节核对，供 B 比较；没有以旧两条件样本代替本次实施验证。
- Not verified：固定 merged 的实际源/同一性/必要短检（未提供输入），任务最终勾选与最终原生评估（B 后）；其它 b2 场景/38/设置/帮助/配置整组、smoke/FAST/全量/meta/61b/夜间/安装/性能/真实模型均按范围未执行，不能称通过。

## Decisions and deviations / Next step

无产品、规划或候选写入；仅本报告与获授工具中央记录。没有改变真实 reminder/standby/PM 状态，没有 merge/push/archive/tag/npm、没有真实模型调用。首次私有搭建问题及续跑已如实保留，不自动重复完整场景。

PM 接受 A 后提供固定干净 merged 检出及 SHA；同一 SID/model/分支续 B。相关字节相同则复用本次正常/坏/恢复原件，只做必要静态/结果消费短检；相关字节变化先交 PM 收敛补验范围。原件未收存前不删除。
