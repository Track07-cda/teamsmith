# npm-cli-and-project-init · PM proposal review

time: 2026-09-22T07:4xZ · reviewer: pm · verdict: **ACCEPTED**

```
change:  npm-cli-and-project-init（P37，propose=dev2）
tip:     f4fea5f（task/P37-openspec-npm-cli-init-skill-）· validate 16/16
user:    2026-09-22「做成像 openspec 的安装形式：CLI 作为 npm 应用安装 + 类 openspec init 在项目里装 skill」
```

## Findings

1. **Decision 1 = 我建议的薄 Node 包装**，且给了**实测对照表**（POSIX 两种都行；Windows 下 npm 生成的
   `team.cmd/.ps1` 无法执行 `.sh` 目标；macOS bash 3.2 会死在 `common.sh` 里；`files` 需加 `bin/`），
   并写明包装器**逐字透传**（不实现子命令、不改参数，`team help`/`version`/退出码与 bash 入口逐字节一致，有断言）✓
2. **Decision 2 的边界很干净**：目标 `<main worktree>/.pi/skills/<name>`（Pi 的项目级搜索路径，
   **在 linked worktree 里跑 init 也装到主检出**）；**按名取源、不做目录扫荡**（拷贝式安装只装它带着的那一个，
   不会顺手装邻居）；`link`（默认）/`--copy`（排除 `.git`、`node_modules`）/`--no-skills`；
   **冲突表逐格写死**（不认识的目录**连 `--force` 都不删**）；`.gitignore` 的 `.pi/skills/` 并入既有块且
   **断言不重复**；**`bootstrap` 复用同一函数**（一个实现两个调用点）——于是"重跑 bootstrap"就是升级路径 ✓
3. **Decision 4**：shell 版本检查**只放包装器**（放 CLI 里在 bash 3.2 上会太晚、且不可测），
   报错点名"实际会跑的那个 bash"与 README 的 Requirements 行 ✓
4. **Decision 5**：`team doctor` 加一行（无入口则**安静**——用 Pi 包/`~/.agents`/settings 的项目不被唠叨；
   pass / warn **永不 fail**，并给出 `team init --force` 修复）——与 doctor 既有的"陈旧但可用"口径一致 ✓
5. **§7 的"必须口径一致"表**列了六个面（init SKILL、README、`team help`、daily SKILL、bootstrap.md、PUBLISH.md）——
   这正是我担心的漂移点 ✓
6. **MODIFIED 的 init-skill requirement**：base 4 条 scenario → delta 5 条，**一条没丢** ✓
7. **§10 划清不做**：不改其它子命令、扩展注入逐字节不变、不动 `install.sh`、**不发 npm**（PUBLISH 只加演练步）✓

## 结论

**ACCEPTED**。apply **排在 P39 之后**（两者都改 README §Install 与 init SKILL，错峰）。
verify 换人（propose/apply 都是 dev2）。
