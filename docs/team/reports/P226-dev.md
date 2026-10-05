# P226 · 探针夹具自洽：删掉「源树里在就拷进来」，复原了证据层的检出也全绿

agent: dev   status: DONE   time: 2026-10-05 10:30 UTC
branch: `task/P226-apply`   PR/MR: -（本地模式，无远端；分支留在本地等 PM 复验后合并）

## 缺陷与根因

`skills/teamsmith/tests/checkout-shape-probe.sh` 的 `scratch_tree` 在造 internal / mixed 形状的树时，会把两份
历史豁免清单（`tmux-lint-legacy.txt`、`signal-lint-legacy.txt`）里注册的 `docs/team/reports/*/pkg/**`
**从环境（源检出）里拷进 scratch 树**（注释原话：「源树里在就拷进来」）。而 ⑨b / ⑩ 为了证明「有一条注册
文件在位 → §31 / §58 照旧判定、不跳过」，会把树里那份清单**重写成只登记自己声明的那一条**合成证据文件。

于是同一棵树里同时存在两种东西：环境带进来的注册文件（清单里没有它们），和清单唯一登记的那一条。
两条 lint 的判据是「清单里每一条都要在位」，逐条核对时把继承来的文件判红 —— ⑨ / ⑩ 各两条断言随之
变红（退出码 + LEGACY / 清单判定行），共 4 条。

**缺陷在夹具，不在产品**：夹具吃了环境，所以同一条断言在不复原证据层的检出里绿、在复原了证据层的检出
里红。P225 的复验正是后者（它按清单从仓外账本归档逐条复原了 17 个注册文件），于是 ⑨/⑩ 两段各红两条。
这也解释了为什么 CI / 公开 clone 一直是绿的：那里本来就没有证据层可吃。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/checkout-shape-probe.sh` | 见下「做法」：构造自洽的 scratch 树 + 两条树自洽守卫 + ⑤d 空面断言 |
| `docs/team/reports/P226-dev.md` | 本报告 |
| `docs/team/reports/P226-dev/`（D94：证据层不进仓库，只在本机） | 复现脚本（`build-restored.sh` / `mutate-eat-evidence.sh` / `run-flip.sh` / `run-copy.sh`）与十次容器运行的原始日志（五个对照运行 + `run-flip.sh` 的一轮五个） |

## 做法与取舍

1. **树做成自洽的，而不是把清单写全。** 用例要证明的是「有一条注册文件在位 → 照旧判定」，它必须自己
   **声明**那一条；若改成「把环境里那 17 条也登记进清单」，在不复原证据层的检出里（CI、公开 clone）
   清单就指向不存在的文件，同一条断言照样红 —— 只是把非确定性从一个环境搬到另一个环境。
2. `scratch_tree` 里删掉那段「源树里在就拷进来」，新增唯一执行点 `scratch_prune_evidence_layer()`：**所有
   形状**构造完显式剔除证据层（`docs/team/reports/*/pkg/**`）；mixed 分支原来那条 prune 并进同一个执行点，
   不留第二条拷贝路径。
3. **两条守卫直接咬住这次的回归**（在 ⑨ 里，紧挨着用它们的用例）：
   - `⑨ scratch 树自洽：构造后证据层为空（不吃环境里的注册文件）`（期望 0 个 pkg 文件）；
   - `⑨ 证据层只有用例自己声明的那一条注册文件（树自洽）`（声明之后期望 1）。
4. **⑤d 把 P225 的实测固化成断言**：机器生成面在位但是**空目录**时「整棵面不在」的跳过前提不成立 ——
   §19 的十条照旧判定并判红（§19 账本 `✓16 ✗10 SKIP0`、exit 1）；同一棵树删掉那两个空面 → 回到 10 条
   SKIP、绿。差别只在空目录，证明判据咬的是「面在（哪怕空目录）就不许跳」。

改动集中在探针这一个文件：`133ccaed` 是 `1 file changed, 50 insertions(+), 15 deletions(-)`，`4a6ca426`
只修了一处注释里的口径；本分支相对基线 `9695cd6e` 的全部改动 = 探针 65 行 + 本报告。

## Verification evidence（全部在容器 `localhost/teamsmith-gate:local` 里跑）

这五轮与 `run-flip.sh` 那一轮用的都是同一份探针（md5 `cf2cd83864d68822980ba90b3e0e451c`，即提交
`4a6ca426` 的内容；`run-flip.sh` 那轮树里只多了本报告的草稿）。此后本分支只加了报告提交，探针未再改动。
表里的日志路径相对本报告所在的 `docs/team/reports/P226-dev/`。

树都是工作树的 tar 副本 + `git init`（不含 worktree 的 `.git` 指针），与 CI 的新鲜检出同形：

```
$ bash docs/team/reports/P226-dev/build-restored.sh "$PWD" <ledger> /tmp/p226-final-restored
restored sha-ok=17 sha-bad=0 tip=fbb41e05215b9be1161035795f6a3809815c664f
$ tar -C "$PWD" --exclude=./.git -cf - . | tar -x -C /tmp/p226-final-default   # 默认环境（证据层不在）
$ distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp \
    -v <副本>:/work -w /work localhost/teamsmith-gate:local \
    bash -c "git config --global --add safe.directory '*'; bash skills/teamsmith/tests/checkout-shape-probe.sh"
```

| # | 跑什么（探针 md5 见括号） | 环境 | 结果 | 原始日志 |
|---|---|---|---|---|
| ① | 探针，**红前对照**（`2919685…`，= P226 之前的文件） | 复原 17/17 | `ok 134 bad 4 skip 0`，exit 1 | `logs/01-red-before-restored.log` |
| ② | 探针（`cf2cd83…`，= 本分支 HEAD） | 复原 17/17 | `ok 146 bad 0 skip 0`，exit 0 | `logs/02-green-after-restored.log` |
| ③ | 探针（`e36fb5f…`，= HEAD + 影子：把非隔离构造加回去） | 复原 17/17 | `ok 140 bad 6 skip 0`，exit 1 | `logs/03-shadow-mutated-restored.log` |
| ④ | 探针（`cf2cd83…`） | 默认（证据层不在） | `ok 146 bad 0 skip 0`，exit 0 | `logs/04-green-default.log` |
| ⑤ | `openspec validate --all --strict` + `smoke.sh --select 36` | 默认 | validate `Totals: 13 passed, 0 failed`，rc 0；§36 `用时 724s · ✓116 ✗0 SKIP3`，选段 `✓ 137 ✗ 0`，rc 0 | `logs/05-validate-and-section36.log` |

②③④ 的 134 → 146 的增量全部对得上：4 条由红转绿（⑨/⑩ 各两条）+ 6 条新 ⑤d + 2 条新 ⑨ 守卫。
⑤ 里 §36⑧ 自己也把探针跑了一遍：`✓ 36⑧ 产品面检出探针全绿（ok 146 bad 0 skip 0）`。

- Verdict: **pass**（探针两个环境状态都全绿；validate 与 §36 在默认环境里全绿）。
- 复现入口：`bash docs/team/reports/P226-dev/run-flip.sh <worktree> <ledger-root>`（全部在**副本**上做，
  不动工作树）。这条入口我自己跑完了一轮（本机 `/tmp/p226-logs-flip`，副本存于 `logs/run-flip/`）：

```
flip-1-restored-green        == 检出形状探针 == ok 146 bad 0 skip 0   (rc 0)
flip-2-shadow-red            == 检出形状探针 == ok 140 bad 6 skip 0   (rc 1)
flip-3-restored-green-again  == 检出形状探针 == ok 146 bad 0 skip 0   (rc 0)   # 影子还原后再跑
flip-4-default-green         == 检出形状探针 == ok 146 bad 0 skip 0   (rc 0)
flip-5-gate                  validate Totals: 13 passed, 0 failed；§36 rc 0
```

**哪些是我跑的、哪些是引用 P225 的**

- 我跑的：上面 ①～⑤ 五个容器运行；17 个注册文件的 sha256 逐条核对（17/17）；影子插入 / 还原的 md5
  对比；`run-flip.sh` 的一轮五个运行（`logs/run-flip/`）。
- 引用 P225 的：空面 `✓16 ✗10 SKIP0` 这个**数值**来自 P225 的复验记录（本任务的探针里没有产品面三形状
  的真跑表）；我只把它**固化成断言**，并在自己四次运行里验证它成立。P225 量到的 `ok 134 bad 4`（同一条探针、
  复原环境）被我用自己的副本原样复现了（①）。
- **没跑**（如实说明）：完整 `smoke.sh` 全套门禁（本任务只跑了 §36 这一段 + 探针 + validate，选段运行
  不是全套门禁）；§26-m 真 pane 组（`--select 36` 的嵌套跑走 FAST，本就跳过，与本次缺陷无关）；时序 /
  性能面板判定。

## Flip evidence

红→绿（同一棵复原树、同一条 `--select` 语义，只换探针文件）：

```
# ① 红前（P226 之前的探针，md5 2919685…）——4 条假红，正是 P225 量到的那四条
$ … checkout-shape-probe.sh   →  == 检出形状探针 == ok 134 bad 4 skip 0   (exit 1)
bad: ⑨ 内部树 + 清单文件都在 → --select 31 退出 0（照旧判定）（期望 [0]，实际 [1]）
bad: ⑨ 内部树 + 清单文件都在 → M28 照旧带清单跑（1 个历史豁免文件）（[
bad: ⑩ 内部树 + 清单文件都在 → --select 58 退出 0（照旧判定）（期望 [0]，实际 [1]）
bad: ⑩ 内部树 + 清单文件都在 → signal-lint 照旧逐条核对（LEGACY 打印）（[

# ② 绿后（本分支 HEAD，md5 cf2cd83…）
$ … checkout-shape-probe.sh   →  == 检出形状探针 == ok 146 bad 0 skip 0   (exit 0)
```

断掉实现 → 守卫必须红 → 还原（"break the implementation → the guard test must fail → restore it"）：

```
$ bash docs/team/reports/P226-dev/mutate-eat-evidence.sh /tmp/p226-final-restored apply
mutated before=cf2cd83864d68822980ba90b3e0e451c after=e36fb5f9d87ce388bfb6d0e73b76762e
$ … checkout-shape-probe.sh   →  == 检出形状探针 == ok 140 bad 6 skip 0   (exit 1)
bad: ⑨ scratch 树自洽：构造后证据层为空（不吃环境里的注册文件）（期望 [0]，实际 [17]）     ← 新守卫 1
bad: ⑨ 证据层只有用例自己声明的那一条注册文件（树自洽）（期望 [1]，实际 [18]）             ← 新守卫 2
bad: ⑨ 内部树 + 清单文件都在 → --select 31 退出 0（照旧判定）（期望 [0]，实际 [1]）        ← 原假红复现
bad: ⑨ 内部树 + 清单文件都在 → M28 照旧带清单跑（1 个历史豁免文件）（[
bad: ⑩ 内部树 + 清单文件都在 → --select 58 退出 0（照旧判定）（期望 [0]，实际 [1]）        ← 原假红复现
bad: ⑩ 内部树 + 清单文件都在 → signal-lint 照旧逐条核对（LEGACY 打印）（[

$ bash docs/team/reports/P226-dev/mutate-eat-evidence.sh /tmp/p226-final-restored restore
restored md5=cf2cd83864d68822980ba90b3e0e451c (branch copy of record=cf2cd83864d68822980ba90b3e0e451c)
```

影子的插法和还原都记在脚本里（`eat-evidence-snippet.sh` 是剪贴自 P226 之前的 `scratch_tree` 的那一段，只对
internal 形状生效）；还原后的 md5 与分支上的文件逐字节一致（上面最后一行），分支本身从未被改过 ——
`run-flip.sh` 的 flip-3 又把还原后的树跑了一遍，仍是 `ok 146 bad 0 skip 0`。

## Decisions and deviations

- 只改了探针一个文件；`lib/checkout-shape.sh` 与两份 lint / 两份清单都没动（缺陷在夹具的构造方式，不在
  判据）。
- ⑤d 的 `✓16 ✗10 SKIP0` 按 P225 的实测值写死（这是有意为之：门禁段落的计数一旦漂移就该有人看一眼，
  而不是自动跟随）。
- 未提交证据层（`docs/team/reports/P226-dev/**`，D94）；报告的五个日志副本留在本机同一目录下。

## Suggested next steps

- PM 独立复验可直接 `bash docs/team/reports/P226-dev/run-flip.sh <你的 worktree> <ledger-root>`（约 50 分钟
  容器时间：四个探针运行 + `validate` + §36）；或在复原环境里单跑一次探针、在默认环境里单跑一次，
  看红→绿的两侧是不是都成立。
- 合并后建议在**复原了证据层的检出**里再跑一次完整 `smoke.sh`（本任务按简报只跑了 §36）——那正是这次
  缺陷唯一暴露过的形状。
- 未做：`⑤d` 的空面判据只在 §19 上固化；若 PM 认为 §31 / §58 也需要空面反向控制，可另开一条小任务。
