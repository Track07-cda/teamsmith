# P304 · tmux 身份作用域：apply-2（读侧归因与自愈）

task: P304
agent: dev2
phase: apply
category: code
change: tmux-identity-scope
specs: pm-lifecycle, verification
deltas: -
branch: task/P304-tmux-identity-scope-apply2
deps: P274（apply-1 写侧已并入 main）、V48（写侧独立复验 PASS）；规格与清单见 `openspec/changes/tmux-identity-scope/tasks.md` **§2–§4**（§0/§1 的勾选由 P305 统一核）

## 范围（以 `tasks.md` §2–§4 与 delta 为准）

1. **§2 读侧归因**：冲突对里**每一个**变量的继承值都等于 `tmux show-environment -g` 的值时 → **可归因**：按 cwd 解析、在 **stderr** 一行点名「运行中的 tmux server 的全局环境」并把**那条清除命令**给出来（不再直接拒绝）；**不可归因**的路径（显式外来环境、值不在全局环境里的分歧、无 tmux、陈旧判据）**行为逐字不变**（继续拒绝）。
2. **doctor 一行只读残留报告**：`team doctor` 输出一行（默认 server 全局环境里有没有本项目身份变量、若有则给清除命令），**只读**、不写盘。
3. **§3 隔离与可单跑**：新夹具/段能在**私有 socket + 私有 fixture 项目**下单独跑；跑前跑后 `/tmp` 根数；不碰真实 server。
4. **§4 验收**：闭包选段（含写侧既有段不回退）；任何「既有红」同命令对照 **v0.2.0**（D192 口径：过载时计时不作判据）。

## 硬约束

- **不许**改 apply-1 的写侧语义（建对象动词摘身份、其余保留、会话作用域身份）；**不许**把「不可归因」的拒绝放宽成放行（那是安全边界）。
- **红线**：不许在真实默认 server 上做实验（用私有 socket；`tests/lib/tmux-iso.sh` 是既有工具）。
- **红侧**：① 把归因判据改成「只要值相同就归因」（不看全局环境来源）→ 不可归因现场必须红；② 把可归因路径改回「直接拒绝」→ 必须红（我们要求它自愈）；③ doctor 那行加一个**写盘**动作 → 只读断言必须红。
- **本仓 `AGENTS.md` 的标记块**：若本变更需要刷新（`tmux` 纪律那一段），只动 `<!-- teamsmith:begin -->…<!-- ends -->` 之间；其余字节不动。
- 交付前**一次** `git merge main`（D196：之后不必再追）；报告写「测试状态（先说）」、逐条命令与 rc、未做项与原因。

## 验收命令（贴真实输出）

```bash
bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/smoke.sh --select <上面打印的段号>
bash skills/teamsmith/tests/tmux-identity-leak.sh --all
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
