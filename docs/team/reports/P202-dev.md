# P202 · routes.sh 翻转②的判据：变异其实落地了，是判据把自己的证据读成了「没命中」

agent: dev   status: DONE   time: 2026-10-03T07:10Z
branch: `task/P202-apply`（本地分支，无远端；tip = `b89ccf27` + 本报告的提交）   PR/MR: -（local 模式）
change: -   phase: apply
verdict: **定位到确切原因（判据读证据的方式错，不是变异没落地），修掉它，并给每个翻转补上「先证明变异落地，再判红」这一步及其自己的红侧。**

## 交付物

| 路径 | 内容 |
|---|---|
| `skills/teamsmith/tests/routes.sh` | 判定改为直接读日志文件（不再经管道）；新增 `mr_flip_landed` / `mr_flip_require` 落地判据；⑧ 的旋钮另有一条独立证明；两条落地判据红侧；「只贴真 finding」的钉子 |
| `docs/team/reports/P202-dev.md` | 本报告 |
| `docs/team/reports/P202-dev/evidence/` | 每条证据的原始输出与复现脚本（`01`–`08` 是输出，`p202-*.sh` 是脚本） |

只动了任务书 grant 里的两个位置（`skills/teamsmith/tests/routes.sh`、本报告目录）。没碰 smoke.sh、没碰别的席位目录、没碰任务书。

## 要做的 1 · 定位（确切原因 + 行号）

**结论：PM 的假设（夹具的变异没落地）在这条链上不成立；真正失效的是判据读证据的那一步。**

**① 副本里有没有当前形状的 `cmd-project.sh`？有，逐字都有。** `mr_scratch_tree` 的副本里
`scripts/lib/cmd-project.sh:43` 是
`  add-agent <a> [--register] [--model m] [--create] [--no-install] [--print]  建长期 worktree（分支 agent/<a>）；`
（PM 的 `/tmp/final-gate` 副本同形、`git status` 干净），翻转②的模式 `add-agent <a> \[--register\]` 与它相容。
我照 `routes.sh:1330` 那行原样跑一遍 sed：`--register` 那一行确实变成 `[--fresh]`；计数上
`grep -cF 'add-agent <a> [--register]'` 真树 1 → 副本 0、`grep -cF 'add-agent <a> [--fresh]'` 真树 0 → 副本 1。

**② 我在容器里独立复现了嵌套那一臂**（`evidence/02-arms-pristine-vs-mutated.txt`，脚本 `p202-arms.sh`）：

```text
arm=pristine   mutation=no  walk_rc=0 log_bytes=13326 matches_pattern=0 findings=0
    verdict=没有兑现                      ← 没变异 → 嵌套 walk 是绿的，「没兑现」在这里是对的
arm=mutated    mutation=yes walk_rc=1 log_bytes=13297 matches_pattern=1 findings=1
      ✗ 断言 L38：add-agent --fresh 被自己的解析器拒绝（原文：✗ add-agent: 未知参数 --fresh）
    verdict=ok
```

也就是说：**嵌套 walk 红 ⇒ 变异落地了**（未变异的副本嵌走是绿的）。现场「rc=1 且判据说没命中」只能是判据这一侧出的错。

**③ 判据这一侧的确切原因（行号，按修复前的 `8ca694cc`）**

- `routes.sh:41` 的 `set -uo pipefail`；
- `routes.sh:1332`（翻转②的判定）：
  `if [ "$MR_FLIP_RC" != "0" ] && printf '%s' "$MR_FLIP_LOG" | grep -q 'add-agent --fresh'; then`
- `grep -q` 一命中就退出；这时把整段日志往管道里写的 `printf` 还没写完，收 SIGPIPE(141)；
  `pipefail` 把整条管道判成非 0 → `if` 走 else → 打印 `翻转②没有兑现`，而那段日志里
  `✗ 断言 L38：add-agent --fresh 被自己的解析器拒绝` 就在 `$MR_FLIP_LOG` 里、还被同一行当证据贴出来。
- 同一形状在 ①③⑤⑥⑦⑨⑩ 七处判定里也在用 —— 这是家族问题，不是翻转②一处。

**④ 复现（`evidence/04-r2-shape-and-clean-flips.txt`，脚本 `p202-r2-standalone.sh`，容器内）**

```text
== shipped helper (extracted verbatim from the file) ==
    mr_flip_log_has() {
      local p
      for p in "$@"; do grep -qF -- "$p" "$MR_FLIP_LOGF" || return 1; done
      return 0
    }
-- log 13KB（命中点在中间：77 行；管道默认 64KB）--
  old shape, default pipe          bytes=13187    false-verdicts=0/3
  old shape, 4KB pipe              bytes=13187    false-verdicts=3/3
  shipped mr_flip_log_has          bytes=13187    false-verdicts=0/3
-- log 200KB（命中点在中间：1178 行；管道默认 64KB）--
  old shape, default pipe          bytes=203826   false-verdicts=3/3
  old shape, 4KB pipe              bytes=203826   false-verdicts=3/3
  shipped mr_flip_log_has          bytes=203826   false-verdicts=0/3
```

同一条日志、同一个命中：管道形状会把命中读成没命中（日志够大时不用任何手段就能撞上；管道变小时必然撞上——
Linux 在用户管道内存配额吃紧时本来就会把新管道发成一页），而直接读文件的判据在任何尺寸下都读到命中。
**这条误判与日志内容无关，所以它不可能靠「让变异更可靠」修掉。**

**⑤ 还缺的一半（M21 那一族，也是任务书要求补的）**：翻转从来只判「walk 红没红 + 日志里有没有那句话」，
从不检查自己那笔变异有没有真的写进副本。于是「模式陈旧 / 锚点移动 / 文件没写成」与「守卫真没红」会给出**同一句**
`没有兑现` —— 读的人分不开。现场的证词正是这样：那条 `没有兑现` 后面只贴了两条含 `✗` 的行，而那两条是
`✓ 断言 L31/L35` 的正文（用法行里本来就有一个 `✗` 标记），不是 finding。新代码把这段证据换成
**只贴真 finding**（红色的 `✗`），并给这条行为加了钉子（见「要做的 3」末条）。

## 要做的 2 · 修

1. 判定改成读文件：`mr_flip_log_has <literal…>`（`grep -qF -- "$p" "$MR_FLIP_LOGF"`，**一个管道都不用**），
   十处判定全部换过去；判据本身**一点没放松**（还是 `rc≠0` 且点名，⑥ 的「只点名该键」也照旧）。
2. 证据改成 `mr_flip_evidence`：优先贴前两条**真 finding**；一条都没有时贴日志尾巴（例如嵌套 run 起不来）。
3. 落地判据 `mr_flip_landed`（纯判据，理由写 `MR_FLIP_WHY`）+ `mr_flip_require`（发 finding 的包装）。
   每个翻转在跑嵌套 run **之前**先过三条：副本与真树**逐字节不同**（静默 no-op 在这里就断）、`gone` 由 1 变 0、
   `present` 由 0 变 1（`gone`/`present` 可以给 `-` 表示这一侧不适用）。不成立就报
   **`变异没落地（夹具缺陷）—— <具体计数>`**，并**跳过**那个嵌套 run（没改到东西，判它红不红没有信息）。
4. ⑧ 是旋钮不是文本，单独给它一条独立证明：helper 里确实有 `noreap` 分支（真树里数得着）**且**这次 run 真的没回收
   ——私有 `TMPDIR` 里直接 `find` 得到一个留下的 `teamsmith-routes.*` 根。它与收尾扫描互为对照：
   根在、扫描看不见 = 扫描瞎了；根不在 = 旋钮没生效。
5. 翻转④的落地证明只查 `gone` 一侧并写明了理由：这步只动行首两个空格，去空格后的行**仍包含**原文本，
   「0→1」用子串表达不出来；而「带两空格的形式 1→0」＋「副本与真树逐字节不同」已经排除「没改」。

## 要做的 3 · 落地判据自己的红侧

两条红侧就在 flips 段里（`evidence/07-gates-final-tip.txt`，出货代码上）：

```text
  ✓ 落地判据红侧 a：陈旧 sed（搜索端不存在）→ 判据报「变异没落地」：scripts/lib/cmd-project.sh 与真树逐字节相同 —— 变异一个字都没改
  ✓ 落地判据红侧 b：只插不删 → 判据报「变异没落地」：目标文本还在：gone 1→1（替换没匹配上）
```

两条都只做文件级检查、不跑嵌套 run（几毫秒）。a 打的是「一个字都没改」，b 打的是「`gone` 一侧承重」。

末条 `判据卫生` 钉的是「没有兑现时只贴真 finding」：拿一段同时含
`✓ 断言 L31：… ｜ ✗ change status <id> [--json]` 与真 finding 的日志喂给 `mr_flip_evidence`，
要求输出里有 finding、没有那条用法行标记（把 helper 改回宽 `grep '✗'` 就会红）。

## 翻转证据（缺陷类任务要求）

**红侧 1 · 让变异真的落空 → 必须报「变异没落地」，不能报「没有兑现」**
（`evidence/03-adversarial-r1-r3.txt`，脚本 `p202-adversarial.sh`；把出货夹具复制一份，只把翻转②的 sed 搜索端改成陈旧的 `--frosh`）

```text
== r1 · flips rc=1 ==
      ✓ 翻转①：help 打印 --model 而解析器拒绝 → walk 红并点名 add-agent --model
      ✗ 翻转②：变异没落地（夹具缺陷）—— scripts/lib/cmd-project.sh 与真树逐字节相同 —— 变异一个字都没改
      ✓ 落地判据红侧 a：…   ✓ 落地判据红侧 b：…
      ✓ 翻转③ … ⑩对照（后面各臂照旧）
```

翻转②的嵌套 run 一次都没跑（该行之后没有 `翻转②没有兑现`），判词也换了主人：**夹具缺陷**，不再是守卫的罪。

**红侧 2 · 把落地判据打残成「永远说落地了」 → 两条红侧必须自己红**
（同一份脚本的 r3 臂）

```text
== r3 · flips rc=1 ==
      ✓ 翻转① …  ✓ 翻转②：add-agent 行印上兄弟命令的 --fresh → walk 红并点名 add-agent --fresh
      ✗ 落地判据红侧 a：陈旧 sed 什么也没改，判据却放行了（判据是橡皮章）
      ✗ 落地判据红侧 b：旧文本还在（只插不删），判据却放行了
```

**绿侧 · 出货代码上全臂绿**（容器内，最终 tip 的 §51；`evidence/07-gates-final-tip.txt`）

```text
  ✓ 51 routes.sh 全绿（209 条断言，1 条可见跳过）
        ✓ 翻转① … ✓ 翻转⑩、✓ 翻转⑩对照
  ✓ 51 名册/契约夹具（list+validate+roster）全绿（136 条断言）
```

（`evidence/04-…txt` 末段另有一次只跑 `flips` 的独立记录：`== 结果 == ✓ 14 ✗ 0`，那是加钉子之前的那一版，14 条 = 十臂 + ⑩对照 + 两条红侧 + 收尾。）

**判据形状的红绿对照**就是上面 ④ 的表：同一条日志，旧形状 3/3 误判（200KB，无需任何手段）、新形状 0/3。

## 门禁

容器 `localhost/teamsmith-gate:local`（`--rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp`），
树是本分支 tip 的**独立克隆** `/tmp/p202-branch`（`git clone --no-hardlinks --branch task/P202-apply`，见文末「工作树」一节）。

```text
### clone tip ###
b89ccf27 test(teamsmith): P202 — pin the evidence helper (only a real finding is quoted as evidence)
### openspec validate --all --strict ###
VALIDATE_RC=0
Totals: 13 passed, 0 failed (13 items)
### smoke --select 51（含 0d + 整个 routes.sh：walk/control/promises/refusals/flips）###
RC51=0
  ✓ 51 routes.sh 全绿（209 条断言，1 条可见跳过）
  ✓ 51 名册/契约夹具（list+validate+roster）全绿（136 条断言）
#5 51 · 用法诚实性：… · 用时 276s · ✓2 ✗0 SKIP0 · ticks 2
账本自查： 5 段收口 · 增量 ✓23 ✗0 SKIP0 ｜ 结果行 ✓23 ✗0 —— 一致
== 选段结果 ==  ✓ 23  ✗ 0
### TEAM_SMOKE_FAST=1 smoke（跑在 2e3c43df，见下）###
RCFAST=0
== 结果 ==  ✓ 3801  ✗ 0
smoke 全绿
```

FAST 那轮跑在本分支的前一个提交 `2e3c43df` 上：后来那个钉子只加在 `mr_flips()` 里面，而 FAST 按契约
**跳过 flips**（同一份契约里 `TEAM_ROUTES_FAST=1` 让 walk/control/promises/refusals 跑、flips 可见地 SKIP），
所以 FAST 到不了那段代码；最终 tip 上的 `--select 51`（**不跳过** flips，上面那条 209 断言就是它跑的）已覆盖该改动。
没有重跑 FAST 的第二个理由是机器：`--select 51` 是 276s，FAST 是 25 分钟，而两者对这次改动是等价的。

早先还有一轮门禁（`evidence/06-…txt`）**作废**：它跑到一半时 `.worktrees/dev` 被切到了 `task/P205-apply`
（见文末），于是它后半段的树不是我的 —— 那一轮里 0d 报红（`✓8 ✗1`，冲突标记）、FAST 报 `✗ 10`，
在干净克隆上重跑分别是 `0d ✓9 ✗0` 和 `✗ 0`。作废那一轮的 §51 段（跑在我自己的树上，`✓2 ✗0`、208 条断言）与最终轮一致。

## 哪些是我跑的 / 哪些是引用

- **我跑的**：上面 ②③④、红/绿各侧、`--select 0d`/`--select 51`/FAST/validate（门禁一节）；以及真树/副本的
  `grep -cF` 计数、`sed -n '43p'` 的前后对照（宿主上的只读命令）。
- **引用的**：PM 在真树上的实测（`routes.sh walk` rc=1 且日志里有 `add-agent --fresh`）—— 与我的 ② 结论一致，
  我没有重复它。现场原始证据来自 PM 的 `final-gate.log`（`/tmp/final-gate.log:4772`）与 `.pi/team/state/bg/release-final-gate-2.log`。
- **没测到**：PM 那次运行的 `routes.log`（在门禁容器里，`--rm` 后没了），所以「那一次到底是哪一侧失败」我无法逐字证明。
  两侧现在都补上了并且可区分：变异没落地 → 夹具缺陷；落地了而守卫没红 → 没有兑现 + 真 finding 现场。

## 范围之外的一条记录（只记，不做）

同一个形状（`printf '%s' "$var" | grep -q …`）在技能里还很多：`grep -rn "| grep -q" skills/teamsmith/tests/*.sh | grep -c printf` 数到 113 行。
它们是否可达取决于该脚本有没有 `pipefail`、以及载荷有没有超过管道容量（默认 64KB，配额吃紧时更小）——
我没有逐条判，也没有改（任务书只授权 `routes.sh` 一处）。若要把这个形状收口，那是一个单独的任务。

## 工作树（需要 PM 知道的一件事）

本回合中途，`.worktrees/dev` 被切到 `task/P205-apply`（`git reflog`：`checkout: moving from task/P202-apply to task/P205-apply`；
与 `.pi/team/state/dev.env` 的 `branch=task/P205-apply`、线程里「P205 排队等你（先做完 P202）」一致）。
我没有把工作树切回去（那会动到 P205 的派单状态），改为：在本分支 tip 的**临时克隆** `/tmp/p202-branch` 里跑门禁、
写报告并提交，然后把提交取回共享仓库的 `task/P202-apply`（`git fetch /tmp/p202-branch task/P202-apply` + `update-ref`，
不 push、不 checkout、不碰 main、不碰任何工作树）。工作树仍停在 `task/P205-apply`，P205 可以随时开跑。

分支上的提交（本地，等 PM 复验后合并）：

| 提交 | 内容 |
|---|---|
| `2e3c43df` | 判定读文件 + 落地判据 + 两条红侧 + ⑧ 的旋钮证明 |
| `b89ccf27` | 「没有兑现时只贴真 finding」的钉子 |
| 本报告的提交 | 报告 + `evidence/` |
