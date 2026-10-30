# V120 · P391 最后 S1–S4 修订独立复核

agent: verify
category: verify
phase: verify
change: instruction-context-slimming
specs: init-skill
deltas: -

## 唯一问题

冻结 P391 `03a05fce764b`（规划工件提交 `ee504509`），作者 dev3。你不是作者；上一位审阅者 dev2 现在做独立的 P397，不打断它。只判 V119 的 S1–S4 是否关闭，及这份小 diff 是否破坏已接受结论。证据先读 `git show 59fd12c00c8d:docs/team/reports/V119-dev2.md`、P391 报告末节、PM 正式 review 最后两节。

阅读 AGENTS→自己 thread→本 brief。源证据 `git diff f5945feb52cd 03a05fce764b -- openspec/changes/instruction-context-slimming` 恰好三个规划文件 +20/-19；proposal 未动，产品/运行文件未动。范围：
- S1：全量候选计数后唯一决定刷新/追加/拒绝，不再 first-match；围栏追加例子已限定 closed，未闭合围栏的明确拒绝例外保留。
- S2：正文采用原 begin 行 LF/CRLF（混合行尾同理），current delimiter 与外部原字节保留；既有整文件 expected 比较及 LF-only 正文反例能约束此点。
- S3：两项拒绝 baseline 已挂到既有 §17/idempotence 任务，未新增门禁系统。
- S4：backtick 围栏 info-string 条件补齐，不是通用/共享 Markdown parser。

不重复 V113 六项、V119 已接受 R1/R2/R3 的整套审查，不重开 marker 发布生命周期；只看上述 diff 有无破坏它们。只阻塞可证伪的实质缺陷，不为同义措辞再铺一轮设计。

## 允许验证和交付

轻量结构命令实际运行并贴输出尾：`"$HOME/.bun/bin/openspec" --version`、`validate --all --strict`、`validate instruction-context-slimming --strict`、`bash skills/teamsmith/tests/spec-refs.sh --check`、`git diff --check`，以及 `bash skills/teamsmith/tests/ledger-ban.sh --names-file <真实主项目名单绝对路径>`。先在此 worker worktree 解析 `git rev-parse --path-format=absolute --git-common-dir`，取其 `../.pi/team/forbidden-names.txt` 并确认存在；若用私有 clone，仍传入原解析值，不从 clone 重新算。missing/SKIP 不算通过。

无需重复试归档：本轮未改变两条 requirement 的 heading/归档操作形状，原试归档可组合采用；若发现相关变动再对自己 `/var/tmp` 副本做试验。禁止 full smoke、install-shape 矩阵、模型变异、真实 init/bootstrap、产品实现、安装/配置/重启、merge/push/真实归档。模型按当前 verify 类别，不带旧 override，启动失败报告原错不自行换模型。

只写并提交 `docs/team/reports/V120-verify.md`（Conventional Commit + V120 + `Agent: verify`）。先给 ACCEPT / NEEDS-CHANGES，再逐项引用 S1–S4 的具体落点和实际命令；不声称 writer 已修复。分支 local，不 push。独立 ACCEPT 后仍由 PM 正式放行；P393/P396 集成、现场规则移出/init/reload/归档保留原授权边界。V118 的报告/原分支留存，此次 --force 只接回已交付的席位，不把 V118 判定改为通过或标 done。
