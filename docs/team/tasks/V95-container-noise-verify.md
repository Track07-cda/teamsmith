# V95 · P366 的独立验收：那处噪声真的关上了吗，另三条归因站得住吗

task: V95
agent: verify
phase: verify
category: verify
change: -
specs: seat-visibility#The orphan survey never reports a process it cannot identify
anchor: none (infra) — 容器内的读数与噪声
deltas: -
branch: task/V95-container-noise-verify

## 受检

候选 `8b132314`（代码提交 `5291c827`），报告 `docs/team/reports/P366-dev3.md`。产品改动只有一处：
`skills/teamsmith/scripts/lib/common.sh` 的 `team_orphan_read_environ`（+7/−2 量级）。`tests/` 一个字未动。

它自报的六条：① 已修（容器 stderr 61B→0B、宿主 63B→0B、rc 仍 1、stdout 仍 0B、读得到时逐字节不变）；
② `M50-②c` 已转绿并给了承重红侧；③ `38-a` 是**夹具缺陷**（flip 树缺 `SKILL.md`，`cmd-init.sh:307/313` 拒源），
不是整套独有；④ `57` 是整套环境下的抖动（两次整套红的是**不同**断言）；⑤ §63 不是挂住（容器 271s、宿主 439s）；
⑥ `13` 行缺 `needs: 5`（表本身错）。

## 要回答的

1. **修得对不对（承重）**：自己造「读不到 environ」的现场（容器里天然有，或用一个不可读的路径替身），确认
   **stdout 与 stderr 都 0 字节**、返回值非 0、调用方仍「跳过且不点名」；再确认读得到时输出与改动前逐字节相同。
   **红侧**：把候选这一处改回 `[ -r ]` 先判 + 直接 `tr <` 的旧写法 → 那几行必须重新出现在输出里。
2. **② 的判据真的转绿**：跑 `M50-②c` 所在段（`--select 25`），贴读数与 rc；并确认它在**容器里**也绿
   （这是原始红的现场）。
3. **③④⑤ 的归因站得住吗**：这三条都是「不是我引入的」，抽查其中**两条**（建议 ③ 与 ④），用自己的命令复现它的
   判断；判据是它的**因果**成立，不是它的**结论**顺耳。若你认为某条其实是真缺陷，点名并给证据。
4. **写集没越界**：`git diff 08a903ae 8b132314 -- skills/teamsmith/tests` 应为空；`git diff` 里 `common.sh` 只应
   动那一处函数。
5. 轻量收口：`bash -n`、`--loop-check`、`section-select.sh --check`、`openspec validate --all --strict`、账本禁令、
   `git diff --check`。

## 边界

只读代码、破坏只在 `/var/tmp` 私有副本、只写 `docs/team/reports/V95-verify.md` 与自己的线程。**不跑整套门禁**；
容器只跑点名的那几段（`--select 25` 与你自己造的那个现场）。结论先写 PASS/PARTIAL/FAIL。
