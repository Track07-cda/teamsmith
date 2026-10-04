# M74 · settings-choice-editors 重做后的独立验证（verify 阶段）

```
task:    M74
agent:   dev
branch:  task/M74-settings-choice-editors-argv（local 模式：不 push；分支留在 .worktrees/dev）
change:  settings-choice-editors（phase: verify；apply = dev2 的 M68（a36a7c0），本验证与其无 apply 关系，D31 成立）
deps:    M65（修订提案）· M68（重做 apply，已合并）· M59/M60（原件交互的基线验证）
status:  PASS（六条对抗性验证全过 + 五条验收命令全绿；1 条 finding 为 pre-existing 噪声，已坐实不算本 change）
```

证据目录：`docs/team/reports/M74-dev/pkg/`（独立复验包：`lib.sh` + `run.sh` + 5 段 +
`m74parse.py` 独立解析器）。PM 可在任意 checkout 上 `bash docs/team/reports/M74-dev/pkg/run.sh` 重跑，
也可 `bash run.sh 10 30` 选段；每段自带 `== 结果 ==` 行，finding 不判失败（包约定同 memory #1053）。
**本任务不改实现**：`scripts/**`、`extension/**`、`tests/**` 零改动（§10 干净证明）；所有变异只在
`/tmp` 的 scratch 副本/夹具里做（pkg/40 的构建幂等段在真树上重建两次 bundle，以 git diff 干净为证）。

## 判定总表

| 任务书验证项 | 方法（对抗性增量） | 结果 |
|---|---|---|
| 1 直写 argv 序列（决定②） | 自有 pty 探针 + argv 记录 wrapper：**enum 键** TEAM_MONITOR_UI（dev2 探的是 bool 键），指纹**逐字节**对独立算的契约 sha256 | PASS（§1，pkg/10） |
| 2 交互路径零读取（M1） | open/move/accept/free-text 四个窗口零子进程断言；静默判据 = argv 连续 3 次不变；第二次直写带**新**指纹（settle 重读落地，不靠动作前重读） | PASS（§2，pkg/10+15） |
| 3 危险值例外（决定④） | **bool 选项条目** TEAM_REVIEW_ALLOW_DIRTY=1（危险值从 choices.values 挑，dev2 探的是数值键的当前项；D6 点名的例子）两次 accept | PASS（§3，pkg/20） |
| 4 「其他」路径（决定③） | 自由输入窗口零读取 + 两步确认逐帧验 + 非法值留草稿零审计 + keep-unset=取消 | PASS（§4，pkg/15） |
| 5 读取一遍且等价（M2） | **自写独立解析器**（m74parse.py，不执行被测代码）与读逐字段深比对 122 条记录 + 耗时复测 + 父实现差分 | PASS（§5，pkg/30） |
| 6 旧语义没丢 | CLI 层直打 refuse(5)/CAS(3)/danger(7)/非法(4)/dry-run 零审计/审计形态 + 构建两次幂等 + restart 回执措辞 | PASS（§6，pkg/40+10） |

翻转证据（验收命令 `panel-flip-m54.sh F-B F-C W-A W-B` 的红绿两侧）见 §7；验收命令全表见 §8；
已知噪声坐实（finding）见 §5.4 与 §9。

---

## §1 直写 argv 序列（pkg/10，pty · 私有 tmux server）

探针对象：**enum 键 TEAM_MONITOR_UI**（规格场景点名的键；dev2 的探针 p21 用 bool 键
TEAM_NOTIFY_TMUX——不同代码路径）。夹具把键摘掉（未设），走完整段：
打开选择器 → 移到 `tui` → 一次 Enter。结果（全 20 条 ok）：

```
ok 窗口①打开选择器：按键→帧之间零子进程（无 config list/__panel-data）
ok 未设 enum 的条目：保持未设起头 + 默认标记在 auto
ok 窗口②移动焦点：零子进程
ok 一次 accept 的回执就是写入（没有第二确认帧）
ok 无确认帧 / ok 无写编辑器
ok restart 类的回执不谎称已生效（需要重启才生效）
ok 第 1 个子进程 = dry-run，指纹 = 构建选择器那次读的指纹
ok 第 2 个子进程 = --yes --fingerprint（同一指纹）
ok accept 之后只有 settings 块的 settle 重读（没有别的块、没有第二次写）
ok 契约落了 tui / ok 审计恰好 +1 行
ok 重开选择器：tui 标为当前（背景重读已喂给视图）
ok 第二次 accept 同样直写（写回默认 auto）
ok 第二次写入带的是**新**指纹（settle 重读落地，不是动作前重读）
ok 直写路径的冲突回执点名了冲突
ok 冲突后契约仍是外部写者的字节 / ok 外部写者的值留在契约里
ok 审计记了一行 result=conflict / ok 冲突只长一行审计
== 结果 ==  ok=20 bad=0 finding=0 skip=0
```

关键 argv（探针 wrapper 逐行记录的真实子进程，`$sha0` 是我对契约独立算的 sha256）：

```
config set TEAM_MONITOR_UI tui --actor panel --dry-run --fingerprint $sha0
config set TEAM_MONITOR_UI tui --actor panel --yes     --fingerprint $sha0
--root … __panel-data --block settings --events 4        ← 唯一后续：settle 重读
```

**对抗性增量**（dev2 包没有的）：① 指纹不是「占位符出现过」而是**逐字节等于**我独立算的契约
sha256；② 第二次直写验**指纹新鲜度**——CAS 的新鲜度来源是写入后那次 settle 重读（不是每次动作前
重读），第二次写入带的是新指纹 sha1 而不是旧的 sha0；③ **直写路径**的 CAS 冲突（编辑器开着时第三方
追加 `TEAM_MONITOR_UI="text"` → accept → 拒写回执点名冲突、契约保对方字节、审计恰好 +1 行
result=conflict）——dev2 的冲突探针走的是 typed 编辑器路径。

## §2 交互路径零读取（pkg/10+15）

四个窗口的零子进程断言（「按键 → 对应帧出现」之间的 wrapper argv 增量必须为空）：

| 窗口 | 断言 | 结果 |
|---|---|---|
| 打开选择器 | Enter→选择器帧之间零子进程 | ok（pkg/10） |
| 移动焦点 | Down→新帧之间零子进程 | ok（pkg/10） |
| accept 直写 | argv 恰为 dry-run + --yes，无读取类子进程 | ok（pkg/10） |
| 打开自由输入 | Enter→编辑器帧之间零子进程 | ok（pkg/15） |

静默判据（memory #1173）：面板的后台子进程全过 wrapper，argv 行数连续 3 次（间隔 0.4s）不变
才算安静；每段按键前先等安静，杜绝把 settle 重读误记进窗口。红侧证明 = 翻转 W-A（§7）：
把 `config set` 前重新塞回 awaited `refreshSettings` 后，p21 的窗口断言恰好在预期点变红。

## §3 危险值例外（pkg/20，pty）

TEAM_REVIEW_ALLOW_DIRTY（未设的 bool 键；危险值 `1` 从 choices.values 里挑——设计 D6 的原话
「选 TEAM_REVIEW_ALLOW_DIRTY=1」；dev2 探的是数值键 TEAM_MIN_FREE_SWAP_MB 的**当前**条目 0）：

```
ok bool 默认标记在 0（关）/ ok bool 无自由输入项
ok 第一次 accept 只出示危险警告（命令的 exit 7 判定）
ok 警告帧形态（危险：…再按一次 Enter 确认）
ok 警告后契约 sha 不变 / ok 警告后审计不增长
ok 第一次 accept 无 --yes / ok 第一次 accept 的唯一动作是 dry-run 校验
ok dry-run 没带 --allow-danger
ok 警告之后选择器还开着（第二次 accept 在同一处）
ok 第二次 accept 写入危险值 / ok 契约落了 1
ok 写入带了 --allow-danger（命令的 danger 例外，不是面板自判）
ok 两次 accept 全程审计恰好 +1（警告那次不留痕）
== 结果 ==  ok=14 bad=0 finding=0 skip=0
```

## §4 「其他」（自由输入）路径（pkg/15，pty）

TEAM_PULSE_INTERVAL（未设的数值键，封闭域的反面教材）：建议值按 schema 列原序
（300/900/1800/3600，默认标 900）、选择器点名「接受区间 60–（空 = 无界）」、
「…（自由输入）」是唯一进编辑器的入口：

```
ok 打开自由输入：按键→编辑器帧之间零子进程
ok 非法值 30：拒绝点名接受域（最小 60）· 编辑器还开着且草稿保留 · 契约 sha 不变 · 审计不增长
ok 非法值的 argv：先过 dry-run（校验是命令的）· 没有任何 --yes
ok 合法值 1800：确认帧在 typed 路径上原样保留（键/新值/需要重启才生效/再按 Enter 写入）
ok 确认帧阶段契约还没写 · 第一次 Enter 只有 dry-run · 第二次 Enter 才 --yes --fingerprint
ok typed 全程审计恰好 +1
ok keep-unset（未设键首条目）：不开编辑器 · 契约 sha 不变 · 审计不增长 · 零 config set（连 dry-run 都没有）
== 结果 ==  ok=22 bad=0 finding=0 skip=0
```

## §5 读取一遍且等价（pkg/30，CLI 层）

### 5.1 独立解析器逐字段等价（条目5 的核心）

`pkg/m74parse.py`：**不执行被测代码**的独立解析器——契约逐行扫描（引号/#/转义/重复行/export/
缩进，按 awk 扫描器同规则）、schema 表按行型直接从 `cmd-config.sh` 源码提取、choices 按设计 D1
的表推导、models 块按 known/seats 来源规则推导、fingerprint/mtime/audit 按公开格式计算，
输出与 `config list --json` 同形 JSON，逐字段深比对（含**键序**，记录顺序是规格的一部分）。

夹具形态（与 dev2 的包不同）：单引号内 `#`、双引号内 `\"`/`\\`、tab 缩进赋值、重复未知键、
行尾中文注释、席位 state 记录（dev.env）、pm 模型 override、未知席位 token（warning 字段）。

```
FIELD-MATCH records=122 known=5 seats=3 audit=2
ok 独立解析器与读逐字段一致（122 条记录，含 choices/models/audit/fingerprint/mtime）
```

（records=122 = 111 schema 键 + 11 个未知键记录；深比对 0 差异。）

### 5.2 耗时级别（设计：~3.4s → ~0.2s）

```
当前实现 5 次耗时（ms）：220 215 219 222 204   → 中位 219
父实现   5 次耗时（ms）：3516 3637 3816 3788 3630 → 中位 3637
ok 耗时级别：父实现中位 3637ms ≥ 3× 现在的 219ms（不是回退）
```

### 5.3 父实现差分（回归：重写前后逐字节）

M68 合并点 e43c7a2 的 `cmd-config.sh` 换进一棵 scratch 树（scripts 其余部分用当前的——
两提交间 scripts/lib 只有 cmd-config.sh 变过，`git diff e43c7a2 HEAD --stat` 证实），同一夹具：

```
ok 父实现的读与现在的读逐字节一致（38590 字节，e43c7a2 对 8b77049）
```

（与 dev2 包的字节比对 38297 字节不同的夹具、相同的结论：重写没有改变读的输出。）

### 5.4 已知噪声坐实（finding，不算失败）

`TEAM_AGENT_MODELS="dev="`（空 override）时读产出**非法 JSON**（`"override":,`）：

```
finding TEAM_AGENT_MODELS='dev='（空 override）产出非法 JSON——父实现同样非法（pre-existing，
不是本 change）："seats":[{"agent":"dev","model":"配置","source":"config","override":},…
```

判定依据：**父实现 e43c7a2 在同一夹具上产出同样的非法 JSON**（字节同形）——缺陷先于本 change
存在（PM 在任务书里预警的方向，坐实为 pre-existing 读路径 bug，且 dev2 的包没覆盖这个形态）。
根因记录：`team_config_agent_model` 对空 token 值回退成打印中文字面量「配置」（来源标签错当模型值），
且 `override` 以 `${#override}` 的算术上下文形态进 JSON。详见 §9。

## §6 旧语义没丢（pkg/40 CLI + pkg/10 回执措辞）

CLI 层直接打（不经面板），全 22 条 ok：

```
ok refuse 键（TEAM_PROJECT）拒写 exit 5 · 点名手改路径 .pi/team/config.sh · 没写进去
ok dry-run rc=0 · 契约 sha 不变 · 不留审计
ok 正常写审计行形态（result=ok actor key old new）
ok CAS 冲突拒写 exit 3 · 契约保对方字节 · 对方写入还在 · 审计记 result=conflict
ok 危险值（TEAM_MIN_FREE_SWAP_MB=0）无许可 exit 7 · 给出危险理由「容量底线归零」· 未写入
ok --allow-danger 写入危险值
ok 非法值（TEAM_PULSE_INTERVAL=30）拒写 exit 4 · 点名接受域（最小 60）· 契约不变
ok 连续两次重建逐字节一致 · 提交的 bundle 与 src 同步（重建 = 提交字节）· git diff 干净
== 结果 ==  ok=22 bad=0 finding=0 skip=0
```

restart 回执措辞（pkg/10 顺带）：写入 restart 类键的回执是
`已写入 TEAM_MONITOR_UI = tui · 需要重启才生效`——不谎称已生效。

## §7 翻转证据（验收命令 panel-flip-m54.sh F-B F-C W-A W-B）

```
$ bash skills/teamsmith/tests/panel-flip-m54.sh F-B F-C W-A W-B
== 结果 ==  ✓ 16 ✗ 0   （rc=0）
```

四个翻转各自的红→绿：

| 翻转 | 打破什么 | 红侧（失败点 = 预期点） | 绿侧 |
|---|---|---|---|
| F-B（schema 列漂移） | schema 枚举偷偷加值不同步 choices.ts | 一致性走查恰好点名漂移键与值 | 恢复后 choices 变绿、bundle 逐字节还原 |
| F-C（机器目录泄漏） | known 里塞进机器目录模型 sub2api | 选择器开屏不该出现的词出现了 | 同上 |
| W-A（零读取窗口回退） | config set 前塞回 awaited refreshSettings | 打开选择器/自由输入窗口各抓到 1 个子进程（`__panel-data --block settings`） | 同上 |
| W-B（直写丢标记） | 直写不带 --actor panel 也不带 --fingerprint | 「直写没有打开编辑器」「契约落了规范值 0」等 4 条预期红 | 同上 |

红侧尾巴（W-A，证明窗口断言抓得住回退）：

```
✗ 打开选择器：按键→帧之间零读取、零子进程（读=1 总=1）：--root … __panel-data --block settings --events 4;
✗ 打开自由输入：按键→帧之间零读取（现场：--root … __panel-data --block settings …）（期望 [0]，实际 [1]）
== 结果 ==  ✓ 108  ✗ 2
```

红侧尾巴（W-B，证明直写标记断言抓得住）：

```
✗ 直写没有打开编辑器（不该出现 [╭─ TEAM_NOTIFY_TMUX]）
✗ 契约里落了规范值 0（…/config.sh 里没有匹配 [^TEAM_NOTIFY_TMUX=.0.$]）
```

每个翻转跑完后 `git status` 干净、bundle 与 HEAD 逐字节一致（翻转脚本自带恢复验证；§10 有我交付时的复核）。

## §8 验收命令（任务书点名，全部实际运行）

| 命令 | 结果 | 说明 |
|---|---|---|
| `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` | rc=0 | 全仓库规格严格校验 |
| `node skills/teamsmith/tests/panel-strings.mjs` | `panel-strings: ok`（rc=0） | 327 个文案键 zh/en 对齐；111 个 schema 键标签双语覆盖 |
| `bash skills/teamsmith/tests/panel-choices.sh` | ✓41 ✗0 | 含一致性走查与 F-A/F-D 翻转 |
| `bash skills/teamsmith/tests/panel-p21.sh choices` | ✓110 ✗0 | 读侧夹具（`--block choices` 开关等价等） |
| `bash skills/teamsmith/tests/panel-p21.sh settings write conflict seats readonly` | ✓95 ✗0 | 既有写路径回归 |
| `bash skills/teamsmith/tests/panel-flip-m54.sh F-B F-C W-A W-B` | ✓16 ✗0 | §7 |
| `bash skills/teamsmith/tests/smoke.sh`（全量） | **第二轮 ✓2803 ✗0（全绿）** | 第一轮 ✗1（我自己的 pkg 文件触发 M28 lint，见下）；修复后第二轮全绿 |
| 复跑佐证：`TEAM_M68_TREE=$PWD bash docs/team/reports/M68-dev2/pkg/run.sh` | 2+5+14 ok，0 bad | dev2 的复验包在本 checkout 上原样可复现 |

smoke 第一次运行的唯一红：`M28 真树有未隔离的 tmux 变更命令` —— 红在**我自己的验证资产**上
（pkg/lib.sh 的 4 行：清理用了字面 `/usr/bin/tmux`（M41 起禁：绕过 PATH 闸门）、start_panel 的
new-session/new-window/kill-server 只靠 PATH shim（lint 口径：shim 会被登录 shell 洗掉，不算隔离证据））。
与实现无关（实现零改动），但门禁口径对 `docs/team/reports/*/pkg/**` 同样生效。修复：全部收进
`m74_tmux()` 包装（体内 `env -u TMUX -u TMUX_PANE TMUX_TMPDIR=<已 mkdir 的私有目录>`，lint 规则 B/C），
TMUX/TMUX_PANE 导出保留给被测面板的后代兜底；注释里记了 lint 口径与 memory #1250 的 sockdir 前提。
修复后 `perl skills/teamsmith/tests/tmux-lint.pl` rc=0（0 RED），pkg 五段复跑结果不变，全量 smoke 复跑见上表。

负载记录（pty 段的已知噪声纪律）：各段起跑时 loadavg 均在 0.9–2.6（阈值 0.75×32=24），无任何
「机器太吵」豁免行出现。

## §9 发现（finding；不阻塞，供 PM 决定去处）

1. **`TEAM_AGENT_MODELS` 空 override（如 `dev=`）使 `config list --json` 产出非法 JSON**——
   **pre-existing**（父实现 e43c7a2 字节同形），不是本 change 引入；dev2 的包与本包 §5.4 各自
   独立坐实。症状：`seats` 里该席位 `model` 变「配置」、`override` 非法。建议：单开修复任务
   （读路径，`team_config_agent_model` 空值回退 + JSON 转义两处）。
2. M65 measure 脚本（`docs/team/reports/M65-dev3/measure/run.sh`）的复跑归 PM（任务书 6.2），
   本包 §5.2 的 5 次中位（219ms vs 父实现 3637ms）可作交叉参照。

## §10 边界与干净证明

- 改动只落在 `docs/team/reports/M74-dev/**`（OWNERSHIP：dev 拥有自己的报告文件/目录）；
  任务书、规格、实现、测试零改动。
- 交付时 `git status --porcelain`：仅 `?? docs/team/reports/M74-dev.md` 与 `?? docs/team/reports/M74-dev/`。
- 翻转与构建幂等跑完后 `git diff HEAD -- skills/` 为空（bundle 与 src 均还原/同步）。
- 所有 tmux 活动在私有 server（`m74pkg-<pid>`）与 /tmp 夹具里；本队真实会话未触碰
  （pkg 的 PATH shim + TMUX/TMUX_PANE 导出 + m74_tmux 包装三层，且 M28 lint 现在 0 RED）。
- smoke 全量第二轮期间无其他门禁并发（flock 串行；panel-flip/p21 均显式排队）。
- 交付时复跑：`openspec validate --all --strict` rc=0（18 项）、`node …/panel-strings.mjs` rc=0。

### 复验入口

```bash
# 整包（约 8–10 分钟；pty 段需要 tmux + node）
bash docs/team/reports/M74-dev/pkg/run.sh
# 单段：bash docs/team/reports/M74-dev/pkg/run.sh 10 15 20 30 40
```
