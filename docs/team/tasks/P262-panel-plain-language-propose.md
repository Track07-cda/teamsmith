# P262 · 面板只说普通话：设置页去掉黑话与内部记录，关键回复页信任发布者标签

task: P262
agent: dev2
phase: propose
category: analysis
change: panel-plain-language
specs: panel, key-replies
deltas: panel, key-replies
branch: task/P262-panel-plain-language-propose
deps: -

## 用户的原话（本变更的需求来源，2026-10-14）

> 这些都是什么语言？派单记录？为什么设置菜单里面要有记录？审计根本没有用，也看不懂，去掉！不要用你自己的一套简写的语言，什么「手改」
> 这里测试旋钮又是什么玩意儿？还有什么内部接缝？
> 不要在界面中包含任何黑话
> 自称去掉，默认信任

（两张截图是 Pulse 面板的设置页：一张逐席位显示「没有完整派单记录: legacy/unknown assignment_version」加一整块原始审计行；另一张显示「依赖策略: 手改 .pi/team/config.sh」「测试旋钮: 磁盘读数夹具（TEAM_MEMINFO_FILE 同族）；只在夹具里用」。）

## 要解决的（写进两个 delta）

### 一、设置页（`panel` 能力的 MODIFIED）

1. **审计整块从界面移除**。审计保留在文件里（`team config log` 仍可读），只是不再出现在界面。design 要说明理由：它是排障材料，不是设置。
2. **只供测试的开关在界面上完全不出现**（今天它们带着「（测试）」标签出场）。读取与命令行行为不变。
3. **界面可见文字里不许出现内部词汇**（用户裁定 D170：措辞由**设计与评审**把关，**不设门禁断言**——下面这份清单是这次要清理的对象与以后的写作参考，不是一个会跑在门禁里的检查）：
   - 要清除的自造说法（中文）：手改、只读键、派单记录、测试旋钮、内部接缝、旋钮、接缝、依赖策略、机器路径；英文对应 hand-edit、knob、seam、assignment record、policy；
   - 要清除的内部标识形态：形如 `M<数字>` 的编号、以及用户看不懂的 `TEAM_*` 键名出现在**给用户看的文字**里（配置键本身照常出现在它该在的地方——命令行与 `team config list`）；
   - 合并前，PM/复验**读一遍**设置页与关键回复页的最终文案（design 里给出最终文案的样张），确认没有上述词。
4. **保留「策略与实际」这层区分，但改成普通话**：例如「下一次派任务会用的模型」与「正在运行的任务实际使用的模型」，并加一句说明它们为什么会不同（任务派出去之后就固定用当时的模型）。席位没有记录时写普通话原因（「这个席位还没有派过任务」），不再出现 `legacy/unknown assignment_version`。
5. **只能改配置文件的值**：提示写成普通话（「这个值要改项目配置文件 `.pi/team/config.sh`，界面不能改」），路径保留（它是事实），不再出现「手改」「只读键」。

### 二、关键回复页（`key-replies` 能力的 MODIFIED）

6. **发布者标签默认信任**：面板与命令行都只显示标签本身（例如「来自 pm · 时间」），不再出现「自称」「未经核验」「declared/not verified」。
7. **规格那一条要改，但安全部分一条都不许弱化**：存储路径与记录名仍按不可信数据处理（拒绝软链、非普通文件、路径穿越、外来根）、读取接口不接受任意路径、正文里的 Markdown 链接与图片、嵌入命令、终端控制序列仍然是惰性文本、显示前仍然消毒。
8. **数据层不变**：存储里记录的仍是发布者写下的标签原文。design 要写清「显示信任」与「记录原样」这两层的关系与不矛盾之处，并在 Non-Goals 里留一句如实说明（标签是调用方自己声明的，工具不认证）。

## 红侧（每条都要有，且只留逻辑类）

**逻辑类**（行为，留在门禁里）：
- 给设置页一份含审计与测试开关的输入 → 渲染结果里**没有**它们；把它们加回渲染 → 红，还原后绿；
- 发布者标签按**原文**渲染（输入 `--from pm` → 界面只显示 `pm` 这个标签，不加限定词）；把它改成带「自称/未经核验」字样 → 红；
- 正文的安全消毒照旧：恶意正文仍惰性渲染且不触发任何动作、软链与 FIFO 仍被拒 → 红侧保留；
- 还原后全绿。

**文本类不设门禁**（措辞、术语是否干净由合并前的评审把关）：不再写「出现禁用词/内部键名/内部编号就红」这类断言。

## 边界

- 只写提案；apply 与 verify 另行换人。
- 落点：`scripts/panel/src/strings/{zh,en}.ts`、设置视图与关键回复视图的渲染、`scripts/lib/cmd-reply.sh` 的用法与列表文本、`openspec/specs/{panel,key-replies}/spec.md`、以及盯着这些字的夹具（`tests/panel-*.sh`、`tests/key-replies*.sh`）。
- **不许碰**：帮助面（P260 的面）、`cmd-watch.sh`/`common.sh` 的报错文案（P261 的面）、`references/**`。
- 不许削弱既有断言（双语覆盖与对比度检查、快照审查照旧）；新增判据是加严。
- 不合并、不推送；做完 `team notify pm`。

## 验收（本阶段）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/P262-dev2.md
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
