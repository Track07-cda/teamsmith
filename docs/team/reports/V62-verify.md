# V62 · 复核最小发布修复，补齐未执行的路由变异（verify）

agent: verify   status: delivered   time: 2026-10-19T14:40Z
branch: `task/V62-release-fixture-review`   PR/MR: -（local 模式）
受检分支：`task/P320-release-fixture-repair`（源码冻结 `b4317dfd5354`，报告提交 `c5c85855`，作者 dev3）

## 结论

**PARTIAL：三处修复成立，补齐的那条验收跑完了但没有全绿——唯一的红是既有夹具缺陷，不是本次改动，也不是产品。**

1. **代码差异成立（PASS）。** 改动只落在三个测试文件（`+49/−37`），是原有断言的同位替换与两处调用顺序调整：
   没有新增/删除断言、没有改产品/规格/发布工具/预算表；三处的前提也都真实——会话 helper 判据一字未改而调用点
   已排到 `kill-window` 之后、载体名已移出产品会剥掉的 `TEAM_` 命名空间、本地版本取自被测树本身
   （`TEAM_VERSION=0.3.0`，派生的 `U_OLDER=0.2.0` 严格更小）。
2. **修好的三个入口在冻结树上确实转绿（PASS，独立复跑）。** 固定镜像内、我自己的完整 clone、`TMPDIR` 指向宿主
   磁盘目录：select `4,6,6i,42,44,54` → 14 段 **✓495 ✗0**、rc=0、HEAD 与工作树前后 0 行变化。
3. **路由变异逐条执行并逐条还原（PASS，31/31）。** 一次 `--flip`：基线整条 CORE `pass=3141 fail=0`、
   31 条变异臂全部「靶向命中 → 按名变红 → 源码逐字节还原」（31/31 的 `source_before == source_restored`）、
   还原臂 `pass=3141 fail=0` 且 `flip-restored-all-green` 绿。
4. **但外层仍是 `RESULT pass=200 fail=1 selected=flip`，唯一红是 `flip-init-legacy-proceeds-bootstrap`。**
   归因定量完成：**既有夹具缺陷**，与 P320 无关——同一变异在基线树 `9c58e03e` 与受检树 `b4317dfd` 上给出
   **逐字节相同的 20 行 init-legacy 读数**（`RESULT pass=29 fail=39 selected=init` 两边一致）；根因是翻转变异
   复制变异树时列了 `extensions`（复数，仓里从来没有这个目录），而产品装的是 `extension/`（单数），于是该臂的
   `bootstrap` 腿**不是**被「旧模型闸门」挡住，而是被「找不到可安装的扩展源」挡住，`init-legacy-bootstrap-refused`
   永远不会变红。把 `extension` 一并复制后，该臂期望的三条 `-refused` 全部按预期变红（实测，见 §4.4），
   即这条红是臂的**复制清单**问题，一行级别，但它属于 tests 面，本任务书禁止我改。

所以：**「三处修复是否保持原行为断言与真实前提」= 成立；「补齐的路由变异是否有牙齿」= 31/31 有牙齿且可还原；
「发布门禁是否全绿」= 否，卡在一条与本改动无关的既有夹具缺陷上。** 发布检查表要不要因它放行、以及那条一行修复
派给谁，是 PM 的裁定。

## 1 · 受检对象与范围

```
$ git diff --shortstat 9c58e03e b4317dfd
 3 files changed, 49 insertions(+), 37 deletions(-)
$ git diff --name-status 9c58e03e task/P320-release-fixture-repair
A	docs/team/reports/P320-dev3.md
M	skills/teamsmith/tests/routes.sh
M	skills/teamsmith/tests/smoke.sh
M	skills/teamsmith/tests/task-model-routing.sh
$ git diff --check 9c58e03e b4317dfd
（无输出）
```

- 基线 `9c58e03e` 就是两棵树的合并基；差量里**没有**产品（`skills/teamsmith/scripts/**`）、规格（`openspec/**`）、
  发布工具（`docs/team/tools/**`），也没有 P316/P317 的任何路径。
- 三个测试文件在 `b4317dfd` 与报告提交 `c5c85855` 上的 blob 哈希逐一相同，所以「在冻结源码上跑」与「在分支 tip
  上跑」是同一份测试：
  `routes.sh 68f2271…`、`smoke.sh ed207ce…`、`task-model-routing.sh 91fc47e…`。
- `task-model-routing.sh` 的差量只有 6 个 hunk，全部落在 1278–1390 的 updatecheck 区段；`grep -cE '^[+-].*init-legacy'`
  是 **0**，`skills/teamsmith/tests/lib/` 一个文件都没改 —— 这一点是 §4.3 归因的基础。

## 2 · 三处修复逐 hunk（原行为断言与真实前提）

### 2.1 会话 helper：只挪位置，判据一字未改

`smoke.sh` 的差量只有 8 个 hunk，**没有一个**落在 `smoke_live_session_ensure` 的函数体里；§42/§44 两处只把
调用行从 `kill-window -t "$SESSION:dev"` **之前**挪到**之后**，`assert_eq`/`assert_has` 的 label 一字未改。

前提是真的：§6i 的 `pm_close_windows`（`smoke.sh:4335`）确实 `tmux kill-window -t "$SESSION:$PMW"`；P319 在容器里
量到「单窗口会话 → `kill-window` → `has-session` rc=1 → `new-window` rc=1」「有 `pm` 窗口时 rc=0」。也就是旧顺序
（先 ensure 再杀窗口）在「会话里只剩 `dev`」时会话被带走、紧随的 `new-window … || true` 静默失败，于是 §42 九条
级联。新顺序让 helper 在会话被带走后立刻按同一份 `$REPO` 重建 `pm` 窗口。

本轮独立运行里这条补救路径**真的执行了**（不是空操作）：

```
✓ 42·P67：夹具会话原本不在（选段运行没带上 §12b-h）→ 本节自建 teamsmith-smoke-4070117（真 pane 断言照跑）
#12 42 · P67 输入框判据 … · 用时 6s · ✓56 ✗0 SKIP0 · ticks 56
```

### 2.2 载体前缀：只改传播位，生产剥离未削弱

`routes.sh`/`smoke.sh` 把四个载体 `TEAM_ROUTES_{TMUX_LOG,WINDOWS,FAKE_LAUNCH,SESSION_FILE}` 改成 `SMOKE_ROUTES_*`
（`routes.sh` 13 处引用、`smoke.sh` 18 处，含两处 shim 的读取位与 `SESSION_FILE` 的 `export`/`unset` 对）。分支上
已经没有这四个 `TEAM_ROUTES_` 载体：

```
$ git grep -n -E "TEAM_ROUTES_(TMUX_LOG|WINDOWS|FAKE_LAUNCH|SESSION_FILE)" b4317dfd -- skills/teamsmith/tests/
（无匹配）
```

残留的 `TEAM_ROUTES_TREE / KEEP / TIMEOUT / FAST / NESTED` 是 harness 自己的旋钮（只在测试进程里读，不跨进产品
进程），`TEAM_ROUTES_UNPROBED` 是路线表格里的一行数据值 —— 都不是传播位，保持原样是对的。

产品侧一个字没改，剥离规则仍是 M67/P274 的形状（可能起 server 的动词摘掉整个 `TEAM_*` 命名空间）：

```
team_tmux_starts_server() { case "$1" in new*|split*|respawn*|start*) return 0 ;; *) return 1 ;; esac; }
team_tmux() { … if team_tmux_starts_server "$verb"; then ( team_tmux_strip_identity; command tmux "$@" ) …
team_tmux_strip_identity() { for v in $(compgen -v TEAM_ …); do unset "$v" …; done; }
```

`compgen -v TEAM_` 只匹配 `TEAM_` 前缀，`SMOKE_ROUTES_*` 按设计活下来 —— 这正是 P319 在容器里用 stub tmux 量到的
两侧（`new-window`/`respawn-pane` 看不到 `TEAM_ROUTES_*`，`list-windows` 看得到）。没有为了让夹具过而放宽剥离
（例如白名单某个 `TEAM_` 名），这是这次修复里最容易走错的一条，作者没走。

### 2.3 本地版本：来源是真前提，派生值确实更旧

```
$ sed -n 's/^TEAM_VERSION=//p' skills/teamsmith/scripts/lib/common.sh | head -1
"0.3.0"
$ U_LOCAL=0.3.0  U_OLDER=0.2.0
  older_strictly_less=True  equal=False  newer_for_9.9.9=True
```

同源性核对：`TREE` 是被测树、`CLI="$TREE/skills/teamsmith/scripts/team"`、`SKILL="$TREE/skills/teamsmith"`，
`s_run` 跑的就是 `$CLI`；产品的 `local_v="${TEAM_VERSION:-0.0.0}"`（`cmd-watch.sh:277`）读的是同一份
`scripts/lib/common.sh`。所以 `U_LOCAL` 与产品实际用的本地版本是**同一来源**，不是「另一处也写着 0.3.0」。
兜底来源 `package.json` 的 `version` 也是 `0.3.0`。

四处缓存种子仍是 `CHECKED_AT=1`（故意陈旧 → 触发一次查询），只把 `LOCAL=` 换成当前版本；只读/禁用两条断言没动：

```
check updatecheck-disabled-cache-pure eq "$(sha …update-check.env)" "$cache0"
check updatecheck-print-cache-unchanged eq "$(sha …update-check.env)" "$cache0"
```

断言集合没有增删：被触及的断言行是 4 删 4 加，全是同位替换（`updatecheck-newer-line` 的内联 `bash -c '[[ … ]]'`
→ 同文件已有的 `contains`，同一个谓词；`updatecheck-cache-written` 的 `LOCAL=0.2.0` → `$U_LOCAL`；
`same`/`older` 两臂的答案改由派生值给出）。

作者如实披露的残留（`U_LOCAL` 两处来源都取不到时会退化成空答案而仍通过）**本轮维持现状**：本树两处来源都在且
实测 `0.3.0`，任务书又禁止为此新增断言/新守卫；记为已知边界，不改。

## 3 · 独立运行 A：smoke 选段（PASS）

### 3.1 命令与参数

固定镜像 `localhost/teamsmith-gate:local`（`podman image inspect` 实测
`1d723525ee58a8b177862746bc92cde2307a7d5f8a76045f5641703d8ac1a50b`，与任务书一致）；`/work` 是**本次独立运行
自己的完整 clone**（`$HOME/.cache/v62/clone`，`HEAD=b4317dfd`，`git status --porcelain --untracked-files=all` 0 行），
不复用作者 clone；`TMPDIR=/vtmp` 挂的是宿主磁盘目录（`$HOME/.cache/v62/tmp`），不是容器内 tmpfs。

```
$ distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp \
    -v $HOME/.cache/v62/clone:/work -v $HOME/.cache/v62/tmp:/vtmp -w /work localhost/teamsmith-gate:local \
    bash -c 'git config --global --add safe.directory /work;
      TMPDIR=/vtmp TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_SECTION_BUDGET=21600 \
        bash skills/teamsmith/tests/smoke.sh --select 4,6,6i,42,44,54'
```

两个旋钮就是任务书允许的既有旋钮（`TEAM_SMOKE_FIXTURE=1` 让段预算覆盖只对夹具路径生效、
`TEAM_SMOKE_SECTION_BUDGET=21600` 避免历史秒数在负载机上切断行为验收）；没有改预算表、没有等待低负载。

### 3.2 读数

```
start=2026-10-19T12:39:56Z HEAD=b4317dfd5354dad58d5d931e3eb924cda4fd411c
status_before=0
#5  2 · init · 用时 1s · ✓37 ✗0 SKIP0
#9  6 · dispatch · 用时 5s · ✓20 ✗0 SKIP0
#10 6i · PM adapter … · 用时 28s · ✓125 ✗0 SKIP0
#11 12b-h0d · P80 下边框判据 … · 用时 8s · ✓83 ✗0 SKIP0
  ✓ 42·P67：夹具会话原本不在（选段运行没带上 §12b-h）→ 本节自建 teamsmith-smoke-4070117（真 pane 断言照跑）
#12 42 · P67 输入框判据 … · 用时 6s · ✓56 ✗0 SKIP0 · ticks 56
#13 44 · P80 输入框判据 … · 用时 5s · ✓18 ✗0 SKIP0 · ticks 18
#14 54 · 派单摩擦 … · 用时 26s · ✓70 ✗0 SKIP0 · ticks 70
账本自查： 14 段收口 · 增量 ✓495 ✗0 SKIP0 ｜ 结果行 ✓495 ✗0 —— 一致
== 选段结果 ==  ✓ 495  ✗ 0
smoke_rc=0
end=2026-10-19T12:41:31Z HEAD=b4317dfd5354dad58d5d931e3eb924cda4fd411c
status_after=0
```

- 选的顺序里包含「曾杀掉唯一窗口」的那条（`6i` 先杀 `pm` 窗口 → `42`）：§42 是 ✓56 ✗0，而 P319 在同一集合上是
  ✓46 ✗9；
- 「本节自建」那行证明挪动后的 helper 的确执行在杀窗口之后，不是被「会话仍存在」短路；
- 14 段收口的增量与结果行逐项一致，HEAD 与工作树前后都没变（指纹 0 行 → 0 行），日志里没有「本次运行无效」与
  「只给夹具路径用；非夹具路径忽略它」的提示 → 预算覆盖生效、树在运行中没有变化；
- 用时 95 s（12:39:56Z → 12:41:31Z），没有被预算切断。

## 4 · 独立运行 B：路由翻转变异（一次性，31/31 臂执行并还原，外层 1 条既有红）

### 4.1 命令与参数

同一冻结树、同一镜像，一次运行（任务书要求只跑一次）：

```
$ … podman run … -v $HOME/.cache/v62/clone:/work -v $HOME/.cache/v62/tmp-flip:/vflip … bash -c '
    TMPDIR=/vflip TEAM_ROUTING_EVIDENCE=/vflip/evidence-outer \
      bash skills/teamsmith/tests/task-model-routing.sh --flip'
```

`--flip` 自带一条**基线臂**（整条 CORE，17 个组）、31 条变异臂（每条都是新 scratch 树：改坏实现 → 要求命名断言
变红 → 源码逐字节还原）、一条**还原臂**。任务书按 28 条计；这棵树的清单实际是 **31** 条（P242 的 22 条之后增补的
`extra-shadow`、`pm-publication`、`monitor-record-drift`、`updatecheck-*` 等），本轮按树的实际条目**全部执行**。

运行窗口 2026-10-19T12:41:40Z → 14:23:15Z（6095 s），`HEAD` 前后相同、`status` 前后都是 0 行。

### 4.2 逐条执行与还原（31/31）

```
CONTROL baseline rc=0
  RESULT pass=3141 fail=0 selected=policy,machine,init,config,upgrade,dispatch,resume,transaction,
                             limits,preview,sid-readers,pm,heal,adopt,updatecheck,boundary
31 条臂，每条都打印：
  PASS flip-<臂>-target-matched      （变异真的落到目标位置）
  PASS flip-<臂>-shape-valid         （改坏的树语法可解析：bash -n + node --check）
  CONTROL <臂> rc=1                  （变异树下整组真的变红）
  PASS flip-<臂>-red                 （rc=1）
  PASS flip-<臂>-named-assertion     （日志里确有具名 FAIL）
  PASS flip-<臂>-specific            （期望的那条具名断言命中；多断言臂逐条各一条）
  PASS flip-<臂>-source-restored     （还原后脚本哈希与变异前完全相同）
CONTROL <臂> source_before=<hash> source_restored=<同一 hash>   × 31，0 条不一致
CONTROL restored rc=0 → RESULT pass=3141 fail=0 + PASS flip-restored-all-green
```

机器核对（对 31 条臂逐名称检查上面五条 PASS，并逐条比较 `source_before`/`source_restored`）：

```
arms declared: 31
arms missing a PASS: none
PASS flip-*-red count: 31
CONTROL rc=0 lines: 2（基线 + 还原）   CONTROL rc=1 lines: 31（每条臂）
source_before != source_restored: 0
outer FAIL lines: ['FAIL flip-init-legacy-proceeds-bootstrap']
outer RESULT: ['RESULT pass=200 fail=1 selected=flip']
```

### 4.3 唯一的外层红是既有夹具缺陷，不是本次改动

失败断言：**`flip-init-legacy-proceeds-bootstrap`**——它要求变异跑里出现 `^FAIL init-legacy-bootstrap-refused$`，
而变异跑的日志里写的是 `PASS init-legacy-bootstrap-refused`（同臂的 `-plain`/`-force` 两条按预期变红，
`-bootstrap-derived`、`-bootstrap-startup-route` 也变红）。

**归因（三项独立证据）**：

1. **与 P320 无关，静态可证。** `task-model-routing.sh` 的差量 6 个 hunk 全在 1278–1390（updatecheck 区段），
   `grep -cE '^[+-].*init-legacy'` = 0；变异器 `tests/lib/model-routing-flips.py` 一个字节没改；smoke/routes 的改动
   与本套件无关。init 组的代码路径在基线树与受检树上逐字节相同。
2. **与 P320 无关，实测可证。** 我把这条臂原样复演（复制受检树 → 跑同一变异器 → `--select init`），在**基线树
   `9c58e03e`** 与**受检树 `b4317dfd`** 上各跑一次：

   ```
   == /base (9c58e03e) mutate init-legacy-proceeds ==
   FAIL init-legacy-plain-refused    FAIL init-legacy-force-refused    PASS init-legacy-bootstrap-refused
   RESULT pass=29 fail=39 selected=init
   == /work (b4317dfd) mutate init-legacy-proceeds ==
   FAIL init-legacy-plain-refused    FAIL init-legacy-force-refused    PASS init-legacy-bootstrap-refused
   RESULT pass=29 fail=39 selected=init
   == diff of init-legacy readings ==
   IDENTICAL init-legacy readings (all 20 lines)
   ```

   两边逐字节相同，也与翻转跑内层日志的 `RESULT pass=29 fail=39` 一致 —— 复演是忠实的。
3. **根因是复制清单里的目录名。** 变异树是这么搭的（`--flip` 的臂循环）：
   `for source_dir in scripts references templates extensions; do … cp -a "$SKILL/$source_dir" …`，
   而 skill 根只有 `extension/`（单数），`extensions/` 在 `e897a7d8:skills/teamsmith` 与 HEAD 上都不存在
   （`git log --diff-filter=D -- skills/teamsmith/extensions` 无记录）。于是变异树永远缺 `extension/team.ts`。
   该臂的 `bootstrap` 腿不带 `--no-skills`，会走到安装步骤，在那里以**另一个原因**失败：

   ```
   === mutated bootstrap: rc and first 12 output lines ===
   rc=1
   teamsmith bootstrap · probe
     …  模型策略    vendor/light ［独立 PM：vendor/pm:high］ …
     配置已存在：…/.pi/team/config.sh（保留你的设置）
     link  …/.pi/skills/teamsmith → …/work-scratch/skills/teamsmith
   ✗ 找不到可安装的扩展源（…/work-scratch/skills/teamsmith/extension/team.ts 不在）
   ```

   也就是说 `rc≠0` 仍然成立，但拒绝它的不是旧模型闸门（该闸门已被变异摘掉），而是缺扩展源 —— 断言
   `init-legacy-bootstrap-refused` 因此永远不会红。`-plain`/`-force` 两条腿带 `--no-skills`，不装扩展，所以它们
   的 `-refused` 是真红（`-derived`/`-startup-route` 也都红了），这个臂整体并非无牙，只有 bootstrap 这一条腿的
   期望与现状不符。

### 4.4 该缺陷的量化（只做反事实，不动任何仓内文件）

同一条臂、同一变异，只把 `extension` 一并复制进变异树：

```
=== init-legacy refused legs (arm expectations) ===
FAIL init-legacy-plain-refused
FAIL init-legacy-force-refused
FAIL init-legacy-bootstrap-refused      ← 期望的红出现了
=== derived/startup + result ===
FAIL init-legacy-plain-derived   FAIL init-legacy-plain-startup-route
FAIL init-legacy-force-derived   FAIL init-legacy-bootstrap-derived
FAIL init-legacy-bootstrap-startup-route
RESULT pass=28 fail=40 selected=init
```

三条 `-refused` 全部变红，正是外层断言期待的形状 —— 即这条外层红可以由「复制清单写成 `extension`」修掉。
**我没有改仓内任何文件**（这是 `/vflip` 下的临时变异树）；而且这个一字修复会影响所有会走到安装步骤的变异腿，
需要它自己的复验（本轮只测了 `init` 组这一条臂），所以我不把它当成本轮交付的一部分。

### 4.5 updatecheck 在翻转跑里是被覆盖到的（不需要另跑）

基线与还原臂都是整条 CORE，含 `updatecheck`；基线的 45 条 updatecheck 断言全 PASS，P319 报红的那两条也在内，
产品行打的就是当前版本：

```
PASS updatecheck-newer-line
PASS updatecheck-cache-written
PASS updatecheck-cached-line
PASS updatecheck-same-{rc,decision,silent,one-call}
PASS updatecheck-older-{rc,decision,silent,one-call}
PASS updatecheck-disabled-{rc,decision,zero-calls,cache-pure,silent}
PASS updatecheck-print-{rc,skip,zero-calls,cache-unchanged}
i 本地 teamsmith 0.3.0，npm 上已有 9.9.9（工具从不自己安装）：npm i -g teamsmith@9.9.9 …
```

按任务书没有另跑 `--select updatecheck`、也没有重跑整套 §61。

## 5 · 没有做的事

- 没有重跑作者已通过的单跑 `--select 44`、`routes.sh` 四段（任务书明确不需要；A 的选段里 §44 是 ✓18 ✗0）。
- 没有跑全量 smoke / `TEAM_SMOKE_FAST`、§61 整组、§51 段、§61b 的 smoke 包装（B 直接跑
  `task-model-routing.sh --flip` 本体，含 updatecheck 与全部路由组）。
- 没有为三处修复新增破坏实验（红侧复用 P319 在同一冻结候选上的实测：§42 ✓46 ✗9、§54 ✓51 ✗19、
  `routes.sh refusals` ✓19 ✗9、`routes.sh walk control promises` ✓205 ✗1、updatecheck `pass=43 fail=2`）。
- 没有改产品、tests、规格、发布工具、预算表；没有移动标签、合并、推送、新增测试/静态检查器/变异器。
- §4.3/§4.4 的两个复演只在容器内的临时变异树上做（`/vflip`），唯一改了仓内文件的就是本报告。

## 6 · 边界与环境

- 只写本报告文件；工作树只在这条分支上提交。
- 容器与克隆归本次独立运行所有（`$HOME/.cache/v62/{clone,clone-base,tmp,tmp-flip,logs}`），没有触碰作者 clone
  （`$HOME/.cache/p320-clone`）、P319/P320 的任何既有证据目录或主检出。
- 原始日志：`$HOME/.cache/v62/logs/smoke-select.log`、`$HOME/.cache/v62/logs/flip.log`；翻转跑的外层现场（含每条臂
  自己的内层日志）由它自己导出到 `$HOME/.cache/v62/tmp-flip/evidence-outer/…`。
