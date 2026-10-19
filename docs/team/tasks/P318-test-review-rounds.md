# P318 · 逐步审查已有测试、移除过度测试（第 1 轮）

task: P318
agent: dev3
phase: apply
category: code
change: -
anchor: none (infra) — 用户：「逐步的审查已有的测试，移除不必要的过度测试」
deltas: -
branch: task/P318-test-review-rounds
deps: **P316 先落地**（它也在改 tests/，同一批文件不许两个写者）——派单前 PM 会确认

## 方法（每轮一小片，报告数字，不许一把梭）

**判据（两条都要满足才留）**：① **破坏产品它必须红**；② 它守的是一个**行为或契约**（退出码 / 状态字段 / 渲染 / 文件内容 / 用户可见文案），而不是「代码里这条分支存在过」。

对每一条断言三选一：**保留 / 合并进相邻断言 / 删除**（删除必须写明「它原本想守什么，现在由谁守」）。

**第 1 轮范围**：`tests/` 下**断言/行数比最高**的 3 个文件（先用 `rg -c 'assert|✓|✗' | sort` 找出来并写进报告），逐条过一遍。

## 边界

- **不许**放宽行为断言来「瘦身」；**不许**删契约类断言（退出码/状态/渲染/文案稳定标记）而不点名接管者；
- 性能/时间类**不在本轮**（P316 已覆盖）；
- 每轮末尾跑该片段的门禁选段 + 报「删了多少条断言、多少行、几条改为合并」，并附**两条红侧**（挑两条你保留的断言，各自造一次破坏 → 必须红）。

## 验收

```bash
bash skills/teamsmith/tests/section-select.sh --paths <你改的测试文件…>
bash skills/teamsmith/tests/smoke.sh --select <上面打印的段号>
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
**先交第 1 轮的清单**（文件 → 断言条数 → 建议处置），我给方向后再动。
