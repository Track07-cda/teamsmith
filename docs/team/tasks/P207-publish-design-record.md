# P207 · 公开面加"设计记录"：导出白名单 + 导出时遮蔽 + 扫描扩展 + 真实过滤历史

```
task:   P207
agent:  <下一个空出的席位>
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 只改发布工具与其验收
deltas: -
grant:  docs/team/tools/publish-public.sh · docs/team/tools/release-check.sh · CONTRIBUTING.md · docs/team/reports/P207-<agent>.md · docs/team/reports/P207-<agent>/**
deps:   第 24/25 节的实测（用户提问后 PM 量过 ✓）：设计记录 = `openspec/changes/archive`（275 文件 / 3.0 MB ✓）+ `docs/team/DECISIONS.md`（72 KB ✓）+ `docs/team/ROADMAP.md`（20 KB ✓）；
        需遮蔽的形状共 **52 处**（家目录 3 ✓、他项目名 16+30+1 ✓、内网地址 2 ✓）；审计面（reports 124 MB / reviews 17 MB / threads / BOARD）**不公开** ✗。
status: done
budget: 一个工作块
priority: 中高（用户已表态"不喜欢快照模型" ✓ → 这条把公开面做成"真实历史 + 设计记录" ✓）
```

## 要做的（**用户确认后再派** ✓ —— D30 ✓）

1. **白名单加三项 + 一个新文件** ✅：`openspec/changes/archive` ✓、`docs/team/DECISIONS.md` ✓、`docs/team/ROADMAP.md` ✓、`CONTRIBUTING.md`（新建 ✓ —— 内容见第 4 点 ✓）。
2. **导出时遮蔽**（**绝不改私有记录** ✗ ✓ —— 私有账本逐字节不动 ✓）：`/home/<user>/…` → `<home>` ✓、同机他项目名 → `<project>` ✓、内网地址 → `<internal>` ✓、
   席位模型/配额细节 → 略去 ✓；遮蔽规则**写进脚本**（可读 ✓、可测 ✓）✓；遮蔽**确定性**（同输入同输出 ✓ —— 过滤历史要快进推送 ✓）。
3. **扫描扩展** ✅：把上述形状加进禁用清单 ✓；**并加一条正向核对**：设计记录三块必须**在**（缺一 → rc≠0 ✓）。
4. **`CONTRIBUTING.md`** ✅（进公开树 ✓）：怎么装与跑 ✓、怎么跑门禁 ✓（`openspec validate --all --strict` + `bash skills/teamsmith/tests/smoke.sh` ✓）、
   变更怎么提（OpenSpec ✓，指向公开的 `skills/teamsmith/references/openspec.md` ✓）、**补丁怎么被接收**（移植式 ✓：公开 PR → 我们落进私有仓并记名 ✓ → 随下次发布带出 ✓）、
   公开历史是什么（产品路径的真实历史 ✓；设计记录以**当前状态**进入 ✓）。
5. **真实过滤历史** ✅：`git clone` → `git filter-repo --path <产品路径…> --path openspec/changes/archive` ✓ → 推公开仓 ✓；
   **确定性**：之后每次发布重跑同一过滤 ✓，未变提交哈希不变 ✓ → **快进** ✓（**不许 force-push** ✗）；tag `v0.1.0` 打在过滤后的对应提交上 ✓。
6. **验收（可证伪）** ✅：① 导出树里设计记录三块在 ✓ 且**没有**任何遮蔽前形状 ✓（扫描零命中 ✓）；② 反向：往私有侧那三块里**临时**加一个 `/home/…` 与一个他项目名 ✓ → 导出后必须**被遮蔽** ✓ 且**私有侧原文件不变** ✓（逐字节 ✓）；
   ③ 历史：过滤后的公开历史**含**产品路径的真实提交 ✓、**不含** `docs/team/reports/**` ✓（`git log --all -- docs/team/reports | wc -l` = 0 ✓）；④ 幂等：连跑两次过滤 → 第二次 `git push` 是**快进**（无 force ✓）。
7. **门禁**：`openspec validate --all --strict` ✓ + 相关段 ✓ + 容器内 FAST ✓；报告点名"哪些自己跑、哪些引用" ✓；**复验换人** ✓。
