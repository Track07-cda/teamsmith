---
id: P471
title: 实施Pulse项目设置精简与用户文案
agent: dev
category: code
phase: opsx-apply
change: pulse-project-settings-simplify
specs: panel, memory-and-deps, verification
deltas: -
branch: task/P471-project-settings-simplify-apply
---

# P471 · 按已接受方案实现；作者只静态，非作者一次行为验收

PM接受记录`docs/team/reviews/pulse-project-settings-simplify-proposal.md`已ACCEPTED（ecde1365/D260）。作者dev2的最终规划f987cc05、非作者dev3最终审阅2eb1e8e2已合并7a2e2918；仅delta末尾空行规范化，正文未变。你未参与规划/审阅。用户要减少日常设置数量和内部语言，不是把完整清单搬进高级页；没有真实配置写入或新版本发布授权。

先读AGENTS/本人线程/OWNERSHIP、本brief及openspec-apply-change skill；用现有OpenSpec1.16在本工作树读list root、status及instructions apply，完整读取其contextFiles。原生proposal/design/三份delta/tasks是唯一范围，不在brief再复制要求。只完成tasks **1.1–1.6**，每项实际完成并静态有据才勾；2.1/2.2/3.1留给非作者及merged阶段，不提前勾验收/归档。遇真正设计冲突交PM，不自行改规划/增加能力。

## Boundaries · 本任务明授写集

- `skills/teamsmith/scripts/panel/src/**`：仅设置展示、局部导航/规则草稿、类型及中英文；复用原数据块/CLI路径，不改变数据协议、匹配算法或后台行为。
- `skills/teamsmith/scripts/panel/panel.js`：仅现有钉住工具链生成，禁止手改。原`panel/README.md`、`skills/teamsmith/references/config.md`及`skills/teamsmith/SKILL.md`只更新对应设置说明，不改版本/无关协议。
- `skills/teamsmith/tests/panel-p21.sh`、`skills/teamsmith/tests/panel-strings.mjs`：在原场景替换本change点名退休的展示断言，保留必要观察；不新增脚本、检查段、词表或快照/平台矩阵。原flip两个产品破坏及正常policy收尾保留；失败必须来自实际被改坏的目标行为，不能拿注入失败或语法错误冒充检出。
- `openspec/changes/pulse-project-settings-simplify/tasks.md`仅勾本人完成项；本人`docs/team/reports/P471-dev.md`。其余规划/正式spec只读；schema/配置writer/common运行语义、真实配置/提醒队列/待命均不改。

源与bundle/相关原测试分小步提交，及时给出可读进度，不把整批留未提交。不要先建通用设置系统或无损解析器；规则编辑只处理原完整值的字段草稿，原token/顺序/重复及取消/错误/冲突按已接受工件承接。同步展示/交互/用户文案，不仅删行。

## 本轮真实命令 · 仅静态

```sh
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
# 依赖未就绪时才按panel/README使用bun install --frozen-lockfile；不升级依赖。
(cd skills/teamsmith/scripts/panel && bunx tsc --noEmit)
bash skills/teamsmith/scripts/panel/build.sh
node skills/teamsmith/tests/panel-strings.mjs
openspec validate pulse-project-settings-simplify --type change --strict --no-interactive
bash skills/teamsmith/tests/spec-refs.sh
# 报告暂存后，仅本任务交付检查
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
git diff --cached --check
```

不运行pty、snapshot、config-cli/panel-choices全量、smoke/FAST/meta/61b、真实Pi、性能或完整计时；不启动/重启真实Pulse。本次V174已完成且FAIL保留，两旧失败由P472只读归因，不等待它全绿、不顺手修提醒。没有“静态通过所以用户操作通过”的说法。

交付冻结候选后，由PM另派非作者在独立检出**一次**执行原定`panel-p21.sh settings groups wheel choices choices-schema write conflict categories readonly flip`；已接受的中英文/窄屏/键鼠/短长列表及真实保存、错误、只读来源放同批，不把每种尺寸/语言跑一整遍，不单独再跑policy。合并后同一人核同一性与必要短接入。你本轮不得提前执行这些场景。

## 交付

报告先给STATIC-READY/阻塞结论及实现范围；写真实命令/版本/rc/输出和bundle来源、退休断言到替代/保留行为的映射、候选产品/测试SHA与尚未执行的行为验收。UI10行仍是C3设计数，未有真实画面前不能写实测127→10。Conventional Commits含P471及`Agent: dev`，本地分步提交，不push/merge/archive/tag/npm；慢命令用team_bg_run后结束回合，完成唤醒再收，不轮询等待。自己的具体临时根用/var/tmp，原件留到PM收存；不碰别人的根或主检出。
