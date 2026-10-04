# M45 · pi 的「有新版本」横幅把输入框判据读成 BUSY（真实现场，不是夹具抖动）

```
task:   M45
agent:  dev2
issue:  
change: -
specs:  -
phase:  -
deps:   -
status: todo
budget: 一个工作块
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev2`。

## 现象与根因（PM 已实证，你复核即可）

main 上连续两次全量门禁在这两条上红（第一次 1 条、第二次 2 条，非确定性）：

```
✗ M28 容器里跑真 pi 体检：输入框判据 + 收回在真实现场成立（找不到 [RETRACT=ok]）
✗ M28 容器里跑真 pi 体检：空闲空框被判 EMPTY（没被误判成忙）（找不到 [verdict=EMPTY]）
```

PM 直接跑容器体检拿到原始现场（`bash skills/teamsmith/tests/container-tmux.sh --with-pi --cmd "bash $PWD/skills/teamsmith/tests/pm-box-real.sh --idle-secs 3"`），输入框区域长这样：

```
        22	 New version 0.86.0 is available. Run pi update
        23	 Changelog: https://pi.dev/changelog
        24	────────────────────────────────────────────────────────────
        25	
        26	────────────────────────────────────────────────────────────
        27	
        28	────────────────────────────────────────────────────────────
        29	/tmp/teamsmith-pmbox.MDbpkN/proj (main)
  verdict=BUSY state=BUSY
  HOLDS_ONLY=no MID_RENDER=no RETRACT_SAFE=no
  RETRACT=failed
```

**pi 0.86.0 刚发布**，pi 的 TUI 在框上方画了「Update Available / New version … / Changelog: …」三行横幅；
`team_input_box_text` / `team_box_holds_only` / `team_box_mid_render` 的判据把横幅当成了框内内容
→ 空闲框被读成 `BUSY` → `RETRACT=failed`、`verdict=EMPTY` 消失。

**这不是夹具问题**：同一套判据也是 outbox 投递守卫与面板「草稿」判读的基础。如果用户/PM 的 pi 版本落后，
面板上就会多出这个横幅，投递守卫可能把「空闲」读成「有草稿」→ 通知被 held（正是 M17/M24/M30 一路在治的病）。

## Deliverables

1. **根因表述**：横幅的准确形状（哪几行、什么条件出现），以及判据在哪一步被带偏（给出实测，不是推断）。
2. **修法（两层都要）**：
   - **判据层**：读框时把已知横幅形态排除（至少：`Update Available`、`New version … is available`、
     `Changelog: <url>`、`Run pi update`）——排除规则要**窄且可测**，不许把用户的真草稿吞掉；
     并给一条「横幅 + 真草稿同时存在」的夹具，证明仍能读出真草稿。
   - **环境层**：夹具/容器跑 pi 时**关掉更新检查**（先查 pi 有没有这样的开关/环境变量/配置项；
     有就用，并在报告里写明是什么；没有就只做判据层，并说明为什么）。
3. **smoke 断言 + 翻转**：
   - 构造带横幅的框 → 旧判据红（证明现在的红就是这个原因）、新判据绿；
   - 带横幅 + 空框 → `verdict=EMPTY`；带横幅 + 真草稿 → `HOLDS_ONLY=yes`；
   - 容器体检（M28 段）在**当前 pi 版本**下必须绿。
4. **文档**：`references/troubleshooting.md` 补一条「pi 有新版本时框读成 BUSY」的症状/处置。

## Boundaries

- 只动判据与夹具/文档；**不改**投递契约、草稿守卫语义、收件箱格式。
- 别的 agent 在动 `smoke.sh` 的其他段落 → 只追加/最小改动你需要的段落，别重排。
- 测试纪律：私有 tmux socket、破坏性调用进容器、别用绝对路径调 tmux。

## Acceptance (must actually be run)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 容器体检（当前 pi 版本）：
bash skills/teamsmith/tests/container-tmux.sh --with-pi --cmd "bash $PWD/skills/teamsmith/tests/pm-box-real.sh --idle-secs 3" | tail -12
```

## Report

`docs/team/reports/M45-dev2.md`（含上面那条容器命令的原始输出尾部）。

---

## PM 追加（2026-09-20T01:4x）：横幅来源与开关已实证

- 那个框**不是**美化插件画的，是 **pi 自带的更新检查**（字符串 `Update Available` 就在 pi bundle 的
  `bundle/chunks/chunk-JVUZSMYM.js` / `modes/interactive/interactive-mode.js` 里；
  容器体检**不挂 $HOME、没有任何插件**，照样出现）。
- 开关已找到：**`PI_OFFLINE=1`** 会关掉更新检查（bundle 里 `isOfflineModeEnabled()` 读 `process.env.PI_OFFLINE`，
  更新检查路径都过这道闸）。
- PM 实测（同一条容器命令 + 容器内 `PI_OFFLINE=1`）：

```
  verdict=EMPTY state=EMPTY
  verdict=BUSY state=BUSY
  HOLDS_ONLY=yes MID_RENDER=no RETRACT_SAFE=yes
  RETRACT=ok
✓ 隔离自检：夹具 session 不在真实默认 server 上
```

**所以你的两层修法就这样落**：环境层 = 夹具/容器跑 pi 时带 `PI_OFFLINE=1`（并写清理由）；
判据层照旧要做（用户的 pi 可能落后一个版本、界面上就有横幅 —— 那时投递守卫不能把空闲读成「有草稿」）。

---

## PM 追加（2026-09-20T01:5x，**用户指令，覆盖上一条**）：**禁止**关闭 pi 的自动更新检查

用户原话：「不要关闭 pi 的自动更新检查！！」——上一条「环境层用 `PI_OFFLINE=1`」**作废**：

- **不许**在任何夹具/容器/文档里设置 `PI_OFFLINE`、也不许用别的方式关掉 pi 的更新检查
  （用户要看到更新提示；而且 `PI_OFFLINE` 是离线总开关，副作用远大于这一件事）。
- **唯一修法 = 判据层**：让输入框判读**容忍**横幅（以及同类装饰行）——横幅存在时，
  空闲框仍须读成 `EMPTY`、带草稿仍须 `HOLDS_ONLY=yes`、收回仍须 `RETRACT=ok`。
- 判据必须容忍横幅**随时出现**（不是只在启动时）：空闲 → 横幅出现 → 再读，结论不变。
- 夹具方向反过来：**用带横幅的真实现场做测试**（当前 pi 就会画横幅），把它钉成断言而不是绕开它；
  若某台机器/某个版本不画横幅，测试也必须绿（两种现场都要过）。
- 报告里请写清：横幅的准确判据（行形态）、排除规则的边界（哪些行绝不排除）、以及
  「横幅 + 真草稿」同时存在时读数仍然正确。
