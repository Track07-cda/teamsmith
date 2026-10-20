# V82 · P327 的独立验收：夹具接进 §38，且地板里真的没有它

agent: verify   status: PASS（四问都成立；红侧一红一名、还原即绿；一条文字级观察见 §七-F1）
               time: 2026-10-20T20:56Z
branch: `task/V82-panel-b2-wiring-verify`（local 模式，未 push）   PR/MR: -
受检：候选 `09aada88`（实现 `e63282cb`；相对合并基 `2c70708f`：`tests/smoke.sh` +45、`tests/section-paths.tsv`
+1/−1、作者报告 +213）。作者报告 `docs/team/reports/P327-dev.md`。对照：`origin/main` 的同名文件。

方法：候选树 clone 成独立检出（`/var/tmp/v82/cand`，detached `09aada88`），三次选段运行各用**私有 TMPDIR +
私有门禁锁**；跑前 `ps` 里没有别人的 `smoke.sh`，跑后 `git status --porcelain -uall` 为 0 行。破坏只打在
`/var/tmp/v82/redtree` 的一份私有副本里（`P327_SUITE` 指过去），仓库与我的工作树一次都没被写过。没有跑整套、
没有跑地板、没有进容器。

## 结论（先看这里）

1. **`panel-b2.sh` 一个字节没改，读数与 P336 一致。** blob 在 `origin/main` 与候选上都是
   `4136a2c7e4712cfe5d6cab45b3de3f016ea3d382`、`git diff` 空；场景表 11 个名字；候选上 `--select 38` 的
   `38-h` 读到 `✓167 ✗0`，与 `docs/team/reports/P336-dev.md` 记的四次 `✓ 167 ✗ 0` 同一个数。
2. **地板里确实没有它，而且“地板”这条 reason 不会被当成直接点到。** 地板对 §38 给的是
   `reason=38 ← floor, needs:63`（`--floor` 的 128 个 key 里 38 只出现这一次）；我按源码边界机械抽出那段
   逐条判 reason 的 16 行代码，把**这条原样输出**喂进去 → 不判直接点到。同树的 `--select 63`（§38 只经
   `needs:63` 进来）在门禁里跑出 `SKIP（条件不满足） 38-h·panel-b2-写信面`、§38 用时 **330 s**；点到时同一段
   用时 **756 s** —— 差 426 s，与作者的 431 s 同一量级。地板不是“跑一次看看”，而是“同一条 SKIP 分支、同一组
   a–g 腿”，这两头我各用一次真实运行钉住了。
3. **直接点到时真跑。** `--select 38`（连跑两遍：绿侧 932 s / 红侧 924 s）都执行了夹具，`38-h` 分别读到
   `✓167 ✗0` 与 `✓166 ✗1`；`--select 38-h` 这种“单点一条腿”选不到（选段器 `未知 key：38-h`，rc=2），
   段是最小粒度，`--select 38` 是能拿到这条腿的最小选择。
4. **逐条判 reason 不是新漏洞。** 那段代码按 `,` 拆、逐 token 去掉前导空格后判闭集
   `''|floor|prologue|needs:*|coupled:*`，只有“其它”——也就是真实的改动路径或 `selected`——才算直接点到；
   合成串里 `floor,needs:63`（无空格）、`floor, needs:63, coupled:5`、FULL 的两条 reason 逐条喂进去全部判“跳过”；
   唯一的例外是我编的 `paths:…` 前缀 —— 它会被当成路径（跑），而选段器根本不产出这种前缀（见 §四）。
   作者说的第一版整串匹配在本机上能复现成同一个 bug：同一串 `floor, needs:63` 用整串 `case` 判就是直接点到。

**反例与还原**：私有副本里把 §38 唯一手挑的断言（2.2「Esc 后草稿保留」的期望值）改坏 → 同一次 `--select 38`
**rc=1**，并逐字点名 `✗ 2.2 Esc 后 state/draft.md 保留草稿（期望 [half a thought (V82-RED)]，实际 [half a thought]）`；
未改动的副本同场景 `✓5 ✗0`，未改动的候选树 `38-h` `✓167 ✗0`。

## 一、`panel-b2.sh` 没被改，读数对得上

```
$ git rev-parse origin/main:skills/teamsmith/tests/panel-b2.sh HEAD:skills/teamsmith/tests/panel-b2.sh
4136a2c7e4712cfe5d6cab45b3de3f016ea3d382
4136a2c7e4712cfe5d6cab45b3de3f016ea3d382
$ git diff --stat origin/main -- skills/teamsmith/tests/panel-b2.sh
（空）
$ grep -n '^ALL=' skills/teamsmith/tests/panel-b2.sh
1229:ALL="cursor keys multiline clipboard draft editor receipt settle pause paste actions"
```

- 11 个场景（上面那行 11 个词）；候选树里 `grep -c V82-RED` 与 `grep -c RED-SIDE` 都是 0，破坏只在
  `/var/tmp/v82/redtree` 里。
- 写集与作者报告一致：`git diff --numstat 2c70708f 09aada88` 只有三行（213 报告 / 1+1 表 / 45 smoke.sh）。
  `section-paths.tsv` 的改动逐字是 §38 那一条：patterns 追加 `skills/teamsmith/tests/panel-b2.sh`，basis 追加一句
  P327 说明；**没有别的行被动过**（word-diff 只有这两处新增）。
- 绿侧的 `--select 38` 里 `38-h` 打的是
  `✓ 38-h panel-b2.sh 写信面（11 场景） 全绿（ ✓ 167 ✗ 0）`。`P336-dev.md`（main 上）记的 `✓ 167 ✗ 0` 出现四次，
  同一个断言总数；P336 自己在报告 `P336-dev.md:293` 交代过“带 shim 的 PATH 下那批绿是环境依赖的”，我这三次运行的 PATH 里
  没有 `scripts/shim`（跑头那行只说“PATH 里没有 pi → 用假 pi”），与 P336 的“无 shim”侧同一条件。

## 二、地板里没有它：两头各一次真实证据

### 2.1 地板对 §38 给的是什么 reason

```
$ bash skills/teamsmith/tests/section-select.sh --floor | grep -E '^(decision|keys)='
decision=RUN
keys=128
$ bash skills/teamsmith/tests/section-select.sh --floor | grep -c '^reason=38 '
1
$ bash skills/teamsmith/tests/section-select.sh --floor | grep '^reason=38'
reason=38 ← floor, needs:63
$ bash skills/teamsmith/tests/section-select.sh --floor --paths skills/teamsmith/scripts/panel/src/App.tsx | grep '^reason=38'
reason=38 ← skills/teamsmith/scripts/panel/src/App.tsx, floor, needs:63
$ bash skills/teamsmith/tests/section-select.sh --floor --paths skills/teamsmith/tests/panel-b2.sh | grep '^reason=38'
reason=38 ← skills/teamsmith/tests/panel-b2.sh, floor, needs:63
```

`--floor` 与 `--floor --paths` 都是 128 个 key（§38 在里面，`38-h` 不在——它不是 key）。纯地板给它的是
`floor, needs:63`；只有 `--paths` 点到写信面（面板源码 / 这个夹具本身）时才多出路径 token。这也是 CI 的形状：
`.github/workflows/gates.yml:123` 是 `smoke.sh --floor --keep --paths "$@"`，`:129` 在无路径时跑整套。

### 2.2 那段判定逻辑对这条原样输出怎么判

判定块在 `tests/smoke.sh:246–261`（16 行，落在父进程的 `elif [ -n "$SELECT_MODE_REQ" ]` 分支里，因此选段子进程
拿的是**导出后的结果**而不是自己重算——`smoke.sh:261` 的 `export` 就是这条通道）：

```bash
SELECT_DIRECT_KEYS=""
while IFS=$'\t' read -r _sel_k _sel_why; do
  [ -n "$_sel_k" ] || continue
  IFS=',' read -r -a _sel_parts <<<"$_sel_why"
  _sel_direct=0
  for _sel_p in "${_sel_parts[@]}"; do
    _sel_p="${_sel_p# }"
    case "$_sel_p" in
      ''|floor|prologue|needs:*|coupled:*) ;;
      *) _sel_direct=1; break ;;
    esac
  done
  [ "$_sel_direct" = "1" ] && SELECT_DIRECT_KEYS="${SELECT_DIRECT_KEYS}${SELECT_DIRECT_KEYS:+ }$_sel_k"
done < <(printf '%s\n' "$SELECT_OUT" | sed -n 's/^reason=\([^ ]*\) ← \(.*\)$/\1\t\2/p')
unset _sel_k _sel_why _sel_parts _sel_p _sel_direct
export SELECT_DIRECT_KEYS
```

我把这 16 行按源码边界（`^  SELECT_DIRECT_KEYS=""` 到 `^  export SELECT_DIRECT_KEYS$`）机械抽出、去掉两格缩进后
原样 `eval` 在合成的 `SELECT_OUT` 上（脚本 `/var/tmp/v82/harness/select-direct.sh`，抽出的 16 行 sha256 =
`982c7b46a56ddc720f25ab81d94f52a3ad6147f2e7718b79f648d4b1b8966e48`）：

| 合成/实录的 reason 串 | `SELECT_DIRECT_KEYS` | 结论 |
|---|---|---|
| `reason=38 ← floor, needs:63`（**`--floor` 的原样一行**） | （空） | 跳过 |
| `reason=38 ← needs:63` | （空） | 跳过 |
| `reason=38 ← prologue` / `← coupled:5` | （空） | 跳过 |
| `reason=38 ← floor,needs:63`（无空格） | （空） | 跳过 |
| `reason=38 ← floor, needs:63, coupled:5` | （空） | 跳过 |
| `reason=38 ← selected` | `38` | 跑 |
| `reason=38 ← skills/teamsmith/tests/panel-b2.sh` | `38` | 跑 |
| `reason=38 ← <面板源码路径>, floor, needs:63` | `38` | 跑 |
| `reason=38 ← paths:skills/teamsmith/tests/panel-b2.sh`（虚构前缀） | `38` | 跑 |
| `decision=FULL` 的两条 reason（未声明路径 + 兜底整句） | 只有那条路径 | 跳过 |
| 两段各一条：`38 ← floor, needs:63` + `39 ← 某路径` | `39` | 38 跳过、39 跑 |

### 2.3 门禁里的同一条 SKIP 分支：`--select 63`

地板那一整轮按任务书不跑（一次约 90 分钟）。能拿到同一条分支、同一组腿、又只花十几分钟的是 `--select 63`：
§38 只经 `needs:63` 进来，reason 是 `needs:63`（不带 `floor`），而 §2.2 的表里两种 reason 都判“跳过”。实跑
（rc=0，实测 log 见 `/var/tmp/v82/runs/indirect/run.log`）：

```
== 选段 == decision=RUN · 运行 11/135 段 · 未跑 124 段
  SKIP（条件不满足） 38-h·panel-b2-写信面 —— 本轮没有直接点到 38（地板 / needs 带进来的；单次全场景 431 s 不进地板，改写信面源码或本夹具时才跑）
#10 38 · 设置选项（M55：choices 读 / 一致性走查 / 选择器夹具） · 参考 用时 330s · ✓15 ✗0 SKIP1 · ticks 16
== 选段结果 ==  ✓ 433  ✗ 0
```

§38 里 a–g 七条腿照常跑（`✓15 ✗0`），`38-h` 只打一行具名 SKIP、记进本轮账本的 `SKIP1`，一段不静默。
**这就是地板的形状与代价**：地板跑的是同一组 a–g，`38-h` 走的是同一个 `cond_skip` 出口（`smoke.sh:18873`），
所以地板里 §38 的用时就是这一档 **330 s**，而不是执行那一档的 **756 s**（作者读数 332 s / 767 s，同一台机器的
不同负载下同一对数字）。

## 三、直接点到时真跑（三次运行的读数）

| 运行 | 选择 | rc | 墙钟 | §38 用时 | §38 断言 | `38-h` | 选段总计 | 树状态 |
|---|---|---|---|---|---|---|---|---|
| green | `--select 38` | 0 | 932 s | 756 s | `✓16 ✗0` | `✓167 ✗0` | `✓432 ✗0` | 跑前/跑后 0 行 |
| red | `--select 38` + `P327_SUITE` 指到改坏的私有副本 | **1** | 924 s | 749 s | `✓15 ✗1` | `✓166 ✗1` | `✓431 ✗1` | 同上 |
| indirect | `--select 63`（§38 只经 needs） | 0 | 1002 s | 330 s | `✓15 ✗0 SKIP1` | 具名 SKIP | `✓433 ✗0` | 同上 |

- 绿侧 §38 的 `✓16` 比改动前多一条（这条腿自己那一条 `ok`/`bad`），红侧是 `✓15 ✗1` —— 新腿确实记进了段账本，
  不是只打印不计数。
- 带腿的 §38 用时 756 s，仍在段挂住上限 1800 s 之内（绿侧看门狗在 660 s / 720 s 各打了一行进度，没有触发上限）。
- `38-h` 单独选不到：`bash skills/teamsmith/tests/section-select.sh --select 38-h` →
  `section-select: 未知 key：38-h（用 --list 看全部 key）`，rc=2。段是最小粒度，间接路径不存在。

## 四、逐条判 reason 不是新漏洞

1. **拆分方式**：`sed` 先把 `reason=<key> ← <why>` 切成两列，`why` 按 `,` 拆，每个 token 去掉一个前导空格后进
   闭集判断。所以 `floor, needs:63` 是 `floor` + `needs:63` 两条，只要全部落在闭集里就不算直接点到；
   `floor, needs:63, coupled:5` 同理。无空格写法（`floor,needs:63`）拆出来同样是这两个 token，判法一样是跳过
   （表里那一行）；也就是说这条判据不依赖选段器的 `", "` 拼接格式。
2. **选段器的 reason 词汇表**（`tests/section-select.sh` 里 `printf 'reason=…'` 只有五处）：裸路径 token
   （`reason=<路径> ← …`）、`selected`、`floor`、`prologue`、`needs:<k>`、`coupled:<k>`；`decision=FULL` 时还有
   “没有任何行声明它”的路径行与一句兜底整句。**没有 `paths:` 前缀**，`full` 是 decision 而不是 reason。
   所以上面那张表里的 `paths:…` 一行是虚构输入，只用来证明“万一将来有人加前缀，它会被当成路径（跑）”而不是
   “现在有这条”。
3. **作者说的第一版**：整串匹配（`case "$why" in ''|floor|prologue|needs:*|coupled:*) …`）对同一串
   `floor, needs:63` 判“直接点到” —— 我在同一台机器上用同一串复算，得到同样的结论。这解释了 767 s 的由来，
   也说明第二版的改动正是那一处（第一版的原件没有被提交，作者报告 §5 自己交代了这次返工，我核的是机制，不是历史字节）。
4. **键隔离**：`sed` 只把**该 key 自己的** reason 行交给这段逻辑，所以 `39 ← 某路径` 不会让 `38` 变成直接点到
   （表里最后一行）。

## 五、反例（红侧）与还原

破坏只有一个字符级的位置（私有副本 `/var/tmp/v82/redtree`，不是候选树）：

```
$ diff -u <原样副本> <改坏副本>
-  assert_eq "2.2 Esc 后 state/draft.md 保留草稿" "$(draft)" "half a thought"
+  assert_eq "2.2 Esc 后 state/draft.md 保留草稿" "$(draft)" "half a thought (V82-RED)"
```

- **夹具层红侧**（改坏副本单跑 `draft` 场景）：`✓ 4 ✗ 1`，rc=1，
  `✗ 2.2 Esc 后 state/draft.md 保留草稿（期望 [half a thought (V82-RED)]，实际 [half a thought]）`。
- **门禁层红侧**（`--select 38` + `P327_SUITE` 指到改坏副本）：整体 **rc=1**，`== 选段结果 ==  ✓ 431  ✗ 1`，
  段内逐字：

  ```
    ✗ 38-h panel-b2.sh 写信面（11 场景） 有失败
          ✗ 2.2 Esc 后 state/draft.md 保留草稿（期望 [half a thought (V82-RED)]，实际 [half a thought]）
        == 结果 ==  ✓ 166  ✗ 1
        panel-b2 有失败项
  ```

  只红这一条：`38-a/b/c/f` 四条照旧全绿，说明失败被准确归到这条腿，没有污染同段别的腿。
- **还原即绿**：同一份副本不改动时 `draft` 场景 `✓ 5 ✗ 0`（31.65 s）；未改动的候选树上 `38-h`
  `✓167 ✗0`（§三的 green 行）。改坏的那份副本我留着没删（`/var/tmp/v82/redtree`），PM 需要时可自己 diff。

## 六、轻量收口

```
$ for f in tests/smoke.sh tests/panel-b2.sh tests/section-select.sh; do bash -n skills/teamsmith/$f; done
（无输出）
$ git diff --check 2c70708f 09aada88
（无输出）
$ bash skills/teamsmith/tests/section-select.sh --check | head -4
ok: 映射表 key 唯一（135 行）
ok: 段 ↔ 行一一对应（源码 135 段 / 表 135 行）
ok: needs 声明全部存在且指向更早的段（108 条）
SKIP（条件不满足）: 行 19 的字面模式在检出里不存在（检出形状 internal，机器生成面（工具在本机生成、不进仓库））：.pi/skills
$ bash skills/teamsmith/tests/section-select.sh --check | tail -1
== 选段自检 ==  ok 9  bad 0  SKIP 1
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.git/../.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify scope=published files=1962 hits=0 names=ok user=resolved
rc=0
```

- **没有新段、没有新检查器**：段表自检在两棵树上都是“映射表 135 行 / 源码 135 段”（`main` 与候选各跑一次），
  本次改动**没有新增 key**（`38-h` 不是 key，选不出来）；字面模式 643 → 644（多出的那一条就是 §38 patterns 里的
  `panel-b2.sh`），检出的真实路径 token 534 → 535（同一条）。
- `bash -n` 三个文件全过（`smoke.sh` / `panel-b2.sh` / `section-select.sh`）。
- **它是这个夹具唯一的执行者**：`grep -rn 'panel-b2\.sh'` 在候选树里只有 `smoke.sh` 的这条腿（`18866` 的默认值、
  `18876` 的执行）与三处注释/文案，另有 `panel-p21.sh:239` 的一句出处说明；没有第二个调用点，所以不存在
  “接了两处、地板从另一处进去”的情况。

## 七、一处观察与边界

- **F1（文字级，非阻塞）**：`section-paths.tsv` 里 §38 那行的 basis 还写着“段内点名 23 条真实路径 token”。
  实测全表 534 → 535，而唯一动过的行就是 §38（新增的 `panel-b2.sh` 归在它名下），所以这一行现在是 24 条。
  `--check` 不校验这个数字（它校验的是“token 都被某一行覆盖”，这一条是绿的），所以它是说明文字与实测差一，
  改一个词即可，属作者的自留地。
- **代价（读数，不是缺陷）**：段是最小粒度，所以任何命中 §38 patterns 的改动都多花 426 s 跑这套写信面夹具。
  实测两例：`--paths skills/teamsmith/scripts/panel/src/App.tsx` → `reason=38 ← <该路径>, needs:63`；
  `--paths skills/teamsmith/tests/panel-p21.sh`（同段另一条腿的夹具）→ `reason=38 ← <该路径>`。这是接线本身的
  价格，与“地板不许变长”不冲突（地板点到 §38 时本来就该跑它）。
- **边界**：没跑整套、没跑地板（按任务书）、没进容器；三次运行各用私有 `TMPDIR` 与私有 `TEAM_SMOKE_LOCK`，
  跑前 `ps` 无别人的 `smoke.sh`，跑后候选树 `git status -uall` 为 0 行。负载：green 3.54→3.03、red 3.03→2.15、
  indirect 2.15→6.06（`/proc/loadavg` 起止）。

## 八、没做与没碰

- 没改实现、没合并、没 push、没动 `main` 与别人的分支；写集只有本报告。候选树、`main`、别人的工作树一次都没被写。
- 没有 `BLOCKED:` 项。
