可发布：本地 `v0.4.7` 固定 `fdd3247a`，最终核对为 18 通过 / 0 失败 / 1 安装跳过、rc=0，标签两项已转绿；实际安装沿用与标签全部 286 个包文件同字节的候选三路线通过证据。外部 main/tag/npm 发布尚未授权，本任务未执行。

# V161 · 0.4.7 最终发布验证

agent: verify   status: PASS (local v0.4.7; authorized combined evidence)   time: 2026-11-16T02:19:58Z
branch: `task/V161-release-047-final`   PR/MR: -

## 原冻结提交 222458cd 的范围与已核对证据

按 PM 于 2026-11-13 更新的 V161 任务书，本次采用用户已授权的组合证据：原完整一阶结果、V159/V160 独立修复复验、本轮新的完整元套件记录；不再运行第二轮完整一阶，不重复 67/68 或 0e/36/40 定点检查。最终提交没有一次重新执行的完整一阶结果，不把 `team review --no-gates` 作为测试通过证据。

冻结检出 HEAD 为 `222458cd5d9371c847b2aa5846ac9569e2d61727`。开跑前 3545 个受版本管理文件已逐文件记录 SHA-256，状态干净、未跟踪文件数 0；基线见本工作树证据目录 `docs/team/reports/V161-verify/frozen-before.json`。启动命令的 PATH 加入既有 `$HOME/.bun/bin`，实际 `openspec --version` 为 `1.16.0`，没有安装或升级工具。

### 原完整一阶：只审阅，不归为本席位执行

原始日志 `rel47-first-order.log` 的头尾均固定为 `572856a3ae57503396019020f58e8e6abcc08db4`；由原 PM 作业 `rel47-first-order-gate` 执行 `smoke.sh --snapshot`，不是 verify 在最终 SHA 上执行。

```text
账本自查：140 段收口 · 增量 ✓5139 ✗2 SKIP19 ｜ 结果行 ✓5139 ✗2 —— 一致
== 结果 ==  ✓ 5139  ✗ 2
快照运行结束：committed=572856a3ae57503396019020f58e8e6abcc08db4 rc=1
```

两条失败逐条为：

1. §68 `P443 真实 Pi 恢复夹具红（rc=1）`：由 V159 的候选与合并提交独立复验承接。
2. §14d `P410 元套件记录` 最近 GREEN 距今 8 天超过 7 天：本轮新元 GREEN 已生成，11 月 16 日的 §14d 实跑实际读到它并通过，已关闭该失败。

19 条跳过都有原始日志：6 个低频元段；10 个检出中不存在的本机生成相位文件；1 个缺少报告证据层的 tmux 豁免清单；1 个容器运行时不可用；1 个冻结检出没有仓外禁名清单。跳过不计通过。原日志及去色摘要已原样复制到本工作树证据目录，未修改原始记录。

### V159 / P452

审阅已提交报告 `docs/team/reports/V159-dev3.md` 与 PM 接受记录 `docs/team/reviews/V159.md`，并核对原始 `run.log`、`RC.txt`、`merged-run.log`，不是只采信 PASS 标题。

- 候选删掉新增两行，恢复场景 `passed=0 failed=1`、`ENOENT … argv.bin`、rc=1；还原同字节文件后 `passed=1 failed=0`、rc=0。
- 合并提交 `1ef83cdf6507a81445a0346ee5b3ab0e28f3b5f4` 的独立记录：恢复场景 rc=0；67/68 选段 331/0、rc=0；OpenSpec 20/0、rc=0。原执行者 dev3，非修复作者 dev。
- 我独立比对该合并提交与冻结 SHA 的 `remind-tool-real.mjs`，逐字节一致，SHA-256 为 `873f8c4ff1f2b7d868853843fa78d34a5771693771db9565c04d98e9d6ab2632`。本轮不重跑这些场景。

### V160 / P453

审阅已提交报告 `docs/team/reports/V160-dev3.md`、接受记录 `docs/team/reviews/V160.md`，并核对合并轮三份原始日志、原后台执行记录和原 manifest 的 13/13 文件 SHA-256。

- 合并提交 `a9bab9e3d0f21e2e843b58f5fbd512bf3cc93769`：0e/36/40 为 213/0、rc=0；26/66 为 222/0、rc=0；故障矩阵 12/12、`isolation=ok`、rc=0。后台记录逐条有退出码，不以脚本末尾 `done` 代替结果。
- 报告明确给出循环清单删行/还原、真实历史空面计数 16→20→32、旧/新临时模板 lint 对照；没有把修改预期总数冒充新增产品覆盖。
- 我逐文件比对四个修复文件与冻结 SHA，全部逐字节一致，结果及 SHA-256 存于 `fixed-file-identity.json`。原执行者 dev3，非修复作者 dev2。本轮不重跑已通过的定点检查。

### `572856a3..222458cd` 差异对应关系

共 29 个路径：18 个账本路径、6 个版本/说明落点、5 个测试文件。五个测试文件分别由上列 V159/V160 证据覆盖；`common.sh` 唯一变化为 `TEAM_VERSION="0.4.6"` 改为 `0.4.7`，其余产品源码、扩展、规格基线与原完整一阶的字节一致。版本落点和新增 CHANGELOG 的打包/安装检查已由本轮实际执行。此范围未发现额外未覆盖的产品行为变化。

## 本轮完整元套件

本席位作业 `v161-meta-full` 已收割，退出 0；真实记录为 `2026-11-13T08:07:03Z`、`GREEN`、冻结提交 `222458cd5d9371c847b2aa5846ac9569e2d61727`、判据 `c715864b`，日志总时长 7841s，作业总时长 7846.6s。六个元段全部实际执行，加四个前导段共 10 段；217/0、SKIP3。三条跳过均为 §36 的 internal 检出没有 `.pi/skills`，不是元段整段跳过。

| 段 | 用时 | 结果 |
|---|---:|---|
| 0 / 0b / 0c / 0d（前导） | 0 / 0 / 3 / 1s | 3/0、3/0、9/0、9/0 |
| 0e | 49s | 26/0 |
| 36 | 1259s | 121/0 SKIP3 |
| 38m | 81s | 2/0 |
| 40 | 190s | 42/0 |
| 51m | 329s | 1/0 |
| 61b | 5923s | 1/0（37 ticks，含翻转组） |

中央 `history.tsv` 原生追加的行、日志头尾和逐段账目一致；没有手工改 history，也没用 `--judge` 生成记录。原始日志副本 `meta-full.log` SHA-256 为 `e256993673a0cbf6bc9f86c18ebfa4acdd80af205abcdfe737caa46d5d765dfc`。运行后再次逐文件读取冻结检出，与开跑前清单完全一致（HEAD、3545 个文件哈希、空 status、0 个未跟踪文件），见 `frozen-after-meta.json`。

## 原冻结提交 222458cd 的短检查

2026-11-16 本席位作业 `v161-short-final` 完成，15.9s、rc=0；逐条结果：

| 命令 | 结果 | rc |
|---|---|---:|
| `openspec --version` | 1.16.0 | 0 |
| `openspec validate --all` | 20 passed / 0 failed；既有长需求文本 WARNING | 0 |
| `bash skills/teamsmith/tests/smoke.sh --select 14d </dev/null` | 5/141 段，38/0、SKIP0；14d 自身 14/0 | 0 |
| `team review REL-0.4.7 --dir "$FROZEN_CHECKOUT" --branch 222458cd5d9371c847b2aa5846ac9569e2d61727 --no-gates` | 中央记录执行者 verify，判定 SKIPPED / gates none | 0 |
| 冻结内容逐文件前后比对 | HEAD、3545 个文件哈希、空 status、0 未跟踪文件全部不变 | 0 |

14d 实际读到 `2026-11-13T08:07:03Z` GREEN（程序显示距今 2 天 ≤7 天），7 列记录、判据 `c715864b`、总时长 7841s 与 10 段均与日志对应。原一阶的第二条失败已通过这次真实读取关闭。该选段未跑的 136 个键保存在 `select-14d.log` 尾部，不把短检查当成全量。中央 `REL-0.4.7.md` 是工具生成的人工检查入口记录，**SKIPPED 不是测试失败，也不是全量 PASS**；它的默认“报告缺失”提示针对不存在的 REL 报告命名，实际报告为本 V161 文件。

## 原冻结提交 222458cd 的版本、打包与真实安装

本席位作业 `v161-release-install` 于 2026-11-16 完成（24.9s）。各命令退出码单独记录，批次 exit=0 **不代表**发布检查通过：

| 命令 | 结果 | rc |
|---|---|---:|
| `bash skills/teamsmith/scripts/team version --check` | 磁盘、SKILL、CHANGELOG 均 0.4.7；提示会话需刷新 | 0 |
| `bash docs/team/tools/release-check.sh --names-file "$NAMES_FILE"` | 26 通过 / 4 失败 / 0 跳过，详见 CRITICAL 与 WARNING | **1** |
| `bash docs/team/tools/release-check.sh --self-test` | A 四条变异 4/4；B tag 判据 4/4 | 0 |
| `npm pack --json --pack-destination "$EVIDENCE/package"` | 真实 `teamsmith-0.4.7.tgz` 与逐文件清单 | 0 |
| `bash install.sh` 后执行安装位置的 `team help` | 真实仓库安装路线，帮助退出 0 | 0 |
| 冻结内容逐文件比对 | HEAD / 3545 文件哈希 / 状态 / 未跟踪列表不变 | 0 |

三条路线由 release-check 真实执行：临时 npm prefix 安装与 `team help`；私有 HOME 的 `install.sh` 安装，两份 skill 与源树逐字节相同；全新项目 `team init`，两份 skill 同字节、项目内 help 退出 0，类别模型及 PM 模型配置等于传入值。补验仓库安装器自身的 help 也为 0。所有 npm 读取都使用私有 HOME、独立空 user/global npmrc 与私有 cache，不访问真实用户认证或全局安装；使用 fixture Git 身份，不依赖真实用户配置。私有 HOME/cache/prefix 所在的本次精确临时目录已删除。

真实包：286 文件，压缩 3,041,117 bytes，展开 9,628,597 bytes；`shasum=02c6646374e5fa5f53c3817dfbb3a9f584ceaa64`；SHA-256 `b140d52c5acedc38a6783df55c53cdab0ffa8756ef8f0647bbcb4e3a6879ef16`。顶层为 LICENSE、README、package.json、install.sh、bin/team.mjs、skills/；没有 docs/、.pi/、.worktrees/ 或 node_modules/。`npm-pack.log` 保存完整 JSON 清单，`package-files.txt` 是实际 tar 成员清单，tgz 保存在忽略的证据目录。

## 固定镜像参考性能

镜像 `localhost/teamsmith-gate:local` 实际存在，ID `fa756c126b701b2ca3fae88588799dca7414a57a609e52e729c25beaecec2d20`。首次按发布清单把冻结检出的容器内路径交给宿主 Podman，Podman 在启动前退出 125：`statfs /var/tmp/rel47-review-222458cd: no such file or directory`；没有取得任何性能读数，原失败日志保留为 `perf-reference-attempt1.log`，不是套件失败。

只修运行路径：把冻结提交 `git archive` 到本席位忽略的证据目录，3545/3545 受版本管理文件与原冻结哈希逐字节一致，再以只读挂载交给同一既有镜像；不新建或升级镜像、不改产品。实际执行命令：

```bash
distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id \
  -e HOME=/var/tmp -e TMPDIR=/var/tmp -v "$EVIDENCE/perf-tree:/work:ro" -w /work \
  localhost/teamsmith-gate:local \
  bash -c 'bash skills/teamsmith/tests/perf.sh --in-container --tree /work'
```

第二次运行真正进入固定镜像、完成一次测量，rc=0；作业 `v161-reference-perf-copy` 已收割。环境自述：参考环境、32 核、CPU 配额 `max 100000`、Node v24.22.1、tmux 3.7b，loadavg 2.84→5.19。套件的“被测版本”行原样为 `unknown（/work）`，因为归档副本没有 `.git`；本报告通过 `perf-source-identity.json` 的完整文件同一性证明绑定 `222458cd`，不把该行改写为自报 0.4.7。

| 参考项 | 原始样本 | 中位 |
|---|---|---:|
| 首帧 | 13902 / 13234 / 13339ms | 13339ms |
| 帧装配 | 1008 / 640 / 605 / 609 / 577ms | 609ms |
| 稳态窗格 CPU | 0.48 / 0.00 / 0.00% | 0.00% |

整窗 CPU 0.162%、树 CPU 85.952%、采样窗 6s。上述数字只参考，没有通过/失败阈值；没有用宿主数字冒充容器读数。只读副本与本任务成功元套件保留的确切临时根、临时快照已清理，日志、tgz、文件同一性证明和清单保留；没有清理任何共享前缀或别人的目录。

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/V161-verify.md` | 原冻结、候选、合并与本地标签最终核对报告；原始失败保留，当前标签检查 rc=0，安装引用同字节实测证据 |
| `docs/team/reports/V161-verify/` | 本工作树忽略的原始证据目录：冻结清单、原一阶/独立修复日志副本、来源 SHA-256、文件同一性记录、本轮日志 |

## OpenSpec assessment

N/A — 本任务 `change: -`、`anchor: none (infra)`，只做发布验证，不写规格或 delta。原冻结提交 222458cd 上已实际执行 OpenSpec 1.16.0 普通 `openspec validate --all`，20/0、rc=0，不是引用 V159/V160 的结果。合并版与最终标签为 21/0，命令与新增规划项见后文；各轮均未运行全仓 strict。

## CRITICAL

受验本地标签 `v0.4.7` / `fdd3247a` 未发现未解决的 CRITICAL；以下 C1/C2 是原 `222458cd` 的历史发现，原始 rc=1 和日志均保留。它们已由 P456 候选、合并提交、本地标签的分阶段独立证据关闭，具体结果见报告末三节。

### C1 · 原公开来源文件包含真实家目录、用户名和项目名（合并复核已关闭）

release-check 的公开面扫描命中 4 个类别/名单项：`[home]`、`[user]`、两条 `[name]`。具体来源是 `AGENTS.md` 第 5、11、40、61、79、96、98、102、103、107、109、111 行的真实家目录/用户名；`skills/teamsmith/scripts/lib/cmd-watch.sh:1503-1504` 和 `skills/teamsmith/tests/smoke.sh:15057,15060` 的真实项目名。报告不重复敏感值，完整扫描诊断保存在忽略的 `release-check.log`。

我另打开实际 tgz，确认 `cmd-watch.sh` 与 `smoke.sh` 都在包内，且与冻结检出逐字节相同；因此不只是 Git 文档问题，也会进入 npm 发布包。该发现改变发布结论，需 PM 安排归属人修改来源文件，不能加白名单或放宽扫描。verify 未修改这些文件。

### C2 · 原公开树跟踪了原始证据日志（合并复核已关闭，完整清单为 80 份）

`git ls-tree -rl 222458cd -- docs/team/reports/P426-dev2` 确认五份日志在版本管理中：`after.log`（1416 bytes）、`before.log`（2354）、`round2-after.log`（2002）、`round2-before.log`（2937）、`round2-live.log`（69），合计 8778 bytes。release-check 按既有公开面规则拒绝；`.gitignore` 仍正确，不能阻止已经被跟踪的文件。npm 文件清单不含这些 docs 日志，但 Git 发布对象包含它们。

该发现改变发布结论。需 PM 保留仓外证据副本后安排从版本管理中移出，并按公开历史边界决定后续处理；verify 不删除、移出或改写他人证据。

历史 BLOCKED 对应 `222458cd`，已通知 PM 并触发 P456；候选与合并提交均已闭合两项问题，没有靠放宽扫描、删除证据或改判历史日志关闭。

## WARNING

- 最终提交不再运行一次完整一阶，按 D244 用户已授权的组合证据方式验收；原完整一阶的 5139/2 保留原始结果，不改写成全绿。
- 发布工具仍提示 29 个旧 tag 不在受验 HEAD 历史上，见 `tag-final/release-check-skip-install.log`。当前 v0.4.7 检查通过，但发布时不能使用 `git push --tags`；外部动作获授权后也只处理本次单个 tag，本任务未删除或推送旧 tag。
- version --check 的 0.4.7 内容正确，但私有 HOME 下提示继承 TEAM_SESSION 与目录推导身份不同，继承值被忽略；它不是共享 PM 已运行 0.4.7 的证据。按工具提示调用 reload_skills，工具返回当前上下文不能排队 follow-up、需手动 `/teamsmith-reload`；未重启或改动真实 PM，未升级全局技能。

## SUGGESTION

None；本轮不额外扩大范围。

## Final assessment

- Counts: CRITICAL 0 · WARNING 3 · SUGGESTION 0（针对受验本地标签 `v0.4.7` / `fdd3247a`）。
- Readiness: **PASS，可发布；发布动作仍须授权**。原一阶两条失败、C1/C2 已由分阶段实际证据闭合；最终标签检查 18/0/SKIP1、rc=0，三路线安装由 286/286 同字节候选真实结果覆盖。中央 `P456.md` 仍是合并 SHA 的 SKIPPED/gates none，不把它改成全量 PASS；本报告各阶段的真实命令/日志才是执行证据。
- Unverified applicable checks and reasons:
  - 按 D244，没有在 `222458cd` 上再跑一次完整一阶；原一阶 19 条跳过仍按原原因保留，不宣称全部产品场景实跑。14d 本轮仅运行 5/141 段，未跑 136 键逐名列于 `select-14d.log` 尾部；67/68 与 0e/36/40 只审已有独立记录，没有重跑。
  - 合并提交与最终标签未重跑窄 26 项、三路线安装、元套件或性能：按任务书避免重复。代码/AGENTS 与已测合并提交一致，实际候选包 286/286 文件与标签检出同字节；复用已有真实执行证据。最终 `--skip-install` 明确跳过 1 项，不把它记作标签轮重新执行安装。
  - 未做全仓 strict、夜间测试或真实全局升级；PM 已创建仅本地的 v0.4.7，本席位没有建/改 tag。未推 main/tag、暂存或发布 npm，未将这些外部步骤写成已完成。
- 原冻结检出 3545 文件、候选 3474 文件、合并 3487 文件、最终标签 3491 文件均与各自开跑前同哈希、状态干净，未跟踪/忽略产物 0。最终轮还核对标签对象与解引用提交不变。见 `frozen-final.json`、各轮 `snapshot-*.json`。

## Verification evidence

原始副本与哈希清单已在本工作树证据目录保存：`source-manifest.json`、`first-order-original.log`、`first-order-summary.txt`、`v159-*.log`、`v159-RC.txt`、`v160-*.log`、`v160-original-manifest.json`。这些是我审阅的其他执行者证据，不算本席位重新执行。

本轮元套件命令（已完成，rc=0）：

```bash
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp
export TEAM_META_KEEP=1 TEAM_SNAPSHOT_KEEP=1
cd "$FROZEN_CHECKOUT"
bash skills/teamsmith/tests/meta-suite.sh --snapshot=222458cd5d9371c847b2aa5846ac9569e2d61727 </dev/null
```

保留开关只用于保全运行现场；没有改跳过、判据、超时或 history。本轮命令/退出码均已落盘：`meta.rc`、`openspec-all.rc`、`select-14d.rc`、`review-no-gates.rc`、`version-check.rc`、`release-check.rc`、`release-self-test.rc`、`npm-pack.rc`、`installer-help.rc`、`perf-reference-attempt1.rc`、`perf-reference.rc`。

发布检查真实输出尾部：

```text
$ bash docs/team/tools/release-check.sh --names-file "$NAMES_FILE"
  ✗ 最新 tag（v0.4.6）≠ package.json（0.4.7）
  ✗ HEAD 领先最新 tag v0.4.6 262 个提交
  ✗ 扫描有命中（home/user/两条 name；具体 file:line 见 C1）
  ✗ 证据层被跟踪了（五份 P426-dev2 日志；见 C2）
== 结果 ==
  通过 26 · 失败 4 · 跳过 0
rc=1

$ bash docs/team/tools/release-check.sh --self-test
  A 四条变异  抓住 4 · 漏掉 0
  B tag 判据  4/4
rc=0
```

- Ledger ban（固定验收项，在本席位分支树上执行）：

  ```text
  $ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
  ledger-ban: root=…/.worktrees/verify scope=published files=2779 hits=0 names=ok user=resolved
  $ echo $?
  0
  ```

  这是本报告写完后的真实运行；日志 `ledger-ban-final.log`、退出码 `ledger-ban-final.rc`。`root` 的家目录仅作显示省略，没有在主检出代跑。

## Flip evidence

本任务不修缺陷，不改产品或测试；仅审阅 V159/V160 的已提交反向证据，具体范围见上。

## Decisions and deviations

- 按更新后的任务书及 D244 的用户授权取消第二轮完整一阶；既有原始红记录不改成绿。
- 原完整一阶不是本席位执行，最终 `--no-gates` 只记录人工审查。
- 性能首次运行在 Podman 挂载阶段退出 125，尚未执行套件；采用完整同字节只读副本修正宿主可见路径后才完成一次参考测量。原失败证据保留，不是盲目重跑产品测试。
- `team_bg_run` 批次 exit=0 只代表脚本结束；发布命令 rc=1 始终单独保留。
- 未合并、未推送、未打 tag、未发布 npm、未改共享安装或真实用户配置。中央只由工具生成获授权的 REL 审查记录，正文执行者 verify、gates none。

## Suggested next steps

原 `222458cd` 的 BLOCKED 结论保留为历史。P456 候选与合并提交补验均已完成，范围与结果见下。PM 接收合并提交证据后处理发布步骤；verify 不标看板 done、不打 tag、不推送或发布，未操作真实用户配置。

## P456 定点补验 · 候选 PASS；合并复核见后

候选 `5eafd5f46864b668734b20dfeec67dd5c890ab5e`，PM 准备的独立检出 `p456-review-5eafd5f4`；开跑前 3474 个受版本管理文件，未跟踪/忽略产物 0，HEAD 与候选相符。本轮仍由 verify 执行，未参与 dev 的实现。

已独立核对：

- `222458cd..5eafd5f4` 的 80 个删除路径，与主仓忽略备份 `.pi/team/state/release-0.4.7/legacy-evidence/manifest.json` 完整集合一致；每份备份的字节数和 SHA-256 与清单一致，且内容与 `222458cd` 原 Git blob 相同。分组为 P426-dev2 5、P443-dev 7、P444-dev2 25、P446-dev2 36、P449-dev 7。五份主报告正文逐字节保留。核验明细存于 `p456/all80-backup-check.json`，没有删改任何原件或备份。
- `AGENTS.md` 标记外逐字节相同；`cmd-watch.sh` 排除两行注释后完全相同。smoke 变化只在原初始化子块与 28-i3；后者除注释及中性目录名外逻辑逐字节相同。扫描器、发布检查、忽略规则、元套件、索引及版本未改；记录见 `p456/static-boundaries.json`。
- 唯一产品行为变化是初始化的 AGENTS 技能路径生成：复用现有三形状判断，普通项目改用运行时 git common-dir 定位技能安装，自托管仍相对 `skills/teamsmith`，`--no-skills` 保留占位。原初始化红侧已改为恢复 AGENTS 旧生成参数，没有新增永久自证层。
- 已完整读取原一次性窄 runner，副本 SHA-256 为 `a58030ad3ba4ccd97341ee9c0174a5c10c3dbad0660c4299082e91242d332e74`；本席位实际执行它，并逐字符确认抽取的两个断言块与冻结候选原文一致。包含主检出/真实 worker 命令、三形状刷新、config/BOARD/标记外不变、旧参数改回红/还原绿与 28-i3 五个子断言。本轮结果独立得到 26/0，不是引用作者结果。
- 独立检出没有作者曾有的未跟踪空 change 目录，未改规格。

### 本席位实际执行结果

后台作业 `v161-p456-candidate` 已收割，2026-11-16T01:54:38Z 结束，总时长 43.1s。各命令独立记录 rc；批次退出 0 不覆盖 release-check 的 rc=1。

| 实际命令（在候选目录执行；路径变量指向本轮既有名单/私有证据） | 结果 | rc |
|---|---|---:|
| `bash "$EVIDENCE/focused-original.sh" "$CANDIDATE" "$EVIDENCE/focused"` | 初始化与 28-i3 原窄断言 26/0；未跑完整 17/28 | 0 |
| 抽取原文与候选逐字符比对 | 两个断言块完全一致，未改原断言 | 0 |
| `bash docs/team/tools/publish-public.sh --names-file "$NAMES_FILE"` | 扫 3474 文件、13 内容形状、8 名单项，0 命中 | 0 |
| `bash skills/teamsmith/tests/ledger-ban.sh --names-file "$NAMES_FILE"` | 候选树 2706 文件、hits=0、names=ok | 0 |
| `openspec --version` / `openspec validate --all` | 1.16.0 / 20 passed、0 failed，普通检查 | 0 / 0 |
| `bash skills/teamsmith/tests/section-select.sh --check` | ok 13 / bad 0 / SKIP1；141 行与段对应、588 个 token 覆盖 | 0 |
| `bash -n` 三个变化脚本 / `git diff --check 222458cd 5eafd5f4` | 无输出、退出 0 | 0 / 0 |
| `bash skills/teamsmith/scripts/team version --check` | 0.4.7 一致；提示刷新会话，不作为真实 PM 已升级证据 | 0 |
| `bash docs/team/tools/release-check.sh --names-file "$NAMES_FILE"` | **28 通过 / 2 失败 / 0 跳过**；两失败仅未打 tag | **1** |
| `npm pack --json --pack-destination "$EVIDENCE/package"` | 实际生成候选包与完整文件清单 | 0 |
| `team review P456 --dir "$CANDIDATE" --branch 5eafd5f4 --no-gates`（从本席位运行） | 中央记录真实执行者 verify，SKIPPED / gates none | 0 |
| `python3 "$EVIDENCE/snapshot.py" after` | HEAD、3474 文件哈希、未跟踪/忽略产物与开跑前相同 | 0 |

唯一索引跳过为检出中不存在机器生成的 `.pi/skills`，没有把这一项称为已检查。未重跑完整元套件、full、14d、67/68、0e/36/40、参考性能或 release 自测；发布检查工具与自测源码未改。

初始化的本轮反向证据原文：

```text
ok P440 init 红：恢复绝对 SKILL_DIR → 断言红（absolute main root remains ）
ok P440 init 还原绿：源仓相对路径与真实命令恢复
focused RESULT pass=26 fail=0
```

普通项目和源仓都实跑生成命令，不只 grep 字符串。普通项目真实 worker 中旧 `.pi/skills` 相对命令 rc=127，新生成的 common-dir 命令 rc=0；三形状刷新时 config、BOARD、AGENTS 标记外字节不变；原 28-i3 的项目内读取、三类读 0/0/0、根外拒绝且返回 0、FIFO 拒绝不阻塞均通过。原始逐项日志与抽取正文保存在 `p456/focused/`，完整计数在 `p456/focused.log`。

### 两项阻塞的关闭与包收据

C1：来源扫描与候选 ledger 均 0 命中；扫描器、名单、忽略规则和安全判断没有放宽。C2：完整 80 个删除路径与备份一致、合计 744963 bytes，80/80 匹配既有忽略规则；候选 `git ls-files 'docs/team/reports/*/*'` 为 0，不是只显示前五项。五份主报告仍逐字节存在，没有删除证据、重写历史或修改原件。原一轮 26/4/0 变为本轮 28/2/0，新增关闭恰为这两项；两条 tag 失败保留原文和 rc=1。

三条安装路线实际全部执行：私有 npm prefix 安装及 help；私有 HOME 中 install.sh 两技能与候选逐字节相同；新项目 init 两技能同字节、help=0、类别/PM 模型等于传入值。候选包含 286 文件，压缩 3041572 bytes、展开 9629913 bytes，shasum `ba087e0a6e5b6f033bde2577c3652d6f89847d30`，SHA-256 `7fad61cf52e706fc7cff9af93215d69df2066569c36a66f6855ac1eb32908a4a`。另打开实际 tgz 逐字节核对 cmd-project、cmd-watch、smoke 三个变动文件与候选相同。完整 npm JSON 与 tar 文件清单分别为 `p456/npm-pack.log`、`p456/package-files.txt`；没有覆盖原冻结包。

私有 HOME、npmrc/cache/prefix 及窄测精确临时根已清理，没有读取真实认证文件、修改全局安装或真实用户配置。version 提示后再次调用 reload_skills，工具仍返回“当前上下文不支持排队 follow-up”，未因此操作真实 PM 或共享安装。

### 候选结论与下一步

P456 候选 **PASS**，未发现新增缺陷。本阶段交付后 PM 已合并；以下为同一 verify 在 PM 准备的 merged-SHA 干净检出的真实复核，不机械重复长套件、安装或性能。

## P456 合并提交复核 · PASS

受验提交 `165119c751a3731243191aae79fa31cb0d553535`，独立检出 `/var/tmp/p456-review-merged`，实际执行者仍为 verify。后台作业 `v161-p456-merged` 已收割，2026-11-16T02:05:32Z 收尾、31.7s、批次 rc=0；各子命令 rc 单独保留，不覆盖发布检查的 rc=1。

### 文件同一性与原件恢复

- 候选到合并仅 18 路径有差异：5 个既有账本文件更新、13 个新增账本/规划文件，包含 P455 的 OpenSpec 提案；没有 P457 的实现。298 个非账本/规格路径的 Git mode/type/blob 完全一致，且额外点名核对 AGENTS、cmd-project、cmd-watch、smoke、发布工具、ledger-ban、索引等；没有可执行差异需要重跑行为或安装。
- 已打开**实际做过安装检查的候选 tgz**，286/286 个包内文件与合并检出逐字节相同，记录于 `p456-merged/candidate-package-identity.json`。复用候选真实安装证据，而非把合并版的安装跳过写成通过。
- 主检出恢复的 80 份本地原文件，与既有备份、原 `222458cd` Git blob 三方逐字节一致、744963 bytes，80/80 仍被既有规则忽略；合并树完整文件清单中原始证据子树文件数 0。只读核验，没有改写主检出文件或备份。完整路径/hash/字节收据在 `p456-merged/restored80-check.json`。
- 开跑前后 HEAD、3487 个受版本管理文件 SHA-256、空 status、未跟踪与忽略产物 0 全部相同，见本轮 `snapshot-before.json`、`snapshot-after.json`。

### 实际短检查与退出码

| 命令（在合并独立检出运行） | 结果 | rc |
|---|---|---:|
| `bash docs/team/tools/publish-public.sh --names-file "$NAMES_FILE"` | 3487 文件、13 内容形状、8 名单项，0 命中 | 0 |
| `bash skills/teamsmith/tests/ledger-ban.sh --names-file "$NAMES_FILE"` | 2714 文件、hits=0、names=ok | 0 |
| `openspec --version` / `openspec validate --all` | 1.16.0 / **21 passed、0 failed** | 0 / 0 |
| `bash skills/teamsmith/tests/section-select.sh --check` | ok 13 / bad 0 / SKIP1；141 行/段、588 路径 token | 0 |
| `bash -n` 三个变化脚本 / `git diff --check 5eafd5f4 "$MERGED_SHA"` | 无输出、退出 0 | 0 / 0 |
| `bash skills/teamsmith/scripts/team version --check` | 版本 0.4.7 正确；六处另由 release-check 核对，未升级真实会话 | 0 |
| `bash docs/team/tools/release-check.sh --skip-install --names-file "$NAMES_FILE"` | **16 通过 / 2 失败 / 1 跳过** | **1** |
| `team review P456 --dir /var/tmp/p456-review-merged --branch 165119c751a3731243191aae79fa31cb0d553535 --no-gates`（从本席位运行） | 中央记录实际执行者 verify、merged SHA，SKIPPED / gates none | 0 |
| 本轮前后逐文件快照 | 合并检出 3487 文件不变、状态干净 | 0 |

OpenSpec 比候选 20/0 增加的一项为 `change/routing-argv-check-slimming`，原日志确有该项成功行；没有把数量变化误说成产品新增测试。索引唯一跳过仍是本机生成的 `.pi/skills` 不在干净检出，未将其称为已检查。

本轮发布检查的两条失败原样保留：

```text
✗ 最新 tag（v0.4.6）≠ package.json（0.4.7）—— 版本号与标签指的不是一回事
✗ HEAD 领先最新 tag v0.4.6 285 个提交 —— 发布前先做版本落点 + 打 tag
! 安装路线（--skip-install）（跳过，不算通过）
通过 16 · 失败 2 · 跳过 1
rc=1
```

所有非 tag 检查通过，原 C1/C2 在合并版继续保持关闭；同字节候选的三路线安装结果仍适用。没有重跑窄 26 项、安装、完整一阶、元套件、14d 或参考性能。完整命令封装与独立原始日志/rc 在 `p456-merged/`；中央工具的 SKIPPED 不是这些命令的替身。

### 最终交付边界

本阶段结论绑定 `165119c7` 及 D244 组合证据；当时标签尚未创建，原始 16/2/1、rc=1 保留。其后 PM 创建了仅本地的 v0.4.7，再由同一 verify 做以下最终标签核对，不改写历史失败、不重跑长套。原 meta GREEN 仍为 `2026-11-13T08:07:03Z` / `222458cd` / 判据 `c715864b`，没有新造记录或改 history。

## 本地 v0.4.7 最终核对 · PASS

PM 创建的是 annotated tag，实际标签对象 `e2e75cfe07e611eeab1d3c75cba719d1176fe4e6`，解引用提交 `fdd3247a451eeeec37985af73d2267b74790058b`；独立检出 `/var/tmp/rel47-tag-final` 的 HEAD 与它完全相同。没有由 verify 创建、移动或删除标签。

与已独立接受的 `165119c7` 比较，仅 8 个账本路径变化；773 个非账本路径的 Git mode/type/blob 相同，所有产品和 AGENTS 不变。另直接打开此前实际验证安装的候选 tgz，全部 286/286 个文件与标签检出同字节；原包 SHA-256 仍为 `7fad61cf52e706fc7cff9af93215d69df2066569c36a66f6855ac1eb32908a4a`。完整收据为 `tag-final/tag-source-identity.json`，没有重跑安装或另造包。

本席位作业 `v161-tag-final` 已收割，作业时长 14.7s、rc=0；逐命令日志时间为 2026-11-16T02:18:38Z—02:18:45Z：

| 实际命令 | 结果 | rc |
|---|---|---:|
| `git rev-parse refs/tags/v0.4.7` / `git rev-parse 'v0.4.7^{commit}'`，并与独立 HEAD 比较 | 标签对象与提交如上，标签确实指向受验 HEAD | 0 |
| 产品 Git 对象与实际候选 tgz 文件逐一比较 | 与 `165119c7` 同源，实际包文件 286/286 相同 | 0 |
| `openspec --version` / `openspec validate --all` | 1.16.0 / 21 passed、0 failed，普通结构检查 | 0 / 0 |
| `bash docs/team/tools/publish-public.sh --names-file "$NAMES_FILE"` | 扫 3491 文件、13 形状、8 名单项，0 命中 | 0 |
| `bash skills/teamsmith/tests/ledger-ban.sh --names-file "$NAMES_FILE"` | 2718 文件、hits=0、names=ok | 0 |
| `bash skills/teamsmith/scripts/team version --check` | 0.4.7 一致；会话刷新提示同前，无全局升级 | 0 |
| `bash docs/team/tools/release-check.sh --skip-install --names-file "$NAMES_FILE"` | **18 通过 / 0 失败 / 1 跳过** | **0** |
| 前后逐文件快照与标签对象/提交核对 | 3491 文件同哈希，状态干净，未跟踪/忽略产物 0，标签未变 | 0 |

最终真实输出包含：

```text
✓ 最新 tag v0.4.7 = package.json（0.4.7）
✓ tag v0.4.7 是 HEAD 的祖先（历史没被改写错位）
✓ HEAD 就在 v0.4.7 上（发布对象唯一）
! 安装路线（--skip-install）（跳过，不算通过）
通过 18 · 失败 0 · 跳过 1
rc=0
```

原预 tag 两条失败现在已实际转绿，不再是未完成步骤。原 `26/4/0`、候选 `28/2/0`、合并版 `16/2/1` 的 rc=1 都保留在各自原始日志；最新 `18/0/1` 只表示本次明确跳过安装后的命令通过，不伪称安装重跑或一次完整全量通过。安装、行为、元套件、自测和参考性能均按授权沿用前述真实证据，D244 的组合边界不变。

最终结论绑定 **`v0.4.7` / `fdd3247a`**。原始日志和逐命令 rc 保存在 `tag-final/`，所有证据总清单为 `MANIFEST.sha256`。本任务只完成本地验证；未推 main/tag、未暂存或发布 npm、未访问认证文件、未改共享安装或真实配置。PM/用户未授权前不得执行外部发布，由 PM 接收本报告后更新看板与关闭 V161。
