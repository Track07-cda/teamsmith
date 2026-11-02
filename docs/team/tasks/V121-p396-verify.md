---
id: V121
title: 标记式关键回复（P396）独立复验
agent: verify
category: verify
phase: verify
change: pi-marker-key-replies
specs: key-replies
anchor: openspec/changes/pi-marker-key-replies/specs/key-replies/spec.md
deltas: -
branch: task/V121-p396-verify
---

# V121 · P396 独立复验（非作者）

被验对象：`task/P396-mvp` @ `9531865f5661`（作者 dev，工作树干净）。你在自己的 checkout 上验，不接受作者数字。

## 一、必须独立证明的行为（每条都要有你自己跑出来的输出或反例）

1. **解析器**：末行控制标记 `[[team-reply]]` / `[[team-reply:<标题>]]` 的识别与剥离。
   - 反斜杠优先级：**先处理转义，再从未转义的连续反引号里取 opener**；只转义第一个反引号不能使后缀失效——这条是 D215 的强制输入，必须有一条你自己的用例证明它。
   - 合法多行行内代码**不得**被当成控制标记删除。
   - 剥离用原 offset 做定点删除，不动其余字节。
2. **来源与资格**：`message_end` 只暂存 → `turn_end` 绑定稳定 entry id → `agent_settled` 才取得发布资格；只有具备资格的记录可自动恢复，不确定的写入留人工；**不得**用正文哈希去猜归属或触发重发。同一条 entry 的重复事件不得发布两次；两条正文相同的合法回复各自发布一次。
3. **控制标记清理与发布资格分离**：失败或中断的回复不发布，但标记仍必须从最终输出里去掉。
4. **定向注入与身份**：只有授权 PM 会话拿到注入；`team doctor` 能指出缺失加载；注入不得把普通回复误当控制回复。加载/身份证据要你自己看，不看作者转述。
5. **三个面干净的证据**：存储正文、Pi 后续历史、Pulse 当前页与历史都不含标记；**同时**按 D214 接受"流式尾部帧短暂可见"（作者实测约 95–187 ms），任何"零闪烁"的断言都应被判为不成立——你要复核的是最终清理，不是声称从未出现。
6. **指令面**：`SKILL.md`、`references/protocol.md`、`templates/pm-prompt.md.tmpl` 已把默认改成"正常回答 + 末行标记"，`team reply post` 退为手工回填；**并且没有覆盖 P393 已合入的 say 语义**（对照 main 的 say 段落）。检查是否还存在"先 post 再回复"的默认步骤残留。

## 二、允许的命令（自己跑，贴输出；不要跑全量 smoke）

- `bash skills/teamsmith/tests/reply-capture.mjs --all`
- `bash skills/teamsmith/tests/key-replies.sh --select workflow,guide`
- `bash skills/teamsmith/tests/key-replies-ui.sh --select blocks,machine,snapshots`
- `bash skills/teamsmith/tests/key-replies-pty.sh --all`
- 真 Pi 相关：按 `docs/team/reports/P396-dev.md` §5 的入口跑你自己的一份（真实草稿、真实模型请求），不要复用作者的目录
- `openspec validate --all --strict`（本机请用 `~/.cache/openspec-1.8.0/node_modules/.bin/openspec`，全局 1.16.0 会把长需求判红）、`bash skills/teamsmith/tests/spec-refs.sh --check`、`section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 重活（`key-replies.sh --all` 约 800s）按 `team_bg_run` 跑，收工再读日志；不要用 `| tail` 吞掉退出码。

## 三、边界

- 不启用真实团队的标记捕获、不写真实回复存储、不改作者分支、不做归档/合并/发布。
- 结论只写 `docs/team/reviews/V121-verify.md`（判定必须写成 `判定: **PASS**` 或 `判定: **NEEDS-CHANGES**` 这一行，`team board` 要读它）。
- 发现缺陷给具体反例（命令 + 输出尾部 + 你认为正确的行为），不要只写"建议改进"。
