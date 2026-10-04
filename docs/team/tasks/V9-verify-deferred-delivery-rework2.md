# V9 · Verify: P6 rework 2 的收口验证

```
task:   V9
agent:  verify
phase:  verify
change: deferred-delivery-and-draft-entry
deps:   V8（你的上一轮），P6 rework 2（tip c350a72，分支 task/P6-apply-deferred-delivery-and-；PM 门禁 PASS）
```

> PM 的实测输入：门禁 PASS（1475/0）；**我自己**重跑了你的 V8 包：`ok 137 / bad 6 / finding 2`（与实现者自报的
> `ok 147 / bad 5 / finding 2` 差一行 bad——我那条多出的是 60-f6「找不到被验 checkout /tmp/review-P6」，
> 是我复跑沙盒路径与你不同所致的夹具行，不算产品缺陷；其余的 bad/finding 与你的交付一致）。
> 实现者对残余行的映射：全部是探针钉住的**修复前语义**被翻转 + N5/N6 两条文档化边界。

## 任务

1. **V8-N1 的关闭确认（最高优先）**：用你自己的夹具在**真实 Pi** 上重演"草稿含一行框线"的形状——必须判 BUSY、
   一个键都不打；连同镜像形（光标在框线上方）和"多行框线/Unicode 框字符/半个框线"的邻近形状。
2. **残余行裁决**：逐条确认 30.3a / 40.3a / 50.3×3 是"钉住旧语义的断言被正确翻转"（它们的 README 声明修好必翻），
   不是新缺陷；实现者说是有意改义的，你要独立判断改义后的行为是否符合规格文本。
3. **N5/N6 文档化边界的诚实性**：读规格与 troubleshooting 的对应段落，判断"提示行槽位耦合 / 前缀窗口"的措辞
   是否如实描述了行为（不许用文档把缺陷洗成特性）。
4. **rework-2 新表面**：框线检测的逻辑变了——攻击它：草稿里有多条框线、框线是 Unicode 全角、框线出现在草稿
   第一行/最后一行、框中间有被剪切的半行；以及离框确认的新信号（payload 离框）在"框被清空但没有提交"时的行为。
5. 门禁三段 + 报告 `docs/team/reports/V9-verify.md`；给 PM 一句可复制的 `team review V9 --dir … --branch …` 命令行。

## 边界

只读交付分支；探针全在沙盒；不改 `openspec/**` 与账本；不 push main。

## 验收

```sh
openspec validate --all --strict && bash skills/teamsmith/tests/spec-lint.sh && bash skills/teamsmith/tests/smoke.sh
```
