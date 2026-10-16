# P292 · 「打断席位长回合」入口：apply

task: P292
agent: dev3
phase: apply
category: code
change: seat-interrupt-entry
specs: boundary
deltas: -
branch: task/P292-seat-interrupt-entry-apply
deps: P291（提案已 ACCEPTED 并入 main，见 `docs/team/reviews/seat-interrupt-entry-proposal.md`）

## 范围与硬约束

合同以 `openspec/changes/seat-interrupt-entry/` 为准（两条要求、十个场景）。**我的准入条件**：

1. **对象证明链照写**：名册 → 记录里的窗口 → pane → pid → **身份与启动时刻**；链上任一步不成立就**拒绝、不发信号**。**不许**按名字、按父子、按进程组。
2. **`--print`/计划态一个信号都不发**；**被拒绝的打断不写审计行**；**审计**一行一打断、字段与打断前读数一致（`session_last`、`uncommitted` 必须是发信号**之前**读的）。
3. **理由必须写进席位的阅读顺序**（收件箱/线程），并保证续跑后它读得到。
4. **红侧逐条**（各给「破坏 → 红点名 → 还原 → 绿」）：① 计划态零信号；② 授权打断 → 审计一行且字段正确；③ 对象不再是那个进程 → 拒绝；④ 正在写盘的席位 → 拒绝并点名（`--force` + 理由可越过且审计记 `forced`）；⑤ 理由落在席位的阅读顺序；⑥ **工作树逐字节不变**（造一个未提交文件，打断后检查仍在）；⑦ 读命令不写任何东西；⑧ 跨项目/非本队席位 → 拒绝并给出该走的路。
5. **写集串行**：`tests/smoke.sh` 与两张 tsv 此刻归门禁锁那条变更与 tmux 身份那条；交付前 `git merge main`，冲突按双方保留，语义冲突停下报我；合并前逐条看「本次相对 main 的删除行」。
6. **不改**：`resume`/`teardown` 的既有语义、死因词表、名册/面板显示、`long-job-suspend` 的车道机制。
7. **文本类不设门禁**（D170）：说明行用语稳定短语 + 行为红侧。

## 验收（贴真实输出）

```bash
bash skills/teamsmith/tests/seat-interrupt.sh                 # 你自己的新夹具（无参数即全组）
bash skills/teamsmith/tests/seat-interrupt.sh --flip          # 逐条红侧
bash skills/teamsmith/tests/smoke.sh --select <选段闭包打印的段号>
bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

## 交付

`docs/team/reports/P292-dev3.md`（逐条 scenario 对照、命令与 rc、八条红侧前后证据、未做项）；不合并、不推送；做完 `team notify pm`；随后由**没写过本变更**的席位独立复验（要自己造一个真在跑的长回合替身）。

## 收尾轮次（2026-10-16，P295 交叉勾选翻出**三条真缺口**，其中一条是**主分支上的活红**）

复验（V49）与合并都过了，但清单里 3.1–3.4 这**一整套交付面**没做；交叉勾选的席位把它如实留空并翻出后果。**我独立复现了那条活红**：

```
bash skills/teamsmith/tests/help-surface.sh --select claims
  ✗ claims: interrupt 的探针 id interrupt 没有配方
  ✗ claims: interrupt 没有探针配方
== 结果 ==  ✓ 82  ✗ 2
```

也就是说 `commands.tsv` 里的 `interrupt` 行（第 50 行）声明了 `faces=state`，但 `help-surface.sh` 的 **claims 探针表**里没有它的配方 → **「帮助面里每条承诺都要被真跑一遍」这条不变量在 interrupt 上是空的**，且非 FAST 的全量段 51 因此红。**这是我的合并检查漏项造成的**：我合并 P292 时只跑了 `validate` 与账本禁令，没跑受影响选段（D-口径：合并后**必须**真跑受影响选段并读结果）。

## 要做（3.1–3.4 + 一条补丁）

1. **探针配方**（3.2）：给 `interrupt` 写 claims 探针——浅 fixture：**私有 socket** 上起一个 stub 席位（带身份 + 窗口 + 记录）→ `team interrupt … --print`（计划态零信号）→ 断言 `faces=state`（写出的审计/收件箱）与「拒绝路径不写任何东西」。配方要能被 `--select claims` 跑到且**全绿**。
2. **文档**（3.3）：`references/troubleshooting.md` 加一节「席位卡在一个长回合里」——先读什么证据（`session_last`/`uncommitted`）、命令怎么用、**已知边界**（只对一个 pid、窗口留下的是活 shell、后台作业不受影响、死因显示 unknown）、以及 `--force` 的语义。
3. **静态纪律**（3.4）：`perl skills/teamsmith/tests/signal-lint.pl --legacy /dev/null` 干净；`kill -TERM "$pid"` 的形态符合既有 lint。
4. **3.1** 若 `commands.tsv` 行已写对，就在报告里给出证据（行号与 `--select claims` 的结果）；若还缺字段（例如 `caps`/`flags` 与实现不一致）一并改对。
5. **验收**：`bash skills/teamsmith/tests/help-surface.sh --select claims` **必须 ✓ 全绿**；`smoke.sh --select <闭包>` 贴结果；**跑前跑后 `/tmp` 根数**（夹具收尾清理）。
6. 改完 notify pm；由**没写过本变更**的席位做定点复检（换人）。

## 返修轮次 1（2026-10-16，换人定点复检 V52 判 FAIL：两条，PM 都判「修」）

复验记录 `docs/team/reviews/V52.md`。

**F1（必修：我们刚加的那把门禁缺反向判据）**：`help-surface.sh` 的 claims 探针只检查「**声明的面都动了**」，没有反向检查「**动了的面必须在声明里**」。复验者造的三例证明它不能证伪声明漂移：① 从声明里删掉 `docs` → 仍 ✓3 ✗0；② 实现多写**未声明**的 `config` 面 → 仍 ✓（探针甚至把 `config` 打印在 `变化=` 里）；③ 实现往**工作树**里写文件 → 仍 ✓（`worktree` 面的指纹只覆盖 `git worktree list` 与分支 refs，**不含工作树内容**）。**当前 `interrupt` 行的声明本身是对的**（复验者逐项核过）——所以这是**缺一把反向 falsifier**，不是声明写错。
**改法**：给 `run_probe` 补上 `changed ⊆ declared` 的反向判据（未声明的面出现 → 红并点名那个面）；并把 `worktree` 面的指纹扩到**包含工作树内容**（`git status --porcelain` 的摘要或全树哈希，取其一并写明）。**红侧**：三例各造一次（少声明 / 多写未声明面 / 写工作树），必须各自红并点名。

**F2（我判修实现，不改文档）**：`references/protocol.md:155` 写「每个拒绝都要点名另一个入口」，而 **`reap` 侧不成立**：活席位上调 `team reap <pid> --yes` 拒绝得**正确**（rc=2、一个信号都不发、pane 还活着），但**从不提 `team interrupt`**（`cmd-reap.sh` 全文件 `grep -c interrupt` = **0**）。
**改法**：在 `reap` 的「它是活着的席位」这条拒绝里**补一句指向 `team interrupt`**（与 `interrupt` 侧已经指向 `team reap --orphans` 对称）——**不**把文档收窄：对用户来说，「你该用哪条命令」正是这条拒绝的价值。
**红侧**：活席位上 `reap` 的拒绝必须含那个指向；把该指向删掉 → 必须红并点名。

**交付**：改完跑 `help-surface.sh --select claims`（✓ 全绿）、`seat-interrupt.sh --all/--flip`、`smoke.sh --select <闭包>`，贴结果；报告写「返修轮次 1」一节；然后 notify pm——**由 V52 第二轮定点复检定论**（同一席位、换会话）。
