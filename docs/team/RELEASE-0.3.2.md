# 0.3.2 · 发布记录与待办

## 已完成

| 步骤 | 结果 |
|---|---|
| tag `v0.3.2` | `b31a1214`，已推公开仓（只推这一个 tag） |
| 发布检查 | 30 通过 / 0 失败 / 0 跳过 |
| npm 暂存 + 2FA | 用户批准；registry `latest=0.3.2`，shasum `cebdcb14…` |
| 发布后实装复核 | `prefix/bin` 五个名字齐全；四个入口解析到包内 shim；`pkill -f …` → rc=64、stdout 空 |

## 待办（需要人做，因为要 2FA）

`npm deprecate` 需要一次性密码，token 不能代替（实测 `EOTP`）。请在**能交互输入 2FA** 的终端里跑：

```bash
npm deprecate 'teamsmith@0.3.1' '未在 npm 安装里链接 pkill/killall/pgrep/pidof，信号闸门在这条安装路线上等于不存在。请升级到 0.3.2。'
npm deprecate 'teamsmith@0.3.0' '未在 npm 安装里链接 pkill/killall/pgrep/pidof，信号闸门在这条安装路线上等于不存在。请升级到 0.3.2。'
```

或者网页：npmjs.com → 包页 → Versions → 对应版本 → Deprecate。

## 下一版（0.3.3）已并入 main、未发

- `tmux-lint` 的 `logs/`/`snapshots/` 整段跳过（P359，独立验收 V92）：任何落在名为 `logs` 的目录下的
  脚本过去永远不会被扫描，且不打印跳过理由。实测改前「干净（扫描 0 个脚本）」、改后红并点名；
  真树 105 个候选里被这两段排除的是 0 个，所以没漏掉任何原本在判的文件。
