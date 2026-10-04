# M10 · Apply: `drop-spec-lint`（用户决定：规格管理归 OpenSpec，删掉自研检查器）

```
task:   M10
agent:  dev2
phase:  apply
change: drop-spec-lint
deps:   用户决定（2026-09-16）；变更目录已由 PM 写好并通过 validate + 试归档
```

## 要做什么（变更的 tasks.md 1.1–1.4 + 2.x，全部）

删除 `skills/teamsmith/tests/spec-lint.sh`；移除 smoke §16 与所有调用它的断言；门禁字符串从三件套改成
`openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`（涉及 `.pi/team/config.sh`、
`scripts/lib/` 里 `{{GATES}}` 的默认填充、`templates/config.sh.tmpl` 的注释）；文档逐处改：SKILL.md、
references/openspec.md（加一段散文：写作约定仍在，但它是约定不是门禁）、references/workflows.md、
references/migration.md、docs/team/PROTOCOL.md、AGENTS.md 的团队块。

## 验收（变更里写死的）

```sh
openspec validate --all --strict
bash skills/teamsmith/tests/smoke.sh
grep -rn "spec-lint" skills/ .pi/team/config.sh AGENTS.md docs/team/PROTOCOL.md   # 除 CHANGELOG/历史外无残留
```

## 证据

报告 `docs/team/reports/M10-dev2.md`：门禁字符串前后对照、触碰文件清单、以及"规格缺陷仍会被诚实拦下"的证明
（构造一个丢场景的 delta → validate 红；试归档红——这两个我今天已在 scratch 上实测过，你重跑一次并贴输出）。

## 边界

只碰上述文件 + 你的报告；不动 `openspec/specs/**`（delta 已在变更目录里）；不归档、不 push main。
