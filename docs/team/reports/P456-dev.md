# P456 · 公开文件路径脱敏与 80 份本地证据取消跟踪

agent: dev   status: DELIVERED (self-tested; independent verification pending)   time: 2026-11-16T01:46:00Z
branch: `task/P456-release-source-cleanup`   PR/MR: -

修复已完成自测：公开扫描 0 命中，80 份误入库证据全部取消跟踪且本地原件 SHA-256 不变，普通 OpenSpec 检查 20/0。发布检查为 16 通过、2 失败、1 跳过；仅剩未打 tag 的两条预期失败，安装路线按本单范围未跑。初始化与 28-i3 原窄测试 26/0 保留，扩围后没有重跑行为测试。

行为受测源码：`38bf501e9863ccad8b7a38417dd61cdecac35cf1`；最终文件清理提交：`408a2220689b70a44dbef794caba23a7b0ffef65`，其与行为受测源码之间产品/永久测试无差异。两次窄测试均从同一行为提交 `git archive` 到一次性冻结目录后运行；临时源码和夹具目录已由各自 EXIT 清理，未起模型、PM 或 tmux 会话。原始日志和一次性 runner 留在被忽略的 `docs/team/reports/P456-dev/`。

## Deliverables

| Path | What |
|---|---|
| `AGENTS.md` | 仅把受管块 12 处技能路径改成 `skills/teamsmith`；标记外逐字节不变 |
| `skills/teamsmith/scripts/lib/cmd-project.sh` | AGENTS 复用已有 `team_init_protocol_skill_dir` 的三种安装分支；普通项目命令经 git common-dir 定位主检出的技能安装 |
| `skills/teamsmith/scripts/lib/cmd-watch.sh` | 两行注释改为通用 `module` 示例；产品逻辑未改 |
| `skills/teamsmith/tests/smoke.sh` | 原 P440 路径断言同时检查 PROTOCOL/AGENTS，执行主检出与真实 worker worktree 的生成命令；原变异臂改为恢复 AGENTS 旧生成参数；28-i3 仅改注释与沙箱目录字面量 |
| `docs/team/reports/{P426-dev2,P443-dev,P444-dev2,P446-dev2,P449-dev}/**` | 80 份全部取消跟踪，包含嵌套 Markdown 原始证据；保留本席位原文件，由现有 `.gitignore:33` 忽略 |
| `docs/team/reports/P456-dev.md` | 本报告，含第一轮阻塞与最终结果的更正 |

提交：`c7480b38` 路径生成与本仓受管块；`38bf501e` 通用例子、原初始化断言替换、P426 五份日志取消跟踪；`47a28fc3` 第一轮 PARTIAL 报告；`408a2220` 按 PM 扩围授权取消其余 75 份证据跟踪。没有修改扫描器、名单、忽略规则、版本、运行时路径边界或任何真实规格。

## 普通项目与 worker 的具体路径反例

源仓的 `skills/teamsmith` 随 git 分支检出，在主检出和 worker 均可用。普通项目只在主检出安装 `.pi/skills/teamsmith`；直接把 PROTOCOL 的这个字面路径搬进 AGENTS，会让 `.worktrees/<worker>` 中的 `bash .pi/skills/teamsmith/scripts/team help` 退出 127。一次性夹具实际取得旧命令 rc=127、新生成命令 rc=0，见 `worker-relative-counterexample.log`、`worker-resolved-help.log`。

最小修正只在 AGENTS 的普通项目分支把路径写为：

```sh
"$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/skills/teamsmith"
```

这段表达式运行时定位同一项目的主检出，不把调用机器的家目录写进文档；双引号保留路径空格。PROTOCOL 的项目根相对写法未变；自托管源仓仍是 `skills/teamsmith`；`--no-skills` 仍为 `<skill-dir>`，不声称存在尚未安装的命令。原 P440 三种形状与红/恢复共 5 个成功断言仍为 5 个，没有新增段、独立永久变异层或索引条目；`section-select --check` 实测仍覆盖全部路径 token。

## 80 份本地原文件收据

原 P426 五份取消跟踪前已记录名称和 SHA-256；扩围的其余 75 份同样先记录再 `git rm --cached`，最后逐文件验证：80 份存在、80 个 SHA-256 不变、80 条被既有规则忽略，剩余 tracked evidence = 0。完整路径及每份 SHA-256 在 `P456-dev/all80-sha256.txt`，该 manifest 自身 SHA-256 为 `f80b44b5b91ac27f7ce6185e5a0a3d9ac7aab5c3afad93a5353a569745ae266b`。`all80-preserved-final.log` 为 `sha256sum -c` 的 80 个 OK。

分组数量：P426-dev2 5、P443-dev 7、P444-dev2 25、P446-dev2 36、P449-dev 7。扩围前的 75 份跟踪清单和 hash 仍保留为 `additional75-tracked-before.txt`、`additional75-sha256.txt`；首轮的 P426 原始清单与 hash 也保留，下面列出其五份收据。

| 文件（均在 `docs/team/reports/P426-dev2/`） | SHA-256 |
|---|---|
| `after.log` | `a227152f359bc87efb48be78348a0c4012ef6cff5d509582bdbd5c2af1c216cd` |
| `before.log` | `d7d1402250ca8a4c7f313aad2ee9fa164e83ef5e9675c7e8c83f18ac8226df21` |
| `round2-after.log` | `8e257c6d9ca08c1e8572b2ae7d5c408d57b227fa15d31ad56b5e561649a5caeb` |
| `round2-before.log` | `fd36862e629aaf581b220ff9abcd88cc300ce9e8fc24a5a46d92bfc4b87c425c` |
| `round2-live.log` | `76e5f3da635787f055f2c4af95045b986d8151d6fa7ceed06de8a0e31ddf8e73` |

主检出的 80 份原件备份由 PM 负责；更新后的只读 brief 记录其已保存到 `.pi/team/state/release-0.4.7/legacy-evidence/` 并验 hash、记录 manifest。合并后 PM 按原相对路径保留忽略副本，使旧报告引用继续可读，不能假定取消跟踪时主检出磁盘文件自动保留。本席位没有写主检出、没有替 PM 做备份，也没有删除任何本地原证据。

## OpenSpec assessment

N/A — 本单是 change-less 的既有公开文件卫生修复，不增加需求、不写 delta。最终运行普通结构检查，而非 strict：20 passed / 0 failed，rc=0。

## 第一轮阻塞的最终处理与更正

1. 首轮仅取消 P426 五份跟踪后发现其余 75 份，已经向 PM 报告；PM 更新主 brief 与 OWNERSHIP，明确扩围为全部 80 份。`408a2220` 仅取消这 75 份跟踪，原件与 hash 全保留。`release-complete.log` 的证据层不变量已通过，阻塞解除。原扫描只打印最前 5 条，不能据此推断全树只有五份；完整清单已留盘。
2. **更正：上一轮把工作树未跟踪空目录误判成仓库里的 change 缺陷。** 实查 `find openspec/changes/panel-symlink-inside-project` 只有目录自身，没有内容；`git ls-files --error-unmatch` 对该路径返回 1。按 PM 授权，仅 `rmdir` 本席位这个空目录，rc=0；未补 delta、未改 spec。随后同一 OpenSpec 1.16.0 普通检查为 20/0。`git diff 4a3c8348 HEAD -- openspec` 仍为空；原 20/1 与定点错误日志作为历史保留，不再列作仓库缺陷。

## CRITICAL

None — 80 份处理后的不变量和普通结构检查均已补跑通过，见 `release-complete.log`、`openspec-complete.log`。

## WARNING

- 没有跑三条安装路线、完整 17/28 段、全量/FAST/meta 或模型路由矩阵。本单按 brief 只跑已有初始化和 28-i3 子用例；`release-check --skip-install` 明确计 1 项跳过。不得把 26/0 称为全段或发布通过。

## SUGGESTION

None。

## Verification evidence

所有相对日志位置均相对 `docs/team/reports/P456-dev/`。

### 1. 改前红 → 最终公开扫描与不变量绿

```sh
$ bash docs/team/tools/release-check.sh --skip-install --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
# release-before.log，原始 rc=1
泄漏扫描不通过（4 条命中）
证据层被跟踪了：P426-dev2 的五份日志
通过 14 · 失败 4 · 跳过 1

# 首轮同命令，release-after.log，原始 rc=1
0 命中
扫描干净（名单查过）
证据层被跟踪了：P443-dev 的文件（当时剩余 75 份）
通过 15 · 失败 3 · 跳过 1

# 扩围完成后同命令，release-complete.log，原始 rc=1
0 命中
扫描干净（名单查过）
证据层（docs/team/reports/<ID>-<agent>/**）没有被跟踪
通过 16 · 失败 2 · 跳过 1
```

最终两条未打 tag 的失败原样保留：最新 tag v0.4.6 不等于 0.4.7，HEAD 领先该 tag。安装路线显式跳过 1 项；不凑全绿、不打 tag、不推送。

### 2. 初始化与 28-i3 的实际窄命令

```sh
$ git archive 38bf501e9863ccad8b7a38417dd61cdecac35cf1 | tar -x -C "$FREEZE"
$ bash docs/team/reports/P456-dev/focused.sh "$FREEZE" "$PWD/docs/team/reports/P456-dev"
# focused.log，rc=0
P440/P456 init 普通项目：PROTOCOL/AGENTS 不含 main/home 绝对路径，AGENTS 命令在主检出与 worker 均可用
P440/P456 init 源仓：PROTOCOL/AGENTS 用 skills/teamsmith 相对路径，AGENTS 命令在主检出与 worker 均可用
P440 init --no-skills：只写明确占位，不伪造 .pi/skills 安装路径
P440 init 红：恢复绝对 SKILL_DIR → 断言红（absolute main root remains）
P440 init 还原绿：源仓相对路径与真实命令恢复
# normal/source/noskills 各自刷新：rc=0；config、BOARD、AGENTS 标记外字节均不变
ordinary worker plain .pi/skills counterexample rc = 127
ordinary worker generated common-dir command rc = 0
# 28-i3 原五条断言全部成功：项目内可读、三类读0/0/0、根外拒绝、根外读rc0、FIFO拒绝且不阻塞
focused RESULT pass=26 fail=0
```

`focused.sh` 通过源码锚点抽取原 `# ②f P440/P456` 到 `# ③ P417` 前的初始化块，以及原 `# ---- 28-i3 项目内的软链` 到 `# 读面形状守卫` 前的子用例。没有改原断言，也没有借完整 28 的计数。抽取正文保存在 `init-body.sh`、`28-i3-body.sh`；生成的普通项目和源仓文档亦留作本地证据。

第一轮失败证据保留：`focused-first.log` 为 25/1；一次性 runner 错用外部技能 CLI 刷新源仓，安装步如实报告源冲突。修正 runner 用该源仓自己的 CLI 后为 26/0；产品源码、永久测试与受测 SHA 均未变。第一轮 `openspec` 裸名因当前 PATH 不含安装目录返回 127，`openspec-first.log` 保留；改用现有安装的绝对入口后得到真实 20/1，没有把未执行说成通过。

### 3. 普通结构、路径登记与字节边界

```sh
$ "$HOME/.bun/bin/openspec" --version
1.16.0
$ "$HOME/.bun/bin/openspec" validate --all
# openspec-complete.log，rc=0；仅在核实并 rmdir 未跟踪空目录后补跑
Totals: 20 passed, 0 failed (20 items)
# 历史 openspec.log 的 20/1 和 openspec-panel-detail.json 的缺 delta 报错仍保留，见更正节

$ bash skills/teamsmith/tests/section-select.sh --check
# section-check.log，rc=0
段正文点名的真实路径 token 都被各自的行覆盖（588 个 token 检查过）
== 选段自检 ==  ok 13  bad 0  SKIP 1
# 唯一 SKIP：检出中没有生成面的 .pi/skills；不是该项已检查

$ bash -n skills/teamsmith/scripts/lib/cmd-project.sh skills/teamsmith/scripts/lib/cmd-watch.sh skills/teamsmith/tests/smoke.sh
# rc=0
$ git diff --check
# rc=0
```

本仓 `AGENTS.md` 标记外与基准 `4a3c8348` 字节比较相同，SHA-256 `6e027522503241862ff6e84a50cf5c681a0333ca7c9e40c87f16f06bb6680edc`；最终 80 份原件 `sha256sum -c` 全 OK；`git ls-files 'docs/team/reports/*/*'` 为 0；80 份逐一 `git check-ignore -q` 均 rc=0。

### 4. Ledger ban

```sh
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
# ledger-complete.log；root 在此缩写为 <worktree>，其余为最终报告写入后的真实结果
ledger-ban: root=<worktree> scope=published files=2706 hits=0 names=ok user=resolved
$ echo $?
0

$ bash docs/team/tools/publish-public.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
# public-complete.log，rc=0
扫描了 3474 个文件 · 禁用形状 13 条 · 名单 8 条
0 命中
公开面干净
# 第一轮 ledger-final.log/public-final.log 仍保留历史读数，不作为扩围后文件数。
```

## Final assessment

- Counts: CRITICAL 0 · WARNING 1 · SUGGESTION 0。
- Readiness: 本单全部授权范围已完成自测，交 V161 独立补验；尚未独立验收，不主张整次发布通过。
- Unverified applicable checks: 三条安装路线及整段/全量未跑，范围与原因见 WARNING；普通结构与文件不变量已补跑通过。

## Decisions and deviations

- 按 PM 更新后的 brief/OWNERSHIP 扩围为 80 份；除此无扩大。未改产品/永久测试来处理后两项收尾，未重跑已有 26/0 窄测试。
- 最终发布检查 16/2/1，两个失败均为尚未打 tag；未把跳过的安装检查算通过。
- 所有后台作业均已收割；提交只留本地任务分支。

## Suggested next steps

1. V161 按最终提交独立补验；PM 接收独立证据后决定是否合并。
2. PM 使用已经完成的 80 份主检出备份，在合并后按原相对路径保留忽略副本。
