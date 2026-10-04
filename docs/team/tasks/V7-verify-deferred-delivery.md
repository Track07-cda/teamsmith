# V7 · Verify: `deferred-delivery-and-draft-entry`（独立验证）

```
task:   V7
agent:  verify
phase:  verify
change: deferred-delivery-and-draft-entry
deps:   P6（apply，tip 37000fa，分支 task/P6-apply-deferred-delivery-and-；PM 门禁 PASS）
```

> 你验证的是用户亲历的 bug 的修复（自动通知把半截草稿粘走并发出）。E3 §5.4 的七条攻击面就是你的任务书。
> 你是独立验证者；实现者的翻转包（tests/flip-glue.sh + fake-tui.py）可以跑，但**结论必须建立在你自己构造的
> 探针上**（它的夹具可能替它的实现量身定做）。

## 七条攻击面（E3 §5.4，逐条给出你自己的证据）

1. **bug 本身**：夹具 pane 里有草稿时，每条路径（say / notify / nudge / 扩展）都试一遍——草稿必须还在框里、
   没离开框、每条消息恰好一条队列条目。
2. **检测器边缘**：空框 / 单行草稿 / 多行草稿光标在末尾之后 / **纯空白草稿**（已知洞——必须被文档化而不是
   静默地错，验证它确实被文档化且行为与文档一致）/ 带包管理器提示行的 pane / 非 Pi pane（bash、vim → UNKNOWN
   → 照常投递）/ shell 提示符 pane（必须被已有的 pane_busy/shell 守卫拒，而不是这个新守卫）。
3. **TTL/滞留**：超过 TEAM_DEFER_TTL → inbox 有那行、HOLDING.log 增长、status 里能看到计数、什么都没被键入。
4. **去重/顺序**：去重窗口内的两条相同通知；排队条目 + 发送方重试 → 恰好一次投递；突发下的 FIFO 顺序。
5. **无回归**：干净输入框上的 `say --verify`（指纹校验照常工作）；`TEAM_NOTIFY_TMUX=0`。
6. **隔离**：你的每个夹具必须证明 `team paths` 指向临时根才写盘，真实 inbox/state 前后哈希不变（M7.2 教训）。
7. **竞态诚实**：check→send 窗口不是原子的——至少验证 Enter 前有一次复检，且在 check 与 paste 之间故意注入
   草稿时消息被滞留而不是被粘（尽力：断言复检存在、窗口是一条命令而不是一串发送）。

## 另加一条（实现者的夹具覆盖不到的）

8. **多行草稿的投递**：`team draft pm` 的内容是多行文本——验证 paste-buffer 路径在真实（假）TUI 上不会把
   多行粘成一团或逐行触发提交；交付后人类的下一手输入不被吞。

## 输出

- `team review V7 --dir <checkout> --strong` 由 PM 跑（账本写是 PM 的活；你跑验收命令并给 PM 一句可复制的命令行，
  像 V6 那样）。
- `docs/team/reports/V7-verify.md`：八条攻击面各自的命令与输出、finding 及复现、你无法确定的事项。

## 边界

只读交付分支；探针全在沙盒；不改 `openspec/**` 与账本；不 push main；发现的缺陷只报告不修。

## 验收

```sh
openspec validate --all --strict
bash skills/teamsmith/tests/spec-lint.sh
bash skills/teamsmith/tests/smoke.sh
```
