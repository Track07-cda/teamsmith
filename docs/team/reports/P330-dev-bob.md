# P330 · 删掉从不被调用的夹具（P328 动作 3 · 两批）

agent: dev-bob   status: delivered   time: 2026-10-20T06:45Z
branch: `task/P330-unreachable-fixtures`   PR/MR: -（local 模式，不推）

## 答案先写

- **两批共删 34 个夹具 / 6 689 行**：第 1 批 **23 个 / 4 333 行**（两提交，判据 = 门禁/CI/`scripts/**`/
  `docs/team/tools/**` 无调用点）；第 2 批 **11 个 / 2 356 行**（三提交，判据 = PM 的「点名它的是不是活文件」：
  10 个 + `flip-m48.sh` 连同 `references/troubleshooting.md` 那条假指针一起处置）。第 2 批方法与清单见第 8 节。
- `tests/loop-inventory.tsv` 同步删掉 4 行（flip-m37 ×1、flip-p210 ×2、flip-p217 ×1；第 2 批那 11 个都没有
  登记行）。`smoke.sh --select 0e` 绿（**✓45 ✗0**，循环清单 85 行 / 85 个循环配平）；`--select 4c` 绿
  （`flip-m48` 换上去的新指针点名的那五条断言真的在跑）。
- **不可达还剩 22 个 / 6 693 行，全部有活文件点名，一个没删** —— 名单与点名它的文件在第 4 节。
  6 689 + 6 693 = 13 382，与下面的扫描总数对得上。
- 扫描总数：候选 **128** 个执行型夹具里 **56 个不可达 / 13 382 行**（P328 记录的是 54 / 13 030；差异来源见
  「偏差」，不是照抄）。
- 删掉的是**从不执行**的翻转/深水夹具；它们守的行为今天由门禁自己的段承接，逐段见第 1 节。两条反例
  （§6b、§21）按「破坏实现 → 该段必红 → 还原 → 绿」在树的副本上实跑过，见第 5 节。
- **诚实边界**：删掉后不能再「对历史缺陷重跑一次变异」（红树 = 修复前 revision）；34 条事故的证据从此只剩
  「任务报告 + 归档变更」两个书面来源，且**其中 4 处今天没有任何门禁段承接**（`flip-p20`、`flip-p22` 的
  `conflict`/`seats` 场景、`flip-m48` 的控制台半边、`flip-m6.3` 的 F17/F27/F30）—— 清单在**第 6 节**，
  已按 PM 要求补上「今天哪一段仍会红」一列。

## 一 · 删掉的是什么，守的行为今天由谁承接

这批删掉的是从不执行的翻转/深水夹具；它们守的行为现在由门禁自带红侧的段承接 —— 逐条：

| 删掉的夹具（行数） | 它重放的行为 | 今天承接它的门禁段（`tests/smoke.sh`） |
|---|---|---|
| `panel-flip-p123.sh` 278 | P123：卡片行只留序号+标题、agent/phase 进键位带；卡片 focus 目标 | **§28 的 28-h**（`:12654` 键位带、`:12657` 卡片行不带 agent/phase、`:12678` focus 目标） |
| `panel-flip-p125.sh` 318 | P125：宽档折叠车道是三列小框、六车道都渲染 | **§28 的 28-h/28-j**（`:12652` 折叠车道 `╭─╮`、`:12651` 六个车道起点、`:13513` 宽档三列） |
| `panel-flip-p128.sh` 259 | P128：分组档原地折叠行的字形落在卡片列、光标在第 1 列 | **§28 的 28-m**（`:13867`–`:13870` P128 列位断言） |
| `panel-flip-m54.sh` 207 | M55：设置视图 `choices` 的读取窗口（F-B）、目录泄漏（F-C）、枚举（A2-enum） | **§38**（`:18426` 跑 `panel-p21.sh` 的 `choices`；`:18497` 的 38-d 明写「行为面红侧在 W-A」） |
| `flip-p144.sh` 112 | D67：删掉磁盘腿 → 派单不再拒绝（ENOSPC 失明） | **§6b**（`:3106`/`:3143` 磁盘不足拒绝派单、`:3110` 点名 inode 与阈值）——反例 A |
| `flip-p211.sh` 152 | P211：看板 `dropped` 的报告不再算「待复验」 | **§21**（`:10579` 不再列为待复验、`:10587` 跳过行点名 dropped）——反例 B |
| `flip-m37.sh` 188 | M37：worker 存活看 pane 进程树，不看 `pane_current_command` | **§6k**（`:4638` 判据来源、`:4775` `6k ②` 有任务在跑不算「停了的 agent」、`:4806` `6k ③` 对照） |
| `flip-m6.5.sh` 116 | M6.5：`team up` 不得谎报「PM 在运行」 | **§6k**（`:4638`「M37 起判据与 M6.5 的 PM 存活同源」）+ §1c |
| `flip-p210.sh` 242 | P210：裸 shell 的 pane 不算在跑（判据收紧） | **§6k ⑥**（`:4824`–`:4832` P210 四条：`pane_current_command=bash`、座位判 `exited`、`resume --dry-run` 可续跑、巡检量） |
| `flip-p217.sh` 291 | P217：`pane_pid` 自己就是那个 agent（`bash <agent>`）算在跑 | **§6k** + **§41**（`:19177` roster 四态 ① running / ② exited） |
| `flip-m6.2.sh` 205 | M6.2：复验结论只认记录里绑定的 revision | **§10b**（`:5195` 复验证据完整性，M6.2/V4.0 F7–F14） |
| `flip-m6.4.sh` 267 | M6.4：跨项目会议的信号与承诺诚实 | **§11e**（`:6446` 会议模式：需授权、intent 校验） |
| `flip-glue.sh` 162 | D20：自动化消息不得把人正在打的草稿一起提交 | **§12b-c**（`:8010` 脏输入框仍按时投递、`:8025` 形状未知给警告） |
| `flip-m17.sh` 204 | M17：放弃 Enter 时「已收回 / 留在框里」分档 | **§12b-g**（`:8187`–`:8191` status/digest 分档与 `held-reason`）+ **§12b-h ⑰**（`:8850`–`:8852` 停顿超上限不提交 / `draft-raced-retracted` / 落在 `held/`） |
| `flip-m12.sh` 185 | M12：`6i` 的夹具产物必须**有界等待**，不赌固定 sleep | **§6i**（`:4260` 无界等待纪律、`:4345`「up 返回 ≠ 夹具已落盘」） |
| `flip-m12-26c.sh` 129 | M12 追加：26-c 容量行自抖的归一化 | **§26 的 26-c**（`:11506` 起，`:11507` 两次独立执行的帧逐字对比、容量行归一） |
| `flip-p156.sh` 133 | P156：26-c 只归一实时读数，结构逐字节比 | **§26 的 26-c**（同上；`:11519` 归一清单） |
| `flip-m34.sh` 96 | M34：看板旧排序（BOARD 文件序原样渲染）必红 | **§28**（`:12468` 跑 `tests/panel-snapshots.sh`，M34 段就在里面） |
| `flip-p18.1.sh` 95 | P18.1：两栏共享预算的旧 bundle 必红 | **§28**（同上，P18.1 段） |
| `flip-m7.1.sh` 135 | M7.1：旧项目「没有任何入口知道要改什么」→ doctor 一行迁移指引 | **§17**（`:9651`/`:9665` 迁移指引断言） |
| `flip-p308-skip-not-pass.sh` 151 | P308：跳过不是通过（收口按段数判，`rc=77`） | **§32⑨**（`:15338` 身份作用域夹具 rc=77 → 点名「跳过不是通过」） |
| `flip-p309-p162-deep.sh` 122 | P309：段 0h 的超深路径硬停必须是**显式造出来**的，不是碰巧 | **§0h**（`:1894` 超深路径硬停 + 点名 AF_UNIX 上限、`:2022` 深路径上私有 server 绑不上） |
| `flip-p20.sh` 286 | P20：面板 compose/clipboard 模型的六批翻转 | **无门禁段承接**：它的载体是 `panel-b2.sh`（门禁不跑，且在 P318 写集里）。见第 6 节诚实边界 |
| `flip-m16.sh` 166 | M16：面向人的输出出现代号时，同一行必须带短名字 | **§30**（夹具自述「这条判据在本仓库只被 smoke §30 守着」） |
| `flip-m6.3.sh` 286 | M6.3 七条：dispatch 分支对照 / 通知不静默吞 / 边界 | **§3b**（`:2843` F16 停在别的任务分支必拒、`:2933` F15 项目外任务书必拒）+ **§7**（`:4931` F18 打错收件人非零、`:4903` F26 PM 收件箱算待办）；F17/F27/F30 未逐条核到段 → 那三条算**无门禁承接** |
| `flip-p160.sh` 182 | P160：三处返工（knocks 补写 / tip 固定 12 位 / 不编造 `task=`） | **§55 + §56**（夹具逐字节取的就是这两段） |
| `flip-p201.sh` 249 | P201：主检出 + 席位线索 = 拒绝（发送者身份） | **§47**（夹具探针就是 `smoke.sh --select 47`；`:20113`/`:20333` P201 断言） |
| `flip-p22.sh` 123 | P22：面板设置面（键表硬编码 / 指纹 / 裸模型名） | **§38-f**（`:18606` 跑 `panel-p21.sh groups settings wheel`，覆盖 `settings` 场景）；它的 `conflict`/`seats` 场景门禁不跑 → 那两半**无门禁承接** |
| `flip-p23.sh` 239 | P24 change-centric 纪律的十对断点 | **§12e / §12g / §12h / §12i / §12j / §12k**（夹具的探针就是这几段拼的，见其 `build_probe`） |
| `flip-p287-name.sh` 279 | P287：席位名按运行时目录解析（名册拼写优先、判不出不猜） | **§47 + §34b**（`:16715` 起五条座位名断言）+ 结构面 **§0b/§0c**（夹具的探针就是 `--select 0b,0c`） |
| `flip-p304-read-side.sh` 98 | P304 读侧：可归因路径 / 归因看来源 / doctor 只读 | **§32**（`:15322`–`:15338` 跑 `tests/tmux-identity-leak.sh`；`--break=` 三条腿就是它的红侧） |
| `team-bg-flip.sh` 239 | M27：后台车道的收割 / 合并窗口 / 账本 / 根解析 | **§13c**（`:7692` 起，`:7704` 跑 `team-bg-harness.mjs`；§58 再跑一次 `--record-only`） |
| `team-inbox-watch-flip.sh` 191 | M30：投递换道的七个定点破坏 | **§12b-pi**（`:9011` 起，`:9156` 跑 `team-inbox-watch-harness.mjs`） |
| `flip-m48.sh` 304 | M48：看板重复 ID（拒绝 / `--allow-dup` / 三处可见 / assign 原地） | **§4c**（`:2717` 起五条：`M48：重复 ID 被拒（非 0）`、`M48：被拒时 BOARD 逐字节未变`、`M48：--allow-dup 显式允许写入`、`M48：assign 后行数不变（不是又加一行）`、`M48：assign 后 T1.1 仍是两行（没有顺手改历史数据）`）；控制台半边（一行两卡共用一个光标）**无门禁承接** |

一句话：**34 条里有 30 条的行为今天由门禁自带红侧承接（§0h、§3b、§4c、§6b、§6i、§6k、§7、§10b、§11e、
§12b-c、§12b-g、§12b-pi、§12e/12g/12h/12i/12j/12k、§13c、§17、§21、§26、§28、§30、§32、§34b、§38、§41、§47、
§55、§56）；4 处没有承接段**（`flip-p20` 整条、`flip-p22` 的 `conflict`/`seats`、`flip-m48` 的控制台半边、
`flip-m6.3` 的 F17/F27/F30）—— 第 6 节按 PM 要求逐条登记。

## 二 · 零引用证据（任务书硬约束 1）

扫描口径（脚本在 `/var/tmp/p330/reach3.py`，不进树）：

- 候选 = `skills/teamsmith/tests/*.{sh,mjs,py,pl,ts,tsx}` + `tests/lib/*.{sh,pl,py}`（128 个）。
- 根 = `tests/smoke.sh`、`tests/perf.sh`、`ci/**`、`.github/workflows/**`、`docs/team/tools/**`、`scripts/**`
  （repo 根的 `scripts/` 与 skill 里的 `scripts/` 都算）。
- 边 = 文本里**路径限定**地出现该夹具名；**整行注释不算调用**（这一条把 `flip-m7.2.sh` 这类「只在
  smoke.sh 注释里被指向」的文件判成不可达 —— P328 的 54 与我的 56 差的 2 个就在这里）。
- 结论从根做传递闭包；不可达 = 闭包里没有它。

命令与结果（在我这棵树上实跑）：

```
$ python3 /var/tmp/p330/reach3.py | tail -1
SUMMARY 128 72 56 13382        # 候选 128 / 可达 72 / 不可达 56 / 行数 13 382
```

删完后对每个被删文件再扫一次（`git grep` 用**路径限定**的分隔符，避免 `flip-p21.sh` 命中 `flip-p210.sh`）：

```
$ git grep -cF -- "<basename>" -- ':!docs' ':!openspec'    # 23 个文件逐个跑
```

| 文件 | 行数 | 删后引用（`:!docs`） |
|---|---|---|
| `panel-flip-p125.sh` | 318 | 0 |
| `flip-p217.sh` | 291 | 0 |
| `flip-p20.sh` | 286 | 0 |
| `panel-flip-p123.sh` | 278 | 0 |
| `flip-m6.4.sh` | 267 | 0 |
| `panel-flip-p128.sh` | 259 | 0 |
| `flip-p210.sh` | 242 | 0 |
| `panel-flip-m54.sh` | 207 | **1（注释）** — `smoke.sh:18497` 的 38-d 注释点名它的 W-A |
| `flip-m6.2.sh` | 205 | 0 |
| `flip-m17.sh` | 204 | 0 |
| `flip-m37.sh` | 188 | 0 |
| `flip-m12.sh` | 185 | 0 |
| `flip-glue.sh` | 162 | 0 |
| `flip-p211.sh` | 152 | 0 |
| `flip-p308-skip-not-pass.sh` | 151 | **1（注释）** — `tmux-identity-leak.sh:64`、`:764` 的两个变异标记注释 |
| `flip-m7.1.sh` | 135 | 0 |
| `flip-p156.sh` | 133 | 0 |
| `flip-m12-26c.sh` | 129 | 0 |
| `flip-p309-p162-deep.sh` | 122 | 0 |
| `flip-m6.5.sh` | 116 | 0 |
| `flip-p144.sh` | 112 | 0 |
| `flip-m34.sh` | 96 | 0 |
| `flip-p18.1.sh` | 95 | 0 |
| **合计** | **4 333** | 21 个 0，2 个只剩注释指针 |

那 2 条注释指针都**不是调用**，且都在本任务书写集之外（`smoke.sh` 是 P326 的写集），所以我没有动它们；
按「纯减法」也没有改一个字。若 PM 要清掉这两句，属下一次同文件编辑。

## 三 · `loop-inventory.tsv` 同步与选段（硬约束 2）

```
$ sed -i -E '/^(flip-p217\.sh|flip-p210\.sh|flip-m37\.sh)\t/d' skills/teamsmith/tests/loop-inventory.tsv
$ bash skills/teamsmith/tests/section-guard.sh --loop-check
ok: 扫描 85 行清单 / 85 个 while+sleep 循环，配平 85 个
section-guard --loop-check: 全过                                  # rc=0

$ bash skills/teamsmith/tests/smoke.sh --select 0e
  ✓ P70 循环清单：干净树绿（85 行清单 / 85 个 while+sleep 循环，配平 85 个）
== 选段结果 ==  ✓ 45  ✗ 0                                          # rc=0（130.0s）
```

## 四 · 名单：按第 2 批口径「点名它的是不是活文件」留下的 22 个

规则（PM 2026-10-20 裁定）：**活文件** = 除 `openspec/changes/archive/**`、`docs/team/reports/**`、
`docs/team/reviews/**`、`docs/team/tasks/**` 之外的任何被跟踪文件（含 `section-paths.tsv` 的 basis 列、
`smoke.sh` 与 `tests/**` 里其它文件的注释、`references/*.md`、`SKILL.md`）。名字出现在任何活文件里 → **不删**
（无论调用还是注释）；只出现在那四类历史面里 → 删。

按这条规则，**22 个 / 6 693 行全部留下**，每个都给出点名它的活文件（`file:line`）：

| 留下的夹具 | 行数 | 点名它的活文件（节选） |
|---|---|---|
| `panel-b3.sh` | 1 460 | `openspec/specs/verification/spec.md:651`、`openspec/changes/behavior-focused-ci/specs/verification/spec.md:595`、`references/troubleshooting.md:1128` |
| `panel-b2.sh` | 1 286 | `docs/team/threads/dev3.md:216/228`、`tests/panel-clipboard-model.ts:9` |
| `flip-m4.3.sh` | 378 | `tests/loop-inventory.tsv:8` |
| `flip-p287-lock.sh` | 342 | `docs/team/DECISIONS.md:1873/1875` |
| `flip-m7.2.sh` | 324 | `tests/loop-inventory.tsv:9/10`、`docs/team/threads/dev2.md:30` |
| `panel-compose-model.ts` | 290 | `tests/panel-b2.sh:241`（构建它的 bundle） |
| `flip-m33.sh` | 286 | `openspec/specs/verification/spec.md:1291/1294`、`tests/flip-p287-lock.sh:199` |
| `flip-m44.sh` | 262 | `tests/smoke.sh:1557` |
| `flip-p171.sh` | 249 | `tests/signal-gate.sh:25/85/499`、`tests/loop-inventory.tsv:11` —— **PM 已裁定留**（P318 保留那三条仪器断言，删复现工具与其冲突） |
| `flip-m45.sh` | 244 | `docs/team/DECISIONS.md:612` |
| `flip-m46.sh` | 238 | `tests/smoke.sh:9177`、`extension/team-inbox-watch.ts:452` |
| `flip-p72.sh` | 202 | `docs/team/threads/dev-bob.md:56/61/71` |
| `panel-clipboard-model.ts` | 187 | `tests/panel-b2.sh:591` |
| `flip-p71.sh` | 184 | `tests/smoke.sh:9212` |
| `flip-p25.sh` | 165 | `extension/team-inbox-watch.ts:599`、`tests/smoke.sh:9188` |
| `flip-m43.sh` | 128 | `tests/smoke.sh:9267`、`tests/flip-p25.sh:33`、`tests/flip-p71.sh:33` |
| `panel-keyprobe.tsx` | 116 | `tests/panel-keyprobe.sh:40/50` |
| `section-needs-audit.sh` | 111 | `tests/section-paths.tsv` 的 basis 列（`:37/39/40` …）、`tests/smoke.sh:18106` —— **PM 已裁定留**（它是审计程序，映射表的依据） |
| `panel-keyprobe-pty.py` | 99 | `tests/panel-keyprobe.sh:60` |
| `panel-keyprobe.sh` | 82 | `tests/smoke.sh:12247` |
| `panel-keyprobe-stub.sh` | 41 | `tests/panel-keyprobe.sh:46` |
| `panel-b2-slow-stub.sh` | 19 | `tests/panel-b2.sh:1014` |

PM 那四条预先查过的结论与我自己的扫描一致（`section-needs-audit.sh` 留、`flip-p171.sh` 留、
`flip-p304-read-side.sh` 删、`flip-p201.sh` 删），我按裁定执行、没有再去复核它们。

## 五 · 两条反例（硬约束 4：被删夹具原本能造红的场景，今天仍被门禁抓住）

两条都在**树的副本**里做（`/var/tmp/p330-cx-a`、`/var/tmp/p330-cx-b`，`git init` 自己的仓库），
真实工作树一个字节没动；做法与当初的 `flip-p144.sh` / `flip-p211.sh` 完全同形：

**反例 A —— `flip-p144.sh` 的现场（磁盘腿被拆掉 → §6b 必须红）**

```
$ bash /var/tmp/p330/cx-a.sh            # 副本里跑，真实树不动
=== clean tree, --select 6b: rc=0 red=0
=== broken copy, --select 6b: rc=1 red=17
--- red lines (first 5) ---
临时根低于磁盘底线时应当拒绝派单
拒绝点名临时根路径（…/disk-full.log 中找不到 [临时根 …/diskroot 磁盘不足]）
拒绝点名实测字节与阈值（… 中找不到 [可用 120.0 MB < 底线 1024MB]）
拒绝点名实测 inode 与阈值（… 中找不到 [inode 可用 40000 < 底线 100000]）
拒绝给临时根的归属有据修法（… 中找不到 [tmp-hygiene.sh --status 看清单，再 --sweep]）
--- expected needles ---
PRESENT  临时根低于磁盘底线时应当拒绝派单
PRESENT  工作树低于底线时应当拒绝
PRESENT  拒绝点名实测 inode 与阈值
```

断点：副本的 `scripts/lib/cmd-agents.sh:1359` 删掉 `team_df_run_lib team_disk_guard "$disk_tmp" "$wt"`
（与当年 `flip-p144.sh` 的断点逐字相同）→ §6b 红 17 条，且红在磁盘腿那一族断言上。

**反例 B —— `flip-p211.sh` 的现场（看板 `dropped` → 报告不得留在待复验清单）**

```
$ bash /var/tmp/p330/cx-b.sh            # 副本里跑，真实树不动
=== clean tree, --select 21: rc=0 red=0
break applied: team_reports_pending_list skips only done|closed
=== broken copy, --select 21: rc=1 red=2
--- red lines ---
P211：看板 dropped 的报告不再列为待复验（不该出现 [M94F]）
P211：digest 不再给 dropped 的报告派 review 待办（不该出现 [team review M94F]）
--- expected needles ---
PRESENT  P211：看板 dropped 的报告不再列为待复验
PRESENT  P211：digest 不再给 dropped 的报告派 review 待办
```

断点：副本的 `scripts/lib/cmd-status.sh:207` 把 `done|closed|dropped) continue` 退回 `done|closed) continue`
（与当年 `flip-p211.sh` 的断点一逐字相同）→ §21 红 2 条，正好是 P211 那两条。

两条都是「干净树绿 → 破坏实现 → 该段必红 → （副本丢弃即还原）」，所以「这两个行为今天仍被抓住」不是
靠我读代码推的，是门禁自己红的。

## 六 · 诚实边界：删掉后失去什么

1. **重跑历史变异的能力**（最直接的一条）：这 34 个文件里绝大多数自带「红树 = 修复前的 revision」这条腿
   （`git archive <BASE>` 或 `TEAM_FLIP_BASE=<sha>`）。删掉后，谁能证明「当年那条断言要是没有修复就会红」
   只剩两种办法：再写一个包，或者手工 checkout 那个 revision。门禁本身的红侧还在（第 1 节的 X 段），
   但那是**对今天的实现**做的破坏-还原，不是对历史 revision 的重放。
2. **哪些历史事故从此只剩「任务报告 + 归档变更」这一个书面证据**（按事故分组，报告都在 `docs/team/reports/`）：

| 事故 / 变更 | 删掉的包 | 剩下的书面证据 | 今天哪一段仍会红（修复被改坏时） |
|---|---|---|---|
| panel-board-cards（P123/P125/P128：卡片行、车道折叠、分组列位） | `panel-flip-p123/p125/p128.sh` | `P123-dev3.md`、`P125-dev3.md`、`P128-dev2.md` + `openspec/changes/archive/2026-09-29-panel-board-cards/` | **§28** 的 28-h / 28-j / 28-m |
| settings-choice-editors（M55：有选择就给选择） | `panel-flip-m54.sh` | `M55-dev3.md` + 同名归档变更 | **§38-b**（`panel-p21.sh choices`）+ **§38-a**（`panel-choices.sh` 的走查断言） |
| 席位存活判据（M37/P210/P217/M6.5） | `flip-m37/p210/p217/m6.5.sh` | `M37-verify.md`、`P217-dev.md`、`P214-dev.md`（P210 的现场） | **§6k**（+ §41） |
| 复验结论与记录绑定（M6.2） | `flip-m6.2.sh` | `M6.2-dev2.md` + 归档变更 | **§10b** |
| 跨项目会议（M6.4/M12） | `flip-m6.4/m12.sh` | `M6.4-dev2.md`、`M12-dev.md` + 归档变更 | **§11e** / **§6i** |
| 输入框草稿与 outbox（D20/M17） | `flip-glue.sh`、`flip-m17.sh` | `P6-dev.md`、`M17-dev2.md` | **§12b-c**、**§12b-g** + **§12b-h ⑰** |
| 看板 dropped 的待复验（P211） | `flip-p211.sh` | `P211-dev.md` | **§21** |
| 容量守卫的磁盘腿（D67/P144） | `flip-p144.sh` | `P144-dev-bob.md` | **§6b** |
| 迁移指引（M7.1） | `flip-m7.1.sh` | `M7.1-dev.md` | **§17** |
| 26-c 容量行自抖（M12/P156） | `flip-m12-26c.sh`、`flip-p156.sh` | `M12-dev.md`、`P156-dev.md` | **§26** 的 26-c |
| 看板排序与两栏预算（M34/P18.1） | `flip-m34.sh`、`flip-p18.1.sh` | `M34-dev3.md`、`P18.1-dev3.md` | **§28**（`panel-snapshots.sh`） |
| 跳过不是通过（P308） | `flip-p308-skip-not-pass.sh` | `P308-dev2.md` + `2026-10-17-tmux-identity-scope` 归档 | **§32⑨** |
| 深路径硬停（P309） | `flip-p309-p162-deep.sh` | `P309-dev2.md` | **§0h** |
| 面板 compose/clipboard 模型（P20） | `flip-p20.sh` | `P20-dev2.md` | **无门禁承接**（载体 `panel-b2.sh` 门禁不跑） |
| 任务名代号（M16） | `flip-m16.sh` | `M16-dev2.md` | **§30** |
| dispatch / 通知 / 边界（M6.3 七条） | `flip-m6.3.sh` | `M6.3-dev.md` | **§3b**（F15/F16）、**§7**（F18/F26）；**F17/F27/F30 无门禁承接**（未核到段） |
| meeting-liveness 续跑（P160） | `flip-p160.sh` | `P160-dev-bob.md` | **§55 + §56** |
| 发送者身份（P201） | `flip-p201.sh` | `P201-dev2.md` | **§47** |
| 面板设置面（P22） | `flip-p22.sh` | `P22-verify.md` | **§38-f**（`settings` 场景）；**`conflict`/`seats` 无门禁承接** |
| change-centric 纪律（P24/P23） | `flip-p23.sh` | `P23-dev-bob.md`、`P24-dev-bob.md` | **§12e/12g/12h/12i/12j/12k** |
| 席位名规则（P287） | `flip-p287-name.sh` | `P288-dev-bob.md` + `2026-10-16-gate-lock-external-deletion` 归档 | **§47 + §34b**；结构面 **§0b/§0c** |
| 身份读侧（P304） | `flip-p304-read-side.sh` | `P304-dev2.md` | **§32**（`tmux-identity-leak.sh`） |
| 后台车道（M27） | `team-bg-flip.sh` | `M27-dev2.md` | **§13c**（`team-bg-harness.mjs`） |
| 投递换道（M30） | `team-inbox-watch-flip.sh` | `M30-dev2.md` | **§12b-pi**（`team-inbox-watch-harness.mjs`） |
| 看板重复 ID（M48） | `flip-m48.sh` | `M48-dev3.md`、`M61-dev-bob.md` | **§4c**（五条）；**控制台半边无门禁承接** |

**PM 指名要确认的一条（`panel-flip-m54.sh`，M54/M55「设置视图：有选择就给选择」）**：承接它的是
**§38-b**（`smoke.sh:18464`–`:18471`，跑 `bash tests/panel-p21.sh choices`，断言名就是
`38-b · panel-p21.sh choices` 的收口判定 `p38_verdict`）与 **§38-a**（`tests/panel-choices.sh`：`:296`
`走查（…）：schema 与 choices 的静态一致性（values/min/max/known）全过`、`:318` `n 条 options 全部被
team config set 接受`、`:330` `每个键的 choices.empty = 校验器对空值的判定`、`:467` read-equality）。
所以它**不属于**「无门禁承接」：翻转当年打的靶（`panel-p21.sh choices` 变红）正是门禁 §38-b 今天跑的同一份场景。

3. **删掉后没有任何门禁段接着的，一共 4 处**（只登记，不补断言 —— 按 PM 的裁定）：
   - `flip-p20`（compose/clipboard 模型）：载体 `panel-b2.sh` 门禁不跑（P318 在改它）。所以删的是一个
     「本来就不在门禁里」的证据包；
   - `flip-p22` 的 `conflict` / `seats` 两个场景：门禁 §38-f 只跑 `groups settings wheel`（含 `settings`）；
   - `flip-m48` 的控制台半边（一行两卡共用一个光标）：只在 `panel-b3.sh board` 里，门禁不跑；
   - `flip-m6.3` 的 F17（去重键区分前 60 字符相同的简报）/ F27（空 tmux 目标被拒）/ F30（wrapper agent
     的启动证据）：这三条我没核到承接段，按「填不出段键」登记。
4. **两句注释指针**留在 `smoke.sh:18497` 与 `tmux-identity-leak.sh:64/764`，指向第 1 批删掉的文件。它们是
   注释，不影响任何断言；清它们是同文件的下一次编辑（`smoke.sh` 属 P326 写集）。**按第 2 批的新口径这两句
   恰好属于「活文件点名」**，也就是说这两个文件（`panel-flip-m54.sh`、`flip-p308-skip-not-pass.sh`）在今天
   的口径下应当留下 —— 第 1 批已在 PM 的裁定里收下，我不擅自回滚；这里如实登记这条口径差异，供 PM 决定
   要不要恢复。

## 七 · 验收命令（都是本 worktree 上真跑的）

```
$ bash skills/teamsmith/tests/smoke.sh --select 0e
  账本自查： 5 段收口 · 增量 ✓45 ✗0 SKIP0 ｜ 结果行 ✓45 ✗0 —— 一致
== 选段结果 ==  ✓ 45  ✗ 0          # rc=0，116.3s
  选段运行不是全套门禁（交付 / 复验 / 归档仍跑整套）；没跑的 130 个段键已在结尾打印

$ bash skills/teamsmith/tests/smoke.sh --select 4c      # 第 2 批新指针点名的那一段，实跑
  ✓ M48：重复 ID 被拒（非 0）
  ✓ M48：被拒时 BOARD 逐字节未变
  ✓ M48：--allow-dup 显式允许写入
  ✓ M48：assign 后行数不变（不是又加一行）
  ✓ M48：assign 后 T1.1 仍是两行（没有顺手改历史数据）
== 选段结果 ==  ✓ 108  ✗ 0          # rc=0；§4c 自身 ✓42 ✗0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…/dev-bob scope=published files=1841 hits=0 names=ok user=resolved    # rc=0（本报告已 add，计入扫描面）

$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict     # 裸 openspec 不在本 shell 的 PATH 上
Totals: 20 passed, 0 failed (20 items)

$ git diff --check          # 无输出（无空白错误）
$ git status --short        # 无输出（报告提交后树干净）
```

两条反例各自跑的是 `--select 6b` 与 `--select 21`（第 5 节），都在 `/var/tmp` 的副本里；真实树在
0e 运行期间**一个字节没动**（gate 的运行指纹要求：运行前后 HEAD 与 `git status --porcelain` 一致）。

## 八 · 第 2 批：按「活文件」口径删掉的 11 个

| 文件 | 行数 | 删前唯一点名它的地方（历史面） |
|---|---|---|
| `flip-m16.sh` | 166 | `reports/M16-dev2.md` |
| `flip-m6.3.sh` | 286 | `reports/M6.3-dev.md` + `archive/2026-10-03-meeting-liveness/tasks.md` |
| `flip-p160.sh` | 182 | `reports/P160-dev-bob.md` + `archive/2026-10-03-meeting-liveness/tasks.md` |
| `flip-p201.sh` | 249 | `reviews/P205-done.md`、`reports/P201-dev2.md` |
| `flip-p22.sh` | 123 | `reports/P22-verify.md` + `archive/2026-09-22-settings-choice-editors/` |
| `flip-p23.sh` | 239 | `reports/P23-dev-bob.md`、`reports/P24-dev-bob.md` + 三份归档 |
| `flip-p287-name.sh` | 279 | `reports/P288-dev-bob.md` + `archive/2026-10-16-gate-lock-external-deletion/` |
| `flip-p304-read-side.sh` | 98 | `reviews/V56.md`、`reports/P304-dev2.md` |
| `team-bg-flip.sh` | 239 | `reports/M27-dev2.md` + `archive/2026-09-23-test-tmp-hygiene/` |
| `team-inbox-watch-flip.sh` | 191 | `reports/M30-dev2.md` + `archive/2026-09-23-test-tmp-hygiene/` |
| `flip-m48.sh` | 304 | `reports/M48-dev3.md`、`reports/M61-dev-bob.md`（活文档那句由本批改掉，见下） |

提交：`cd7da321`（10 个 / 2 052 行）、`bcaf5822`（改文档）、`52c949b9`（删 `flip-m48.sh` / 304 行）。

### 动态零引用（PM 要求的第二道证明，11 个文件逐个过）

```
# ① import / require（bun / node / python 的三种引入面）
$ grep -rIn -E "(import|require|from)[^\n]*['\"][^'\"]*(flip-m16|flip-m6\.3|flip-p160|flip-p201|flip-p22|flip-p23|flip-p287-name|flip-p304-read-side|team-bg-flip|team-inbox-watch-flip|flip-m48)" \
    --include='*.ts' --include='*.tsx' --include='*.mjs' --include='*.js' --include='*.py' . | grep -v '^./docs/team/\(reports\|reviews\)'
（无输出）

# ② 测试收集规则：仓库里唯一的 test 入口是 package.json（没有 vitest/jest/pytest/`*.test.*` 收集面）
$ grep -n '"test"' package.json
35:    "test": "TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh"
（smoke.sh 就是门禁本体，已在第 2 节的可达性扫描覆盖）

# ③ 变量拼接出来的调用点（flip-<变量>.sh / team-<变量>-flip.sh 之类）
$ grep -rIn -E '(flip-|team-)[^"'"'"' ]*\$|\$\{?[A-Za-z_]+\}?(-flip|\.sh)' --include='*.sh' --include='*.ts' --include='*.mjs' --include='*.py' skills/teamsmith scripts
skills/teamsmith/scripts/lib/outbox.sh:598:  buf="team-outbox-$$-$RANDOM"      # 临时名，不是夹具名
skills/teamsmith/tests/fixtures/p55/flip-p49.sh:30: … teamsmith-p55-flip-sock-$(team_project_ns).XXXXXX   # 临时目录名
（没有一条能拼出这 11 个文件名）

# ④ loop-inventory：11 个都没有登记行，所以第 2 批不用动清单
$ for f in flip-m16 flip-m6.3 flip-p160 flip-p201 flip-p22 flip-p23 flip-p287-name flip-p304-read-side team-bg-flip team-inbox-watch-flip flip-m48; do
    grep -c "^$f\.sh	" skills/teamsmith/tests/loop-inventory.tsv; done | sort -u
0
```

### `references/troubleshooting.md` 那一条（PM 要求给出改前 / 改后）

改前（`:1123`–`:1125`）：

> The fixtures that pin this are `tests/panel-b3.sh board` (two rows with one id: one cursor, both reachable,
> both walks) and `tests/smoke.sh` §4c (refusal, `--allow-dup`, the three visible reports); `tests/flip-m48.sh`
> proves both go red when the row identity / the check is removed.

改后：

> The gate pins this in `tests/smoke.sh` §4c (`bash skills/teamsmith/tests/smoke.sh --select 4c`):
> `M48：重复 ID 被拒（非 0）`, `M48：被拒时 BOARD 逐字节未变`, `M48：--allow-dup 显式允许写入`,
> `M48：assign 后行数不变（不是又加一行）`, `M48：assign 后 T1.1 仍是两行（没有顺手改历史数据）`, and the three visible
> reports (`board ls`, `team digest`, `team doctor`); each goes red when the row identity or the check is
> removed. The console half — two rows with one id sharing one cursor, both reachable, both walks — is pinned
> only by `tests/panel-b3.sh board`, which the gate does not run: no gate section carries it.

新指针是可执行的：`--select 4c` 实跑一遍（第 7 节），五条断言都在结果里。

## Decisions and deviations

- **只删 23 个，不删 33 个**：任务书第 4 条与硬约束 3 要求「`references/*.md`、`SKILL.md`、`openspec/**`、
  `docs/team/tools/**` 里点到名的先列名单」。归档变更里的点名（25 个）按字面属 `openspec/**`，所以我一并
  列出、不删。若 PM 裁定「归档点名不算」，第 2 批可以一次删掉 c) 25 个 + d) 里 3 个 keyprobe 伴生文件
  （需同批删 `panel-keyprobe.sh`）共 5 438 + 256 行。
- **与 P328 的 54 / 13 030 差 2 个 / 352 行**：我的扫描把「只在整行注释里出现」不算调用，于是
  `flip-m7.2.sh`（324 行，`smoke.sh:6014/6054` 只是注释指向它）与 `flip-p71.sh`（184 行）在我的口径下变成
  不可达；反过来 P328 的候选集与我不同（`tests/lib/**` 里的 `section-guard.sh` 与顶层同名副本的歧义）。
  两个口径都指向同一批「没人调用」，差异只影响「这一批删多少」，不影响任何一条真调用。
- **`tests/section-guard.sh`（顶层 142 行的旧副本）没删**：它与 `tests/lib/section-guard.sh`（1 007 行，smoke
  真正 source 的那份）同名但内容不同，门禁读的是 `lib/` 那份；因为 `openspec/specs/verification/spec.md`
  历史上点过 `tests/section-guard.sh` 这个名字（属 `openspec/**`），按第 4 条留下列进名单。
- **没有新增任何夹具、检查器、预算表、规格条文**；两个扫描脚本与两个反例脚本都在 `/var/tmp/p330/`，不进树。
- **没跑整套门禁**（任务书明确要求，P326 正在改 `smoke.sh`）：只跑了 `--select 0e`、两条反例各自对应的
  `--select 6b` / `--select 21`。没跑的段见 `--select 0e` 结尾的 130 个键。

## PM 裁定（2026-10-20，第 1 批已收，第 2 批口径）

第 1 批收下：23 个夹具 / 4 333 行、`loop-inventory.tsv` 同步 4 行、`--select 0e` ✓45 ✗0、两条反例实跑。你主动把「26 个只在归档里被点名」的留着等裁，这一点做对了——我抽查了其中四个，`section-needs-audit.sh` 与 `flip-p171.sh` 都**被活文件引用**（见下），如果照「归档点名」一刀切就会切到活的东西。

### 第 2 批的口径（一条规则，自己执行，不要再逐条问）

判据从「谁点名」改成「**点名它的是不是活文件**」：

- **活文件** = 除 `openspec/changes/archive/**`、`docs/team/reports/**`、`docs/team/reviews/**`、`docs/team/tasks/**` 之外的任何被跟踪文件（含 `section-paths.tsv` 的 basis 列、`smoke.sh` 的注释、`references/*.md`、`SKILL.md`、`tests/**` 里其它文件的注释）。
- **名字出现在任何活文件里 → 不许删**（无论那是调用还是注释）；先在报告里列出来。
- **只出现在上述四类历史面里 → 删**。
- 删除前额外证明一次**动态**零引用：`bun`/`node`/`python` 的 import/require、`*.test.*` 的收集规则、以及变量拼接的调用点（你上一批已做过一次，保留做法）。

### 按这条规则，我已经查过的四个（结论给你，不必再查）

- `section-needs-audit.sh`（111 行）——**留**。`section-paths.tsv` 的 basis 列有几十行写着「口径见 tests/section-needs-audit.sh」，`smoke.sh:18106` 也点名它。它是**审计程序**，不是夹具；删了那张映射表的依据就成空话。
- `flip-p171.sh`（249 行）——**留**。`signal-gate.sh:25/85/499` 三处注释写着「完整矩阵在 tests/flip-p171.sh」。它是 P171（`state/` 软链失明）唯一的复现工具；P318 这轮刚裁定保留那三条仪器断言，删掉复现工具与那条裁定冲突。
- `flip-p304-read-side.sh`（98 行）——**可删**（只被 `reviews/V56.md` 点名）。
- `flip-p201.sh`（249 行）——**可删**（只被 `reviews/P205-done.md` 点名）。

### `flip-m48.sh`（活文档点名）：删，并同时改那一行

`references/troubleshooting.md` 那句「钉住这件事的夹具是 `tests/flip-m48.sh`」指向一个从不运行的夹具，是**假指针**。做法：把那句改成指向**今天真的会跑**的那一段（给出段键与断言名），再删夹具。`references/troubleshooting.md` 不在 P326 写集里，你可以改这一行。报告里贴出改前/改后的两行。

### 事故墓碑的清单（第 6 节）：我接受你的写法，但要补一列

你给的「事故 → 删掉的包 → 剩下的书面证据」这份表很好。补一列 **「今天哪一段仍然会在修复被改坏时变红」**：填不出段键的，标 `无门禁承接`（你在 `flip-p20` 上已经诚实地标了一次）。这一列是我据以决定「要不要在下一批里给那条事故补一条真会跑的断言」的唯一依据——现在不补，只登记。

### 第 1 批里我要确认的一件事

`panel-flip-m54.sh`（207 行）删掉了。它对应的 M54/M55 是「设置视图：有选择就给选择」。请在报告里点明：这个行为的门禁承接者是哪一段、哪条断言（`38-a panel-choices.sh` 的哪一行）。填不出来就说明它属于「无门禁承接」那一类，按上一节登记。
