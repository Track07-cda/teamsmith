# P424 · 详情面按真实落点判软链（含规格 delta）

agent: dev   status: delivered   time: 2026-11-06T09:40Z
branch: `task/P424-symlink-detail`（local 模式：分支留本地，未推送，无 PR/MR）

## 结论先说

详情面（`__panel-data --block detail` 的四类 source）与 `changes`/`specs`/`decisions` 三个列表块，不再把
「路径上任一段是软链」当成拒绝理由：解析真实落点后，落在**项目根内**就照常读（并把经过的软链段如实报出），
落在项目根外仍然拒绝，原因里同时点名**真实落点**与**项目根**。用户现场形状（账本根本身在项目内换了个位置）
由「详情整页不可用」变成可用。非普通文件（FIFO / 设备 / 目录 / 套接字 / 坏链）按类型拒绝、从不 open。

PM 裁决的两件都已落地（`docs/team/threads/dev.md` 2026-11-06 那节）：① 根内软链允许跨 change、允许经别名到
`archive`，只守「不得读到项目根之外」；② 规格确实冲突，已新建
`openspec/changes/panel-symlink-inside-project`，用 MODIFIED Requirement 把「软链一律拒绝」那条改成按落点判，
`openspec validate --all` 由红变绿（21 passed / 0 failed），该 change 的 `--strict` 也绿。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-watch.sh` | 落点判据一份（`_landing` / `_boundary` / `_within` / `_landing_reason` / `_container_ok` / `_link_segs`），发现面、读面、三个列表块共用；读面仍是一次 open + fd 身份 + 落点现查；非普通文件在 open 之前按类型点名拒绝；详情块新增 `links` 字段 |
| `skills/teamsmith/tests/smoke.sh` | §28-i2 目录软链断言改为新合同（根外拒绝点名落点+边界、根内别名照常服务且 `links` 点名）；新增 §28-i3（项目内软链可读、根外拒绝、FIFO 按类型点名且不阻塞）；`demo-sym` 的拒绝断言补上「真实落点 + 项目根」 |
| `openspec/changes/panel-symlink-inside-project/proposal.md` | Why / What / Capabilities / Impact（短） |
| `openspec/changes/panel-symlink-inside-project/tasks.md` | 落点判据 / 报告字段 / 夹具三节，逐条已勾 |
| `openspec/changes/panel-symlink-inside-project/specs/panel/spec.md` | `panel` 的 MODIFIED Requirement（全量重述）+ 三个场景 |
| `docs/team/reports/P424-dev.md` | 本报告 |

提交（tip `879c7402`）：

```
59bb3b00 fix(panel): judge detail symlinks by their landing zone (P424)
293e54ed test(panel): pin inside/outside symlink landing in the detail view (P424)
9904a63c fix(panel): keep the decision slicer in the P424 detail rewrite (P424)
a1e9ca41 test(panel): keep the 28 row's path tokens honest (P424)
14b395ee docs(P424): report the landing-zone detail reader (P424)
b4c13db2 fix(panel): name a discovered non-regular file instead of silently skipping it (P424)
879c7402 docs(openspec): propose the landing-zone rule for the detail reader (P424)
```

## 规格 delta 与它对应的场景

| 主规格里的位置 | delta 里怎么说 | 谁在守它（夹具） |
|---|---|---|
| 拒绝段最后一句「a discovered path that is a symbolic link SHALL be refused and named, never read through」 | 解析真实路径后再判：**根内照常服务**并把经过的软链段报出来；**根外拒绝**并同时点名真实路径与项目根 | `28-i3`（项目内软链可读 + `links`）、`28-i3`（根外拒绝，两个路径都在原因里）、`28-i2`（`demo-sym` 与目录软链的根外分支） |
| 新增一句：非普通文件（FIFO / 设备 / 目录 / 套接字 / 坏链）不得 open，按类型拒绝并点名 | 「SHALL NOT be opened at all … refused and named with its kind」 | `28-i3` FIFO（直连与经软链两种，`timeout 10` 当绊线，原因里点名 `FIFO`） |
| `--source change` 那段「MUST NOT serve a file of any other change or of the archive」 | 收紧成「**按它自己的路径**不许」：项目内解析得到别名的 change 目录按所请 id 服务；archive 用自身目录名提问仍然什么都没有 | `28-i2` 目录软链（`alias` / `archalias` 照常服务，`archive` 正常路径 count 0） |
| 旧场景 `Scenario: A symlinked entry is refused, never read through` | 场景名保留（openspec 的 MODIFIED 不允许丢场景），GIVEN 收紧为「软链目标在**项目根外**」；正文改成点名真实路径 + 项目根 | `28-i2 软链` / `28-i3 根外软链` |
| 新场景 `Scenario: A symlinked path that stays inside the project opens` | 账本根与 `changes/<id>` 都是项目内软链 → 两种读都返回正文、报出 `links`、不带不可用原因 | `28-i3 项目内软链` |
| 新场景 `Scenario: A non-regular discovered path is refused and named` | FIFO 直连或经软链 → 十秒内返回、count 0、无正文、原因点名路径与 `FIFO`、`--file` 选它非 0 退出 | `28-i3 FIFO` |

## Verification evidence

### 门禁（选段，跑在交付 tip `879c7402` 上）

```
$ bash skills/teamsmith/tests/smoke.sh --select 28
== 选段 == decision=RUN · 运行 9/139 段 · 未跑 130 段
#9 28 · 控制台表面（pulse-console B3：i18n 键集合 / 调色板对比度 / 四档快照 / refresh_s / panel.conf 边界） · 参考 用时 34s · ✓171 ✗0 SKIP0 · ticks 171
账本自查： 9 段收口 · 增量 ✓426 ✗0 SKIP0 ｜ 结果行 ✓426 ✗0 —— 一致
== 选段结果 ==  ✓ 426  ✗ 0
```

实际跑到的段：`0 0b 0c 0d 2 18 26 27 28`（前导段 + §28 的 needs 拉进来的 18/26/27）。**没跑**：其余 130 个键
（`0e 0f 0g 0h 0i 1 1b 1c 3 4 4b 4c 5 3b 6 … 66 67`，全表见 `/var/tmp/p424-select28-5.log`）。
选段运行不是整套门禁。

本轮新断言与改写后的断言（原文）：

```
  ✓ 28-i3 项目内软链：详情可读、不报来源不可用、links 点名那一段、决策与列表照常
  ✓ 28-i3 项目内软链：三类读都退出 0
  ✓ 28-i3 根外软链：仍拒绝并点名真实落点 + 项目根、正文/列表都不读
  ✓ 28-i3 根外软链：仍退出 0（不是错误帧）
  ✓ 28-i3 FIFO：指向 FIFO 的软链不被服务、不阻塞（timeout 10 是绊线）、拒绝时点名是 FIFO
  ✓ 28-i2 软链：拒绝并点名（真实落点 + 项目根）、其余 artifact 照常、目标不读穿
  ✓ 28-i2 目录软链：根外拒绝并点名落点与边界、根内别名照常服务且 links 点名（正常路径仍到不了 archive）
  ✓ 28-i2 项目根软链：还原后 change/decision 照常服务
```

### 规格校验

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all
Totals: 21 passed, 0 failed (21 items)                     # rc=0（PM 定的判据：本仓非 strict）

$ PATH="$HOME/.bun/bin:$PATH" openspec validate panel-symlink-inside-project --strict
Change 'panel-symlink-inside-project' is valid             # rc=0
```

`--all --strict` 仍红，但红的不是本 change：现在是 `1 passed, 20 failed`，那 20 条全是主规格既有的
「Requirement text is very long (>500 characters)」警告；同样的命令在 base 提交 `937a5380` 上是
`0 passed, 20 failed`（逐条相同），本 change 恰好是那条 `1 passed`。

### 其它验收命令

```
$ node skills/teamsmith/tests/panel-strings.mjs
panel-strings: ok                                          # rc=0（本任务没改文案，跑一遍确认没连带）

$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 13  bad 0  SKIP 1                        # rc=0

$ git diff --check 937a5380..HEAD
（无输出，rc=0）
```

### 账本禁令（固定验收行）

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/…/.worktrees/dev scope=published files=2418 hits=18 names=ok user=resolved
$ echo $?
1
```

`hits=18` 全部落在 **PM 写的账本文件**里（`docs/team/tasks/P424-symlink-detail.md` 3 条、`P415`/`P417`/`P418`/
`P420` 的任务书与 `reviews/P415.md`、`reviews/P418.md`）；本任务改的 6 个文件与本报告 0 命中。这些文件在
OWNERSHIP 之外（任务书是 PM 的只读文件），我没有改，`rc=1` 是先前就有的账本状态。

## Flip evidence

`--select 28` 第一次跑（`1cc7b795` 的树）**红 4 条**：我改写发现面时把 `team_panel_detail_decision_slice`
一起删掉了，决策源全部退化成「DECISIONS.md 里没有 D<号>」，长条目那条还在 python 里抛 `IndexError`：

```
  ✗ 28-i2 决策：D7/D8 切片与 D9 的空表 + 原因（期望 [ok]，实际 []）
  ✗ 28-i2 项目根软链：还原后 change/decision 照常服务（期望 [ok]，实际 [decision 没复原]）
  ✗ 28-i3 项目内软链：… （项目内软链下的决策条目读不到：''）
  ✗ 28-i2 决策：超过 128 KiB 的条目按同一上界截断（期望 [ok]，实际 []）
  Traceback (most recent call last): … IndexError: list index out of range
```

函数逐字恢复（`9904a63c`）后转绿。

判据本身的翻转（证明新断言有牙齿）：把 skill 树复制到 `/var/tmp`，只把落点判据改回「任一段是软链就拒」，
同一个现场（账本根指向项目内别处）两份输出：

```
# 未改的副本（= 交付代码）
{"id": "P1", "count": 1, "text": "# P1 report", "files": [...], "links": ["docs/team"]}

# 判据改回「任一段是软链就拒」
{"id": "P1", "count": 0, "file": "", "text": "", "files": [], "reason": "软链拒绝：docs/team（docs/team）"}

# 把 §28-i3 的检查器直接喂给上面这份红输出：
项目内软链的详情仍报错误：'软链拒绝：docs/team（docs/team）'；项目内软链的详情没有读到正文：''；
没有把经过的软链段报出来（links）：None
```

FIFO 那一侧同理：交付代码下 `reason = "不是普通文件，不打开：docs/team/reports/P2-dev.md（FIFO）"`、
`--file` 选它 rc=1；类型检查去掉就会回到「open 一直等写者」——`timeout 10` 的绊线会判 124。

## Decisions and deviations

1. **规格已按 PM 裁决落地**（新建 change + MODIFIED，见上一节）。旧场景名保留是 openspec 校验器要求的
   （MODIFIED 块必须包含现状里的每个场景名），我把它标注成「项目根外」那种情形，没有删场景。
2. **根内别名现在可跨 change、可经别名到 `archive`**：这是 PM 的裁决（放弃「任何软链都是攻击」这个模型，
   只守「不得读到项目根之外」）。`archive` 仍不能用正常路径被服务（发现面按 id 拼路径）。四条旧的「根内别名
   也拒」断言没有删，改成了新合同的正面断言（`28-i2 目录软链`），diff 里可见。
3. **`links` 是新字段，不动界面**：详情块 JSON 多一个 `links: [相对路径…]`（只在经过软链时出现）；
   `panel/src`、`panel.js`、i18n 文案都没动，所以不需要重建提交的构建产物。
4. **非普通文件怎么挡（与 brief 措辞的差异）**：brief 说「O_NONBLOCK 那套保留」，但 bash 的 `exec 9<` 没有
   O_NONBLOCK 可用，这个读者从来就没有 O_NONBLOCK（有它的是 `replies.mjs` / `monitor.mjs`）。这里用的是
   「open 之前判类型」：发现面按类型点名拒绝，读面在 `exec 9<` 之前再判一次 `[ -f ]`。要字面意义的
   O_NONBLOCK 得把读者换成 node/perl，超出这张单的范围。
5. **允许根在项目外时的边界**：绝对路径的 `TEAM_DOCS_DIR` / `TEAM_SPEC_DIR` 落在项目外时没有更外层的可信
   锚点，边界就是那个根自己（与改动前「不读穿源根」同义）。
6. **重写了一次提交信息（只动信息，不动内容）**：第一条产品提交的正文里写了用户现场项目的名字，而它在
   `.pi/team/forbidden-names.txt` 里（公开仓不该出现）。用 `git rebase -i` 的 reword 把那一个词改掉，之后 3 条
   提交 SHA 连带变化：`7eb20aa2 → a1e9ca41`。**树逐字节相同**（`git diff --stat backup/p424-pre-namefix HEAD`
   无输出），门禁证据仍成立；旧指向保存在本地 ref `backup/p424-pre-namefix`，PM 确认后可删。
7. **发现面的一处顺带修复**：字节数原来在 glob 未命中时对字面模式跑 `wc -c`，在 `set -e` 下会把整个发现
   子进程带走（探针里条目连自己的报告都列不出来）。已挪进 `record_path`，只在 `-f` 成立时算（`b4c13db2`）。

## Suggested next steps

- **PM 审这份 proposal**（`docs/team/reviews/<change>-proposal.md` 那一步）。按协议 dev 不自己验证/归档；
  归档由 PM 在独立复验 + 用户确认后做。
- **账本禁令的 18 条命中**都在 PM 的账本文件里（含本任务书），需要 PM 侧处理。
- **合并前的整套门禁**未跑（本单按约定只跑选段）；复验命令：`bash skills/teamsmith/tests/smoke.sh --select 28`。
