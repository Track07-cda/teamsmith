# V10 · Verify: 收口验证（rework 4 → 收敛判据裁决）

```
task:   V10
agent:  verify
phase:  verify
change: deferred-delivery-and-draft-entry
deps:   V9，P6 rework 4（tip d83ecd6，分支 task/P6-apply-deferred-delivery-and-；PM 门禁 PASS 241s）
```

> 实测输入（PM 亲手）：门禁 PASS；我把你的 V9 包在返工 4 的树上重跑了：`ok 98 / bad 3 / finding 8`——
> **与我在返工 2 的树上的同一包结果逐数相同**，这本身可疑：要么包的钉子钉的是冻结的旧期望（修了对它也不动），
> 要么返工没改变被探测的行为。真实 Pi 段（90-realpi）两轮都干净（22 ok / 0 bad / 0 finding——事故与丢失都不可复现）。

## 任务

1. **逐行裁决我这次重跑的每一条 bad/finding**（`/tmp/v9pkg-r4/logs/` 在，可直接读；也自己重跑）：对每一行判定
   ① 钉住旧期望被正确翻转 ② 修复没触及 ③ 真实残余缺陷。特别点名的四行：`30.3a/30.6b/30.6c`、`V9-B1`（子串变体）、
   `V9-B2`（N2 回归）、`V9-B6`（注意：finding 行里 reason 已是 `stall-timeout`——判它是"已改成可恢复"还是"仍终态"）、
   `V9-C1/C2/C4`（文档措辞与实测的一致性——rework 4 声称更正了，逐字核对）、`V9-D2`。
2. **你自己的探针复测 B1 子串变体与 N2 回归**（rework 4 声称修了并加了双向回归断言——在沙盒里把断言破坏一次
   看它红不红，证明断言是真的）。
3. **收敛判据裁决**（写死在任务里的）：本次是否还有 ① 真实 Pi 上重演 D20 事故 ② 消息丢失/粘稿 ③ 文档诚实性
   finding？三者皆无 = 判"可归档"；有 = 逐条列出。
4. 门禁三段 + 报告 `docs/team/reports/V10-verify.md`；给 PM 一句可复制的 `team review V10 …` 命令行。

## 边界

只读交付分支；探针全在沙盒；不改 `openspec/**` 与账本；不 push main。

## 验收

```sh
openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
```
