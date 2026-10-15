# P287 · 门禁的私有夹具根与锁文件要能扛住「别人的清理命令」

task: P287
agent: -
phase: propose
category: analysis
change: gate-lock-external-deletion
anchor: none (infra) — 共享机器资源的归属与可见性
deltas: -
branch: task/P287-gate-lock-external-deletion
deps: 2026-10-15 的实测事件（见 `docs/team/DECISIONS.md` D184 / 证据文件 `/tmp/.teamsmith-smoke-diag.1287305.log`）；与 P280（门禁锁卫生）同族但**不同场景**，不夹带进它的返修

## 现象（实测，18:07:21）

本机**另一个项目**的清理命令带了一条 `rm -rf /tmp/teamsmith-smoke.*`，删掉了当时**正在跑**的门禁私有 TMP；**机器锁文件 `/tmp/teamsmith-smoke.lock*` 本身也在那个 glob 里**。两条后果：① 那次运行按哨兵设计 exit 2（点名红 + 停跑，不是假红）；② **锁文件被删静默破坏了互斥**——`flock` 锁的是 inode，持有者握着被 unlink 的 inode，新运行新建文件、在另一个 inode 上拿到「锁」，两套「顶层」运行可以并发而双方都以为自己独占。

## 要做什么

1. **归属**：让夹具根与锁文件的**名字带项目身份**（或把锁放进本项目自己的状态目录），使一个装了 teamsmith 的项目**不可能**用 `rm -rf /tmp/teamsmith-smoke.*` 命中另一个项目的**活**运行；同时不破坏现有夹具的可清洁性（陈旧根仍要能被本项目的清扫器回收）。
2. **察觉**：持有者要能发现自己的锁文件**被替换或删除**——持有者记录里已有 `start=`/`heartbeat=`，可比对 inode 或心跳写不进去即判定，并**响亮地停**（点名「锁文件已不在/已被替换」）而不是继续以为自己独占；等待者也要能看出「我等的那个 inode 已经没了」。
3. **两条都要红侧**：① 删掉锁文件 → 持有者在有界时间内点名并停（不是无声继续）；② 换一个同名新文件 → 同样被察觉。另加**反向**：正常运行时**不许**误报。
4. **不许**把锁整个去掉，也不许把「删了锁文件」当成通过（那会变成静默并发）。

## 边界

- 只写提案（含上面两条红侧设计）；apply 与 verify 另换人。
- 与 P280/P281 的关系：本变更是**新场景**（外部删除），P281 的返修不夹带它；实现落点可能要复用 `gate-lock.sh`，在 design 里写清写集与串行要求。
- 排期：todo。

## 验收（本阶段）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
