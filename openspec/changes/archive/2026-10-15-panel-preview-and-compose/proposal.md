## Why

Pulse 是用户整天盯着的窗口，但它的三个「项目面」——变更、规格、决策——目前只给一行摘要：想知道一条规格的正文、
一个变更的 proposal/design/tasks、或某条决策的全文，用户必须离开面板去翻文件。用户的第 ②③ 条诉求（可预览 spec 与
变更详情、可预览决策详情）就是这个缺口。

用户的第 ① 条（「写信的消息发送后，清空输入框」）**复核后不是任务书里写的那条缺陷**：产品今天的路径已经在回执
结算时清空草稿（`scripts/panel/src/App.tsx` 的 send 结算 + `src/main.tsx` 的 `clearDraft`），并且 `tests/panel-b2.sh`
的 B3 组早已把它钉在 `queued` 回执上（本轮实跑 ✓）。真正缺的是**合同与红侧**：结算规则不在规格里，失败侧没有任何
夹具，而「清空写盘失败时留下幽灵草稿」这一条**是真的**（内存清了、文件没清 → 下次 `m` 把已发出的正文带回来）。
本提案把草稿生命周期写成可证伪的合同，并只改这一处真缺陷（见 design §2 的判定表与 §7 的红侧）。

## What Changes

- **草稿生命周期**（第 ① 条）写成合同：结算类回执（`delivered`/`queued`/`held`）→ 输入行与 `state/draft.md` 一起
  清空；`error` 类（没有机器裁决、桥没跑起来、守卫非零退出且没有 durable 结果）→ 草稿原样保留；写盘失败时
  **不许假装清掉了**——留在输入行并点名文件，内存与磁盘不再会分叉，重启后不会有幽灵草稿。
- **只读预览**（第 ②③ 条）：`team __panel-data --block detail` 增加一个显式 `--source`：`spec`（capability 的
  `spec.md`）、`change`（该 change 的 proposal/design/tasks 三个 tab）、`decision`（按决策号取 `DECISIONS.md` 里
  一条的正文）。**复用**同一个块、同一份 128 KiB 上限、同一个消毒器、同一条详情视图渲染与只读纪律，不新造第二条
  读取/渲染路径；根固定（规格/变更在 openspec 目录下、决策在账本里），拒绝集合外的路径、非法 id 与软链。
- **入口**：工作页（第 2 页）上变更/规格/决策三块的**行**和看板行一样可聚焦（`↑`/`↓` 按绘制顺序走、`enter`/点击
  打开），打开的就是同一个详情视图、带对应的 source；不新开页面、不加动作键、不引入写操作。
- **范围**：不动路由/派单/账本写入，不改 `team reply`（关键回复在已归档的另一个 change），不引入新依赖，不改
  机器出口（`--print`/`--json`）的字节。

## Capabilities

### Modified Capabilities

- `panel`：草稿结算合同；详情读取面的 `--source` 维度与三类预览；工作页行的可聚焦集合与绘制序行走；只读/机器
  出口/i18n/宽窄屏的继承关系。

## Impact

- 产品面：`scripts/lib/cmd-watch.sh`（`team_panel_detail_records`/`team_panel_detail_json` 增加 source 与三类发现，
  决策切片）、`scripts/panel/src/{main.tsx,App.tsx,data.ts,layout.ts,types.ts,strings/{zh,en}.ts}` 与重建的
  `panel.js`。
- 夹具面：`tests/panel-b2.sh`（草稿结算组）、`tests/panel-b3.sh`（workdetail/detail 的预览行与空块规则）、
  `tests/smoke.sh` 的详情读者段（`--source` 三类的拒绝/缺失/上界/软链）与 `tests/panel-b3-stub.sh`（预览行可清空的
  旋钮）、`tests/panel-snapshots.sh` 快照。
- 规格面：`openspec/specs/panel/spec.md` 三条 MODIFIED requirement（见 delta）。
- 边界与前提：接口/键位/持久化的取舍、以及两处与任务书措辞不同之处见 `design.md`；两条需要 PM 裁定的点见下。

## 需要 PM 裁定的两点（提案按推荐版本写）

任务书第 1 条的字面把失败侧写成「发送失败 / 未确认（`unconfirmed`）/ 队列忙（busy）→ 草稿保留」。复核发现前两类
里有一处与现有绿灯夹具和投递守卫的安全属性相抵触，提案按推荐版本落笔，请评审时裁定：

1. **`queued` + `TEAM_OUTBOX_RESULT=busy`（PM 的输入框正忙）**：条目已经 durable 地进了 `state/outbox/`，回执也会
   告诉用户「已入队（PM 的输入框在忙）」。提案按**清空**写（= 今天的 green 行为，`panel-b2.sh` B3 组钉着它）。
   若改成保留：同一段正文可能被再次提交，而草稿类投递**没有去重**（`team_draft_send` 不传 `--dedup`），会造成重复
   投递。
2. **`held`（含 `unconfirmed`；rc=0 且条目在 `state/outbox/held/`）**：这是**结算**不是丢失——durable 副本在
   `outbox/held/`、收件箱里也有一份、回执点名 reason。`unconfirmed` 的 payload 很可能已经在 PM 的输入框里等着
   「搭下一次 Enter 的车」，保留草稿会让用户再按一次 Enter，而守卫再贴一遍、又没有去重 → 同一条消息可能到两次。
   提案按**清空**写（= 今天的实际行为，本轮实跑证实）。任务书字面要求保留；若裁定保留，改变的是 `App.tsx` 里
   一行判定 + 一条场景文字，本提案的设计表里已把它标成一行可切换的判决。

第 1 条里「发送失败 → 保留」与「写盘失败不能留下幽灵草稿」两条提案照办；第二类（`geometry-untrusted`/`queue-stalled`
/`offline`/无机器裁决）本来就走 `error` 类、今天就已经保留。

## Evidence（本阶段复核，2026-10-14）

1. **结算清空今天的实现**：`scripts/panel/src/App.tsx` 的 send 结算 `if (r.state !== 'error') { updateDraft('', false);
   setPoint(0); api.clearDraft() }`；`src/main.tsx` 的 `clearDraft: () => writeDraft('')`。回执类由 `src/compose.ts` 的
   `mapReceipt` 决定（`rc !== 0` → `error`；`result=held|terminal` → `held`；其余 rc=0 → `delivered`/`queued`）。
   `writeDraft` 吞掉写盘错误，`clearDraft` 不回报结果 —— 幽灵草稿的入口就在这里。
2. **本地实跑**：`TEAM_B2_KEEP=1 bash skills/teamsmith/tests/panel-b2.sh receipt` → `✓ 13 ✗ 0`；保留现场
   `/tmp/teamsmith-panel-b2.5igNOe/`。三种回执的帧分别是 `delivered`/`queued`/`held`；跑完后
   `receipt/root/.pi/team/state/draft.md` 是 0 字节 —— 即 `held`（`unconfirmed`）今天也是清空的，任务书
   「发送成功后没有清空草稿」的判断与现场不符。
3. **既有绿灯夹具**：`tests/panel-b2.sh:894` 断言 `queued` 之后 `state/draft.md` 为 0 字节（B3 组），本轮实跑通过。
4. **既有读者合同**：`tests/smoke.sh` §28-i 已钉住 `--block detail` 的发现集、`--file` 拒绝、128 KiB 与消毒；
   `tests/panel-b3.sh` 的 `detail`/`workdetail` 是真实 pty 上的范本，本提案的预览夹具按同一形状扩展。
5. **投递语义**：`scripts/lib/cmd-draft.sh` 的 `team_draft_send` 不传 `--dedup`（草稿不去重）；`outbox.sh` 的
   `unconfirmed` 是终态、不自动重贴（`delivery-guard` 规格），所以「保留草稿 + 再按 Enter」是唯一可能的重复投递
   路径。`held` 类（`unconfirmed`）在回执里带 `reason=`，用户知道副本在哪。

## Out of scope

- 不新开第六页、不做「按号定位」输入行、不做正文里的交叉引用跳转（design §3 记录取舍）。
- 不写任何规则/派单/账本内容，不碰 `team reply`，不加 Pi 工具、不加配置键、不加依赖。
- 不改 `--print`/`--json` 的既有字节与既有键。
