# P227 · P226 探针夹具自洽的独立验证

agent: verify   status: DONE   time: 2026-10-05T13:44:04Z
branch: `task/P227-verify`   PR/MR: -（local 模式，无 push）

**Verdict: PASS（任务书范围）**。独立复现修复前 `134/4`；修复后证据层在位、缺席两个环境均 `146/0`。
向构造后的树注入 17 个注册文件，两条自洽守卫实际判红；恢复同一 HEAD 探针后重新跑到 `146/0`。
空生成面判红 10 条，删除空面回到 SKIP10。严格规格校验和容器第 36 段均通过。未跑全套门禁。

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/P227-verify.md` | 本报告，唯一提交文件 |
| `docs/team/reports/P227-verify/` | 独立复验证据包，按 D94 留在工作树、不进仓库；含构造脚本、运行脚本、SHA256、原始日志及输入探针 |

被验版本：`49e40f0495fe87fe6d1ee8c4882e99b1ac9122d2`，实现提交 `a836c41a`，作者 dev。
本人没有写该实现，本轮未修改工作树的任何实现文件。

## 独立现场

- 用自己的 `prepare.py` 从 `git archive HEAD` 分别构造 `present` / `absent` 两棵环境树，再各自 `git init`。
  不复用 P226 的构造脚本，也不复用被验探针的 scratch。容器不挂 worktree 的 `.git` 指针。
- 两份真实豁免清单分别注册 16、1 个文件。依任务书授权从项目账本归档逐条恢复，17/17 个 SHA256 与冻结清单相符；
  第二棵树 17 个路径均缺席。清单与产品文件不变，仅证据层不同。
- 初始两树六个内部面都在。十个 `.pi` 相位文件是本人构造的最小存在性夹具，不是假称运行了生成器；第 19 段仅检查文件在位。
  `AGENTS.md` 保持 HEAD 内容。空面实验只在第二棵环境树上改变 `.pi/prompts` / `.pi/skills`。
- 开跑前宿主 `/tmp` 可用 **2358 MB**，高于 **1024 MB** 地板；全部串行运行在
  `localhost/teamsmith-gate:local`，镜像 ID 前缀 `1d723525ee58`。
  夹具 `TMPDIR=/evidence/.tmp` 映射到证据包所在磁盘，避免占满宿主 tmpfs；结束时临时目录无文件。
- 所有日志与耗时都是本人实际运行所得。P225/P226 报告仅用于了解背景和预期，没有引用它们的结果替代验收。

## Verification evidence（实际命令与输出）

复现入口（从 verify 工作树运行；容器命令在 `run.sh` 中）：

```bash
python3 docs/team/reports/P227-verify/prepare.py
# HEAD=49e40f0495fe87fe6d1ee8c4882e99b1ac9122d2;
# independent present=17 SHA256 matched; absent=0; two true git repositories built
bash docs/team/reports/P227-verify/run.sh
# All independent P227 cases completed.  exit 0
```

容器调用：

```bash
distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id \
  -e HOME=/tmp -v "$PKG/.environments:/cases" -v "$PKG:/evidence" \
  -w /cases/present localhost/teamsmith-gate:local bash /evidence/container-cases.sh
```

容器内逐案命令如下。`checkout-shape-probe.sh` 各次仅换探针或实施所述注入；独立环境未重建。
日志路径相对 `docs/team/reports/P227-verify/logs/`；退出码和墙钟耗时见 `results.txt`。

| 案例 / 真实命令 | 输出与退出码 | 耗时 | 原始日志 |
|---|---|---:|---|
| present，旧探针；`bash skills/teamsmith/tests/checkout-shape-probe.sh` | `ok 134 bad 4 skip 0`，rc 1 | 579s | `present-before.log` |
| present，HEAD + 构造后注入；同一命令 | `ok 140 bad 6 skip 0`，rc 1 | 585s | `present-mutated.log` |
| present，恢复 HEAD；同一命令 | `ok 146 bad 0 skip 0`，rc 0 | 585s | `present-after-restored.log` |
| absent，HEAD；同一命令 | `ok 146 bad 0 skip 0`，rc 0 | 585s | `absent-after.log` |
| absent，两个空生成面；`bash skills/teamsmith/tests/smoke.sh --select 19` | 第 19 段 `✓16 ✗10 SKIP0`；选段 `✓37 ✗10`，rc 1 | 4s | `empty-surfaces.log` |
| 同树删除空面；同一选段命令 | 第 19 段 `✓16 ✗0 SKIP10`；选段 `✓37 ✗0`，rc 0 | 3s | `removed-surfaces.log` |
| `openspec validate --all --strict` | `Totals: 13 passed, 0 failed (13 items)`，rc 0 | 1s | `openspec.log` |
| `bash skills/teamsmith/tests/smoke.sh --select 36` | 第 36 段 `✓116 ✗0 SKIP3`；选段 `✓137 ✗0`，rc 0 | **715s** | `section36.log` |

第 36 段自身记账耗时 **713s**，连入口总耗时 **715s（11分55秒）**；外层没有设置 FAST。
它也实际调用了探针，输出尾部包括：

```text
✓ 36⑧ 产品面检出探针全绿（ok 146 bad 0 skip 0）
#5 36 · 选段与分段账本自检（P98 · gate-runtime-budget） · 用时 713s · ✓116 ✗0 SKIP3 · ticks 119
== 选段结果 ==  ✓ 137  ✗ 0
```

**没有跑全套 smoke、真实性能测量或第 26 段真 pane 组。** 本任务以第 36 段为验收范围，探针自己的嵌套门禁按原设计 FAST。
第 36 段选段没有运行的 120 个键如下（入口公共检查 0/0b/0c/0d 照常运行）：

```text
0e 0f 0g 0h 0i 1 1b 1c 2 3 4 4b 4c 5 3b 6 6b 6c 6d 6e 6f 6g 6h 6i 6j 6k 7 7b 8 9 10 10b 10c 11 11b 11b2 11b3 11b4 11c 11d 11e 11e2 11f 11g 11h 11i 11j 14b 15b 15c 12 13 13b 13c 12b 12b-h0 12b-h0b 12b-h0d 12b-h0c 12b-pi 12b-pi2 12b-pi3 14 14c 54 14d 17 18 18b 18c 19 20 21 22 23 24 25 26 27 28 29 30 31 31c 32 33 12e 12f 12g 12h 12i 12j 12k 34 34b 35 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 57 58 15 55 56 59 60
```

第 19 段的两个独立选段另跑了 19、没跑 36；其余未跑键与上表相同。

## Flip evidence

**红前 → 绿后**：同一棵 present 环境，旧文件来自
`git show 728f1736:skills/teamsmith/tests/checkout-shape-probe.sh`，只替换该文件。
旧侧四条 bad 与任务书的故障形状相符：

```text
bad: ⑨ 内部树 + 清单文件都在 → --select 31 退出 0（照旧判定）（期望 [0]，实际 [1]）
bad: ⑨ 内部树 + 清单文件都在 → M28 照旧带清单跑（1 个历史豁免文件）（[
bad: ⑩ 内部树 + 清单文件都在 → --select 58 退出 0（照旧判定）（期望 [0]，实际 [1]）
bad: ⑩ 内部树 + 清单文件都在 → signal-lint 照旧逐条核对（LEGACY 打印）（[
== 检出形状探针 == ok 134 bad 4 skip 0
# 恢复被验 HEAD 探针，再运行：
== 检出形状探针 == ok 146 bad 0 skip 0
```

**break the implementation → the guard test must fail → restore it**：本人在证据副本中，紧接
`P_IN2="$(scratch_tree in2 internal)"` 后加入逐条复制，把真实 17 个注册文件塞回刚构造好的树。
未修改 guard、lint 或清单。不能只把 prune 变成 no-op，因为修复同时已经删掉原来的环境复制入口；
本次采用任务书允许的构造后注入，直接让 guard 观察到真实污染。

```text
bad: ⑨ scratch 树自洽：构造后证据层为空（不吃环境里的注册文件）（期望 [0]，实际 [17]）
bad: ⑨ 证据层只有用例自己声明的那一条注册文件（树自洽）（期望 [1]，实际 [18]）
# 另四条为原来的第 31 / 58 段内部清单假红。
== 检出形状探针 == ok 140 bad 6 skip 0
# cp after-probe.sh 恢复、cmp 逐字节核对、同树再次执行：
== 检出形状探针 == ok 146 bad 0 skip 0
```

被验探针 SHA256：`fd299447d044e097885289a76a5ddb6c30a982e555ff6494c7eca7441ba13f24`。
结束后工作树原文件、`after-probe.sh` 与 present 中恢复后的文件逐字节相同；`git diff --exit-code -- skills` 返回 0。

## Decisions and deviations

- 无范围偏离。仅在自己的证据副本实施故障注入、空目录实验；归档只读，主工作树与其他分支不动。
- 使用两个真实 git 仓库、磁盘型 TMPDIR；容器内串行且 `TEAM_SMOKE_NO_LOCK=1`，未与自己另一轮门禁并发。
- 全部八案都由本人运行，无借用结果。证据包遵循 D94，不提交；本地任务分支交付报告即可，不 push、不 merge。

## Suggested next steps

- PM 按本报告复核并处理本地报告合并；证据包入口是 `docs/team/reports/P227-verify/README.md`。
- 未发现本任务范围内的缺陷或阻塞。范围 PASS 不代表全套门禁已运行。
