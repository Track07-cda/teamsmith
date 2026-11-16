# V164 · 0.4.7 公开 CI 三类失败独立诊断

**结论：不是三类误报。review 有真实产品显示缺陷；install-shape 是参考树安装方式不一致；§69 的测试启动器把 Pi 路径写死到了不存在的位置。** 三类都不应靠放宽匹配、跳过场景或延长等待解决。原 CI 仍为 FAIL，本次只交诊断，不交修复或发布通过结论。

agent: verify   status: DELIVERED (diagnosis; original CI remains FAIL)   time: 2026-11-16T06:44:01Z
branch: `task/V164-release-ci-diagnosis`   PR/MR: -

## Deliverables 与输入

唯一仓内写入为 `docs/team/reports/V164-verify.md`。被诊断 run=`43810623157`、冻结 SHA=`fdd3247a451eeeec37985af73d2267b74790058b`；PM 准备的 `/var/tmp/rel47-ci-fdd3247a` 在前后均为该 HEAD，`git status --short` 无输出。没有使用当前 main/dev 后续 P457 实现代替这个输入。

主检出通过 `git rev-parse --path-format=absolute --git-common-dir` 定位；只读 `.pi/team/state/release-0.4.7/{ci-result.json,ci-jobs.json,ci-artifacts.json,ci-logs.zip,ci-logfiles/*}`。原日志 ZIP 实读 63 项；三个失败现场实际下载、解包并逐个与 API 公布 SHA-256 比对一致：

| Artifact | ID | ZIP bytes / 成员数 | SHA-256 |
|---|---:|---:|---|
| gate-failure-scene-s1 | 14201825602 | 12998755 / 3 | `6f0946c411dc583ccfcfa14d75b0e5885b0850dcc420375f19a136f56106c8b1` |
| gate-failure-scene-s3 | 14201256281 | 21440080 / 25 | `b1ae81cea9b220491f20c99c8ce7de07f90f819301af27962e41d818b08f4611` |
| gate-failure-scene-s4 | 14201925828 | 22663729 / 5 | `c6e1335e777d1abdfbb70d52734dfd165bdf7c86a0ac789e0ab5d2486a252d7d` |

下载使用现有 gh 认证间接注入只读 API；仅单次请求加 `curl --resolve api.github.com:443:140.82.114.6`。前几次 TLS EOF 与 CI 本身的失败无关；未改 DNS/代理、未打印凭据或带签名下载地址。后台下载与唯一较慢场景日志在主根 `.pi/team/state/bg/v164-{ci-scenes,ci-scenes-retry,ci-scenes-rest,raw-and-one-case}.log`，均已收割；前三个作业因下载失败退出 1，最后一个包含成功下载和场景的真实失败 rc=1。

## C1 · 已证产品缺陷：把路径中间的 `/tmp` 当成 HOME

### 原始记录与根因

s3/s4 的 `teamsmith-smoke-*.tgz` 中，`p440-review-green.log`、`p440-review-restore-green.log` 均为 `independent checkout display mismatch`；`p440-review-sibling.log` 和 `p440-review-restored.log` 则分别显示真实 checkout 原路径和 review PASS。留存的 `repo/docs/team/reviews/T1.1.md` 实际含：

```text
s3: - 独立 checkout：`/var<home>/teamsmith-ci-tmp/s3/teamsmith-smoke-work-0c9a453f.6NJJdn/review-checkout`…
s4: - 独立 checkout：`/var<home>/teamsmith-ci-tmp/s4/teamsmith-smoke-work-0c9a453f.O3ZinC/review-checkout`…
s4: - 门禁锁：`/var<home>/teamsmith-ci-tmp/s4/teamsmith-smoke.lock`…
```

这些 T1.1 留存文件在后续 smoke 用例中又被覆盖过（s3 时间 05:32:50Z、s4 时间 05:34:02Z，晚于 P440 还原），不能当成 P440 当刻所有字段的快照；但同一错误显示仍在文件中，且 P440 专用日志保留了原路径、PASS 和具体断言失败。

冻结 `cmd-review.sh:95–126` 的 `team_review_ledger_display_root` 先做无左边界的全局 `root/` 替换，之后的裸 root 遍历也只判右侧。CI 容器 `HOME=/tmp`、测试临时根 `/var/tmp/teamsmith-ci-tmp/sN`，所以 `/var/tmp` 被改为 `/var<home>`。`/var/tmp/...` **不在** `/tmp` 下；这不是合法的 HOME 显示转换，也不是测试期望过严。

### 本轮原函数最小复现（rc=0，但输出错误）

```bash
bash <<'BASH'
source /var/tmp/rel47-ci-fdd3247a/skills/teamsmith/scripts/lib/cmd-review.sh
export TEAM_MAIN_ROOT=/var/tmp/teamsmith-ci-tmp/s4/teamsmith-smoke-fixture/repo HOME=/tmp
printf '%s\n' \
  '独立 checkout：`/var/tmp/teamsmith-ci-tmp/s4/teamsmith-smoke-fixture/review-wt`' \
  '兄弟：/var/tmp/teamsmith-ci-tmp/s4/teamsmith-smoke-fixture/repo-ledger/checkout' \
  '主目录：/tmp/checkout' '兄弟组件：/srv/tmp/checkout' | team_review_ledger_display
BASH
```

```text
独立 checkout：`/var<home>/teamsmith-ci-tmp/s4/teamsmith-smoke-fixture/review-wt`
兄弟：/var<home>/teamsmith-ci-tmp/s4/teamsmith-smoke-fixture/repo-ledger/checkout
主目录：<home>/checkout
兄弟组件：/srv<home>/checkout
```

**实际影响：** review 执行路径、门禁退出码及 PASS 判定仍正确；公开 Markdown 的独立检出路径、命令、锁路径会变成不存在的位置，读者无法据此找到原现场。与是否分片无关，同样输入的本地使用也受影响。

**最小修法与责任：** PM 另派拥有 `scripts/lib/cmd-review.sh` 写权的 apply 工人；去掉现有无边界全局替换，在同一替换逻辑中同时判断路径左/右边界，保留真正 main/home 根和子路径的转换、兄弟前缀及 C/UTF-8 标点规则。保留 P440 原精确路径断言，不把预期改成 `/var<home>`。原 s3/s4 `p440-review-red.log` 均为 `absolute main root remains`，故意恢复未净化写盘的行为仍被抓到；修复后仍须保留该红侧以及同副本还原绿，不删除或条件跳过。

## W1 · 已证测试参考偏差：默认安装与 `--no-skills` 比整块

冻结 `install-shape.sh:852–876`：`init_cfg_fixture` 首次用 `--no-skills` 写入非默认 session/名册/docs/PM 窗口/门禁；`chk_init_render_from_config` 随后对被测树执行裸 `init`（默认安装），参考树却只调用带 `--no-skills` 的 `init_cfg_fixture`。两条失败在 1073 与 1598 行调用同一检查函数，不是两个产品错误。

P456 的 `cmd-project.sh:259–268,416–443` 已使 AGENTS 使用与 PROTOCOL 相同的三形状判断：普通项目为 git common-dir 命令，源仓为 `skills/teamsmith`，不安装技能为 `<skill-dir>`。原 s2 日志 2203–2207 行包含三形状通过以及恢复绝对 SKILL_DIR 的红/还原绿。这里不能为了旧比较而把三形状重新生成成同一个路径。

**原 s4 `install-shape.log` 为 201/2，两个失败均是实际 10290 bytes、期望 9438 bytes。** `diff expected actual` 中 `<` 是参考树的 `<skill-dir>`，`>` 才是实际树的 git common-dir 命令；这与 brief 最初的“实际/期望”简述相反，以原始 diff 为准。

### 本轮只跑共享检查函数，不跑完整 install/flip

一次性 Python 进程从冻结 `install-shape.sh` 原样提取 `git_new/run_tree/file_hash/init_cfg_fixture/chk_init_render_from_config` 五个函数，在独立私有 HOME、禁用用户 Git 配置的 `/var/tmp/v164-init-assertions-ra__c46r` 中交给 Bash 执行。实际执行部分为：

```bash
TREE=/var/tmp/rel47-ci-fdd3247a
p="$ROOT/actual"; git_new "$p"
init_cfg_fixture "$TREE" "$p"
chk_init_render_from_config "$TREE" "$p"
# 原函数已创建 $p.expected，仍为 --no-skills 参考形状
expected="$p.expected"
run_tree "$TREE" "$expected" init --session cfg-session --agents "alice bob carol" \
  --pm-window cfg-pm --docs docs/crew --vcs local --gates "make check" \
  --task-models 'routine=deepseek/deepseek-flash analysis=xai/grok-4.6 verify=kimi-coding/k3-256k' \
  --pm-model 'deepseek/deepseek-flash'
cmp -s "$expected/AGENTS.md" "$p/AGENTS.md"
```

```text
original-shared-assertion rc=1
裸 init 的受管块与同参数的显式渲染不同（实际 10290 字节 / 期望 9438 字节）…
actual-installed=yes expected-installed=no
same-shape-explicit-init rc=0
same-shape-exact-AGENTS-cmp rc=0
runner_rc=0
```

runner rc=0 只表示诊断脚本完成；**原检查确实 rc=1，不算通过。** 把参考树改为同形显式安装之后，AGENTS 逐字节相等，未修改任何产品或测试源码。

**实际影响：** 本轮没有发现裸 init 不继承配置或生成错误路径；受影响的是两条测试比较。**最小修法：** 由 tests owner `agent:dev` 把共享检查函数的显式参考初始化改成与裸 init 相同的默认安装方式，保留非默认参数、config 哈希不变、整块 cmp、各字段断言；不换成忽略路径或部分匹配。保留第⑮条故意撤掉“既有配置取现值”的变异，但要在同形正常基线绿后确认它因 session/名册等真正错误而红；当前原日志的第⑮条红不能单独作有效反证，因为正常基线已因安装形状不同而红。

## W2 · 已证测试启动路径错误；原 CI 的首次进程退出原件缺失

### s1 原件核齐的事实

不是只读外层尾部：已完整读取 s1 smoke tgz 的 `p444-real.log`（3452 bytes），七条首次报错分别是 `batch / event-first / event-after / G2-bound / death-event / before-call / after-call initial response` watchdog；末行 `passed=0 failed=7`，外层 §69 为一个 FAIL、659s。它们证明七场景都未走到初始响应条件，**不能单靠这七条错误证明七个 Pi 的原始退出码相同**。

- 原 s1 gate 日志 495 行：`pi 1.5.2 (resolved for this run: 1.5.2)`；workflow 在 PATH 上运行 `pi --version`，镜像用 `npm install -g` 安装 Pi。
- 同一 s1 日志 2893、2904 行：§67 和 §68 均 `SKIP…找不到真实 Pi（可设 P442_PI）`。
- driver `remind-tool-real.mjs:16` 却默认选 `$HOME/.bun/bin/pi`，不是 PATH 上的 Pi；CI `HOME=/tmp`，因此它选 `/tmp/.bun/bin/pi`。workflow 没有设置 `P442_PI`，也没有在这个位置安装 Pi。
- driver 135 行把 `session-start` **或** `done` 存在都当成启动等待结束；进程以 127 退出、没有会话时仍继续等业务条件，90s 后才报 watchdog。

s1 ZIP 只有两个 `teamsmith-pty-wait-selftest-*.tgz` 与一个 smoke tgz，没有日志所指的 `teamsmith-p444-real-evidence-work-0c9a453f.yEtk2Q`。原 63 项 ZIP 内 `gates (shard 1_4)/6_Collect the failure scene.txt` 也只报打包 3 个族；`ci/collect-scene.sh:39` 的四个既有前缀不含此 evidence 家族，而 driver 的运行根又硬编码 `/var/tmp/p442-real-*`、默认自行删除。故原 CI 的 `done`、session、provider request、Pi stderr **不在现有制品里**，不能伪称已读到原 CI 七个 `127`。

### 唯一原始最小场景的本地复现

使用冻结原 driver 已有的单场景选项，模拟 CI 的调用者 HOME；没有改 driver、没有新 selector，没有重跑七例。driver 自己的 HOME、Git 项目、socket 与 loopback provider 均在私有 `/var/tmp` 下，真实团队状态未读写。

```bash
mkdir -p /var/tmp/v164-ci-evidence-tp0bcycw/single-batch
unset P442_PI
HOME=/tmp P442_KEEP=1 \
  P442_EVIDENCE=/var/tmp/v164-ci-evidence-tp0bcycw/single-batch \
  node /var/tmp/rel47-ci-fdd3247a/skills/teamsmith/tests/remind-tool-real.mjs \
  --select=adversarial-batch
```

```text
FAIL real Pi A+B exact event, duplicate/member/foreign-session replay preserve a fresh generation:
Error: watchdog: batch initial response: condition stayed false
kept private fixture root=/var/tmp/p442-real-1ZhF1j
remind-tool-real: passed=0 failed=1 evidence=/var/tmp/v164-ci-evidence-tp0bcycw/single-batch
rc=1
```

随后只读留下的启动/退出文件，得到真正先发生的错误，而不是重复超时：

```text
launch.txt: … exec /tmp/.bun/bin/pi --provider p442 --model controlled …
adversarial-batch/done: 127
session-start exists=False
events.jsonl exists=False
requests.jsonl exists=False
$ bash -c '/tmp/.bun/bin/pi --version'
bash: line 1: /tmp/.bun/bin/pi: No such file or directory
missing-driver-binary-rc=127
```

该复现没有启动成功的 Pi 或模型请求；是“找不到程序”被启动等待错误掩盖，不是“Pi 已运行但模型不回”。CI 的 PATH 版本记录不能证明 driver 的另一路径可用。当前本机 `"$HOME/.bun/bin/pi" --version` 实读也为 **1.5.2**，不能据此把首次错误归因于 Pi 版本变化。

**历史对照：** V161 引用的本机完整一阶原日志中 §69 为 114s、4/0；P444 受控七场景原日志为 `passed=7 failed=0`；V159 的真实启动 argv/恢复路径证据使用本机已有 Pi，并保留 provider 请求和真实 session。旧证据没有记录可独立核对的 Pi `--version`，本轮不倒填历史版本；本机调用者 HOME 下已有 Bun 安装路径，而 CI 是 npm 全局安装加 `HOME=/tmp`，这是已证明的调用方式差异。

**实际影响与最小修法：** 目前证据指向测试启动器，尚未证明提醒产品发送/观察有回归。由 `agent:dev` 统一 driver 及 smoke §67/68 对真实 Pi 的定位：保留显式 `P442_PI`，默认发现 PATH 中实际可执行的 Pi；不能给 CI 建一条假 HOME 软链，也不能把 §69 改成跳过。复用现有启动等待，在 `done` 早于 `session-start` 时立即报告退出码和原始启动错误，而不是继续等待业务条件。保留全部七场景、原 watchdog、受控 provider 与真实事件证据；没有运行任何修复后绿侧，本次不声称修好。若要保留后续原件，可把现有 driver 输出直接落到调用者 smoke 的 `$TMP` 子目录随现场一起保存，不新加收集前缀、门禁或筛选器。

## V161 为什么没覆盖

- **C1：** 本机原一阶 P440 绿，测试根不以 HOME 为中间路径组件；V161 未用 CI 的 `HOME=/tmp + TMPDIR=/var/tmp/...` 组合，重复本机相同布局的全量也不能证明该输入正确。
- **W1：** P456 的窄补验执行原 smoke 三形状及其旧参数红/还原绿（26/0），但没有执行另一个既有消费者 `install-shape.sh` 的配置继承整块比较。它虽未改字节，却受 P456 生成路径变化影响；V161 把它漏出影响范围。
- **W2：** 本机完整一阶和 V159 的受控 Pi 用的是确实存在的本机安装路径；V161 沿用这些行为证据，没有覆盖镜像全局安装与私有 HOME 的组合，也没核对“version 命令与 driver 启动的是同一个可执行文件”。

因此应补上述输入/消费者的定点证据，不把“再跑一次本机全量”当作影响分析或修法。

## coverage 与 OpenSpec assessment

原 coverage 日志实读四片 own 数为 **40/35/33/33**，四份清单均与重算逐字一致；去重并集 **141 = 基线**。`ok 6 bad 1` 的唯一红为矩阵结果 `failure != success`，不修改 coverage，不新增防护。

OpenSpec：**N/A（本任务为 `change: - / anchor: none (infra)` 的已发布 CI 只读诊断）**，未实现 change、未改规格，也不作归档就绪判断。

| Dimension | Assessment | Evidence |
|---|---|---|
| Completeness | 诊断范围完成 | 三类逐项原件/源码分析；原函数、共享 init 断言与唯一单场景复现；覆盖统计及 V161 漏面说明 |
| Correctness | 两类精确根因 + 启动路径复现；不虚构缺失的 CI 退出原件 | C1 错误路径原件；W1 不同安装形状对齐后整块 cmp=0；W2 本地 `done=127`、零 session/request，原 CI 进程文件缺失单列 |
| Coherence | 保留真实行为与原故障证据 | 未放宽原路径/配置断言；未删场景、延时、吞 rc 或用 skip 替代失败 |

## Final assessment 与未做项

- Counts: **CRITICAL 1（C1）· WARNING 2（W1/W2）· SUGGESTION 0**。
- 本只读诊断可交付；原 CI 失败、测试内跳过与上述产品缺陷均未被本任务修复，不给发布 PASS。
- 未跑：完整/FAST smoke、61b/meta/夜间/性能、完整安装/帮助页/三路线、§69 其余六场景、任何修复后场景。未安装依赖、未调用真实模型、未创建真实团队提醒、未改真实配置/进程/state、未重跑远端 CI、未改 tag/npm、未 push/merge。
- 原 CI Pi 进程退出/会话/provider 原件不在制品里；本地一次 127 是复现证据，不冒充原 CI 的七份退出码。临时下载、一次性 init 和私有 Pi 根的必要收据已写入本报告，原 artifact 可按 ID/hash 重新下载；本次临时目录收尾删除。
- Flip evidence：本任务不是缺陷修复，不制造修复后 PASS；沿用并核对的原 P440 未净化红侧、P456 旧参数红侧保留；W1 第⑮条必须在正常参考形状修正后再判其有效性。

## 收尾检查

报告暂存后只运行本工作树 ledger-ban 与 diff-check；没有为只读报告重跑产品检查。

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify scope=published files=2731 hits=0 names=ok user=resolved
ledger-ban-rc=0
$ git diff --check && git diff --cached --check
diff-check-rc=0
```

`<user>` 是扫描器原生输出，不是改到主检出代跑；以上 `hits=0/rc=0` 来自本分支已暂存的报告树。

## Suggested next steps

**BLOCKED（修复实施，不阻塞本诊断交付）：** PM 另派 C1 的产品 apply 写权，以及 `agent:dev` 的 W1/W2 测试修复；本席位不跨目录自行修正。无需动 0.4.7 已发布 tag/npm 或 coverage，不把本报告合入等同于缺陷已经修复。分支保持本地，由 PM 接受诊断和后续定点证据后处理合并。
