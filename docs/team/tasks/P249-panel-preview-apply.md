# P249 · Pulse：写信槽与只读预览（apply）

task: P249
agent: dev2
phase: apply
category: code
change: panel-preview-and-compose
specs: panel
deltas: panel
branch: task/P249-panel-preview-apply
deps: P248（提案已 ACCEPTED，判定与两处裁定见 `docs/team/reviews/panel-preview-and-compose-proposal.md`）

## 范围

按已接受的 `openspec/changes/panel-preview-and-compose/`（proposal / design / tasks / `specs/panel` delta）实现**全部条目**，逐条以 tasks.md 为准，本条不重述。要点：

- **草稿生命周期**：`App.tsx` 的结算改成「先写盘、写成功才清内存」；`delivered`/`queued`（含 busy）/`held`（含 `unconfirmed`）→ 清空；`error` 类（无 durable 结果）→ 保留并点名；**写盘失败不许假装清掉**（输入行仍留着、回执点名文件）。
- **只读预览**：`team __panel-data --block detail` 增加显式 `--source spec|change|decision`（三类发现集、`--file` 只许取发现出来的路径、非法 id/越界/软链拒绝并点名、128 KiB 上界与消毒沿用、缺目标给空清单 + 可读原因而不是空文档当成功）；决策切片按 id 标题到下一个同级或更高级标题（同 id 的更深一级补记留在正文里）。
- **入口**：工作页第 2 页的变更/规格/决策块**行**接入既有可聚焦集合与绘制序（板行 + 这三类行），`enter`/点击开同一详情视图；`Esc`/`q` 原地返回，`q` 在详情打开时不收缩控制台（已文档化的例外）。
- **不改机器出口**：`--print`/`--json` 不因预览多读一字节或变一个字段；打开/关闭预览对机器帧除时间戳外逐字节不变。

## 边界

- 只碰 design 的 Impact 列出的路径（`scripts/lib/cmd-watch.sh`、`scripts/panel/src/**` 与重建的 `panel.js`、`tests/panel-b2.sh`、`tests/panel-b3.sh`、`tests/panel-b3-stub.sh`、`tests/panel-snapshots.sh`、`tests/smoke.sh` 的详情读者段与必要的 tsv 登记）。
- **不要**碰路由/派单/账本写入、`team reply`（已归档的另一个 change）、`openspec/specs/**` 的 canonical（delta 由归档落地）。
- 不许删/skip 断言换绿；快照变动要逐条说明「能被新增入口/source 解释」；新跳过必须有名有理由。
- 不合并、不推送；做完 `team notify pm`。

## 验收命令（报告里贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/smoke.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')   # 按改动算闭包，别手挑段号
bash skills/teamsmith/tests/panel-b2.sh --all
bash skills/teamsmith/tests/panel-b3.sh --all
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

**红侧一条不许少**（design §7 的十一条，逐条给红→还原→绿）：结算清空（拿掉 `updateDraft('')` 或 `clearDraft` 任一调用）、`error` 类保留、`held` 是结算、**写盘失败不假装清掉**（草稿文件置只读）、三个 source 的发现集与顺序（删判据回落 / 凭空补 tab）、拒绝集（越界路径、跨 source、非法 id、软链）、决策切片边界（少切补记 / 越界切片）、上界与消毒（200 KiB 规格 + 带 `ESC[2J` 的变更文件）、空块无死项、一页一行序（跨块断掉或两个光标）、机器出口不变。

## 交付

`docs/team/reports/P249-dev2.md`（逐条 tasks.md 对照、命令与 rc、十一条红侧的前后证据、快照逐帧说明、未做项）；证据包按 D94 放仓外；之后由**未写过本任务**的席位独立复验（V33）。

## 返修轮次 1（2026-10-14，独立复验 V33 判 FAIL：唯一阻塞 F1）

复验记录 `docs/team/reviews/V33.md`（受检 `4decbe8`，与你的 `b5ed56b7` 的产品树逐字节相同）。除了 F1，其余部分它逐条重做并核对上了：草稿结算、三类预览的发现与拒绝、切片边界、上界（128 KiB 两个方向）、消毒、入口与原地返回、**十一条破坏性对照**、既有测试强度审计、越界审计、容器纪律。

**F1（必修）：预览读取面只拒绝叶节点软链，目录软链会被读穿。**

- 现场：`openspec/changes/<id>` 或 `openspec/specs/<cap>` 本身是**软链**时，`team monitor` 的预览读者照读其下文件；于是「只能读 openspec 目录内」「不得读穿」「不得提供别的变更或 `openspec/changes/archive/` 里的文件」三条纪律同时被破坏。
- 复验者给的反例（仓外 `pm-skills-ledger/team/reports/V33-verify/probe-reader.sh`，容器 + 独立 clone）：它的 85 条检查里 **6 条目录软链用例红**；加十行判据后 91/0。
- 修法方向（你自行定，但要给依据）：在发现与读取两处都对**路径的每一段**做软链判定（或对解析后的真实路径做前缀包含判定），使「目标必须在解析后的 openspec 根之内」这一条对目录与叶节点一视同仁。
- **红侧（三条，各自破坏→红点名→还原→绿）**：① `openspec/changes/<id>` 是软链（指向根内或根外各一例）→ 预览拒绝并点名；② `openspec/specs/<cap>` 是软链 → 同上；③ `openspec/changes/archive/<某变更>` 通过软链或正常路径都不得被服务（这条顺带证明你修完没有放过归档目录）。
- 不改机器出口、不改只读语义、不削弱既有 §28-i2 的断言；复验者点名的那 10 行示范补丁只是它的实现建议，你可以另写更好的，但要满足上面三条红侧。
- 修后冻结新 tip；由 **V33 第二轮**（同一复验任务、换会话）复检，只有 PASS 才关单。

- **既有红归属（V33 的对照，PM 已收录）**：`v0.2.0` 的 FAST 全量在容器里是 `✓3991 ✗1 SKIP55`，唯一的红与候选**同名同形**（`6e` 的「resume 位置参数不可用」），且两棵树都跳过同一批真进程段落。结合单独选段的两棵树 `✓164 ✗0`，可判 `6e` 那条 FAST 红是**序列依赖**（FAST 跳 §6 → 没有 assignment），不是产品缺陷；你的报告里报的 `✓4027 ✗1 SKIP55` 与它差 1 条通过，属跳过计数口径差异，不必改。

## 返修轮次 2（2026-10-14，V33 第二轮判 FAIL：唯一阻塞 F2）

复验记录 `docs/team/reviews/V33.md` 第二轮（受检 `b5683765`）。**F1 已关闭**（目录软链的拒绝生效，它第一轮的反例从 85 通过 6 失败变成 91 全绿，且拒绝对根外目标、根内别名、归档别名逐段点名）。但返修新加的读取判据是 **check-then-read**：

- **合同**：「a discovered path that is a symbolic link SHALL be refused and named, **never read through**」；你在返修报告里还自己承诺「即使路径在发现之后、读之前被换成软链，也一个字节都不读」。
- **事实**：`team_panel_detail_json` 里「判据」与「真正读」之间有一个可命中的窗口。复验者的对抗 fuzz（把被预览的文件在「真文件 ↔ 指向树外的软链」之间翻转）在冻结 tip 上 1400 次读取里 **117 次把树外正文当预览正文服务**。

**修法（我定方向 A，不按 B 改合同）**：把「判」与「读」合成**原子**——用 `O_NOFOLLOW` 打开（不跟软链），或对打开的 fd `fstat` 确认是普通文件后再从**同一个 fd** 读。也就是判据与读取作用于同一个 inode，中间没有窗口。复验者说约十行产品代码。

**红侧**（都要破坏→红点名→还原→绿）：
1. 复验者的对抗 fuzz（仓外 `pm-skills-ledger/team/reports/V33-verify/probe/probe-reader-race.sh`，或你重写等价的）在**修复后泄漏必须是 0**；还原成 check-then-read → 泄漏再次出现（这是承重证据）。
2. F1 的三条目录/规格/归档拒绝不许回退（回归断言照旧绿）。
3. 机器出口与只读性质不变。

**另外**：复验第一轮记的缺测项（草稿删除后不得复活那条，只有它的 pty 探针验过、发布的夹具缺断言）这次一并补上夹具断言。

修后冻结新 tip；由 V33 **第三轮**定点复检（同一任务、换会话）。

## 返修轮次 3（2026-10-14，V33 第三轮判 FAIL：F2 已关闭，两个新阻塞同根）

复验记录 `docs/team/reviews/V33.md` 第三轮（受检 `576a0d1`）。**F1、F2 都已关闭**（目录软链、叶节点竞态都成立）。但这一轮的读取判据仍有两处缺口，**同根**：

- **F3（静态，无竞态）**：逐段判据从**源根**（`openspec/changes`、`openspec/specs`、`docs/team`）往下走，**项目根到源根之间的段**（`openspec` 本身、`docs` 本身）从不判。于是 `openspec` 或 `docs` 本身是软链时，四类预览（change/spec/decision/entry）**照读树外正文**。复验者在**真界面**上走通（真 tmux + 真面板 + 真 CLI，按 ↓ 落到变更块那行、按 enter，抓到的帧里就是树外内容）。
- **F4（竞态）**：逐段判据按**路径名**走，不与**读的那个对象**绑定；中间目录在 open 之后被换回真目录（原子交换），判据看不到句柄打开的是树外对象。复验者把 fuzz 从「翻叶节点」改成「翻父目录」后，400 次读取里 **8 次**泄漏。

**修法（复验者已实测的方向，一条判据同时关掉全部四处）**：让判据作用于**读的那个对象**——打开之后取句柄自己解析出的路径（`readlink /proc/self/fd/N`），要求它**逐字节等于**「项目根真实路径 + 字面相对路径」，并把逐段判据的锚点提到**项目根**（即连 `openspec`/`docs` 本身是不是软链也判）。这样 F1（目录软链）、F2（叶节点换入换出）、F3（源根之上的段）、F4（中间段换回真目录）落在同一条判据下。复验者把这个方向实测过（`probe/fix-direction-r3.py`，16 增 4 删）：F3 的四条读穿变成逐段点名的拒绝、F4 的 8/400 变 0/200、`--select 28` 与决策源 fuzz 全绿。

**要求**：
- 按上面的方向实现（可参考复验者的探针 `probe/fix-direction-r3.py`，但**自己实现并自证**，不许只抄它）；
- 逐段判据的锚点必须是**项目根**（含 `openspec`/`docs` 本身），不只是源根往下；
- **红侧**：① F3 四条（`openspec` 是软链、`docs` 是软链，各自四类预览都拒绝并点名）在修复后绿、还原后红；② F4 的父目录原子交换 fuzz 修复后泄漏为 0、还原后泄漏复现；③ F1/F2 的三条与竞态断言不许回退；④ 真界面那条（↓ + enter 的端到端）复验者会重做，你要给它的夹具/命令。
- 报告里要把「我前几轮的哪一处承诺这次兑现了、哪一处还在修」写清楚（不许把「读不到 fd 身份就拒绝」这类说成「绝对安全」）。

修后冻结新 tip；由 V33 **第四轮**复检（同一任务、换会话）。
