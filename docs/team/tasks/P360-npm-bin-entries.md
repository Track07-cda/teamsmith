# P360 · 0.3.1 在 npm 上仍然没装上四个信号入口（bin 字段漏列）

task: P360
agent: dev3
phase: apply
category: code
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 打包与安装面
deltas: -
branch: task/P360-npm-bin-entries

## 事实（PM 在 0.3.1 发布后照惯例从 registry 实装一次，抓到的）

```
npm i -g --prefix /tmp/x teamsmith@0.3.1
ls /tmp/x/bin        → team            # 只有 team
pkill/killall/pgrep/pidof            # 不在 prefix/bin 里，用户敲到 /usr/bin
```

`package.json` 的 `bin` 只列了 `team`。`npm install -g` **只给 `bin` 里列出的名字建链接**——包里的 shim 文件在（0.3.1 修的就是这个），但没有任何东西指向它们。所以 **0.3.0 与 0.3.1 的 npm 用户都没有闸门**。

**为什么两次独立复验都没抓到**：`install-shape.sh` 的 `chk_prefix_signal_entries` 检查的是「包内 `shim/<name>` 在不在、用 `PATH=$shim:…` 能否解析」——它从没检查 **`npm i -g` 之后 `prefix/bin` 里有没有这四个名字**。断言比宣称弱一格，两次复验都在同一格里。

## PM 已经做的（你在此基础上收口，不要重做）

1. `package.json` 的 `bin` 补齐五项：`team` + `pkill`/`killall`/`pgrep`/`pidof` → 各自指向 `skills/teamsmith/scripts/shim/<name>`。
2. `install-shape.sh`：
   - `chk_prefix_signal_entries` 开头补**缺失的证伪者**：`prefix/bin/<t>` 必须存在且 `readlink -f` 落在 `<prefix>/lib/node_modules/teamsmith/` 内（否则 `return 1` 并点名「npm 的 bin 字段没列它」）；
   - `chk_pack_manifest` 从「恰好一个 bin 键」改成「team + 四个信号入口，且四个都指向包内 shim」。
3. 版本 0.3.2（六处落点 + CHANGELOG 条目，写明 0.3.0/0.3.1 都受影响、`install.sh` 路线不受影响）。

## 你要做的

1. **跑通安装面那一段**：`bash skills/teamsmith/tests/install-shape.sh`（约几分钟；`2 条 ✗` 是改前的旧断言，改后必须 0 红）。贴段尾。
2. **补红侧两条**（承重，这是本任务的核心）：
   - 把 `package.json` 的 `bin` 临时改回只列 `team`（私有副本里）→ 新断言必须**红并点名四个入口**；
   - 把 `bin.pkill` 指到 `/usr/bin/pkill`（私有副本里）→ 必须红并点名「指向不是包内」。
   两条都要给出改前（红）/还原（绿）的读数。
3. **真安装复核**：`npm pack` → `npm i -g --prefix <私有目录>` → 打印 `prefix/bin` 清单与四个 `readlink -f`，并验一次拒绝路径（例如 `pkill -f p360-probe` 必须被拒、`/usr/bin` 没被执行）。
4. 轻量收口：`bash -n`、账本禁令、`git diff --check`。

## 边界

写集：`package.json`、`skills/teamsmith/tests/install-shape.sh`、版本六处与 `CHANGELOG.md`（PM 已改的部分接着用，**别回退**）、报告。不改信号闸门实现、不改别的断言、不加门禁段。

发布由 PM 做（0.3.2 + 给 0.3.1 打 deprecate），你**不要**碰 registry。
