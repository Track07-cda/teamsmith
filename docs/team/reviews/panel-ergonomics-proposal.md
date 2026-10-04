# panel-ergonomics · PM proposal review

time: 2026-09-19T16:35:00Z · reviewer: pm · verdict: **ACCEPTED**

```
change:  panel-ergonomics
owner:   dev-bob（propose 阶段）
tip:     67ceb23（task/P19-propose）
```

## 我检查了什么（不是「报告说通过」）

| 检查 | 结果 | 依据 |
|---|---|---|
| 门禁 | `openspec validate --all --strict` → **14/14** | 我在 checkout 里重跑 |
| delta 结构 | panel **6 ADDED + 5 MODIFIED**，memory-and-deps **1 MODIFIED** | `find specs -name '*.md'` + requirement 清单 |
| 用户五条要求全部落位 | 光标编辑 ✓ / pi 键位 ✓ / 多行 `ctrl+j` ✓ / 剪贴板图片 ✓ / `线程`→`往来` ✓ / 工作页详情入口 ✓ | 逐条读 requirement 原文 |
| 页面索引 | requirement 里的「工作页（page 2）」与实现一致 | `layout.ts:1327-1330`（1 总览 / 2 工作 / 3 消息 / 4 看板） |
| `C-e` 冲突裁决 | 已落地：`C-e`=行尾、外部编辑器→`C-o`，含**迁移 scenario**（`C-e` 不再启动编辑器） | design 决策 10 |
| `ctrl+j` 终端现实 | 明确：`\r`=提交、孤立 `\n`=换行、`shift+enter` 无 Kitty 时退化为 enter、粘贴内换行语义不变、standby 原因单行化 | panel spec 154-200 |
| 键位可达性 | 两种编码（legacy 字节 + Kitty CSI-u）都要工作，pty 夹具直接发 Kitty 字节；未绑定修饰键**不得把字母插进草稿** | panel spec 78-122 |
| 图片粘贴边界 | 4 种 MIME、`wl-paste`→`xclip`、1s/3s/50MiB 有界、**不在渲染路径上**、失败静默回退文本、不删临时文件 | panel spec 201-265 |
| 工作页详情 | 可聚焦 + 绘制序行走 + 光标字符与色调（不只靠颜色）+ enter/点击 + **原页渲染并原地返回** + 空/降级**无死项** + `pageUp/Down` 接管滚动 | panel spec 266-315 |
| 详情契约复用 | 同一发现规则（`.`/`-` 边界，`P1` 不匹配 `P17`）、128KiB、标签页、sanitizer、路径边界 | MODIFIED 515 起 |
| 改名范围 | zh 表 `往来`（`收件箱与往来` / `收件箱 {n} 条 · 往来 {m} 条 · {age}` / 空态），**目录、命令、英文 term 不变**；`grep -c '线程' zh.ts` 必须为 0（写进 scenario） | MODIFIED 480 起 |
| 开放问题 | 「None」，且每个取舍都写死（键位/词界/编码/kill ring/窗口/探测顺序/临时路径/测试缝/改名范围/滚动键） | design 237-241 |
| 迁移与回滚 | 6 个批次各自可上线、各自 `git revert`；无磁盘格式变化 | design 228-236、tasks §1-7 |

## 结论与备注

**ACCEPTED。** 备注三条（不阻塞 apply）：

1. **范围比用户原话宽一点**（kill ring + undo、Kitty 编码、pageUp/Down 接管）：属「继承 pi 键位」的自然外延，
   且每条都有可证伪 scenario，保留。
2. **与 M40 的合并顺序**：M40（身份/spawn/notify）也在改 `smoke.sh`；apply 分支从当前 main 起，
   交付时我按「M40 先合 → 再合本 change」的顺序处理冲突（两批段落互不重叠）。
3. **验收焦点**（apply 阶段我会重点复验）：`ctrl+j` 与粘贴 LF 的区分、`C-e` 迁移、图片探测的有界性与
   非渲染路径、工作页返回原页、降级布局无死项、改名 grep 断言。

**归档**（2026-09-20）：用户先看预览再确认 → `openspec archive -y panel-ergonomics` → `2026-09-20-panel-ergonomics`；
规格库 14/14；CI run `35504428650` **绿**（9m0s，钉死容器；job id 106061723342）。
