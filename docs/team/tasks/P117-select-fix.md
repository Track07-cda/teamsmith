# P117 · 选段返工：剪贴副本必须**永远可解析**（V1）+ `needs` 闭包补齐（V2）

```
task:   P117
agent:  （等席位）
issue:
change: gate-runtime-budget        # P112 独立验证判：V1 严重、V2 实质 —— **归档前必须修**
specs:  verification#（路径选段 / 选段运行自述）
phase:  apply
anchor: change
deltas: verification
grant:  skills/teamsmith/tests/{section-select.sh,section-paths.tsv,smoke.sh}（选段相关处）· skills/teamsmith/tests/**（夹具）· skills/teamsmith/references/protocol.md（需要时一句）· openspec/changes/gate-runtime-budget/specs/verification/spec.md（措辞需要时）
deps:   P112（独立验证报告 + 证据在 docs/team/reports/P112-dev2/）· P98（apply）· P115（V3 已修，不必管）
status: todo
budget: 一个工作块
priority: **高**（旗舰功能在最常用入口上不可用）
```

> 本地模式：不 push。**CI 不再作为判据**（D54）。真源 = P112 报告的 §5.1/§5.2（含复现与翻面证据 ✓）。

## V1（严重）· 剪贴副本可能**语法就不能解析**

**机制**：生成副本时把**任何缩进的** `section "…"` 都当段边界 ✗，而 `tests/smoke.sh:7714` 的 `14c` 段头
**缩进坐在 FAST 守卫里** ✓ → 「保留 14、不选 14c」把 `fi` 一起剪掉 → 副本 `bash -n` 失败 ✗ →
选段跑**跑完一切后 `exit 2`**（无结果行、无解释 ✗）；反方向（只选 `14c`）→ 孤立 `fi` ✓。
**最常用的三个入口**（`--paths skills/teamsmith/scripts/team` · `lib/cmd-agents.sh` · `tests/smoke.sh`）都中招 ✓。

**要求（按机制口径，不指定实现）**：
1. **对每一个段键**，生成的副本都必须 `bash -n` 通过 ✓ —— 这是硬承诺，也是**可证伪的检查**：
   `section-select.sh` 应该提供一个模式，**一次跑完全部键**、每个都 `bash -n`（或等价解析检查）✓；
2. 不选中的段**必须真的不跑** ✓（语义不变 ✓）；选中的段**行为与原套件逐字一致** ✓；
3. **失败要早**：若副本无法解析，必须在**跑任何段之前**拒绝并**点名原因**（哪个键、哪一行）✗ ——
   **不许**"跑完所有选中段再 exit 2" ✗（这正是现场的形状 ✗）；
4. 建议的两条实现路线（二选一，**写明理由与代价**）：① 剪贴器**感知嵌套**（`if/fi` · `case/esac` · 函数 · heredoc ✓）；
   ② 不剪文本，改成**运行期中和**（未选中的段在副本里变成空操作 ✓，副本结构完整 ✓）。
5. **红侧**：把剪贴器还原成"按缩进段头剪"（scratch 影子）→ 那个"全部键都 `bash -n`"的检查**必须红** ✓。

## V2（实质）· `needs` 闭包不完整

`--select 3b` → ✗8、`--select 6` → ✗15（补 5 个键后各自 ✗0 ✓ —— 最短反例在报告 §5.2 ✓）。

**要求**：把夹具前提段补进 `needs` ✓；新增断言：**逐键跑一遍"该键的选集在该键上应当是绿的"**（或等价口径 ✓），
并对**至少两个**夹具依赖键给出**红侧**（删掉一条 `needs` → 该键的选集变红 ✓）。

## 验收

- `bash -n` 全键扫描 **0 失败**（修前 ≥3 个键失败 ✓）；两个夹具依赖键的选集 **0 红** ✓；
- `openspec validate --all --strict` + **FAST 全绿** + 一次全量；报告给**红/绿原始输出**；
- 黄线：不改 FAST 守卫本身（`14c` 仍归 FAST 管 ✓）；不改账本与收口行 ✓；不放松任何既有断言 ✓。
