# pi-only-scope · PM proposal review

time: 2026-09-22T07:3xZ · reviewer: pm · verdict: **ACCEPTED**

```
change:  pi-only-scope（P34，propose=dev3）
tip:     91e0ae7（task/P34-scope-pi-only-init-propose）· validate 16/16
user:    D35（2026-09-22「L2；未来有能力和时间肯定预留对其他 agent 的支持」）
```

## Findings

1. **三条 delta 全 ADDED、各一条 requirement**（agent-adapters / init-skill / memory-and-deps），
   既有 base scenario 零删除（ADDED 天然如此）；每条 requirement 都写了**文件清单式**的"宣称面"
   （README / SKILL description+段+引用表 / init SKILL / references×4 / 模板 / monitor.mjs 降级文案）
   与**禁语清单**（`any TUI agent` 等五种写法），红侧是"往 scratch 树追加一句 → 搜索命中并非零退出" ✓
2. **D1 的裁断我认可**：三条既有 requirement **原样保留**（MODIFIED 要整段转写 12 条 scenario，
   有漂移风险且零行为收益；降级会把 12 条被依赖的行为移出规格）。理由引了 OpenSpec 自己的
   artifact 说明与仓库先例——这是"论证过的取舍"，不是省事。
3. **D3 的落点巧妙**：frozen 标注放 **schema 行的自由文本列**（route/note），于是
   `team config list --json` **逐字**带出来、控制台在行下显示——机器面和人情面同源。
4. **D5 的零行为证明**：`team dispatch … --print` 在**本分支**与**改动前 revision** 两棵树上渲染并
   `diff`（PM 侧另有 §6i 的 LEGACY_REF 字节比对）——不加新夹具也能证"渲染代码没动"。
5. **禁语清单与 doctor 行为**：init 问卷只问 Pi 版本floor（含 0.76.0–0.79.0 的 stderr 探针形状）与已装插件；
   四个键仍在 schema、仍 `apply` 类、行为不变（写入/校验/CAS/审计/危险值规则一律不动）✓。
6. 规模 3 requirement / 约 9 scenario，未膨胀；边界写明"源码注释与测试不在宣称面内，本 change 只改文档
   与一条诊断文案"。

## 结论

**ACCEPTED**。apply 按 tasks.md 走；verify 换人。**排期**：P34 的 apply 先做（它动 README/SKILL/init SKILL），
P37（npm 安装形态）的 apply 排在它之后——两者都会改 README §Install，错峰避免对冲。
