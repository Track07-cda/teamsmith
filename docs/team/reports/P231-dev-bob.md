# P231 · 清掉树里残留的真实对端项目名 + 让账本扫描覆盖所有被跟踪的账本文件

agent: dev-bob   status: delivered   time: 2026-10-14T00:36:47Z
branch: `task/P231-scrub-peer-name`   PR/MR: -（local 模式，分支留在本地）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/references/protocol.md` | §8f 标题与正文的一处对端名 → `an external project`；§9b-3 补 P231 的新口径（面 + 归属头两铁律 + 夹具） |
| `skills/teamsmith/scripts/lib/common.sh` | 两处注释（渲染 `&` / pi 绝对路径）→「外部项目实测」 |
| `skills/teamsmith/scripts/lib/cmd-watch.sh` | 一处注释（resume 位置参数）→「外部项目反馈」 |
| `skills/teamsmith/tests/smoke.sh` | 6e 段的段名/标题与 ④ 的括注改名；§60 头注释改成新面 |
| `skills/teamsmith/tests/section-paths.tsv` | 6e 行的 id/键同步改名；§60 的 basis 补 P231 口径 |
| `skills/teamsmith/tests/section-budgets.tsv` | 6e 行的 id 同步改名（预算表按 id **精确匹配**，不改就掉进默认预算） |
| `docs/team/ledger/branch-inventory-20261005.tsv` · `branch-cleanup-20261005.tsv` | 分支名 → `task/P138-<peer>-team-say`（行结构 / tip / 日期 / 分类不动） |
| `openspec/changes/archive/2026-09-16-rename-watchdog-to-pulse/design.md` | `docs/alignment-<peer>-reply.md` |
| `skills/teamsmith/tests/ledger-ban.sh` | 账本面从 `docs/team/**/*.md` 放宽到 **docs/team 下会被提交的每一个文件**（published 与 `--all` 两条枚举都改） |
| `skills/teamsmith/tests/section-select.sh` | 装载期铁律：`# ledger-scan:` 必须**唯一**且指向**承载账本禁令的那一段**，违反即 die 点名（表路径 + 行号 + 段 key） |
| `skills/teamsmith/tests/ledger-claim.sh` | 新红侧夹具 ④ / ④b / ⑤ / ⑥（非 .md 植入 + 假绿对照），共 **15 ✓ 0 ✗** |
| `docs/team/reports/P231-dev-bob/{pkg,logs}/`（被忽略，不进公开面） | 证据包：`redside-names.sh` / `redside-face.sh` / `flip-both.sh` + 全部原始日志 |

## 第一部分：清名（13 行 / 9 个文件，与任务书的表逐条对上）

改法（只拿掉名字，句子本意不动）：注释/正文用「外部项目」，tsv 分支名与 design 里的路径用 `<peer>`。
名字不落本报告——下面点名的是**改前树**（`fc6b8aeb`）上的真实命中，输出由扫描器遮蔽后打印：

```
$ bash docs/team/reports/P231-dev-bob/pkg/redside-names.sh
改前树（fc6b8aeb）：publish-public rc=1
  ✗ 命中 [name]
      openspec/changes/archive/2026-09-16-rename-watchdog-to-pulse/design.md:65:…, `docs/alignment-«name»-reply.md`, …
      docs/team/ledger/branch-inventory-20261005.tsv:150:task/P138-«name»-team-say	ef4d50397a1181ed68769caf93873ac73726b5c1	2026-09-29	merged	-
      docs/team/ledger/branch-cleanup-20261005.tsv:150:task/P138-«name»-team-say	ef4d50397a1181ed68769caf93873ac73726b5c1	2026-09-29	merged	0
  ✗ 命中 [name]
      skills/teamsmith/tests/smoke.sh:2833 / :2834 / :2858 · section-paths.tsv:47 · section-budgets.tsv:49
      common.sh:5080 / :5237 · cmd-watch.sh:251 · references/protocol.md:485 / :494
汇总：2 条命中 · 点名 13 行 · 9 个文件
```

**诚实边界**：这些名字**已经在已推送的公开历史里**（public 的 main 停在 `ca7c176`，2026-10-13）。
清工作树**改变不了「已经公开」**这件事；本任务不做历史改写、不做 force-push（两条都明令禁止）。
清理的意义仅是「从今以后不再新增暴露」。

## 第二部分：扫描面 + 归属

1. **面放宽**（`ledger-ban.sh`）：published 用 `git ls-files -z -c -o --exclude-standard -- docs/team` **全量**
   （删掉 `case *.md` 过滤），`--all` 的 find 也删掉 `-name '*.md'`。真实树：**files 1426 → 1431**
   （多出来的 5 个就是 `docs/team/ledger/*.tsv`、`docs/team/tasks/.gitkeep`、`docs/team/tools/*.sh`）。
   放宽**之前**这 5 个里恰恰藏着名字 —— 于是同一棵树、同一个植入得到「假绿」（见 Flip evidence ①）。
2. **归属落在承载段**（`section-select.sh` 的 `load_table`）：`# ledger-scan:` 头现在受两条装载期铁律 ——
   ①必须**唯一**（重复头过去是「最后一行赢」）；②指向的那一行 patterns 列里必须有
   `skills/teamsmith/tests/ledger-ban.sh`（指向别的段/未知段过去只看「段在不在」）。违反即 die，
   点名表路径 + 行号 + 具体段 key，不静默选一边。缺头仍是 `--check ⑦` 的一条红（账本路径回到 NONE），
   这一支没动。
3. **门禁牙齿**：`ledger-claim.sh` 从 10 条涨到 **15 条**，新增的都在 §60 里跑：④ 指向别的段、④b 未知段、
   ⑤ 两行表头（旧行为最后一行赢，现在是拒绝）、⑥ 非 .md 植入红 + 把面退回 `*.md` 的**假绿对照**。

## Verification evidence（全部真跑；日志在 `docs/team/reports/P231-dev-bob/logs/`）

```
$ TEAM_FORBIDDEN_NAMES="…/.pi/team/forbidden-names.txt" bash docs/team/tools/publish-public.sh
== 公开面泄漏扫描 ==
  面    被跟踪的树（…/.worktrees/dev-bob）（2010 个文件：产品/工具面 582 · 账本面 1427 · 例外 1）
  形状  13 条内容形状 + 9 类路径 + 8 条外置名单
  扫描了 2010 个文件 · 禁用形状 13 条 · 名单 8 条
  ✓ 0 命中
✓ 公开面干净        rc=0
```
任务书括注的「禁用心智形状仍全跑」自证：**这版工具没有这条输出**（我找不到任何这样一行，
`git log -S'自证' -- docs/team/tools/publish-public.sh` 也是空的）。它有的自证是「形状 13 条 … 名单 8 条」
这类计数行与 EXEMPT 打印。**我没有伪造它**，改用下面两条补「形状真的在开火」：
`release-check.sh --self-test` 四棵变异树 4/4 被抓住（`accept-5b-*.log`），以及 `redside-names.sh`
在改前树上确实逐行点名。

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file .pi/team/forbidden-names.txt
ledger-ban: names：名单已配置（.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=/home/<user>/…/.worktrees/dev-bob scope=published files=1432 hits=0 names=ok user=resolved
$ echo $?   → 0
```
（这个 `files=1432` 里**包含本报告**：报告也是 `docs/team` 下会被提交的文件，扫描面放宽后它自己在网内。）
说明：这条命令按任务书原样跑需要名单在旁边。worktree 里没有 `.pi/team/`，我放了一份**被忽略**的本地副本
（`.pi/team/…` 在 `.gitignore` 里，`git check-ignore` 有证据，不会进任何提交）。不放也能跑，但会走
「名单缺失 → 可见 SKIP（rc=3，不算通过）」。

模板里那条**固定验收行**（绝对路径版，不依赖本地副本；在我自己的 worktree、本分支的树上跑）：

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（…/.git/../.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=/home/<user>/…/.worktrees/dev-bob scope=published files=1432 hits=0 names=ok user=resolved
$ echo $?
0
```

```
$ bash skills/teamsmith/tests/smoke.sh --select 6e        # 改过 6e 的标题/两张 tsv 的键
  == 选段结果 ==  ✓ 165  ✗ 0        （10 段，rc=0）
$ bash skills/teamsmith/tests/smoke.sh --select 60        # 改过 §60 的头注释与夹具（同一段承载本 change）
  == 选段结果 ==  ✓ 40  ✗ 0         （5 段，rc=0）
$ bash skills/teamsmith/tests/section-select.sh --check
ok: 账本归属（ledger-scan 60）声明有效：9/9 个账本样例被它覆盖
== 选段自检 ==  ok 8  bad 0  SKIP 1     rc=0
```
（两次都是**选段**，不是整套门禁；未跑的 117 / 122 段按选段器自述列出。）

```
$ bash docs/team/tools/release-check.sh
  通过 21 · 失败 4 · 跳过 0        rc=1
```
**4 条都不是本分支引入的**，逐条给出处（`git diff --name-only fc6b8aeb...HEAD` 的 13 个文件里没有
`docs/team/tools/release-check.sh`，也没有 `cmd-project.sh`）：
- **3 条 tag 行**：`git tag --sort=-v:refname | head -1` 选到的是**旧内部 tag 线**（`v1.42.0`，2026-09-19），
  它既不等于 `0.1.2`、也不是 HEAD 的祖先。这是仓库级的既有状态（`v1.42.0` 同样不是 main-tip `fc6b8aeb`
  的祖先）。把 tag 集合换成公开线（只留 `v0.1.x`）后，这一节**只剩任务书预期的那一条**：
  ```
  ✓ 最新 tag v0.1.2 = package.json（0.1.2）
  ✓ tag v0.1.2 是 HEAD 的祖先
  ✗ HEAD 领先最新 tag v0.1.2 78 个提交
  通过 15 · 失败 1 · 跳过 3
  ```
  （临时 clone 里 `git tag -d 'v1.*'` 后跑同一条命令，源仓只读。）
- **1 条 `team init 失败`**：route 3 调的是裸 `"$INST/prefix/bin/team" init`，而 main 的 `cmd-project.sh`
  现在要求新鲜项目必须给 `--task-models`/`--pm-model`（`e897a7d8` 起）：
  ```
  ✗ init: 缺少 --task-models（项目类别映射是必填输入；没有默认模型可猜）
  ```
  即 `release-check.sh` 的 route 3 在路由合并后**没有跟着更新**（`fc6b8aeb` 的同一行就是裸 init），
  属 PM 目录（`docs/team/tools/`），我没有越界改。

```
$ git diff --check && git status --short      → 无输出（干净）
```
（`ledger-ban` 与 `publish-public` 两条在上面的报告落盘后**又各跑一次**：files=1432 / 2010 文件、hits=0、rc=0；
`git status` 在提交报告时也是干净的。）

## Flip evidence

**① 假绿 → 真红 → 真绿**（`pkg/redside-face.sh`，同一棵改前树 + 同一份真名单，只换扫描器）：
```
---- ① 改前扫描器 × 改前树 ----   files=1426 hits=0        ← 假绿（13 行泄漏就在树里）
---- ② 本分支扫描器 × 改前树 ---- rc=1 files=1431 hits=2
    docs/team/ledger/branch-cleanup-20261005.tsv:150: [names] task/P138-<names#6>-team-say …
    docs/team/ledger/branch-inventory-20261005.tsv:150: [names] task/P138-<names#6>-team-say …
---- ③ 本分支扫描器 × 清理后的树 ---- files=1431 hits=0    ← 真绿
== redside-face == ✓
```

**② 把实现弄坏 → 守卫必须红 → 还原**（`pkg/flip-both.sh`）：
```
A 面退回 md-only   → ledger-claim ✓ 13 ✗ 2（⑥ 非 .md 没有红 + 同一尸体上的锚点断言）
A 还原             → ledger-claim ✓ 15 ✗ 0
B 去掉装载期检查   → ledger-claim ✓ 12 ✗ 3（④ rc=0 照旧通过、④b、⑤）
B 还原             → ledger-claim ✓ 15 ✗ 0
还原核对：git status 为空 ✓      == flip-both == ✓
```
B 的破坏侧正好复现了 V26 的 OBS2/OBS3：指向别的段时 `--check` 返回 **rc=0**（旧行为放行）。

**③ 任务书三条红侧逐条对上**：①「把替换改回原名 → 点名 file:line；改回 → 0 命中」= `redside-names.sh`
（改前树就是「改回原名」的全部 13 行，rc=1 逐行点名）+ accept 1（现在的树 0 命中）。②「非 .md 被跟踪文件
植入 → 红并点名；改前假绿」= `redside-face.sh` ①② 与 `ledger-claim` ⑥。③「指向别的段 / 两行表头 →
装载报错点名」= `ledger-claim` ④ / ④b / ⑤。

## Decisions and deviations

- 6e 的段名定为「**外部项目实测反馈**」，三个地方（`smoke.sh` 的 `section "…"`、`section-paths.tsv` 的
  id 与 key、`section-budgets.tsv` 的 id）**同一次改完**：预算行是按 id 精确匹配的，漏一处就静默掉进默认预算。
- 中性写法按任务书给的两种：注释/正文用「外部项目」，结构化字段（tsv 分支名、design 里的文档路径）用 `<peer>`。
- 我改了 `section-select.sh` 与 `ledger-claim.sh`：任务书的「允许改」点名的是 `ledger-ban.sh`（或承载它的
  脚本/库）+ 清单登记，而第 2、3 条要求（归属必须落在承载段、两行表头必须拒绝）的**实现处**就是这两个文件
  （装载器 + 它唯一的夹具）。若 PM 认为超出授权，请退回，我原地回滚。
- 事实与任务书预期的一处出入已写在 evidence 里：`publish-public.sh` 没有「禁用心智形状仍全跑」的自证行，
  我没有编造，改用 `--self-test` 的四条变异 + 改前树逐行点名作等价证据。

## Found, not fixed（交回 PM；都在我目录之外或任务书明令不许顺手改）

1. **`publish-public.sh` 的 `[name]` 形状区分大小写，`ledger-ban.sh` 的不区分。** 于是名单里那两个名字的
   **大写拼写**对 publish-public 完全不可见：被跟踪树里还剩 **33 处 / 15 个文件**（`grep -Iwoi` 逐行数出来的；
   全部为大写拼写，小写拼写已清零）。逐条看上下文都是同一个对端（「来自 … 的教训」/「… 实测」/
   「… 已验证过」/「… 的 machine」），但**不在任务书的表里**，按边界我一条没改。
   涉及文件：`skills/teamsmith/{CHANGELOG.md,extension/team-notify.ts,references/{config.md,protocol.md},
   scripts/lib/{cmd-agents.sh,cmd-review.sh,cmd-status.sh,common.sh},tests/{section-budgets.tsv,section-paths.tsv,smoke.sh}}`、
   `openspec/changes/archive/2026-10-03-delivery-truth/{design,proposal,tasks}.md`、
   `openspec/changes/archive/2026-10-03-meeting-liveness/proposal.md`。
   请裁断：是（a）新开一个清名任务、并把 publish-public 的 name 形状改成大小写不敏感（与 ledger-ban 同口径），
   还是（b）只往外部名单里补大写拼写（名单是外部文件，只有你/用户能改）。
   与第一部分同样的诚实边界适用：这些**也已经在公开历史里**。
2. **`docs/team/RELEASE-PUBLIC.md:112`**（PM 目录）现在与实现不符：「`ledger-ban.sh` 每次门禁扫
   `docs/team/**/*.md`」→ 应改为「扫 `docs/team` 下会被提交的每一个文件」。一句话的事，我没动。
3. **`docs/team/tools/release-check.sh` 的两处红**（PM 目录，见 evidence）：route 3 的裸 `team init`
   需要跟着路由 change 补 `--task-models`/`--pm-model`（否则发布前检查恒有 1 条红）；旧内部 tag 线
   （`v1.4x`）是否迁移/重打，属于发布决定，不是文本清理能解决的。
4. `docs/team/reviews/P233.md:73`、`docs/team/tasks/P212-*.md` 等**历史记录**里仍写着旧面
   （`docs/team/**/*.md`）——它们是当时状态的真实记录，按「不许改历史记录」我没动。

## Suggested next steps

- **独立复验**：我写过 apply，按 D31 不能自己验；请派一个没写过本任务的席位（`team review P231 --strong`）。
- 上节 1–3 需要 PM 裁断/落盘；`BLOCKED:` 意义上的阻塞**没有**——本交付的两个部分都已落地并各自带红侧。
- 复验时可先跑：`pkg/redside-names.sh`、`pkg/redside-face.sh`、`pkg/flip-both.sh`（都只读仓库、写自己的
  临时根），再跑任务书那 6 条验收。

## 未做项（点名）

- 历史改写 / force-push：明令禁止，未做。
- `.pi/team/forbidden-names.txt`：未改、未提交（worktree 里那份是**被忽略**的本地副本，只为让验收命令走真名单）。
- `docs/team/DECISIONS.md`：PM 单写者，未动。
- 上节 1–3 的跨目录改动：按边界交回 PM（不是漏做，是不许顺手做）。
- 本报告**没有**跑的：整套全量门禁（只跑了与改动相关的 §60、§6e 与上面几条）；FAST/全量留给复验与合并。
