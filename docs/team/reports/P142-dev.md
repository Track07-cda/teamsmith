# P142 · 判据修正：`14b` 的 dep-scope 检查按「主题」判，不按「工具名」判

agent: dev   status: done   time: 2026-10-01
branch: `task/P142-14b-harness`   PR/MR: - （local 模式：分支留在工作树，未 push）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/smoke.sh` | 判据重写：`dep_scope_hits` 的逐行豁免从工具名白名单改成**行内话题**（`DEP_HARNESS_TOPIC_RE`）；话题只算正文（`^[^:]*:[0-9]+:` 前缀锚定）；两条翻转自测改成「无工具名的 harness 英/中句」（正向）与「产品英/中句逐条断言」（反向） |
| `skills/teamsmith/tests/section-paths.tsv` | `14b` 行 patterns 补 `ci/Containerfile` —— 段 36 `--check` 要求段内点名的真实路径 token 有声明 |
| `docs/team/reports/P142-dev/select-14b-before.log` | 红证据（提交 `d6bed2e0`：新夹具 + 旧白名单判据 → 14b ✓25 ✗1） |
| `docs/team/reports/P142-dev/select-14b-before-live.log` | 本次现场打断证据（把判据换回白名单 → 14b ✓25 ✗1） |
| `docs/team/reports/P142-dev/select-14b-after.log` | 绿证据（最终 revision → 14b ✓26 ✗0，整体 ✓47 ✗0） |
| `docs/team/reports/P142-dev/real-sentence-flip.sh` | 证据脚本：判据从交付树里 `awk` 出来跑（不手抄），逐句判红/绿 |
| `docs/team/reports/P142-dev/real-sentence-flip.log` | 输出：真实那句旧红新绿 + 逐句对照表 + 路径前缀陷阱 |
| `docs/team/reports/P142-dev/fast-final-summary.log` | 最终 revision 上 `TEAM_SMOKE_FAST=1` 的逐段账目（✓3156 ✗0，115 段收口，跳过 34 个真进程段） |
| `docs/team/reports/P142-dev/select-tip-0d-14b.log` | 报告 revision 上的补跑：`--select 0d,14b` → ✓47 ✗0（含已跟踪文件的冲突标记守护） |

提交（分支 `task/P142-14b-harness`，均本地）：

```
d6bed2e0 test(P142): 14b 的 harness 翻转夹具去掉工具名 —— 旧白名单判据下它必红（25✓1✗）
b1c35d1f fix(P142): 14b 的依赖收窄判据改按主题判 —— harness/门禁语境放行、产品语境照旧报红
35df37e2 docs(P142): 逐句红/绿对照证据 —— 判据从交付树里抽出来跑，含真实那句与路径前缀陷阱
```

## 要做的四条（逐条对照）

1. **按主题判** ✅：这一行只要在讲 harness / 门禁**这个话题**就放行。话题证据是两部分：英文词
   （`test(s)` / `testing` / `suite(s)` / `fixture(s)` / `harness(es)` / `smoke` / `gate` / `ci` / `lint` /
   `perf`，字母数字紧邻的不算（`pretests`、`testsuite` 不是），连字符/空格边界算（`multi-tests` 是））＋中文词（测试 / 门禁 / 套件 / 夹具 / 冒烟 / 自测 /
   用例 / 参考镜像 / 参考环境 / 钉死镜像 / 门禁镜像）＋几条 harness 侧路径与短语（`tests/`、
   `ci/Containerfile`、`container-tmux.sh`、`pm-box-real.sh`、`TEAM_PERF`、`pinned image|gate`、
   `reference image|environment`）。工具名只是话题证据之一，不再是「把容器写进句子」的通行证。
2. **反向有牙** ✅：产品语境照旧报红，四种形状都钉住（英文两条、中文两条，含一条故意带触发词
   `看门狗容器` 但无话题词的）。见下面的「仍会红」清单。
3. **两条翻转自测真的检验两条** ✅：正向夹具（harness 英/中句）**一个工具名都不含**，旧白名单下必红
   （`select-14b-before.log` 就是这条红）；反向夹具对英文、中文**每一条**分别断言命中，不再
   「有输出就算过」。
4. **报告写清改的是判据不是文案，并列出具体句子** ✅：见下面两张清单；改动前 PM 已在 `436b57e4`
   做了最小文案改动（往 `troubleshooting.md:1152` 那句中补上 `tests/smoke.sh`、`tests/perf.sh`、
   `tests/container-tmux.sh` 三个工具名）让 main 变绿，那段文案本次**一个字没动**。

## 改后不再红的具体句子（旧判据红 / 新判据绿）

| 句子 | 旧 | 新 | 话题证据 |
|---|---|---|---|
| `references/troubleshooting.md:1148`（`eb25b765` 原文，逐字取自 git）：<br>`image (`ci/Containerfile`) is the one built for the suite. A `git worktree` cannot be mounted for a container` | 红（当年那条假红） | 绿 | `suite`、`ci/Containerfile` |
| 夹具英：`The gate suite keeps its tmux-touching fixtures in a disposable container (podman runtime, optional).` | 红 | 绿 | `gate`、`suite`、`fixtures` |
| 夹具中：`门禁套件里接触 tmux 的夹具在一次性容器里跑（podman，可选）。` | 红 | 绿 | 门禁、套件、夹具 |
| `Run team perf --container to judge the panel red lines inside the pinned image.`（M58 夹具） | 绿 | 绿 | `perf`、`pinned image` |
| 真树现存 7 行命中（`troubleshooting.md` 的 1014/1024/1043/1152、`SKILL.md` 69/75、`workflows.md` 206） | 绿（旧豁免刚好覆盖） | 绿 | 全是 perf 套件 / 门禁镜像 / suite 语境，逐行列在 `real-sentence-flip.log` 供人工核对 |

## 改后仍会红的具体句子（反向）

| 句子 | 旧 | 新 |
|---|---|---|
| `The pulse daemon now runs inside a podman container on every host.` | 红 | 红 |
| `装 teamsmith 需要 podman；看门狗跑在容器里。` | 红 | 红 |
| `The console backend runs in a podman container on every host.` | 红 | 红 |
| `看门狗容器里跑着面板。`（触发词在、话题词不在） | 红 | 红 |

## Verification evidence (must have actually been run)

```
$ bash skills/teamsmith/tests/smoke.sh --select 14b          # 最终 revision
  ✓ 翻转自测：文档讲「产品跑在容器里」（英文 + 中文两条）都会被抓到
  ✓ 翻转自测：harness/门禁主题的容器说明不误报（P142：不带工具名也放行）
  ✓ 翻转自测：M58 — 性能套件的参考镜像说明放行、产品语境的 podman 照旧报红（豁免逐行）
#5 14b · 文档一致性：… · 用时 0s · ✓26 ✗0 SKIP0 · ticks 26
== 选段结果 ==  ✓ 47  ✗ 0          # 全部在 docs/team/reports/P142-dev/select-14b-after.log

$ bash skills/teamsmith/tests/smoke.sh --select 0e,35,36,14b   # FAST 首跑抓到我改坏的 6 条，修后复跑
== 选段结果 ==  ✓ 177  ✗ 0          # 逐段：0 3 / 0b 2 / 0c 7 / 0d 9 / 0e 23 / 14b 26 / 35 2 / 36 105

$ <home>/.bun/bin/openspec validate --all --strict
Totals: 15 passed, 0 failed (15 items)

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh          # 最终 revision 35df37e2，816s
账本自查： 115 段收口 · 增量 ✓3156 ✗0 SKIP34 ｜ 结果行 ✓3156 ✗0 —— 一致
== 结果 ==  ✓ 3156  ✗ 0
FAST 模式：跳过 34 个真进程段落（…）—— 完整门禁请不带 TEAM_SMOKE_FAST 重跑
# 逐段账目在 docs/team/reports/P142-dev/fast-final-summary.log
# （首跑同一条命令是 ✓3150 ✗6，那 6 条就是下面「FAST 首跑抓到的 6 条」）

$ bash skills/teamsmith/tests/section-select.sh --check
ok: 段正文点名的真实路径 token 都被各自的行覆盖（423 个 token 检查过；0 个豁免类 token 不参与）
== 选段自检 ==  ok 7  bad 0
```

`openspec` 不在我的 PATH 里，用绝对路径 `<home>/.bun/bin/openspec`（与 P136/P137 报告等价）。
按任务书不跑全量：FAST 跳过的 34 个真进程段（tmux / 真 pi / podman 场地类）在本次改动里没有可执行
行为面，完整清单在 `TEAM_SMOKE_FAST=1` 那一跑的日志里；全量与容器内门禁由 PM 复验跑。

**FAST 首跑抓到的 6 条（都是我这次改出来的，已修）**，逐条与根因：

```
✗ 35 守卫：smoke.sh 里出现了性能判定标记 / 比较 / 测量夹具点名（5483: … perf.sh …）
✗ P70 gate-guard 第四向：干净副本绿（期望 [0]，实际 [1]）          ← 同因连带
✗ P70 gate-guard 第四向还原：绿（期望 [0]，实际 [1]）              ← 同因连带
✗ 36① --check 红：bad: 段 14b 读了它没声明的路径：token ci/Containerfile（源码行 5497）
✗ 36① 副本表未改就红（夹具本身有问题）
✗ 36① 变体树注入前就红了（夹具本身有问题）                          ← 同上，表没修好导致夹具前置条件失败
```

- 段 35 的 `gate-guard.sh` 有一条 `FIX_RE='panel-cpu\.sh|panel-cpu-premise\.sh|perf\.sh'`：**门禁本体
  `smoke.sh` 不许出现测量夹具的文件名**。我新写的注释把旧白名单原文连文件名一起抄了进去 → 命中；
  P70 ④ 把 `smoke.sh` 拷进 scratch 再跑守卫，于是连带两红。修法：注释里改回旧正则的**原文形态**
  `perf[.]sh`（不含字面量，且与旧代码逐字一致）。
- 段 36 的 `--check` 要求段内点到的真实路径 token 在该行 patterns 里有声明；新正则里的
  `ci/Containerfile` 是新 token → 三条红。修法：TSV 补声明（没有放宽检查）。
- 段 35/36 都是**既有**守卫，正是它们该拦的东西；这说明新判据的字符串确实进了门禁本体，而不是只换了夹具。

## Flip evidence（红→绿，本次现场）

```
# ① 打断实现：把话题判据换回 P142 之前的工具名白名单（逐字取自 git show d6bed2e0）
$ bash skills/teamsmith/tests/smoke.sh --select 14b
  ✗ 翻转自测：harness 主题的容器说明被误报：/tmp/teamsmith-smoke.aan6r0/docsandbox-dep/references/troubleshooting.md:1249:The gate suite keeps its tmux-touching fixtures in a disposable container (podman runtime, optional).
#5 14b · … · ✓25 ✗1 SKIP0 · ticks 26 ;  == 选段结果 ==  ✓ 46  ✗ 1      (rc=1)

# ② 逐字节还原（cmp 一致）后同一命令
$ bash skills/teamsmith/tests/smoke.sh --select 14b
#5 14b · … · ✓26 ✗0 SKIP0 · ticks 26 ;  == 选段结果 ==  ✓ 47  ✗ 0      (rc=0)
```

另一条更接近真实现场的红→绿：`eb25b765` 的那句原文（无工具名）在旧判据下命中
`…troubleshooting.md:1148:image (`ci/Containerfile`) is the one built for the suite.…`，新判据下无输出
（`real-sentence-flip.log` 第 2 节，输入是从 git 取的原文，不是手抄）。

## Decisions and deviations

- **判据形态选了「正则主题词」，没选「上下文窗口 / 距离判定」**：`grep -E` 表达不了「容器词与话题词
  在同一句子里」的距离约束，而这个不变量本来就是**逐行**门禁；话题词表是封闭的，加词要走同一条
  双向夹具。代价写在下面「残余」里。
- **话题只算正文（前缀锚定）**：实测若不锚 `^[^:]*:[0-9]+:`，沙箱/临时根名里的
  `teamsmith-smoke.<rand>` 会把**每一行**都放行（两条产品句在沙箱路径下假绿，判据形同虚设）。
  这条是本次自己的对抗性检查查出来的，证据在 `real-sentence-flip.log` 第 3 节。
- **没有动 `14b` 行的 basis 注记**（「段内点名 25 条真实路径 token」）：那是 P98 的人工注记，机器键是
  `--check`（现在 ok 7 bad 0）；本次新增 1 个 token，但我不掌握原作者的口径，不凭猜改数字。
- **残余（写在这里，供后续任务判断是否要收）**：豁免是「行内出现话题词 → 整行放行」，因此
  「产品句里恰好带了 gate/CI/test 等词」的混合行会被放行；反向的产品句没有话题词才会红。要再收紧
  只能上逐句语法或「容器词附近 N 词内必须有话题词」，`grep -E` 做不到，且会给文档作者造成新的
  「凑词」压力（正是 P142 要消掉的病根）。本次按任务书的口径（产品跑在容器里 → 红）双向钉死。
- **分支基线是 `cac3270d`，FAST 跑在 `35df37e2`**：此后 main 前进到 `7e84e9ef` / `d65d4723`
  （发布中性化），其中 `smoke.sh` 的改动在 7436 行以后的段（§12b-pi2 / §32 的仓库名替换），与本任务
  改的 5479–5532 行段**不重叠**；任务书没要求抬基线，我没有 `git merge main`。若 PM 要在已含新 main
  的基线上重跑门禁，说一声即可。
- **报告文件（`e3e30a38` 及本次收尾提交）晚于 FAST 的那点差量**：在报告 revision 上补跑了
  `--select 0d,14b` → ✓47 ✗0（`0d` ✓9 ✗0：已跟踪文件的冲突标记守护把新报告文件也扫了；`14b`
  ✓26 ✗0）。这次选段在共享锁上排队等另一套全量 smoke 跑完（共 18.8 分钟）才开跑 —— 排队不是挂死，
  日志 `docs/team/reports/P142-dev/select-tip-0d-14b.log`。
