# panel-preview-and-compose · tasks

阶段口径：**apply** 由收到本 change 的席位顺序完成（每一项都留下可复跑的夹具与其红侧）；**verify** 由另一个席位
（与 apply 作者不同，`team dispatch` 的守卫会拦自验）在独立现场重跑下表全部场景与保留回归。本文件不是规格；
合同文本在 `specs/panel/spec.md` 的 delta 里，逐条 MODIFIED 不得丢基线场景。

## 1 冻结与投影

- [x] 1.1 读 PM 的提案评审记录：确认裁定点 D1（`queued+busy`）与 D2（`held`/`unconfirmed`）按提案推荐版本落笔，或按
  裁定改写判定表与对应场景文字；把结论记进 `docs/team/reports/<ID>-<agent>.md`。 · 证据：PM 评审记录 + 报告里的裁定摘录
- [x] 1.2 在**独立树**做归档投影自证：`cp -a openspec /tmp/<x> && cd /tmp/<x> && openspec archive -y
  panel-preview-and-compose && openspec validate --all --strict` 必须绿；逐条 MODIFIED 与基线逐场景对照（丢失任一
  基线场景 = 返工），并确认没有第二个未归档 change 动 `panel`。 · 证据：贴出投影命令与输出尾

## 2 草稿结算（规格：`panel`#A human can write to the PM from any page）

- [x] 2.1 `src/main.tsx` 的 `clearDraft` 改为回报写入结果（`writeDraft` 返回 bool），`src/App.tsx` 的 send 结算改为
  「先清磁盘、成功才清内存」，失败时保留草稿并在回执里点名 `state/draft.md`（新 zh/en 字符串）。 · 证据：`bun run
  typecheck`（与 main 逐条相同的 class A）· `build.sh` 重建 `panel.js`
- [x] 2.2 `tests/panel-b2.sh` 新增结算组（真 pty + 私有 tmux server）：`delivered` 与 `queued` 两跑清空（输入行 + 文件
  + 重启后 `m` 为空）、`error` 类两跑保留（桥无机器行 / `offline`）、`held`（`unconfirmed` 静态页脚）按裁定、以及
  「发送后把 `state/draft.md` 置为只读」的失败清空用例。 · 证据：`bash tests/panel-b2.sh <新组>`（全绿）+ 该组四条红侧输出
- [x] 2.3 翻转实证：逐条破坏实现（删 `clearDraft` 调用 / 把 `held` 划进 `error` / 恢复「先清内存后写盘」），各自必须
  让对应断言变红，还原后全绿。 · 证据：报告里 red→green 四组原始输出

## 3 预览读取面（规格：`panel`#A focused card opens a read-only markdown detail view）

- [x] 3.1 `scripts/lib/cmd-watch.sh`：`team_panel_detail_records`/`team_panel_detail_json` 增加 `--source entry|spec|
  change|decision`（缺省 `entry`，既有发现集与拒绝语义逐字不变），实现三类新发现集、id 文法校验、软链拒绝、决策条目
  切片（`##`/`###` + 同层或更浅终止、更深同号补记留在正文内）与缺失目标的空文件表 + 可读原因。 · 证据：`bash
  tests/smoke.sh --select <详情读者段>`（新断言全绿）
- [x] 3.2 在 `tests/smoke.sh` 的详情读者段补齐：三个 source 的发现集与 tab 顺序、越界路径/跨 source/非法 id/软链的
  拒绝点名、缺失编号的 unavailable、200 KiB 截断、`ESC [2J` 消毒、`--print`/`--json` 不变与只读扫描。 · 证据：段输出
  尾 + 三条红侧（放开 `--file` 校验 / 穿透软链 / 去掉截断）各自变红
- [x] 3.3 面板侧：`src/types.ts`/`src/data.ts` 把 source 带进 `detail` 块的请求（仍只在视图打开时装配），`App.tsx` 的
  `setDetail` 带上 source，`layout.ts` 的详情视图渲染 unavailable 文案（zh/en 表）。 · 证据：`bun run typecheck` ·
  `tests/panel-snapshots.sh` 逐帧审查后 `--update` 且无 update 复跑一致
- [x] 3.4 真实 pty：`tests/panel-b3.sh detail` 组增加规格/变更/决策三种预览的打开、tab 切换、滚动与原地返回。 · 证据：
  `bash tests/panel-b3.sh detail`（全绿）

## 4 工作页入口与页面行序（规格：`panel`#The work page's board rows are focusable…）

- [x] 4.1 `layout.ts`：把块的行序拼成一页一份的绘制序（块放置顺序 + 块内绘制序，降级/空块不贡献），预览行的 ref 用
  块名作作用域；三个预览块画光标、登记 `focus`/`open-focused` 目标（两段点击）。 · 证据：`tests/panel-snapshots.sh` +
  `panel-b3.sh workdetail` 目标表断言
- [x] 4.2 `App.tsx`：页面行走跨块（既有 `resolveFocus`/`moveBoardFocus` 复用）、首个 `↓` 落点不变、行 source 派生并
  传到 `setDetail`、`enter`/点击打开与 `esc`/`q` 原地返回、键带发行键；`tests/panel-b3-stub.sh` 增加「预览块清空」旋钮
  供空块场景使用。 · 证据：`bash tests/panel-b3.sh workdetail`（含空板 / 空块 / 60x10 降级三条）
- [x] 4.3 按新语义重述既有场景「An empty or degraded board has no dead item」的夹具：空板 + 预览块空 → 无光标/无目标；
  空板 + 规格块有一行 → 首个 `↓` 聚焦该行、`enter` 开预览。 · 证据：该组断言输出
- [x] 4.4 翻转实证：只走板内（跨块断掉）、空块仍登记目标、预览行取显示标题当 id —— 三条各自变红，还原后全绿。 · 证据：
  报告里的 red→green 原始输出

## 5 收尾

- [x] 5.1 字符串表双向、四档宽度快照、两种主题、两种密度、59 列页签可达性；重建 `panel.js` 并记 sha256。 · 证据：
  `tests/panel-strings.mjs` · `tests/panel-snapshots.sh` · `tests/panel-contrast.mjs`
- [x] 5.2 只读与机器出口：打开/关闭三种预览前后 `--print`/`--json` 逐字节（除时间戳）不变、`docs/`+`openspec/`+`state/`
  的哈希扫描只允许控制台自己的三个文件变化。 · 证据：段输出
- [x] 5.3 登记新夹具到 `tests/section-paths.tsv`/`section-budgets.tsv` 的归属段（不新建绕过门禁的独立套件）。 · 证据：
  `bash tests/section-select.sh --paths …` 的 RUN 决定
- [x] 5.4 相关段 + `TEAM_SMOKE_FAST=1` 快跑 + `openspec validate --all --strict`；全量门禁留给 PM 复验，按纪律后台跑。 ·
  证据：各命令 rc 与输出尾

## 6 独立验证（另一席位，不是 apply 作者）

- [ ] 6.1 在独立冻结克隆重跑第 2/3/4 节的**全部**场景与保留回归（`panel-b2.sh` 全组、`panel-b3.sh`
  `detail`/`workdetail`、详情读者段、快照与字符串门）；逐条给 command/assertion/rc 与 skip，缺测不标 pass。 · 证据：
  独立记录 + 原始日志
- [ ] 6.2 逐条重做红侧（第 2.3/3.2/4.4 的每一条），确认「破坏实现必红、还原必绿」，不是只复跑绿侧。 · 证据：red→green
  原始输出
- [ ] 6.3 反面证据：越界路径与软链拒绝、决策切片边界（补记在内、下一条不在内）、200 KiB 截断、空块无死项、机器出口
  不变、`panel-page=9` 回退 —— 每条都要在**修改后的树**上真跑。 · 证据：命令与输出尾
- [ ] 6.4 判 `verification` 的 correctness 门：只有证据通过；不因为「作者报告说绿」判过，也不拿结构绿当功能通过。 ·
  证据：`docs/team/reviews/<ID>.md`

## 7 apply / verify 的验收命令（本阶段不运行）

```bash
bash skills/teamsmith/tests/panel-b2.sh <结算组>          # 第 2 节
bash skills/teamsmith/tests/panel-b3.sh detail workdetail # 第 3/4 节
bash skills/teamsmith/tests/smoke.sh --select <详情读者段> # 第 3 节
bash skills/teamsmith/tests/panel-snapshots.sh            # 第 3.3/4.1/5.1 节
bash skills/teamsmith/tests/panel-strings.mjs             # 第 5.1 节
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
```

红侧命令按第 2.3/3.2/4.4 节逐条现场改坏再还原；夹具与命令的最终形态以 apply 冻结的接口为准，但**场景名与红侧
方向**不得改（改了就是换合同，要重新走提案）。
