# V8 · Verify: P6 rework（六条 finding 的关闭确认 + F3b 的二值裁决）

```
task:   V8
agent:  verify
phase:  verify
change: deferred-delivery-and-draft-entry
deps:   V7（你的上一轮），P6 rework（tip f6a6ec6，分支 task/P6-apply-deferred-delivery-and-；PM 门禁 PASS）
```

> 三条事实输入（PM 实测，不是听报告）：门禁在返工 tip 上 PASS；**我自己**重跑你的 V7 探针包得到
> `ok 191 / bad 10 / finding 9`——10 条 bad 全部是你包里"钉住旧 buggy 行为"的断言，被修复翻转（90.C 的
> 草稿在光标下方：期望 EMPTY 实际 BUSY，队列 0→1；90.D 复检 only-ours→extra-text；70.2/70.3/70.4 的旧路径全灭）。
> **但有一行你没点名、实现者也没回答：`V7-F3b`（同一 payload 到了两次：人按 Enter 先随草稿提交一次，
> held 条目事后又被排水投了一次）。** 它不在你原报告的 13 条 finding 里，也不在返工报告的映射里。

## 任务

1. **F3b 二值裁决**：在你自己的夹具上复现或证伪。若真：给出精确路径（payload 在粘贴瞬间进了脏框、被人的
   Enter 带走、排水又投一份），并判定它违反规格的哪一条（或规格没盖住——那也是答案）。若夹具时序假象：
   给出触发条件与为什么不算实现缺陷。
2. **六条 finding 的关闭确认**，用你自己的探针（不是包里的翻转断言）：F1（整框检测，光标上下方的草稿都要
   判 BUSY——真实 Pi 再验一次）、F2（复检=指纹比对，大 payload 折叠场景不放行）、F3（竞速条目标记终态，
   排水不重投）、F4（确认=payload 离框，不再盯尾部 400 字节）、F5（确认送达的 say 不写收件箱、不抬计数）、
   F6（无 TMUX 环境 SKIP 不 FAIL）。
3. **新表面攻击**：整框检测 + 指纹复检 + 离框确认是三处新代码——试着造出它们误判的形状（框内只有提示符
   装饰/刚清空的一瞬/折叠标记本身含文字/粘贴进行中的中间帧）。
4. 门禁三段 + 报告 `docs/team/reports/V8-verify.md`；给 PM 一句可复制的 `team review V8 --dir … --branch …` 命令行
   （账本写由 PM 执行，同 V6 的分工）。

## 边界

只读交付分支；探针全在沙盒；不改 `openspec/**` 与账本；不 push main。

## 验收

```sh
openspec validate --all --strict && bash skills/teamsmith/tests/spec-lint.sh && bash skills/teamsmith/tests/smoke.sh
```
