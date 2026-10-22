# 0.3.2 发布复盘

- tag：`v0.3.2` → `b31a1214`（已推公开仓）；`main` 同点
- 发布检查：`docs/team/tools/release-check.sh` **30 通过 / 0 失败 / 0 跳过**
- npm：暂存 `5de1b250-…` → 用户批准 2FA → registry 复核 `latest=0.3.2`，
  shasum `cebdcb14…`，integrity `sha512-t1lN3N7e…`
- **发布后实装复核（这一版的主要判据）**：`npm i -g --prefix` → `prefix/bin` 五个名字齐全，
  四个信号入口 `readlink -f` 全部落在 `lib/node_modules/teamsmith/skills/teamsmith/scripts/shim/` 内；
  `team version` 报 0.3.2、`team help` rc=0；`pkill -f npm032-probe` → **rc=64、stdout 0 字节**（拒绝，未真发信号）

## 这一版只有一件事

0.3.0 与 0.3.1 的 npm 用户**没有信号闸门**：`package.json` 的 `bin` 只列了 `team`，而 `npm i -g`
只给 `bin` 里列出的名字建链接——包里带着四个 shim（0.3.1 修的就是这个），却没有任何东西指向它们。
这一版把四个名字加进 `bin`，并补上那条**缺失的证伪者**：装完之后 `prefix/bin/<名字>` 必须存在且解析到
包内部，否则判红（`install-shape.sh` 现 144 通过 / 0 失败）。

## 两次复验为什么都漏了

原来那条断言检查「包内 `shim/<名字>` 在不在、用 `PATH=$shim` 能否解析」——它从没检查 **装完之后
`prefix/bin` 里有没有它们**。断言比宣称弱一格，两次独立复验都停在同一格里。这次的修法是把那格补上，
而不是再写一句「已验证」。

## 边界（如实记账）

- 本版**没有**跑四小时整套门禁：产品面只改了 `package.json` 的 `bin` 字段，其余是夹具与文档；
  治理它的那段（安装面）在交付树上 **144/0**，且真安装路径逐条实测。整齐账见 `reviews/P360`。
- `0.3.0` / `0.3.1` 的 deprecate **未完成**：`npm deprecate` 需要一次性密码（`EOTP`），
  token 不能代替。留给用户在网页或 CLI 交互式执行，命令写在 `docs/team/RELEASE-0.3.2.md`。
