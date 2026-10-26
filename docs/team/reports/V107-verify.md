# V107 · 独立复验：61b 单条翻转臂（`init-legacy-proceeds`）的修复

agent: verify   status: pass   phase: verify   change: -   deltas: -   category: verify
specs: `verification#The gate judges behaviour only, and never reports a skip as a pass`
anchor: none (infra) — 独立复验夹具/翻转契约修复
branch: `task/V107-routing-bootstrap-flip-review`（local 模式，未推）   time: 2026-10-26T11:11Z

## 结论（先看这一段）

**PASS。** 候选 `42064b9d`（测试改动 `ca112db6`）的修复成立，任务书四条要求逐条有实跑证据：

1. **老期望确实测不到东西，原因就是作者说的那个。** 变异 scratch 只拷 `scripts/references/templates/extension`
   （`task-model-routing.sh:1443-1449`），不是可安装的 skill 源；变异体里 bootstrap 过了模型策略闸门
   （打印 `模型策略 vendor/light ［独立 PM：vendor/pm:high］`、`配置已存在…保留你的设置`），随后在
   `✗ 技能源不合法：… 没有 SKILL.md` 处 rc=1。于是只看 rc≠0 的 `init-legacy-bootstrap-refused`
   在**控制与变异两侧都 PASS** —— 我在三棵树上的实测：`PASS init-legacy-bootstrap-refused`（control）、
   `PASS`（mutant）、`PASS`（未变异同形 scratch），`^FAIL init-legacy-bootstrap-refused$` 三处都是 0。
2. **新断言有判别力**：变异体 3/3 命中（`derived`、`startup-route`、`print-refused`），未变异真树 0/3，
   未变异同形 scratch 0/3。
3. **改动只有那一处、契约没有被削弱**：相对 `fd971b5a` 只有一个 hunk（`@@ -1493 +1493,10 @@`，+10/−1），
   真树的 `check init-legacy-bootstrap-refused` 仍在原位 `:829` 逐字节未动，产品代码零差异
   （`git diff --stat d8a21c03..42064b9d` 只有 `docs/` 与这一个测试文件）。臂内 check 由 3 条变 5 条。
4. **轻量收口全绿**：`bash -n` rc=0、`git diff --check` rc=0、ledger ban 命中 0。

我的变异复现给出 `RESULT pass=29 fail=39 selected=init`，与 0.3.4 冻结门那一轮该臂的
`RESULT pass=29 fail=39 selected=init` **逐字相同**（冻结门日志 `p238-routing-flip.log:259`）——
说明我复制出来的 scratch 与闸门里那棵是同一形状、同一失败面。

边界（见 §6）：**没有**重跑整份 `--flip`、**没有**跑全量门禁；非 `--print` 路径的 **rc 级**翻转仍未覆盖
（该路径的 rc 被装 skill 的失败钉死，这是作者已记录的后续项，属 PM 取舍，不影响本次判定）。

## 复验对象与私有副本

| 项目 | 值 |
|---|---|
| 复验时的分支 tip | `d7bdcbbc`（`task/P377-routing-bootstrap-flip`；我的实跑是在 `42064b9d` 上做的，两者测试文件逐字节相同，核对见下表后一段） |
| 测试改动 | `ca112db6` · `skills/teamsmith/tests/task-model-routing.sh` · +10/−1 |
| 作者报告 | 该分支 `docs/team/reports/P377-dev.md`（本分支不可见，从候选提交读出） |
| 我的私有副本 | `<base>` = 私有目录；候选树是 `git archive 42064b9d` 解出的**全量独立副本**，与我的工作树无关 |
| 私有副本一致性 | `git show 42064b9d:…task-model-routing.sh` 与副本 `sha256 = 11c4c4e2dd5c…f4c7cfa507c` |

**候选前进到 `d7bdcbbc` 后的核对（2026-10-26T11:12Z）**：`git diff 42064b9d..d7bdcbbc` 只有
`docs/team/reports/P377-dev.md` 的 `time:` 一行（`11:35Z` → `11:06Z`）；`ca112db6` / `42064b9d` /
`d7bdcbbc` 三个提交的 `task-model-routing.sh` sha256 同为 `11c4c4e2dd5c…f4c7cfa507c`，且
`git diff --stat d8a21c03..d7bdcbbc -- skills/` 仍是那一个测试文件（+10/−1）。所以下面全部实跑证据
原样适用于新 tip，**没有重跑，也没有重开审阅**。

`<base>` 里的三棵树都是我这次现场建的，没有复用作者的目录：

```
<base>/candidate   ← git archive 42064b9d（未变异真树：对照）
<base>/mutants/init-legacy-proceeds ← scratch 形状（只拷四个目录）+ touch .routing-mutant + flips.py 变异
<base>/sameshape   ← 同样的四个目录、同样的形状，但**不打变异**（反向对照）
```

## 1 · 单臂复现：三棵树

命令（每棵树一次，只跑 `init` 组，不是整套 flip）：

```
$ TMPDIR=<base>/tmp/control TEAM_ROUTING_EVIDENCE=<base>/ev-control \
    bash <base>/candidate/skills/teamsmith/tests/task-model-routing.sh --select init
RESULT pass=68 fail=0 selected=init                                            rc=0   6s

$ python3 <base>/candidate/skills/teamsmith/tests/lib/model-routing-flips.py \
    <base>/mutants/init-legacy-proceeds init-legacy-proceeds
{"mutation": "init-legacy-proceeds", "changes": [{"file": "…/cmd-project.sh", "matched": 1, "before": "b69dbb56…", "after": "24ff0340…"}, {"file": "…/cmd-project.sh", "matched": 1, "before": "24ff0340…", "after": "022b5088…"}]}   rc=0

$ TMPDIR=<base>/tmp/mutant TEAM_ROUTING_TREE=<base>/mutants/init-legacy-proceeds \
  TEAM_ROUTING_EVIDENCE=<base>/ev-mutant \
    bash <base>/candidate/skills/teamsmith/tests/task-model-routing.sh --select init
RESULT pass=29 fail=39 selected=init                                           rc=1   7s

$ TMPDIR=<base>/tmp/sameshape TEAM_ROUTING_TREE=<base>/sameshape \
  TEAM_ROUTING_EVIDENCE=<base>/ev-sameshape \
    bash <base>/candidate/skills/teamsmith/tests/task-model-routing.sh --select init
RESULT pass=67 fail=1 selected=init                                            rc=1   6s
FAIL init-bootstrap-fresh-rc        ← 同形 scratch 唯一红：这棵树装不了 skill，与本次判据无关
```

变异是否真的落地（读我这份 scratch 的产品库，不是作者的报告）：

```
$ grep -n "P235_FLIP_init-legacy-proceeds\|P238_FLIP_init-legacy-proceeds-policy" -A2 …/cmd-project.sh
73:  return 0 # P235_FLIP_init-legacy-proceeds
81:  printf '%s\n' vendor/light; printf '%s\n' vendor/pm:high # P238_FLIP_init-legacy-proceeds-policy
```

冻结门那一轮该臂的臂级结果（只读已存在的日志，未重跑）：

```
$ grep -a -n -B6 -A1 '^FAIL flip-init-legacy-proceeds-bootstrap$' \
    "$HOME/.cache/release034/tmp/teamsmith-smoke-work-0c9a453f.sBd9jn/p238-routing-flip.log"
259-RESULT pass=29 fail=39 selected=init
260-evidence: /evidence/tmp/…/flip-evidence/init-legacy-proceeds/…
261-PASS flip-init-legacy-proceeds-red
262-PASS flip-init-legacy-proceeds-named-assertion
263-PASS flip-init-legacy-proceeds-plain
264-PASS flip-init-legacy-proceeds-force
265:FAIL flip-init-legacy-proceeds-bootstrap          ← 冻结门唯一的**外层**红
266-PASS flip-init-legacy-proceeds-source-restored
$ grep -a '^RESULT .* selected=flip$' …/p238-routing-flip.log
RESULT pass=200 fail=1 selected=flip
```

即：臂本身是红的（`flip-init-legacy-proceeds-red` PASS，因为变异体的 `init` 组 rc=1），缺的只是**命名断言**
那一条；这与我复现出的 `pass=29 fail=39` 逐字相同。

## 2 · 机制：bootstrap 到底在哪一步死

三个证据目录里的 `init-cmds.log`（`i_run` 原样记录的 `command` / `rc` / 输出），路径掩成 `<base>`：

```
##### 变异体（<base>/ev-mutant/…/init-cmds.log:191）
command=bootstrap --no-pulse --agents dev
rc=1
teamsmith bootstrap · init-legacy
  模型策略    vendor/light ［独立 PM：vendor/pm:high］        ← 模型策略闸门被拆掉后**通过了**
  配置已存在：…/init-legacy/.pi/team/config.sh（保留你的设置）
✗ 技能源不合法：<base>/mutants/init-legacy-proceeds/skills/teamsmith 没有 SKILL.md —— …
  miss  teamsmith-init（源 <base>/mutants/init-legacy-proceeds/skills/teamsmith-init 不在：…）
  miss  handover（源 <base>/mutants/init-legacy-proceeds/skills/handover 不在：…）
✗ 找不到可安装的 skill 源（…）
```

```
##### 未变异真树（ev-control）与未变异同形 scratch（ev-sameshape）：除夹具临时路径外逐字相同
command=bootstrap --no-pulse --agents dev
rc=1
✗ bootstrap: …/init-legacy/.pi/team/config.sh 还在用退休的模型键（TEAM_DEFAULT_MODEL TEAM_AGENT_MODELS）—— 任何写入之前停住
  项目模型策略是破坏式升级：bootstrap 不是迁移路径（init --force 也不是）
  路线 ① 手工事务（先预览）：team config upgrade-models --task-models 'dev=p/old default=p/old' --pm-model 'p/old' --dry-run
  路线 ② 启动事务（机械形状由它迁移）：team up（--print 只预告，--no-migrate 只报告）
```

```
##### 变异体的 --print 路径（ev-mutant:205）：rc 侧真的翻转了
command=bootstrap --no-pulse --agents dev --print
rc=0
（--print：只看计划，什么都没改）
```

所以：`-refused` 只看 rc，而这条路径的 rc 在**两侧都是 1**（控制因闸门、变异因装 skill），它从一开始就没在测这条变异；
闸门被拆掉后真正消失的是拒绝输出里的两条路线与推导命令（`derived` / `startup-route`），
不装 skill 的 `--print` 路径则是 rc 从 1 变 0（`print-refused`）。

## 3 · 判别力矩阵（臂的 grep 打在三种日志上）

`check NAME grep -q '^FAIL <check>$' "$TMP/flip-$mutation.log"` 的完全等价复算：

```
pattern                                       control  mutant  sameshape
^FAIL init-legacy-bootstrap-refused$               0       0         0     ← 老期望：两侧皆 0（永远红）
^FAIL init-legacy-bootstrap-derived$               0       1         0
^FAIL init-legacy-bootstrap-startup-route$         0       1         0
^FAIL init-legacy-print-refused$                   0       1         0
```

`grep -q` 的 rc（0=命中=该 check 通过；1=未命中=该 check 红），三种日志 × 四个模式：

```
init-legacy-bootstrap-refused              control=1 mutant=1 sameshape=1
init-legacy-bootstrap-derived              control=1 mutant=0 sameshape=1
init-legacy-bootstrap-startup-route        control=1 mutant=0 sameshape=1
init-legacy-print-refused                  control=1 mutant=0 sameshape=1
```

- **变异体**：新三条全部 rc=0（命中），老那条 rc=1 —— 这就是冻结门那条红。
- **未变异真树**：新三条 rc=1（没命中）→ 变异没落地时臂照样红，不是橡皮章。
- **未变异同形 scratch**：新三条同样 rc=1 —— 同形树上的「装 skill 失败」没有被误当成这条臂的证据；
  该树唯一的红是 `init-bootstrap-fresh-rc`（另一个 check），不在本臂的 grep 集合里。
- 臂内另两条断言在变异日志里都在：`FAIL init-legacy-plain-refused`、`FAIL init-legacy-force-refused`。
- 三份日志 `^SKIP ` 计数均为 0（没有把「缺拒绝」变成 skip）。

## 4 · 差异审查：只有一处，且是真替换不是削弱

```
$ git diff -U0 fd971b5a..ca112db6 -- skills/teamsmith/tests/task-model-routing.sh | grep '^@@'
@@ -1493 +1493,10 @@ if has flip; then          ← 只有一个 hunk，落在 init-legacy-proceeds 分支内
$ git diff --stat fd971b5a..42064b9d
 2 files changed, 224 insertions(+), 1 deletion(-)        ← 测试文件 +10/−1，作者报告 +214
$ git diff --stat d8a21c03..42064b9d
 5 files changed, 316 insertions(+), 1 deletion(-)        ← 其余全是 docs/（BOARD、任务书、报告）
```

- 删掉的那一行：`check flip-init-legacy-proceeds-bootstrap grep -q '^FAIL init-legacy-bootstrap-refused$'`
  —— 就是 §3 里「两侧皆 0」的那条不可判别期望。
- 换上的三行：同一路径的两条**路线**断言（`derived` / `startup-route`）+ 不装 skill 路径的 rc 断言（`print-refused`）。
- 真树的命名断言 `init-legacy-bootstrap-refused`（`:829`）、`bootstrap-derived`（`:831`）、
  `bootstrap-startup-route`（`:832`）、`print-refused`（`:834`）**逐字节未动**；未变异真树 `--select init`
  `68 fail=0` 也证明它们仍然承重。
- 臂内 check 数 3 → 5（`grep -c 'check flip-init-legacy-proceeds'`：旧 3 / 新 5），5 个 check 名全局唯一。
  因此下一次整套 flip 的 `RESULT` 应为 **pass=203 fail=0**（推算，**未实测**，任务书禁止重跑整份 flip）：
  冻结门那次是 200 pass + 1 fail = 201 条，本臂占 3 条、其中 2 条已计入那 200（日志 263–265 行
  `plain`/`force` PASS、`bootstrap` FAIL）；换成 5 条全绿后是 200−2+5 = **203 pass / 0 fail**。
  ⚠ 作者报告 §Notes 写的是「200 → 202」，**少算了一位**（它把那条失败当成原本通过）；
  这只是报告里的预期数字错，不影响代码与契约，但发布验收时请按 203 对表。
- 没有新增段、没有新增夹具、没有 `|| true`、没有把任何断言改成 skip；`flip-init-legacy-proceeds-red` /
  `-named-assertion` / `-source-restored` 的结构未变。

## Flip evidence（defect-fix 必填）

**red → green（同一份变异日志、同一组 grep，改前 / 改后）**

```
# 改前：臂点不到名（0.3.4 冻结门那条红）
$ grep -q '^FAIL init-legacy-bootstrap-refused$' <base>/runs/mutant.log; echo $?
1
# 改后：三条新断言逐条命中
$ grep -q '^FAIL init-legacy-bootstrap-derived$'        <base>/runs/mutant.log; echo $?
0
$ grep -q '^FAIL init-legacy-bootstrap-startup-route$'  <base>/runs/mutant.log; echo $?
0
$ grep -q '^FAIL init-legacy-print-refused$'            <base>/runs/mutant.log; echo $?
0
```

**反向控制（断言不是橡皮章）**：同一组 grep 打在未变异真树与未变异同形 scratch 上都是 **0/3**
（`grep -q` rc=1），也就是「变异没落地 → 臂必须红」仍然成立。

## 5 · 轻量收口

```
$ bash -n <base>/candidate/skills/teamsmith/tests/task-model-routing.sh; echo rc=$?
rc=0
$ git diff --check d8a21c03..42064b9d; echo rc=$?
rc=0
$ bash skills/teamsmith/tests/ledger-ban.sh --root <base>/candidate --names-file <名单文件>; echo rc=$?
ledger-ban: root=<base>/candidate scope=published files=2195 hits=0 names=ok user=resolved
rc=0
$ bash skills/teamsmith/tests/ledger-ban.sh --root <我的工作树> --names-file <名单文件>; echo rc=$?
ledger-ban: root=…/.worktrees/verify scope=published files=2195 hits=0 names=ok user=resolved
rc=0
```

（候选副本那一次为了 `git ls-files` 先在私有目录里 `git init` 了一份本地索引，与仓库无关。）

## 6 · 剩余边界与给 PM 的判定

- **非 `--print` 路径仍只有消息级翻转**：该路径 rc 在控制与变异两侧恒为 1（控制因闸门、变异因装 skill），
  所以 rc 级断言在这棵 scratch 上不可实现；要它成立必须给 scratch 一个可安装的 skill 源，并整套重跑 flip。
  这是作者已记录的取舍，我这边**未**扩大范围。它改变的是「后续可选项」，不是本次判定。
- **未见削弱契约的痕迹**：唯一被删的是一条两侧皆绿的期望；真树的 `init-legacy-bootstrap-refused` 仍在原位，
  未变异真树 `68/0` 是它仍承重的证据。
- **未做**（任务书明确禁止）：整份 `--flip`、全量门禁、0.3.4 最终 tip 上的重跑。
- 建议：接受本次修复；`--select flip`（或最终 tip 的整套门禁）在最终候选上重跑一次，确认 §61b 由
  `pass=200 fail=1` 变为 `pass=203 fail=0`（推算见 §4）且其余 30 条臂不变。
