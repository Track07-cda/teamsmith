---
id: A11
title: 同步规格并归档剪贴板准备复用
agent: dev2
category: code
phase: archive
change: clipboard-test-session-reuse
specs: verification
deltas: -
branch: task/A11-archive-clipboard-session-reuse
---

# A11 · 只收尾已验收的测试变更

你未实现本change（实现者dev）。P464/V169/P466/V171已接受关闭；D253依D241用户授权确认归档，不再等额外人类确认。最终报告1649f07a、清单6d8cc242，P466实际verify记录绑定merged30ea8df0；原生5/5、1requirement/6scenario、CRITICAL/WARNING/SUGGESTION均0。完整clipboard只跑一次26/0，真实坏/恢复与种子消费成立，merged101依赖同一仅实际父结果消费，不为归档重复这些行为。

## 执行与写集

1. 读自己线程、archive/sync skills、change全部工件及正式verification；现有OpenSpec1.16原生list/status/instructions确认自己的根/5of5和适用guidance/specs rules。`team change status`只剩A11自身未完成属预期，别的阻塞要报告。不安装/升级/初始化新root，不据advisory变更CLI或写无关规则。
2. 在自己唯一/var/tmp普通独立副本先试原生 `openspec archive -y clipboard-test-session-reuse`，核同步和移动；再在自己稳定任务分支同样原生执行一次。不用hardlink、不手写移动/合并、不跳同步/验证。复用A10已验证的最短方法，不新造audit框架；对五工件逐文件比较、正式spec旧前缀/新增delta精确对比和普通Git差异足够，不跑全仓行为或新平台。
3. 唯一写集：该change五工件整体移入原生日历archive（含.openspec.yaml）、正式 `openspec/specs/verification/spec.md`只追加已接受的一条需求/六场景，以及自己 `docs/team/reports/A11-dev2.md`。原Purpose/既有需求场景及所有产品/tests/CI不变。OWNERSHIP已临时授正式spec，交付后归还PM；其它变更/真实团队状态均不可动。
4. 自己分支真实运行一次下列短检查，保存stdout/stderr/rc。较慢批次后台启动即结束回合，完成唤醒再收取；不等待/轮询。

```sh
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
openspec validate --all
bash skills/teamsmith/tests/spec-refs.sh --check
# 最终报告暂存后
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
git diff --cached --check
```

保留既有非strict口径和真实原生提示，不称全仓strict绿；若本次新增内容产生额外问题，列明交PM，不擅改已接受规范或旧Purpose。引用/映射未变的选择器平台沿用旧回执，不重复。

5. 报告答清真实归档路径/根/5of5、五工件原样、正式新增恰一次、其它正文和可执行文件不变；实际只做了哪些检查、原件位置。保留原旧样本16.812/84.018及等待失败、V171私有准备rc3/首次错误标签和未测整套速度边界，不改写成全绿/新提速。不另起面板/构建/首例/clipboard/b2/38、其它设置/帮助/配置整组、smoke/FAST/全量/meta/61b/安装/性能/真实模型。
6. Conventional Commits含A11和Agent: dev2，小步本地提交后交付。你不merge/push/tag/npm、不代PM写接受结论或看板，不改0.4.7包。原日志不git add -f；只清自己的本次具体试验根，P464/V169/P466/V171原件尚未收存，绝不清理它们或别人的目录。原生CLI越界或前置不符则保留现场BLOCKED，不扩修。
