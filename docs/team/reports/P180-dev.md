# P180 · 隔离前置返工：动词按 **argv 逐词**解析，`-S`/`-L` 显式目标必须仍是本轮私有 socket

agent: dev · status: DELIVERED（local 模式：分支留在本地、不 push；PM 复验后本地合并） · time: 2026-10-02
branch: `task/P180-rework` · base: `c9691684`（= 派单时的 main）· 任务书：`docs/team/tasks/P180-iso-verb-parse-rework.md`
授权实现路径：`skills/teamsmith/tests/**` · `docs/team/reports/P180-dev.md` · `docs/team/reports/P180-dev/**`

## 结论

P178 F1 的返工做完，**红侧逐形态 + 影子 + 同源契约**三件套都在 0h 段内（无新段、无调用点改动）：

1. **动词不在首位也能认**：`tmux_iso_argv_parse` 按 **argv 逐词**解析（跳过全局选项及其值，取第一个非选项词），
   契约与 M36/M67 的运行时闸门 `scripts/shim/tmux` 的 `_parse_globals` **同源**（`-L/-S/-c/-f/-T` 值类分开写或粘连、
   `-2/-8/-C/-D/-l/-u/-v/-V/-N` 开关、`--` 之后是动词）。`kill-*` 前缀（含 `kill-s` 这种歧义前缀）与**认不出的形态**
   一律按破坏性对待 —— 不装懂（`TMUX_ISO_ARGV_UNCERTAIN=1`）。
2. **显式目标不许指到别处**：argv 里出现 `-S <路径>` / `-L <名字>` 时，解析出的目标**必须仍是本轮私有 socket**；
   指共享默认 socket → `explicit-target-is-default`，指别的私有名 → `explicit-target-mismatch`，**一律硬停**
   （判据只有逐词解析出的目标，不做任何子串匹配 —— #1529 的教训）。
3. **壳函数搬进 lib、与探针同源**：`tmux()` / `command()` 两个壳由 `tmux_iso_install_suite_guards` 安装，
   smoke 只装它、探针装的也是它 —— “生效的那一份”与“分析用的那一份”同一份。非破坏性调用照旧按 PATH 透传
   （`builtin command tmux`），破坏性调用才前置 + 按 M23 形态执行（`env -u TMUX -u TMUX_PANE` + 本轮私有 `TMUX_TMPDIR`）。
4. **红侧逐形态 + 反向 + 影子**（0h 段，✓192 条断言）：**13 种“动词不在首位”的绕过形态** → 硬停（exit 2）
   **且记录桩为空**；5 种正常形态 → 照常执行（记录桩收到 argv）；另有一腿**真杀**（本轮私有 server 上的一次性
   受害 session，真的被收掉）；把动词解析退回“只看首参”的影子下，每条绕过形态都**不再硬停**且记录桩收到调用。
5. **不改口径**：验证过的“三条件 + 失败/成功相 + 硬停 + 一行醒目结论 + SKIP 字面格式 + 审计行”全部原样
   （0h 既有的 ①–⑧ 断言一条没动、全绿）；**不改调用点**（其它段落里的 `tmux …` 一个没改）。

## 提交

| Commit | 内容 |
|---|---|
| `9f70be86` | 实现：`tmux_iso_argv_scan/_parse`（逐词解析 + 不装懂）+ 显式目标判据 + `tmux_iso_install_suite_guards`（壳函数搬进 lib）+ 探针壳 + 值类选项缺值不挂死 |
| `7912111c` | 0h：⑨ 调用形态红侧 / 反向（5 + 真杀）/ ⑩ 影子（动词解析）/ ⑪ 缺值边界；⑦ 静态钉子改指 lib |
| `9dea4aa2` | 0h：⑫ 同源契约（与 shim 同矩阵）/ ⑬ 影子二（显式目标判据）/ `-uf` 组合簇红侧；`section-paths.tsv` 0h 行补 shim 路径 |
| `（本报告）` | 报告 + `logs/` 原始输出（00–08） |

## 交付物

| Path | 做了什么 |
|---|---|
| `skills/teamsmith/tests/lib/tmux-iso.sh` | `tmux_iso_argv_scan` / `tmux_iso_argv_parse`（逐词解析 + 破坏性分类 + 不装懂）；`tmux_iso_prove` 的 `--argv` 通道与显式目标判据；`tmux_iso_suite_call` / `tmux_iso_install_suite_guards`（`tmux()` 与 `command()` 两个壳）；`--tmpdir/--sock-name/--own-root/--caller-tmpdir` 缺值立刻 `bad-option`（不挂死） |
| `skills/teamsmith/tests/lib/tmux-iso-call-probe.sh` | 新夹具：装**同一份**壳后执行一段调用形态；记录桩（写 `<记录>` 的“要动手”调用、只读白名单另记 `<记录>.ro` 并交真身）+ rc 2 = 硬停 |
| `skills/teamsmith/tests/smoke.sh` | 0h 段：⑦ 静态钉子改指 lib；⑨/⑩/⑪/⑫/⑬ 五块新断言（100 处 `P180`）；`tmux` 壳改为 `tmux_iso_install_suite_guards` 安装 |
| `skills/teamsmith/tests/section-paths.tsv` | 0h 行的 patterns 补 `lib/tmux-iso-call-probe.sh` 与 `scripts/shim/tmux`（同源契约读了它；不补 → 36①/产品面 `--check` 点名） |
| `docs/team/reports/P180-dev/logs/` | 00–08 原始输出（解析矩阵 · 形态红反两侧 · 容器 `--select 0h` · 容器 FAST · 容器全量 · openspec validate · lint+自检 · shim 盲区 · P173 根因） |

**只挡“本 shell 自己的调用”，这条边界写进 lib 文件头**：壳函数不 `export -f`，所以 `env tmux …`、
`bash -c 'tmux …'`、窗口 harness、以及**绝对路径**（`/usr/bin/tmux`）都在射程外 —— 前者由 M36/M67 的 PATH 闸门
（窗口/agent 层）与 M41 的静态规则管，本库管门禁脚本自己的调用。`\tmux` / `"tmux"` **不是**绕过（bash 对函数照查，
0h 有断言钉住）。

## 验证证据（都实际跑过；命令 + 原始输出尾巴）

**自己跑的**（命令 + 原始输出都在 `logs/`）：

```text
$ distrobox-host-exec podman run … localhost/teamsmith-gate:local bash -c 'openspec validate --all --strict'
Totals: 22 passed, 0 failed (22 items)                                   # rc=0（logs/04）

$ distrobox-host-exec podman run … bash skills/teamsmith/tests/smoke.sh --select 0h
#5 0h · tmux 隔离前置：三条件 + 硬停 + 影子（P162） · 用时 2s · ✓192 ✗0 SKIP0 · ticks 192
账本自查： 5 段收口 · 增量 ✓213 ✗0 SKIP0 ｜ 结果行 ✓213 ✗0 —— 一致
== 选段结果 ==  ✓ 213  ✗ 0                                          # rc=0（logs/02）

$ distrobox-host-exec podman run … bash -c 'TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh'
#8 0h · tmux 隔离前置：三条件 + 硬停 + 影子（P162） · 用时 2s · ✓192 ✗0 SKIP0 · ticks 192
…
  ✗ 36⑧ 产品面检出探针有失败（1 条）          ← 唯一的红，且是既有红（发现② / P173）
账本自查： 122 段收口 · 增量 ✓3631 ✗1 SKIP36 ｜ 结果行 ✓3631 ✗1 —— 一致
== 结果 ==  ✓ 3631  ✗ 1                        # 摘录见 logs/03（SKIP36 = FAST 不跑的真进程段落）


$ distrobox-host-exec podman run … bash -c '… bash skills/teamsmith/tests/smoke.sh; bash skills/teamsmith/tests/smoke.sh --select 0h'
  ✗ 36⑧ 产品面检出探针有失败（1 条）          ← 全量（非 FAST，122 段全跑）里同样只有这一条
账本自查： 121 段收口 · 增量 ✓4355 ✗1 SKIP3 ｜ 结果行 ✓4355 ✗1 —— 一致
== 结果 ==  ✓ 4355  ✗ 1                        # RC_FULL=1（就是那条既有红）；RC_SEL0H=0；摘录见 logs/08
$ perl skills/teamsmith/tests/tmux-lint.pl --quiet && perl skills/teamsmith/tests/tmux-lint.pl --selftest --quiet
rc=0 / ✓ tmux-lint --selftest：35 个夹具 + 历史豁免机制全部符合预期     # （logs/05）

$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 7  bad 0  SKIP 0                                   # （logs/05）
```

（`121 段收口 / SKIP3` 是全量形态的既有账目形状 —— P162/P174 的全量日志同样是这两个数，不是本轮少了一段。）

**引用/复用的**（别人的判据，我不改）：

- **0h ①–⑧ 段既有断言**（P162 的三条件/成功相/影子 + 端到端）：原样保留，`--select 0h` 全绿（上面那一行）。
- **FAST 与全量里唯一的红都是 `36⑧`**（P148 形状探针的牙齿一），与纯净 main 上同一条 —— 见发现②。
- **M28 lint 与它的 35 条自带夹具**（P159/M28 的产物）：绿（`logs/05`）。
- **P148 探针的形状/前提判据**：只作为“既有红”的对照被引用（见「发现②」），未改它一行。

## 红绿翻转（缺陷修复必交）

**① 红（改前形状）＝ ⑩ 影子**：把 `tmux_iso_argv_scan` 换回“只看首参”（P162 的 `case "${1:-}"` 形状），
同一个探针、同一张形态矩阵下：

```text
P180 影子：-S 共享默认 socket        → 不再硬停（exit 0）+ 记录桩收到调用
P180 影子：-L 私有名                 → 不再硬停 + 记录桩收到调用
P180 影子：-f 之后的动词（隔离坏）    → 不再硬停 + 记录桩收到调用
P180 影子：-L default（隔离坏）       → 不再硬停 + 记录桩收到调用
P180 影子：-L default（未设 TMPDIR）  → 不再硬停 + 记录桩收到调用
P180 影子：command tmux -S 共享默认   → 不再硬停 + 记录桩收到调用
P180 影子：\tmux -S 共享默认          → 不再硬停 + 记录桩收到调用
P180 影子：命令链 a; tmux -S 共享默认 → 不再硬停 + 记录桩收到调用
P180 影子：组合簇 -uf /dev/null …     → 不再硬停 + 记录桩收到调用
```

“记录桩收到调用”就是“真 tmux 会真的执行”：桩只记录、绝不动手（只读白名单另记 `.ro` 并交真身），
所以这条证据不是“它会不会”，而是“**argv 已经到了执行器面前**”。

**② 绿（改后）＝ ⑨ 红侧（13 条）+ 反向（5 条 + 真杀）**（原始输出 `logs/01`、`logs/02`）：

```text
rc=2 记录桩=[]  tmux -S /tmp/tmux-1000/default kill-server              → SKIP（argv 里的 -S/-L 直接指向共享默认 socket）
rc=2 记录桩=[]  tmux -S /tmp/tmux-1000/../tmux-1000/default kill-server → 同上（路径绕一圈也算）
rc=2 记录桩=[]  tmux -L p180-other kill-server                          → SKIP（…不是本轮的私有 socket）
rc=2 记录桩=[]  command tmux -S /tmp/tmux-1000/default kill-server      → 同上（命令壳同源）
rc=2 记录桩=[]  \tmux -S /tmp/tmux-1000/default kill-server             → 同上（反斜杠不是绕过）
rc=2 记录桩=[]  true;   tmux -S /tmp/tmux-1000/default kill-server      → 同上（命令链）
rc=2 记录桩=[]  true && tmux -S /tmp/tmux-1000/default kill-server      → 同上（命令链）
rc=2 记录桩=[]  tmux -f /dev/null kill-server（TMUX_TMPDIR 不存在）     → tmpdir-missing
rc=2 记录桩=[]  tmux -L default kill-server（TMUX_TMPDIR 不存在）       → tmpdir-missing
rc=2 记录桩=[]  tmux -f /dev/null kill-server（TMUX_TMPDIR 未设）       → target-is-default
rc=2 记录桩=[]  tmux -L default kill-session（TMUX_TMPDIR 未设）        → target-is-default
rc=2 记录桩=[]  tmux -uf /dev/null kill-server（隔离坏）                → tmpdir-missing
rc=2 记录桩=[]  command tmux -f /dev/null kill-server（隔离坏）         → tmpdir-missing

rc=0 记录桩=[kill-server]                          tmux kill-server                       （动词在首位，不误伤）
rc=0 记录桩=[-S <本轮私有 socket> kill-session …]   tmux -S <本轮私有 socket> kill-session  （任务书点名的形态）
rc=0 记录桩=[-f /dev/null kill-server]             tmux -f /dev/null kill-server          （动词不在首位 + 隔离健康）
rc=0 记录桩=[kill-session -t x]                    command tmux kill-session -t x         （command 壳照常执行）
rc=0 记录桩=[-L default list-sessions]             tmux -L default list-sessions          （只读调用不误伤）
真杀一腿：-S <本轮私有 socket> kill-session → 受害 session 真的被收掉（真杀，不是只在桩上过场）
```

**③ 破实现 → 守卫必须红 → 还原**：除了 ① 的动词解析影子，还有 **⑬ 影子二**（把 P180 的显式目标判据整段
`sed` 掉）—— 那三种 `-S`/`-L` 绕过形态在影子二下**全部不再硬停**且记录桩收到调用；两个影子都是 `sed` 出来的
**临时变异体**（在 `$TMP` 里），仓库文件未改。也就是说：不管摘掉哪一半实现，红侧都会红。

**④ 夹具自己先红过一轮（不是橡皮图章）**：同源契约那段第一次跑是 **9 条红** —— `env …; local gate="clean"`
里的 `local` 把 `$?` 冲成了 0，闸门侧一律被读成“clean”。改成先收 `rc=$?` 再判，才绿。

**⑤ 反向不误伤（既有门禁）**：**全量（非 FAST，122 段全跑）✓4355 ✗1**，唯一的红就是既有的 `36⑧` ——
0c、31c（真私有 server 生死与前置）、12b-h（真 pane 端到端）、52（席位死因）这些真进程段落全绿，说明私有
socket 上的破坏性调用、窗口注入、容器自检一件没被误拦。

## 绕过形态清单（任务书第 3 条：请核实还有哪些形态能绕）

| 形态 | 现在能不能绕 | 谁挡 | 证据 |
|---|---|---|---|
| 动词不在首位（`-S/-L/-f/-c/开关/--` 之后） | 不能 | 本库（逐词解析） | ⑨ 红侧 9 条（另 4 条带显式目标，见下一行） |
| `-S <共享默认 socket>` / `-L default`（显式目标） | 不能 | 本库（显式目标判据） | ⑨ 红侧 4 条 + ⑬ 影子二 |
| `command tmux …` | 不能 | `command()` 壳（与裸 tmux 同源） | ⑨ 红侧 3 条 |
| `a; tmux …` / `a && tmux …`（命令链） | 不能 | 壳函数（词就是 `tmux`） | ⑨ 红侧 2 条 |
| `\tmux …` / `"tmux" …` | 不能（**不是**绕过） | bash 对函数照查 | ⑨ 红侧 1 条 |
| 组合簇 `-uf /dev/null kill-server` | 不能（本库多认一格、按破坏性对待） | 本库（不装懂）；**闸门那侧不认这一格 → 见发现①** | ⑨ 红侧 1 条 + `logs/06` |
| 值类选项缺值（`tmux -L`） | 不能（按破坏性对待、且不挂死） | 本库（`UNCERTAIN` + `bad-option` 早退） | ⑪ 两条 |
| 绝对路径 `/usr/bin/tmux …` | **能**（射程外，设计如此） | M41 静态规则（仓库脚本/fixture 里禁止） | 本库文件头 + M28 lint 的 M41 规则绿 |
| 子进程（`env tmux …` / `bash -c 'tmux …'` / 窗口 harness） | **能**（壳函数不 `export -f`） | M36/M67 的 PATH 闸门（窗口/agent 层）；本库只挡本 shell | 本库文件头（刻意不 export） |
| 换一个 shell / 不 source 本库的脚本 | **能** | M28 lint 的调用点证据规则 | 静态层：lint 绿 |

## 发现（不在本任务射程，只报不改）

**① `scripts/shim/tmux`（M36/M67 运行时闸门）有组合簇盲区**（`logs/06`）：同一现场（`TMUX_TMPDIR` 回退到默认
socket）下，`tmux -uf /dev/null kill-server` → 闸门 **放行**（rc 0，真身收到 argv ⇒ 真 tmux 会执行）；而
`kill-server`、`-f /dev/null kill-server` 都被拒（rc 64）。原因：闸门的 `_parse_globals` 把 `-uf` 当“无值开关”
跳过一格，于是把 `/dev/null` 读成了子命令。P180 的解析侧**多认这一格**（按破坏性对待），所以门禁脚本这侧
不受影响；但窗口/agent 层那一层仍会放行 —— 属 `skills/teamsmith/scripts/**`，不在本任务授权路径，**建议单开任务**。

**② 全量的 `36⑧` 红是既有红（P173 跟踪），我用纯净 main 证过，并顺手钉了根因**（`logs/07`）：

- 纯净 main 存档（`git archive main`）+ 同一容器跑 `checkout-shape-probe.sh` → `ok 71 bad 1`，
  唯一那 bad = “⑨ 产品面树里出现裸 tmux 变更调用，§31 仍然绿”（我的分支上同样 `ok 71 bad 1`、同一条 bad）。
- 根因：`tmux-lint.pl` 的 `collect_wrappers` 把“函数体里出现 tmux 一词”的函数登记成本**目录**的 tmux 包装
  （同目录互认），而 `skills/teamsmith/tests/pulse-nudge-key.sh:103` 的**毒丸** `tmux() { printf 'ERROR: fixture
  touched tmux'; exit 99; }` 因此给 `%WRAP_DIR{tests}{tmux}` 留下一条**非零**记录（`= 1 if !exists`）→
  `wrapper_iso` 把它当成“有隔离证据的包装” → `tests/` 里**任何**文件的裸调用都被当成“走包装、有证据”。
  佐证：在我的树副本里**只把那个函数改名**（函数体一字不动），lint 立刻报 `RED …/tmp-hygiene.sh:1188 tmux kill-server`。
- **交叉印证**：P173-dev2 的报告（`docs/team/reports/P173-dev2.md`，分支 `task/P173-apply`）把任务书里的
  猜测（“§31 走了跳过路径”）更正为**同一条**根因（`%WRAP_DIR` 的同目录互认）并修了 lint；那条改动**不在我的
  base（`c9691684`）上**，所以我的分支上这条红还在（两边证据对上了：他拿到 `--list` 的
  `ok …tmp-hygiene.sh:1188 tmux kill-server`，我用“改名即变红”独立钉到同一个文件）。
- 顺带：P180 把 `smoke.sh` 的内联 `tmux()` 搬进 `tests/lib/tmux-iso.sh` 后，`tests/` 那一格少了一个来源、
  `tests/lib` 多了一个（本目录判据仍然正确）——但毒丸那一格还在，所以那条红与 P180 无关。

## 决策与偏差

- **不加 `--force` / 环境变量绕过路径**：前置不成立就硬停，没有“放行开关”（P162 的既定口径）。
- **`section-paths.tsv` 0h 行补两处 patterns**：`lib/tmux-iso-call-probe.sh`（新夹具）与 `scripts/shim/tmux`
  （同源契约那段真的读它）。不补的话 P98 的 `--check` 会点名“段 0h 读了它没声明的路径”，产品面检出也会跟着红。
  第一次 FAST 跑的 4 条红就是它 —— 守门在工作，不是噪声。
- **不开新段**：红侧全部放在 0h 段内（同一段自述+预算在 `section-budgets.tsv` 里已有 60s 的 floor，实测 2s），
  所以没有动 `section-budgets.tsv` / `loop-inventory.tsv`（新代码没有 `while … sleep` 循环）。
- **同源契约只放“两边语法都覆盖”的形态**：组合簇是解析侧多认的一格（闸门不认），单列在红侧；把那一格塞进
  parity 会变成“拿不同的语法互相打脸”，不是同源。
- **`tmux_iso_skip` 在探针里被覆写**（打印 SKIP 字面格式），与 P162 探针同形 —— 0h 的 SKIP 字面断言对两条路径都成立。
- **未改**：`scripts/**`（含 shim）、其它段落的任何调用点、`tmux_iso_prove` 的三条件判据、审计行格式、
  `checkout-shape-probe.sh`（发现② 是 P173 的活）。

## 建议下一步

- **PM 复验**：独立 worktree 跑 `openspec validate --all --strict` + `bash skills/teamsmith/tests/smoke.sh`
  （全量；`--select 0h` 与 FAST 我都跑过）。全量实测只剩 1 条既有红（`36⑧`，P173；P173-dev2 的修合并后应全绿）。
- 复验重点建议：
  1. `--select 0h` 里 ⑨/⑩/⑫/⑬ 四块的“记录桩为空 / 收到 argv”两句断言（这是 P180 的判据本体）；
  2. 反向那腿**真杀**是不是真的收掉了受害 session（不是只在桩上过场）；
  3. 两个影子（⑩ 动词解析、⑬ 显式目标判据）是否各自都能把红侧弄红。
- 账本建议：任务书点名的例（`tmux -S <本轮私有 socket> kill-session`）已在反向上钉住；“`scripts/shim/tmux`
  组合簇盲区”（发现①）如果不单开任务，就至少要一条看板行 —— 那是窗口/agent 层现在唯一还放行的破坏性形态。
