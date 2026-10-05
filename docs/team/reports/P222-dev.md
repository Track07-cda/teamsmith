# P222 · 公开检出转绿：机器生成面单列一类 + 扩展现有救生通道 + 更正一句假文档

agent: dev   status: done   time: 2026-10-05
branch: `task/P222-apply`   PR/MR: -（local 模式）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/lib/checkout-shape.sh` | 第三类面「机器生成面」；新增 `checkout_generated_surface_absent` / `checkout_registered_paths_absent`，并把 `checkout_prereq_missing` / `checkout_literal_skippable` 改成带根的口径 |
| `skills/teamsmith/tests/smoke.sh` | §19 的十条相位命令/相位 skill 走生成面口径；§31（M28）与 §58（signal-lint）两处豁免清单救生通道按「清单注册的路径逐条不在」扩宽；`prereq_skip` 文案点名形状 + 前提类别 |
| `skills/teamsmith/tests/section-select.sh` | `--check` 的字面存在性：生成面（整棵不在）按缺失跳过；其余仍走精确白名单，SKIP 行点名形状与类别 |
| `skills/teamsmith/tests/checkout-shape-probe.sh` | 混合形状夹具（公开仓 CI 的形状）+ 三个方向的反向控制（面在位 / 文件都在 / 旧规则）+ 红→绿现场 + 两个影子 |
| `skills/teamsmith/references/openspec.md` | 生成面那段改成实话：钉住的版本能生成什么、没有 `verify` 那一对、拿不到时用什么替代、忽略规则 |
| `README.md` | 安装步骤不再写「the five phase commands」，并指到 references/openspec.md §6 |

## 现场复核（P214 的结论 → 我自己复核到的）

公开仓检出是**混合形状**：账本可读层、`openspec/changes`、`AGENTS.md`、`SCOPE.md` 都在（→ 判 `internal`），
而 `.pi/prompts/**`、`.pi/skills/**`（机器生成、被 `.gitignore` 忽略）与证据包
`docs/team/reports/*/pkg/**`（刻意不进仓库）不在。我在容器里用一个**干净 clone**（= 公开仓 CI 的形状）逐条复核：

- §19：十条相位断言红（`.pi/prompts/opsx-*.md` ×5、`.pi/skills/openspec-*/SKILL.md` ×5 不在）。
- §31：M28 的豁免清单（`tmux-lint-legacy.txt`）指向 `docs/team/reports/*/pkg/**`，lint 把「清单里的文件不在了」
  判成过期 → 红。
- §58：signal-lint 的豁免清单同一根因 → 红。
- §36：P148 时代的探针把 `AGENTS.md` 等当作「产品面检出里必定不存在」的前提，`AGENTS.md` 回来以后前提变了 → 红。

openspec 版本也复核了（容器里 `openspec --version` = 1.8.0）：

```
$ openspec --version
1.8.0
$ openspec config list | tail -1
workflows: propose, explore, apply, update, sync, archive (from core profile)
$ openspec config profile expanded
Error: Unknown profile preset "expanded". Available presets: core
$ openspec init --tools pi        # 空目录里
Restart your IDE for the new commands to take effect.
$ ls .pi/prompts
opsx-apply.md opsx-archive.md opsx-explore.md opsx-propose.md opsx-sync.md opsx-update.md
$ ls .pi/skills
openspec-apply-change openspec-archive-change openspec-explore openspec-propose openspec-sync-specs openspec-update-change
$ ls .pi/prompts/opsx-verify.md .pi/skills/openspec-verify-change
ls: cannot access '.pi/prompts/opsx-verify.md': No such file or directory
ls: cannot access '.pi/skills/openspec-verify-change': No such file or directory
```

**没有** `opsx-verify.md`，也**没有** `openspec-verify-change/SKILL.md` —— 文档里那句「五个相位命令由
`openspec init --tools pi` 生成」是假的，已改成实话（生成的是哪些、`verify` 那一对从哪来、拿不到命令时怎么办）。

## 改动要点

### 1. 判据（`tests/lib/checkout-shape.sh`）

- **三类面**：产品面（`skills/` 与 `openspec/specs/` 在位）；内部开发面（六个，任一个在位就不是产品面检出）；
  **机器生成面**（六个里的 `.pi/prompts`、`.pi/skills`）。
- 生成面的判定单位是**整棵面**：面不在（`! -e && ! -L`）→ 落在面里的检查以可见 SKIP 点名；
  面在位（**哪怕只是个空目录**）→ 面里的文件缺失**照旧判定、照旧判红**。一个人真装了生成器却少了文件，
  那是真问题，不许被这条跳过吞掉。
- 「缺席的证据层」：两份豁免清单按 sha256 冻结的是 `docs/team/reports/*/pkg/**`。清单里**每一条都落在内部面、
  且都确实不在这棵检出里**时，这一册账在检出里无法裁决 → 改用空清单跑（lint 的牙全在）并记一次可见 SKIP；
  只要**有一条注册路径在位**（哪怕 sha 已经对不上），就照旧逐条核对。
- 判据是纯文件、零外部命令：不读 `TEAM_ROOT`/git/CI 变量；根由调用方按「脚本所在树」传入（smoke 用脚本路径
  推导的 `$CHECKOUT_REPO_ROOT`，选段器用它已有的 `$ROOT`，含显式 `--root`）。

### 2. 三条救生通道（smoke 两处 + 选段器一处）

- `smoke.sh` §19：`smoke_prereq_absent` → `checkout_prereq_missing`（生成面整棵不在 → 可跳；否则仍只在
  「产品面检出 + 前提落在内部面」时可跳）。`prereq_skip` 的文案现在点三件事：**形状**、**这是哪一类前提**、
  **缺的是哪一个**：`… —— 检出形状 internal：机器生成面（由工具在本机生成、不进仓库） .pi/prompts/opsx-apply.md 在检出里不存在（跳过不是通过）`。
- `smoke.sh` §31/§58：豁免清单的救生通道不再以 `[ "$CHECKOUT_SHAPE" = "product-only" ]` 为门槛（那条门槛在混合
  形状下必然落空），改成「清单每一条都落在内部面 **且** 都不在这棵检出里」；两条通道各自可见 SKIP 并点名
  `docs/team/reports/*/pkg/**`（那个形状的注册路径）。有一条产品面路径、或有一条注册文件在位 → 照旧带原清单跑。
- `section-select.sh --check` ③：字面存在性检查里，生成面（整棵不在）按缺失跳过；其余字面量仍只在**产品面检出**
  且**逐字命中**那几个精确前提时才跳（`openspec/changes/typo-planning-file.md` 这类拼写与任意 `.pi/` 新路径照旧红）。
  SKIP 行点名形状与类别：`SKIP（条件不满足）: 行 19 的字面模式在检出里不存在（检出形状 internal，机器生成面（工具在本机生成、不进仓库））：.pi/skills`。

### 3. 探针（`checkout-shape-probe.sh`）

新增（全部只在 `$TMPDIR` 下的 scratch 树里跑，嵌套 smoke 用私有 TMPDIR + 清身份 + FAST + 不排队）：

- **⑤b-⓪ 红→绿现场**：同一棵混合树、同一道 `--select 19`，把判据覆盖回 P222 **之前**的规则（生成面不单列）
  → **十条 ✗、零 SKIP、rc≠0**；用发出去的判据 → **十条可见 SKIP、零 ✗、rc=0**。
- **⑤b**：混合树里 §19 十条各自 SKIP 并点名；§31/§58 的豁免清单按「证据层缺席」跳过并点名，而两份 lint 对
  **产品文件**的判定照旧；往产品文件里植入裸 `tmux` / `pkill -f` → 照旧红并点名。
- **⑤c 反向**：机器生成面在位且十个相位文件齐全 → §19 的十条**照旧判定**（十 ✓、零 SKIP）。
- **⑨b / ⑩ 反向**：合成一份内部证据文件 + 按它重写的清单（源树里历史包不在也能跑的确定性夹具）→ §31/§58
  **照旧逐条核对**（打印 `LEGACY`），不按「证据层缺席」跳过。
- **影子**：① 把「生成面整棵不在」改成恒真 → 内部树里被删掉的相位文件从红变跳过；② 把选段器的字面判据改成
  恒跳过 → 行 19 的缺失产品字面量被吞、`--check` 判绿。两条影子证明上面那些控制不是橡皮章。
- 夹具顺手收敛了 /tmp 占用（就地删+还原、一棵树打两个牙齿、影子复用已有内部树）。

## Verification evidence（全部实跑，含命令与输出尾）

### 验收 1 · 混合形状夹具（公开仓 CI 的现场）

夹具构造（探针里的 `scratch_tree <名> mixed`，确定性、与源树里有没有证据包无关）：产品面文件真拷；
`AGENTS.md`/`SCOPE.md`/`openspec/changes`/账本目录在位；`rm -rf .pi/prompts .pi/skills`；
删掉所有 `docs/team/reports/*/pkg`。

```
$ bash skills/teamsmith/tests/checkout-shape-probe.sh          # 宿主，内部检出
== 检出形状探针 == ok 138 bad 0 skip 0
probe-rc=0
```

```
$ bash /tmp/p222-dbg3.sh   # 一次性复现脚本；同一对控制常驻在探针里（⑤b-⓪ 三条）
=== 旧规则（P222 之前）===      rc=1 · red=10 skip=0
  ✗ 本仓库为 Pi 生成了相位命令 opsx-explore（缺 …/.pi/prompts/opsx-explore.md）
=== 新规则（P222 修后）===      rc=0 · red=0  skip=10
  SKIP（条件不满足） 本仓库为 Pi 生成了相位命令 opsx-explore —— 检出形状 internal：机器生成面（由工具在本机生成、不进仓库） .pi/prompts/opsx-explore.md 在检出里不存在（跳过不是通过）

$ bash skills/teamsmith/tests/checkout-shape-probe.sh | grep '^ok: ⑤b 旧规则'   # 常驻的那三条
ok: ⑤b 旧规则（P222 之前）下同一棵混合树 --select 19 判红（红→绿现场）
ok: ⑤b 旧规则下十条相位检查都判红（零 SKIP）
ok: ⑤b 旧规则下一条机器生成面前提 SKIP 都没有
```

容器里对**混合形状**的实跑（干净 clone，`--select 19,31,58`）：

```
$ bash /tmp/p222-gate.sh /tmp/p222-tree2 /tmp/p222-scene-sel "19,31,58" p222-sel
openspec-exit=0
#13 19 · OpenSpec 五阶段流水线：每阶段有所有者与门禁（M9.1） · 用时 0s · ✓16 ✗0 SKIP10 · ticks 26
#14 31 · tmux 接触面：隔离 lint + 容器跑法（M28） · 用时 3s · ✓9  ✗0 SKIP2  · ticks 11
#15 58 · 信号纪律：闸门 / 作业 pid / lint（P159） · 用时 9s · ✓13 ✗0 SKIP1  · ticks 14
smoke-exit=0   container-rc=0
  选段运行不是全套门禁（交付 / 复验 / 归档仍跑整套）；引用它的报告必须点名没跑的段
```

（§31 的第二条 SKIP 是既有的「31b·容器 tmux 自检（podman）：找不到可用的容器运行时」——容器里 podman 不可用，
与本任务无关。）

### 验收 2 · 反向（标准内部检出 / 面在位 / 文件都在）

- 完整内部树（`scratch_tree internal`，六个面全在）：§19 的十条**照旧判定**——⑤c 夹具（面在位 + 十个相位文件
  齐全）实测 `--select 19` rc=0、**十 ✓、零 SKIP**；⑤ 夹具（面在位 + 删掉一个 `opsx-apply.md`）实测 rc≠0、
  红并点名、**不出现前提 SKIP**。

```
ok: ⑤c 十条相位前提全部照旧判定（十条 ✓）        ok: ⑤c 一条机器生成面前提 SKIP 都没有
ok: ⑤ 内部树删 opsx-apply.md → 红并点名         ok: ⑤ 内部树删 opsx-apply.md → 不是前提 SKIP（面在位就不许跳）
ok: ⑨ 内部树：§12k 的比对照旧执行               ok: ⑨ 内部树：§12k 不出现检出前提跳过
ok: ⑨ 内部树 + 清单文件都在 → M28 照旧带清单跑（1 个历史豁免文件）
ok: ⑨ 内部树 + 清单文件都在 → 不以「证据层缺席」为由跳过
ok: ⑩ 内部树 + 清单文件都在 → signal-lint 照旧逐条核对（LEGACY 打印）
```

豁免清单里的文件**都在**时（⑨b/⑩ 用一份合成证据文件 + 按它重写的清单，源树里历史包不在也能确定性跑）：
`--select 31` rc=0、`另有 1 个历史豁免文件` 照旧判定、零「证据层缺席」SKIP；`--select 58` rc=0、打印
`LEGACY  docs/team/reports/P222-fixture/pkg/legacy.sh`、零 SKIP。清单里出现**产品**路径时照旧不跳
（`⑨ 清单含产品路径 → 不以「豁免清单」为由跳过（前提逐条成立才跳）`），产品文件缺失照旧判红并点名
（`⑩ 缺失的产品面条目照旧判红并点名该文件`）。

### 验收 3 · 牙齿与影子

```
$ bash skills/teamsmith/tests/checkout-shape-probe.sh | grep -E '^ok: (⑤b|⑤c|③ 影子|⑨ 影子|⑩ 影子|⑨ 内部树 \+)'
ok: ⑤b 旧规则（P222 之前）下同一棵混合树 --select 19 判红（红→绿现场）
ok: ⑤b 旧规则下十条相位检查都判红（零 SKIP）
ok: ⑤b 混合形状 --select 19：十条断言变成前提 SKIP
ok: ⑤b 混合形状：产品文件里的裸 tmux 调用照旧判红并点名
ok: ⑤b 混合形状：产品文件里的 pkill -f 照旧判红并点名 file:line
ok: ⑤b 混合形状：那条红是 M28 判红（不是整条检查被跳过）
ok: ⑤c 十条相位前提全部照旧判定（十条 ✓）
ok: ⑨ 内部树 + 清单文件都在 → M28 照旧带清单跑（1 个历史豁免文件）
ok: ⑨ 影子：把「生成面整棵不在」改成恒真 → 内部树里删掉的文件从红变跳过（反向控制咬的就是它）
ok: ③ 影子：把字面判据改成恒跳过 → 缺产品字面被吞、--check 判绿（上面那条控制就是冲它来的）
```

另有三条**既有的**（P173/P176，本次未改、仍全绿，说明这轮重写没有把它们的牙拔掉）：

```
ok: ⑨ 牙齿一的前提：那棵树里有 tmux 包装且与运行时闸门同源（同一份共享分类器）…
ok: ⑨ 影子一：归属规则改回「同目录互认」→ 同一条植入又被记成有隔离证据、§31 判绿 —— 牙齿一随之变红（牙齿真的咬在归属规则上）
ok: ⑨ 影子：lint 用豁免机制把植入的调用记绿 → 牙齿一随之失去牙（判定确实接在 §31 的 lint 上）
ok: ⑩ 影子：删掉逐条内部面判据（=「任何缺失即跳过」）→ 同一条产品面缺失被吞、§58 判绿（牙齿真咬在判据上）
```

### 验收 4 · 门禁（容器，钉住的镜像 `localhost/teamsmith-gate:local`，`/work` = 干净 clone）

```
$ distrobox-host-exec podman run --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp \
    -v <clone>:/work:ro -w /work localhost/teamsmith-gate:local bash -c \
    'openspec validate --all --strict; bash skills/teamsmith/tests/smoke.sh --keep'
tip=eb0fcaf53703f45669f8b5b8c4ca59ddfab332bf
loadavg=2.13 2.56 3.36 3/3409 1804645
- Validating...
✔ spec/agent-adapters … ✔ spec/watchdog
Totals: 13 passed, 0 failed (13 items)      openspec-exit=0
#72  19 · OpenSpec 五阶段流水线…            ✓16 ✗0 SKIP10 · ticks 26
#84  31 · tmux 接触面：隔离 lint + 容器跑法  ✓9  ✗0 SKIP2  · ticks 11
#98  36 · 选段与分段账本自检（P98）          ✓116 ✗0 SKIP3 · ticks 119
#120 58 · 信号纪律：闸门 / 作业 pid / lint    ✓13 ✗0 SKIP1  · ticks 14
账本自查： 124 段收口 · 增量 ✓4640 ✗0 SKIP19 ｜ 结果行 ✓4640 ✗0 —— 一致
== 结果 ==  ✓ 4640  ✗ 0
smoke 全绿    smoke-exit=0   container-rc=0

# §36 里的探针行（与宿主侧一致；早前一轮的 135 是那次 clone 还没包含 ⑤b-⓪ 的三条）：
  ✓ 36⑧ 产品面检出探针全绿（ok 138 bad 0 skip 0）
@@ 本次运行之前还有三次容器锚点，都不当证据看：
   · `p222-gate-full`（tip e31d0de2）—— 完整的 ✓4640 ✗0，但它早于最后两个提交（⑤b-⓪ 与措辞）；
   · `p222-gate-final`（同一份 clone）—— 跑到一半被我终止（`container-rc=143`，日志见
     `.pi/team/state/bg/p222-gate-final.log`），**不是**门禁结果；
   · 所以本文的整套记录只有上面这次（tip eb0fcaf5）。
```

**跑了什么 / 没跑什么**：容器里跑的是**整套**门禁（`openspec validate --all --strict` + 全量 smoke，124 段全部
参与，逐步账本自检一致）——没有任何段落被跳过不跑；段内的 SKIP 只有两类，都在日志里逐条点名：
①「检出前提」（生成面/证据层/`AGENTS.md` 前提，共 19 条）；②环境类跳过（TMUX 之外、podman 不可用之类）。
宿主侧另跑过探针本身 5 轮（每轮 ~9–10 分钟；其中两轮各抓到一次**夹具自身**的问题，见 Decisions 最后一条），
最终形态 `ok 138 bad 0 skip 0`。

> 原始日志（本机证据层，被 `.gitignore` 忽略、不进仓库）：`docs/team/reports/P222-dev/evidence/` 下的
> `container-full-eb0fcaf5.log`・`container-select-eb0fcaf5.log`・`container-select-tip-635b98d7.log`・
> `container-select-prefix-a0b52580.log`・`host-probe-final.log`。

**交付 tip 与门禁 tip（`eb0fcaf5`）的差别**：三处，全部非行为性 —— `references/openspec.md` 的一句 skills 列表
措辞、`lib/checkout-shape.sh` 的一条注释、这份报告本身。交付 tip 上另跑了一轮容器 `--select 12k,19,31,36,58`
（覆盖读 `references/openspec.md` 锚点的那两段 + 三个受影响段 + 报告在场）：见本文件末尾的「交付 tip 复跑」。

### 真实树指纹

探针自己带 ⑧：收尾时比对 `skills/teamsmith/{references,templates,scripts,extension,SKILL.md}`、`skills/teamsmith-init`、
`SCOPE.md`、`AGENTS.md` 的逐文件 md5 → `ok: ⑧ 真实树指纹前后一致（夹具只动 scratch 树）`。五次运行都通过
（P148 曾实测过夹具穿软链写回真树的事故，这条守卫就是为它留的）。

## Flip evidence（红→绿）

1. **同一个夹具的两个方向（探针里常驻）**：混合树 + `--select 19`，判据换回 P222 之前的规则 → `red=10 skip=0 rc=1`；
   换回发出去的判据 → `red=0 skip=10 rc=0`。命令：`bash skills/teamsmith/tests/checkout-shape-probe.sh`（看 ⑤b-⓪ 三条）。
2. **真门禁上的前后（同一镜像、同一份混合形状）**：

```
# before：pre-fix 的 tip（a0b52580），同一个干净 clone 形状，容器里 --select 19,31,58
#13 19 · … ✓16 ✗10 SKIP0 · ticks 26        #13 之前还有 10 条 ✗ 逐条点名缺哪个文件
#14 31 · … ✓8  ✗1  SKIP1  · ticks 10        ✗ M28 真树有未隔离的 tmux 变更命令
#15 58 · … ✓12 ✗1  SKIP0  · ticks 13        ✗ 58 lint 真树判红
smoke-exit=1

# after：交付 tip（eb0fcaf5），同一形状、同一选段
#13 19 · … ✓16 ✗0 SKIP10 · ticks 26         # 十条可见 SKIP，各自点名 .pi/prompts/… 或 .pi/skills/…
#14 31 · … ✓9  ✗0 SKIP2  · ticks 11
#15 58 · … ✓13 ✗0 SKIP1  · ticks 14
smoke-exit=0
```

（before 的红数 12 = P214 量到的 16 条里落在 §19/§31/§58 的那 12 条；另外 4 条在 §36 的探针里，探针的期望
已按新语义重写，见 验收 3。）
3. **破坏实现 → 守卫必须红**：⑨ 影子把「生成面整棵不在」改成恒真 → ⑤ 那条「删掉的文件必须红」立刻失败；
   ③ 影子把字面判据改成恒跳过 → ③ 的「缺产品字面照旧红」立刻被吞。

## Decisions and deviations

- **判据的第二参数用「相对路径」而不是「绝对路径」/形状字符串**：`checkout_surface_path` 只需要路径；
  `checkout_registered_paths_absent` 才需要根（它要看文件系统）。这样调用方（smoke 的按名跳过）与选择器
  （`--check` 的字面量）能用同一份口径，且不会有人把 `$REPO` 这类夹具变量带进判据。
- **判据不读 `AGENTS.md` / 不读 git / 不读 CI 变量**：形状只看六个内部面的存在性。这一点没变（P148 的设计），
  本次只是把其中两个面单列。因此 `TEAM_ROOT` 继承、`.pi/team/state` 之类的账本内容一律不影响分类（①/② 的
  夹具覆盖）。
- **`docs/team/reports/**` 不进选段器的白名单**：它不在 `--check` 的字面量里，所以那边无需例外；豁免清单的
  救生通道在 smoke 里，用「清单注册的路径逐条不在」这个**可证伪**的判据，而不是「目录不在」。
- **没有动 `packages/**` 的产品语义**（白名单、`publish-public.sh` 都不在本次改动里）：这轮是让门禁认得出
  「公开检出按构造缺什么」，不是改公开什么。
- **未把 `openspec/changes` 从白名单里拿掉**：它仍是精确字面量（P150 的走查在内部面里读未归档 change 的
  delta）。设计决议 3 要求的「精确相等、不前缀豁免」保持原样；新增的只是**生成面**这一条。
- **文档口径**：`references/openspec.md` 现在写明「按你钉的版本看它能生成什么」，并给出 1.8.0 的实测；
  `verify` 那一对不可生成时，verify 相位由本指南与 §5 的产物（`docs/team/reviews/<ID>.md`）把关，命令文件
  只在该检出的机器生成面**在位**时才检查（不在位时是点名 SKIP，不是红）。
- **头两轮探针运行各抓到一个夹具 bug**（都是先红后修）：① `⑤c` 把十个相位文件写进一个还不存在的目录，
  结果“十条照旧判定”实测只判了五条；②“字面判据恒跳过”的影子打在了 scratch 树的 lib 上，却用真树的选段器
  跑（它 source 自己的 lib）。两处修正见提交 `e31d0de2`；最终形态 138 ok / 0 bad。

## 复现步骤（另一个 agent 能照着跑）

```bash
# 0) 环境：容器门禁镜像 + 干净 clone（不要挂 worktree：worktree 的 .git 是指针文件，容器里 git 不认）
git clone --branch task/P222-apply --single-branch <主仓> /tmp/p222-tree && cd /tmp/p222-tree && git log --oneline -1

# 1) 探针（宿主，~10 分钟）：混合形状夹具 + 反向 + 影子；期望最后一行 ok 138 bad 0 skip 0
bash skills/teamsmith/tests/checkout-shape-probe.sh

# 2) 混合形状的「受影响段」（容器，~4 分钟）：期望 19 ✓16/✗0/SKIP10、31 ✓9/✗0/SKIP2、58 ✓13/✗0/SKIP1、rc 0
distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp \
  -v /tmp/p222-tree:/work:ro -w /work localhost/teamsmith-gate:local bash -c \
  'git config --global --add safe.directory /work; bash skills/teamsmith/tests/smoke.sh --select 19,31,58 </dev/null'

# 3) 整套门禁（容器，~40 分钟）：期望 openspec 13/0、smoke ✓N ✗0、账本自查一致
distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp \
  -v /tmp/p222-tree:/work:ro -w /work localhost/teamsmith-gate:local bash -c \
  'git config --global --add safe.directory /work; openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null'

# 4) 红侧（同一镜像、同一形状，pre-fix 的 tip）：期望 §19 ✗10、§31 ✗1、§58 ✗1、rc≠0（smoke-exit=1）
git clone --branch task/P222-apply --single-branch <主仓> /tmp/p222-pre && cd /tmp/p222-pre && git checkout a0b52580
distrobox-host-exec podman run --rm … -v /tmp/p222-pre:/work:ro … bash -c 'bash skills/teamsmith/tests/smoke.sh --select 19,31,58 </dev/null'

# 5) 混合形状夹具的权威定义就在探针里：`scratch_tree <名字> <product-only|internal|mixed>`
#    （`skills/teamsmith/tests/checkout-shape-probe.sh`，`# ── scratch 树` 一节）：产品面文件真拷，
#    internal/mixed 再加六个内部面，mixed 再 `rm -rf .pi/prompts .pi/skills docs/team/reports/*/pkg`。
#    探针每次运行都会真跑一遍这些夹具，并对真实树做前后指纹比对（⑧）。
```

## 交付 tip 复跑（`b8a143e5`，容器，`--select 12k,19,31,36,58`）

```
$ distrobox-host-exec podman run --name p222-tip --pid=host --cgroups=enabled --userns=keep-id \
    -e HOME=/tmp -v /tmp/p222-tree2:/work:ro -w /work localhost/teamsmith-gate:local bash -c \
    'git config --global --add safe.directory /work; openspec validate --all --strict; \
     bash skills/teamsmith/tests/smoke.sh --select 12k,19,31,36,58 </dev/null'
openspec-exit=0
== 选段 == decision=RUN · 运行 18/125 段 · 未跑 107 段
#13 19 · OpenSpec 五阶段流水线… · 用时 0s   · ✓16 ✗0 SKIP10 · ticks 26
#14 31 · tmux 接触面…          · 用时 3s   · ✓9  ✗0 SKIP2  · ticks 11
#16 12k · 模板与文档（P24/B7）  · 用时 0s   · ✓32 ✗0 SKIP0  · ticks 32      # 读 references/openspec.md 锚点的那段
  ✓ 36⑧ 产品面检出探针全绿（ok 138 bad 0 skip 0）                          # 报告文件在场也不影响
#17 36 · 选段与分段账本自检（P98） · 用时 733s · ✓116 ✗0 SKIP3 · ticks 119
#18 58 · 信号纪律…             · 用时 9s   · ✓13 ✗0 SKIP1  · ticks 14
账本自查： 18 段收口 · 增量 ✓603 ✗0 SKIP16 ｜ 结果行 ✓603 ✗0 —— 一致
smoke-exit=0   container-rc=0
```

**没跑的（107 个键）**：除上面五段外全部（包括 §1–§18系列、§26 真 pane、§33、§38…）；它们与本次改动
无交集，整套全绿的记录是上一节的 `eb0fcaf5`（两者只差本报告/文档措辞/一条注释）。

## Suggested next steps

- 绿了以后，如果想让这条判据再硬一点：把「机器生成面」也纳入 `section-select.sh --verify-copies` 的
  副本比对口径（本轮只动了 `--check` 与 smoke 两条通道；`--verify-copies` 在公开检出里本来就不跑）。
- 公开仓 CI 那边这轮不改 workflow（`ci/**` 不在本次 grant 里）：等这条分支合并后，CI 的下一次运行就是它的
  真实验收；如果 CI 仍红，把 job log 贴回来，红点会落在与本任务无关的段上（那时按新红处理）。
