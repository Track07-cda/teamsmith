# M11 · bootstrap 不该把 PM 窗口名写成当前窗口碰巧的名字

```
task:   M11
agent:  （空闲时指派）
deps:   v1.35.0
```

> 实测（本项目今天发生）：配置里 `TEAM_PM_WINDOW="pi"`——bootstrap 把"当前窗口名"当成了 PM 窗口名
> （`cmd-bootstrap.sh:68` 的 `pmwin="${pmwin:-${det_win:-$TEAM_PM_WINDOW}}"`，det_win 优先于默认值）。
> 后果：窗口后来被改成什么都行，但配置一直说 pi，巡检的面板报"PM 窗口缺失"，而 PM 实际上活着。
> 这类漂移正是"探测现实时把碰巧当成了约定"。

## 要求

1. bootstrap/init 写配置时 PM 窗口名固定为 `pm`（默认值），**不**继承当前窗口碰巧的名字；
   若当前窗口名字不同，bootstrap 顺手把它改名成 `pm`（或在输出里给出一条改名命令）。
2. `team doctor` 加一条：配置里的 PM 窗口名与实际窗口不符时报警（现在的"窗口缺失"提示对改名漂移不说人话）。
3. 夹具：在一个窗口名是 `bash`/`pi`/随便什么的沙盒会话里跑 bootstrap，配置必须写出 `pm`。

## 边界

`scripts/lib/cmd-bootstrap.sh`、`scripts/lib/cmd-project.sh`（doctor）、`tests/smoke.sh`（自己的段）、
`templates/config.sh.tmpl` 注释一句话。不动巡检逻辑本身。

## 验收

```sh
openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh && TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
```
