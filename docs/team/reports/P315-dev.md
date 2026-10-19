# P315 · 两条发布门禁红：归因、修法与修复后的读数（apply · dev）

## 结论

**两条红都不是本次发布周期的产品提交引入的，而且都不是产品行为问题**：`36⑧` 是门禁自己的一行 `tmux new-session`
缺静态隔离证据（`7166c147` / P297 引入），`38-a` 是 `/team` 扩展落地（`45a78952`）后翻转夹具的拷贝集合没跟上。
**两条都已修好并各自一小步提交**（`326ccb09`、`96ac7d0c`），修复后：

| 判据 | 改前 | 改后 |
|---|---|---|
| `perl skills/teamsmith/tests/tmux-lint.pl` | `RED smoke.sh:769 … 缺：-L/-S + 私有 TMUX_TMPDIR`，`1 条变更命令没有隔离证据` | `干净（扫描 93 个脚本，228 条变更命令全部有隔离证据）` |
| `checkout-shape-probe.sh` | `bad 10` | `== 检出形状探针 == ok 146 bad 0 skip 0` |
| `TEAM_SMOKE_FAST=1 smoke.sh --select 36` | `✓142 ✗1`（`36⑧ 产品面检出探针有失败（10 条）`） | `✓ 143 ✗ 0 SKIP3`，`36⑧ 产品面检出探针全绿（ok 146 bad 0 skip 0）` |
| `bash tests/panel-choices.sh` | `✓ 46 ✗ 2` | `✓ 48 ✗ 0` |
| `TEAM_SMOKE_FAST=1 smoke.sh --select 38` | `✓415 ✗1`（`38-a panel-choices.sh 有失败`） | `✓ 416 ✗ 0 SKIP3`，`38-a panel-choices.sh 全绿（ ✓ 48 ✗ 0）` |

**0.3.0 能不能发，仍不是本报告能定的**：`RELEASE-PUBLIC.md` §1 要的是冻结克隆 + 钉死容器里的整套门禁，我这里给的是
本机 distrobox 内、本工作树上 `TEAM_SMOKE_FAST=1` 的选段读数（§5 逐条点名没跑的东西）。选段不是整套。

**改动的全部内容**（相对上一版报告 `179bec8f`）：

```
$ git diff --stat 179bec8f..HEAD
 skills/teamsmith/tests/panel-choices.sh | 17 ++++++++-----
 skills/teamsmith/tests/smoke.sh         | 44 ++++++++++++++++++---------------
 2 files changed, 35 insertions(+), 26 deletions(-)
```

两个都是 `tests/` 下的门禁夹具，没有一个字节落在 `scripts/`、`templates/`、`extension/` 这类产品面上。

## 1 · 归因：都不是本次发布周期的产品提交引入的

判据（D192/D198）：同一命令、同一选段、不同树。

| 树 | `--select 36` | `--select 38` |
|---|---|---|
| `v0.2.0`（上一个发布版，`7e2fa494`） | ✓141 ✗0 ｜ `ok 146 bad 0 skip 0` | ✓392 ✗0 ｜ `panel-choices.sh ✓ 48 ✗ 0` |
| `main~20`（`0cbcdb7a`，今天合并之前） | ✓142 ✗1 ｜ 探针 10 条 bad | ✓415 ✗1 ｜ `38-a` 有失败 |
| 受检树（`97b6b5ae`，修复之前） | ✓142 ✗1 ｜ 同上，10 条 bad 逐条相同 | ✓415 ✗1 ｜ 同上 |

两个基线给同一结论的两种说法：**相对上一个发布版是回归，相对 `main~20` 是已经在了**（今天三次合并既没引入也没修掉）。
对发布决策真正要紧的是第三问「是不是发布提交引起的」，答案是否。

`36⑧` 的根因提交是 `7166c147`（P297，10-17）；`panel-choices.sh` 自 `v0.2.0` 起零提交，是夹具的拷贝集合在
`45a78952`（`team init` 开始安装 `/team` 扩展）之后变得不够。

## 2 · `36⑧` 的修法（`326ccb09`）：把 helper 挪到私有 `TMUX_TMPDIR` 生效之后

`smoke_live_session_ensure` 的注释要求它必须住在**前导段**里（选段副本只整段保留前导 + 选中段），而 M28 的文件级隔离
证据要求私有 `TMUX_TMPDIR` 出现在**使用之前**。原来的位置两条只满足一条：helper 定义在第 768 行，私有 socket 的
`TMUX_TMPDIR="$SMOKE_TMUX_TMPDIR"; export TMUX_TMPDIR` 在第 1014 行 —— 用在使用之前，拿不到那份豁免。

**修法**：函数体一字未改，整块（含注释）挪到私有 socket 段落之后、前导段之内。三条约束同时成立，可核：

```
$ grep -n 'smoke_live_session_ensure()\|TMUX_TMPDIR="$SMOKE_TMUX_TMPDIR"; export TMUX_TMPDIR\|^section "0 · 临时仓库"' skills/teamsmith/tests/smoke.sh
1014:  TMUX_TMPDIR="$SMOKE_TMUX_TMPDIR"; export TMUX_TMPDIR
1050:smoke_live_session_ensure() { # <段标签>
1437:section "0 · 临时仓库"
```

`1050` 在私有目录（1014）之后、第一个段头（1437）之前 —— 隔离证据与「在前导段里」两条都在。调用点 `§42`（`19804`）、
`§44`（`20032`）一个字没动，`section-select.sh --select 36` 生成的副本里这个函数照旧在（`grep -c` = 1，副本 `bash -n` 通过）。

**没选另一条路（给那一行加 `-L`）的理由**：同一个 helper 里还有三处**裸** `tmux` 调用（`has-session` ×2、
`display-message`），`§42`/`§44` 之后也照旧用裸调用读这个会话。只把 `new-session` 钉到 `-L <名字>` 会让会话建在另一个
socket 上，紧接着的 `has-session` 按私有 `TMUX_TMPDIR` 去找它 —— 找不到，helper 会报「建不出来」并红。挪位置是唯一
不改变运行时落点、又补上静态证据的改法。

### 翻转证据（红 → 绿，同一棵树只差这一处改动）

```
改前（97b6b5ae）：
$ perl skills/teamsmith/tests/tmux-lint.pl
  RED  skills/teamsmith/tests/smoke.sh:769  tmux new-session -d -s $SESSION -n pm -x 120 -y 30 -c $REPO 2>/dev/null || true
       缺：-L/-S + 私有 TMUX_TMPDIR
tmux-lint：1 条变更命令没有隔离证据（扫描 93 个脚本，其中 228 条变更命令；历史豁免另算 0 条）
rc=1

改后（326ccb09）：
$ perl skills/teamsmith/tests/tmux-lint.pl
tmux-lint：干净（扫描 93 个脚本，228 条变更命令全部有隔离证据）
rc=0
```

```
改后：
$ bash skills/teamsmith/tests/checkout-shape-probe.sh        # 932s
== 检出形状探针 == ok 146 bad 0 skip 0
rc=0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 36     # 36 用时 1142s
  ✓ 36⑧ 产品面检出探针全绿（ok 146 bad 0 skip 0）
账本自查： 5 段收口 · 增量 ✓143 ✗0 SKIP3 ｜ 结果行 ✓143 ✗0 —— 一致
== 选段结果 ==  ✓ 143  ✗ 0
rc=0
```

## 3 · `38-a` 的修法（`96ac7d0c`）：夹具补拷 `extension/` + F-A 匹配口径收窄

`panel-choices.sh` 的两个翻转夹具（F-A `flip-drop-pm`、F-D `flip-suggest`）这样搭树，编出来的树里没有 `extension/`：

```bash
cp -a "$skill/scripts" "$ft/skills/teamsmith/scripts"
cp -a "$skill/templates" "$skill/references" "$ft/skills/teamsmith/"     # ← 缺 extension
```

`45a78952` 之后 `team init` 要走 `team_extension_install`（源 = `$TEAM_SKILL_DIR/extension/team.ts`），拷出来的树里没有
它 → init 立即退出 → 走查拿不到结论（`rc=3`）→ F-D 两条断言红，`38-a` 跟着红。两处拷贝行都补上 `extension`。

**F-A 的匹配口径**是本条红里唯一一条会"自己骗自己"的地方，按要求一并收窄：

```bash
改前：grep -a '✗' "$tmp/flip-drop-pm-red.log" | grep -qi 'pm'
改后：grep -a '✗' "$tmp/flip-drop-pm-red.log" | grep -qF '独立 PM'
```

理由是实测出来的：红日志里唯一的 `✗` 是 `…找不到可安装的扩展源（/var/tmp/…-panel-choice-pm_skills-…/flip-drop-pm/…/extension/team.ts 不在）`，
`grep -qi pm` 命中的是路径里的 `pm_skills` —— 夹具当场坏掉，这条"红侧点名 pm"照样 ok。下面第二节的翻转证据就是这件事。

### 翻转证据一（红 → 绿）

```
改前（97b6b5ae）：
$ bash skills/teamsmith/tests/panel-choices.sh
    ✗ F-D：红侧没有点名 TEAM_PULSE_INTERVAL / 30
    ✗ F-D：恢复后走查仍红（rc=3）
      ✗ 找不到可安装的扩展源（…/flip-suggest/skills/teamsmith/extension/team.ts 不在）
== 结果 ==  ✓ 46  ✗ 2
rc=1

改后（96ac7d0c）：
$ bash skills/teamsmith/tests/panel-choices.sh        # 88s
  ✓ F-A：去掉 PM 的 known 解析后断言红且点名独立 PM（rc=1）
  ✓ F-A：恢复真树后 known 断言绿
    --- 红侧尾部 ---
      ✗ known = 类别策略的模型 + 独立 PM 模型 + 已提交记录的模型（各一次）（表达式：…）
== 结果 ==  ✓ 48  ✗ 0
rc=0
```

F-A 红侧点名的是正文那一句（`known = … 独立 PM 模型 …`），不再是别的行。

### 翻转证据二（把实现弄坏 → 守卫必须失去牙 → 恢复后重新有效）

跑在 `/var/tmp` 下的一份**临时副本**上（真树不动），只把 F-A 那处拷贝集合再改回缺 `extension`，`TEAM_CHOICES_TREE`
指真树：

```
$ TEAM_CHOICES_KEEP=1 TEAM_CHOICES_TREE=<worktree> bash /var/tmp/p315-fa-broken/panel-choices.sh flip-drop-pm
  ✗ F-A：去掉 PM 的 known 解析后断言没红/没点名独立 PM（rc=3）
    ✗ 找不到可安装的扩展源（…/flip-drop-pm/skills/teamsmith/extension/team.ts 不在）
== 结果 ==  ✓ 1  ✗ 1
rc=1

同一份红日志（flip-drop-pm-red.log，全文 6 行）上两种口径：
$ grep -a '✗' flip-drop-pm-red.log | grep -ci 'pm'      → 1     （旧口径：把夹具坏掉判成"点名 pm"= 假绿）
$ grep -a '✗' flip-drop-pm-red.log | grep -cF '独立 PM'  → 0     （新口径：如实判红）
```

也就是说：这条断言现在**在夹具坏掉时会红**，而改前它在同一个场景下是绿的。恢复真树后 `✓ 48 ✗ 0`（上一节）。

## 4 · 修复后读数里的 SKIP 是什么（不是通过）

`--select 36` 的 `SKIP3` 是 `36① --check` 的三棵树（真树/表副本/变体树）对 `.pi/skills` 的前提跳过 —— 那一面是机器生成面，
本仓这种检出里按构造不存在；`36⑥`/`36⑦` 两条断言本身照旧判绿。`--select 38` 的 `SKIP3` 是 FAST 模式关掉的三个慢段
（`26-m` 真 pane、`38-b`/`38-f` 的 `panel-p21` 场地）。两者都是可见跳过、逐条点名，不计入 `✓`。

## 5 · 环境与测量条件（D192）

- 32 核机器，跑前 `loadavg 18.33 15.85 15.06`、跑后 `16.53 16.19 15.19`（同项目其他席位同时在跑）。
- 全部 `TEAM_SMOKE_FAST=1`，本机 distrobox 内、本工作树（分支 `task/P315-release-reds-attribution`）。
- 用时只作记录、不作判据：`--select 38` 111s、`--select 36` 1142s、`checkout-shape-probe.sh` 932s、
  `panel-choices.sh` 88s、`tmux-lint.pl` < 1s。
- 两次选段链跑在同一份工作树上、串行执行；树在跑动期间没有提交也没有写文件（D189/D192 的指纹口径）。

## 6 · 没跑什么 / 边界

- **没跑整套门禁**：只有 `--select 36`、`--select 38` 两个闭包（36 侧含 §0/0b/0c/0d，38 侧含 §2/26/27/28），外加探针、
  `panel-choices.sh`、`tmux-lint.pl` 的直调。闭包之外的段没跑。
- **没在容器里跑**：发布前置要求在冻结克隆 + 钉死容器里跑整套门禁，这一步要 PM 在发布前置自己量；本报告的读数不能替代它。
- **没碰产品面**：改的全是 `skills/teamsmith/tests/` 下的两个夹具文件；`scripts/`、`templates/`、`extension/`、
  `openspec/` 一个字节未动。
- 临时夹具目录按本次运行的具体路径清理（`/var/tmp/p315-fa-broken`、`/var/tmp/teamsmith-…-panel-choice-…<本次>.<随机>`），
  没有按共享 ns 前缀通配删别人的在飞目录。

## 7 · 本报告的验收读数

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…/.worktrees/dev scope=published files=1767 hits=0 names=ok user=resolved
rc=0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 18c,7b,24,60     # loadavg 16.92 16.37 15.30
账本自查： 9 段收口 · 增量 ✓158 ✗0 SKIP1 ｜ 结果行 ✓158 ✗0 —— 一致
== 选段结果 ==  ✓ 158  ✗ 0
rc=0
```

这两条是本报告文件本身要过的闸门（账本禁令 + 账本引用/记录/报告证据）；产品侧的读数与命令在 §2、§3 的代码块里。
