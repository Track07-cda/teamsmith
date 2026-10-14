# 提案复核 · `panel-preview-and-compose`（P248）

- 复核者：PM（未参与撰写）
- 输入：分支 `task/P248-panel-preview-propose`，冻结 tip `efc968a`；证据 `pm-skills-ledger/team/reviews/P248/`（独立 clone `scratch/`、试归档副本 `trial/`）
- 判定: **ACCEPTED**，含两处裁定与一处**对 PM 任务书的更正**

## 一、我独立跑过什么

| 检查 | 结果 |
|---|---|
| 严格校验（含该 change） | `openspec validate --all --strict` = **16 passed / 0 failed** |
| 基线场景对照（`panel` 的三条 MODIFIED） | 三条要求**零场景丢失**：`A human can write to the PM from any page` 7→11、`A focused card opens a read-only markdown detail view` 7→15、`The work page's board rows are focusable…` 5→9 |
| 试归档投影 | 在副本里 `archive` 成功（`+0 ~3 -0`），归档后 `validate` = **15/0**；投影后 `panel` 规格共 **234** 个场景 |
| 缺陷复核（我自己读码，不引用作者结论） | `App.tsx:698-702`：**非 error** 回执（`delivered`/`queued`/`held`）会同时清内存（`updateDraft('', false)`）与磁盘（`api.clearDraft()` → `main.tsx:787` 的 `writeDraft('')`）；**error** 回执保留文字。**结论：作者说的对——「发送成功后没清空」这条不是稳定复现的缺陷**，真实存在的是：① 结算规则不在规格里（可静默回归）；② 失败侧无夹具；③ **写盘失败时内存已清、磁盘还留着已发出的正文** → 下次 `m` 把旧文带回来（用户看到的「没清空」最可能就是这个幽灵草稿），且那次异常会变成未处理的 rejection |

## 二、两处裁定（作者请我裁的）

**D1 · `queued` + `result=busy`（PM 的输入框正忙）→ 清空。裁定：同意作者。** 条目已 durable 进 `state/outbox/`，回执明确告诉用户「已入队（PM 框在忙）」；改「保留」会让同一段正文被再次提交，而草稿投递**没有去重**（`team_draft_send` 不传 `--dedup`）→ 重复投递。清空不丢文本，因为副本在队列里。

**D2 · `held`（含 `unconfirmed`）→ 清空。裁定：同意作者。** 这是**结算**不是丢失：durable 副本在 `outbox/held/`、收件箱也有、回执点名 reason；`unconfirmed` 的 payload 很可能已在 PM 的输入框里等「搭下一次 Enter 的车」，保留草稿会诱发第二次粘贴 → 又一次重复。任务书的字面（「未确认 → 保留」）在此让步于「不留重复投递的口子」。

**同时确认任务的对称面**：`error` 类（无 durable 结果：`offline`/`unknown-failed`/桥没跑起来/`geometry-untrusted`/`queue-stalled`）**保留**文字——那才是不该丢的情形。这条不对称是整个判决表的要点，delta 的场景把它写成了可证伪的合同。

## 三、对 PM 任务书的更正（作者发现，我采纳）

我的任务书第 1 条把失败侧写成「发送失败 / 未确认 / 队列忙 → 保留」，**粒度错了**：把「有 durable 副本的结算」与「什么都没写进去的失败」混成一类。作者按回执类（`delivered`/`queued`/`held`/`error`）重写了判决表并逐格给出判据，粒度正确。**任务书的那句话作废，以本设计与 delta 为准**。

## 四、准入条件（写进 apply 任务书）

1. **红侧一条不许少**（design §7 的十一条）：结算清空（拿掉 `updateDraft('')` 或 `clearDraft` 任一调用必红）、`error` 类保留、`held` 是结算、**写盘失败不假装清掉**（把草稿文件置只读 → 输入行仍有字并点名文件）、三个 `source` 的发现集与顺序、拒绝集（越界路径/跨 source/非法 id/软链）、决策切片边界（含「同 id 的 `###` 补记留在正文里」）、上界与消毒、空块无死项、一页一行序、机器出口字节不变。
2. **只读与根固定**：`--source` 的根只许是该面板自己的项目根下（规格/变更在 openspec 目录、决策只在 `docs/team/DECISIONS.md`），`--file` 必须是该 source 发现出来的路径之一，软链**拒绝并点名**而不是读穿；`--print`/`--json` 不得因此多读一个字节或变一个字段。
3. **不改机器出口、不加动作键、不新开页面**：入口落在工作页既有行的可聚焦集合上（板行 + 第 2 页的变更/规格/决策块行），`enter`/点击打开同一详情视图；`Esc`/`q` 原地返回；`q` 在详情打开时不收缩控制台是**已文档化的例外**。
4. **快照与 i18n/宽度/主题**：`panel-snapshots.sh` 的变动要逐帧能被「新增预览入口/新 source」解释（不许把回归钉进基线）；`zh`/`en` 两份字符串表同步；四档宽度与两主题不变弱。
5. **换人复验**：apply 与 verify 不同席位；verify 必须在**独立 clone + 钉死容器**里跑该 change 段与真 pty 取证，并对每条合同给红侧；「既有红」必须用**同一条命令**对照上一个全绿 tip（当前是 `v0.2.0` 的 tag 树）。
6. **串行**：`cmd-watch.sh` 与 `smoke.sh`/快照都在本 change 的写集合里——目前无其他在飞变更占用，PM 会保持串行。

## 五、遗留（不阻塞）

- 草稿投递**没有去重**（`team_draft_send` 不传 `--dedup`）是本次判决表的安全前提；若将来给草稿加去重，D1/D2 的判决可以重新讨论。已记入 design §8 的未决项。
- 决策预览只服务 `DECISIONS.md`；`ROADMAP.md`/`BOARD.md` 不在本 change（后续候选）。
