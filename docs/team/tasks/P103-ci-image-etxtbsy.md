# P103 · CI 镜像构建：esbuild postinstall 的 `ETXTBSY`（Text file busy）

```
task:   P103
agent:  dev-bob
issue:
change: -                        # 无 change：CI 构建环境（D31 允许 infra 的 anchor: none）
specs:  -
phase:  apply
anchor: none (infra) — 只改 `ci/Containerfile` 的安装方式与证据输出，不改产品代码
deltas: -
grant:  ci/Containerfile · docs/team/reports/P103-*/**（证据）
deps:   CI run `36396850260`（commit `66d74e4d`）**失败**：`Build the gate image` 步骤
status: wip（等席位）
budget: 小
priority: **中高**（CI 是合并/交付的公开门；本地门禁不受影响）
```

> 本地模式：不 push（**CI 的最终确认由 PM 在下一次 push 后看**）。

## 现场（我从失败 run 的日志里取的原文）

```
#11 18.19 npm error path …/@earendil-works/pi-coding-agent/node_modules/esbuild
#11 18.19 npm error command sh -c node install.js
#11 18.19 npm error   errno: -26,
#11 18.19 npm error   code: 'ETXTBSY',
#11 18.19 npm error   syscall: 'spawnSync …/node_modules/esbuild/bin/esbuild',
#11 18.19 npm error   spawnargs: [ '--version' ],
```

**`ETXTBSY`（Text file busy）**：esbuild 的 `install.js` 刚写下的二进制**还没被关闭就 exec** —— 已知的 npm /
overlayfs 竞态（容器里更常见），与我们的脚本无关 ✗。它**不是**测试红，而是**镜像构建**红。

## 要做的

1. **先诊断再改**：把该 run 的 `--log-failed` 拉下来（`GH_TOKEN=$(cat .github-pat) gh run view 36396850260 --log-failed`），
   在报告里**引用原文行**（上面这段），并说明你判断的根因类别（竞态 vs 网络 vs 版本漂移）；
2. **改法（按推荐顺序，选一个并说明理由）**：
   - **(A) 确定性优先**：Pi 的全局安装用 `--ignore-scripts`，随后**显式**跑一次 esbuild 的安装
     （`node <pi>/node_modules/esbuild/install.js` 或等价写法）→ 把"写句柄没关就 exec"的竞态从根上去掉；
   - **(B) 有界重试**：安装包一层 `for i in 1..3`（每次之间 `sleep`），**每次尝试都打印序号与错误类别**，
     全部失败则**原样失败**并保留最后一个错误（**不许**吞掉真错误、不许无限重试）；
   - 两者可叠加，但要在设计里说清"为什么这样能消除竞态、而不是把它藏起来"。
3. **不许放松任何别的东西**：pi/openspec/node/bun 的**版本钉住**保持原样；镜像的**自检**（`--selftest`）保持原样。
4. **证据**：
   - 本地 `podman build`（用 `ci/Containerfile`）**能成功**（注意：本地可能本来就撞不上竞态，**要如实说明它不是决定性证据** ☆）；
   - 说明**决定性证据只能是 CI 的那次构建** → 报告里写"待 PM 在下一次 push 后确认"；
   - 如果你选了 (A)，给出证据证明 esbuild 二进制**真的**被正确安装（`esbuild --version` / `node_modules/esbuild/bin/esbuild`
     可执行、且镜像自检仍绿）。
5. **零回归**：`openspec validate --all --strict` + FAST（本地能跑的部分）；不强求全量（CI 本来就跑全量 ✓）。
