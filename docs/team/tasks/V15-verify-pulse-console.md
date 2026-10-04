# V15 · Verify: `pulse-console` 整变更独立验证（对照设计定稿打）

```
task:   V15
agent:  verify
phase:  verify
change: pulse-console
deps:   B1/B2/B3 全部合入主线（HEAD = 你的起点）；设计定稿 docs/team/designs/pulse-console.md（用户已批）；
        P11 提案 + 三批复验记录在案
```

## 核心问题（逐条给实测答案）

1. **设计稿逐条对账**：三页/设置浮层/消息入口/鼠标/i18n/响应式四档/只读+三动作/性能红线/状态不靠颜色/
   坏数据不拖垮/q 收起巡检不死——每一条实测（pty/tmux 夹具或命令行），判「符合 / 偏离 / 变形」。
2. **攻击新表面**：鼠标点击的坐标边界（点页签缝隙、点越界行、滚轮在空区）；中文输入法粘贴长文；
   设置浮层写坏 panel.conf（垃圾字节/缺键）后启动；窗口拖到 59 列再拖回；深浅主题对比度；
   写信期间大事件刷新（草稿不丢这个已钉，你再打别的形状）。
3. **`--print`/`--json` 契约**：与 B3 前的主线逐字节对比（除时间戳与只增字段）。
4. **性能**：60 秒 CPU 采样；一帧装配时长；resize 连续 20 次后的内存与句柄。
5. 门禁三段 + 报告 `docs/team/reports/V15-verify.md` + 可复制的复验命令行。

## 边界

只读主线；探针全在沙盒/私有 socket；不改 specs/ 与账本；不 push。

## 验收

```sh
openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
```
