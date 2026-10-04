# M16 · 沟通纪律：代号必须随身带人话名字

```
task:   M16
agent:  dev2
deps:   用户反馈（2026-09-17）："PM 喜欢只用代号（M2、T1.2）指代事务，但用户不一定记得这些编号"
```

## 规则（写进 skill 的 PM 提示词与协议）

面向用户的输出（汇报、提醒、消息、release 注记）里，每次用代号（M12 / P14 / V15 / T1.1）指代事务时，
**同一处必须带它的短名字**：`M12（修冒烟抖动）`。里程碑、变更名同理。代号是台账的钥匙，名字是给人读的——
两者不许分家。长列表里同一行重复同一代号也要带名字（每行自成阅读单元）。

## 落地

1. `templates/prompt-pm.md.tmpl` 与 `references/protocol.md`：加这条沟通纪律（英文写，含义如上）；
2. PM 提示词的汇报模板示例全部改成"代号+名字"形态；
3. digest / board 等 CLI 面向人的输出自查：凡只印代号的地方补上任务名（BOARD 行本来就有任务列——
   检查 digest 的待复验/待收尾段是否只印了 ID）；
4. 夹具：渲染一份假 BOARD + 假报告集，断言 digest 输出里每个代号同行的同一行上有该任务的名字。

## 边界

模板、references、cmd-status.sh（digest 输出）、tests/smoke.sh（自己的段）。不动账本。

## 验收

```sh
openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh && TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
```
