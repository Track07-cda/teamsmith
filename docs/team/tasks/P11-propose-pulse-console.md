# P11 · Propose: `pulse-console`（控制台化实施提案）

```
task:   P11
agent:  dev2
phase:  propose
change: pulse-console
deps:   E6 ACCEPTED（D26）；设计定稿 docs/team/designs/pulse-console.md（用户已批）
```

## 要做什么

按五段式写 `openspec/changes/pulse-console/`：proposal（为什么/改什么/边界/验收）+ tasks（有序、可勾）+
规格 delta（新 capability 或并入 panel——你提案里给出取舍，倾向并入 panel 能力并 MODIFIED 布局/交互需求）。
**设计稿是事实来源**：三页 + 设置浮层 + 消息入口 + 鼠标 + i18n + 响应式四档 + 纪律（只读+三动作、
坏数据不拖垮、性能红线、状态不靠颜色单独表达）。D26 的前置条件必须写进 tasks 第 0 步：
数据装配异步化 + 缓存化（附 E6 §0 的实测数字），消息入口排在其后。

## 提案必须回答

1. 分几个 PR 式批次落地（建议：批 1 异步化；批 2 消息入口+写信；批 3 翻页+鼠标+i18n+响应式）；
2. v1 砍线（任务详情钻取挪 v1.1）在 tasks 里怎么标；
3. 测试矩阵：布局快照四档 × 深浅主题、鼠标 pty 驱动进测试套件（E6 的脚本可直接搬）、
   字符串表键集合断言进门禁、写信期间输入区暂停刷新的夹具；
4. 与现有 `--print` 契约、26 段冒烟、`TEAM_MONITOR_UI` 的兼容；
5. state/panel.conf 与 config.sh 的边界（哪些是面板偏好、哪些仍是项目契约）。

## 边界

只写 `openspec/changes/pulse-console/**` + 你的报告 `docs/team/reports/P11-dev2.md`。不动实现、不动 specs/、
不动账本。不 push。

## 验收

```sh
openspec validate --all --strict
openspec change show pulse-console   # 结构完整
```
