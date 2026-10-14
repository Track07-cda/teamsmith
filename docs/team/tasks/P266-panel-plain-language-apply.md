# P266 · 面板普通话：apply

task: P266
agent: dev3
phase: apply
category: code
change: panel-plain-language
specs: panel, key-replies
deltas: -
branch: task/P266-panel-plain-language-apply
deps: P262（提案已 ACCEPTED，见 `docs/team/reviews/panel-plain-language-proposal.md`；change 目录在分支上，合并到 main 后再起手）

## 范围

实现已接受的 `openspec/changes/panel-plain-language/`：proposal、design 七条决策、`tasks.md`、三个 delta（`panel` 五条 MODIFIED、`key-replies` 一条 MODIFIED、`memory-and-deps` 三条 MODIFIED）。**基线场景一条都不许丢**（我在复核时逐条核过：panel 11→12、7→7、6→7、2→2、1→1、4→6）。合同以 change 目录为准。

**先合并 main 起手**：change 目录要先并入 main 再动手（如果它不在 main 上，先把 P262 的分支并入或通知我）。

## 复核时点名的准入条件

1. **门禁只留逻辑**（D170）：审计块与测试开关不出现（渲染行为）、发布者标签按原文显示、正文安全消毒照旧——这些给破坏性对照；**措辞/术语/排版不设门禁断言**。合并前把**设置页与关键回复页的最终文案样张**贴进报告（我直接读，不靠门禁断言）。
2. **写集串行**：`smoke.sh`、`section-*.tsv`、`cmd-watch.sh`、`cmd-config.sh` 此刻也被别的在飞任务改；交付前 `git merge main`，冲突按**双方保留**解决，语义冲突停下报我。
3. **安全不回退**：`key-replies` 的拒绝/消毒场景一字不松；发布者标签改的是**显示**（去掉限定词），存储里记录的仍是发布者写下的标签原文。
4. 文案同时改中文与英文两套字符串；`SID`→「会话」、来源标签→普通话、区块标题改成那两个普通话标题。

## 验收（贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/smoke.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/key-replies.sh --all   # 关键回复的安全回归不许降
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

**红侧**：审计块/测试开关出现在界面 → 红；发布者标签加限定词 → 红；正文消毒关掉/软链放行 → 红；还原后全绿。

## 交付

`docs/team/reports/P266-dev3.md`（逐条决策对照、命令与 rc、红侧前后证据、设置页与关键回复页的最终文案样张（中英文各一份）、未做项）；证据包仓外；不合并、不推送；做完 `team notify pm`。

## 返修轮次 1（2026-10-14，独立复验 V36 判 FAIL：唯一阻塞）

复验记录 `docs/team/reviews/V36.md`（受检 tip `9d402ab`）。其余逐条绿（审计/测试开关不出现的渲染行为、发布者标签信任、消毒不回退、双语覆盖与对比度、红侧）。唯一阻塞：

**设置页「席位有记录但读不出来」那一行仍写着「派单记录」**——`scripts/panel/src/strings/zh.ts:224` `settingsAssignmentUnreadable = '这个席位的派单记录读不出来，面板不显示它在用的模型'`。这正是用户第一个点名的词（「派单记录？」），也是你提案自己的清词清单里点名的词。

**修法（复验者已定位，按它做）**：
1. 改那句普通话（例如「这个席位派过任务，但它的记录读不出来，面板不显示它在用的模型」）；**同步 `design.md` 的文案对照表**（第 103、191 行）——设计文稿自己把这半句写错了、与它的上一条决策自相矛盾，**把设计文稿也改掉**。
2. **同步一处夹具 needle**：`tests/panel-p21.sh:1587` 把整句里的这半句逐字钉住了（`wait_row policy-unreadable … '这个席位的派单记录读不出来'`）——改字符串要连同它一起改，否则那条断言会红。
3. 不用改的：`specs/panel/spec.md:393` 只写「a sentence saying so」（措辞层面），不用动。

**红侧**：把这半句改回「派单记录」→ 设置页那条断言红并点名；还原后绿。另外把 design 的文案对照表与字符串、needle 三处核对一致（三处不一致正是这次的根因）。

修后冻结新 tip；由 V36 **第二轮**复检。
