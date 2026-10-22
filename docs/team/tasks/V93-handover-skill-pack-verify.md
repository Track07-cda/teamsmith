# V93 · P361 的独立验收：第三个技能真的被装上，且断言跟着契约走

task: V93
agent: verify
phase: verify
category: verify
change: -
specs: teamsmith#installation
anchor: none (infra) — 打包与安装面
deltas: -
branch: task/V93-handover-skill-pack-verify

## 受检

候选 `3bb984a7`（实现 `34eafbad`，报告 `docs/team/reports/P361-dev3.md`）。改动面：`cmd-init.sh` 的技能发现与
声明面、`install-shape.sh` 的三处硬编码计数、`smoke.sh` 的若干处、`skill-load.mjs` 的路由判据、文档与版本（0.3.3）。

作者给的关键事实：**改动前的夹具 + 改动前的代码是全绿的**——旧夹具只数「2 条 link」、旧代码只认两个名字，第三个
技能对两边同时不可见。他把断言改成「与源清单一致」而不是「改成 3」。他还给了 `install-shape` 160/0、smoke 选段 149/0。

## 必须自己做的

1. **装三个**：在一个私有夹具项目里 `team init`，贴 `.pi/skills/` 的 `ls`；三个目录都在，且每个 `SKILL.md`
   的 `name:` 与目录名一致（自己读 frontmatter，别抄报告）。
2. **对称盲区真的关上了**：把候选的 `install-shape.sh` **换回 main 那版**、代码保持候选 → 必须**红**（旧夹具
   在新代码上应当发现「源里有三个、装出来三个」而不满足它写死的 2？或如作者所述反过来红）。**两个方向都要试**：
   （a）新夹具 + 新代码 → 绿；（b）旧夹具 + 新代码 → 你说的那个方向会怎样；（c）新夹具 + 旧代码（`cmd-init.sh`
   换回 main 版）→ 必须**红并点名 handover 没装**。把这个 2×2 的四格读数写出来，这是本任务最有价值的证据。
3. **可见性三态**：私有副本里（a）删掉 `skills/handover/` 目录 → 安装不崩、且**可见地**说出少了一个技能
   （作者称 `miss`）；（b）把 `handover/SKILL.md` 的 `name:` 改成别的 → 红并点名（他的 ⑩）；（c）声明面里列一个
   源里不存在的技能 → 必须可见（他的 `note`/`broken`）。三态各给读数。
4. **`--no-skills` 仍一个不装、`--copy` 三个都是真目录且逐字节一致**。
5. **`npm pack` 带 `skills/handover/SKILL.md`**，且包里**没有**账本/`docs/team`。
6. **路由判据的收窄要你裁定**：`skill-load.mjs` 从「description 含 `teamsmith|多 Agent|团队`」改成「description
   必须含**技能自己的名字**」。请判：这是**去掉了一个伪行为断言**（名字与长度是机械可判的、路由质量属评审），
   还是**放宽了覆盖**？并实测一个边界：造一个 description 只有 12 个字符但含技能名的 skill → 现在会不会通过？
   若会通过，写明「这算不算缺陷」并给一句建议（例如加一条最小信息量下限）。
7. 轻量收口：`bash -n`、`--loop-check`、`section-select.sh --check`、账本禁令、`git diff --check`。
   `install-shape.sh` 全套请自己跑一次（约 2 分钟），不要抄作者的 160/0。

## 边界

只读代码、破坏只在 `/var/tmp` 私有副本、只写 `docs/team/reports/V93-verify.md` 与自己的线程；不改实现、不合并、
不 push。**不要跑整套门禁**（`install-shape` 与 smoke 选段足够）。结论先写 PASS/PARTIAL/FAIL。
