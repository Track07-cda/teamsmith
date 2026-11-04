# 0.4.0 发布执行记录

冻结提交 `e5d565b0`（README 的安装示例指向 `@v0.4.0`），tag `v0.4.0`（annotated，对象 `1eb01e3d`）。

## 一、发布前检查（都是实测）

- **版本一致**：`team version --check` → 磁盘 0.4.0 / `SKILL.md` 0.4.0 / CHANGELOG 0.4.0（`package.json` 同为 0.4.0）。
- **一阶全量门禁**：`bash skills/teamsmith/tests/smoke.sh --snapshot </dev/null` → **rc=0，`== 结果 == ✓5037 ✗0`**，快照 `committed=e5d565b0…`，`快照运行结束 committed=e5d565b0… rc=0`，143 段计时行。日志在 `/var/tmp/release-040-gate.log`。
  这条用的是 P410 的冻结快照机制：活树上的后续提交不会让它作废，快照内部指纹照旧抓「夹具改了树」。
- **元套件绿记录**：`2026-11-04T19:06:45Z · GREEN · 7165s · 10 段 · 判据 edda4fcb`（发版清单要求 ≤7 天，满足）。
- **快照/时间成本**：一阶 143 段（含分段）实际用时约 77 分钟；元套件 119 分钟在夜间跑，不进每次门禁。

## 二、推送（只推这一条历史）

```
git push public main               # db0bea98..e5d565b0
git push public refs/tags/v0.4.0   # 只推这一个 tag，没有 --tags
git push public main:dev           # dev 镜像同名前进
```

远端核对：`refs/heads/main = e5d565b0…`、`refs/tags/v0.4.0 = 1eb01e3d…`。

## 三、npm 未完成：缺发布凭据（卡在这里）

```
$ npm stage publish --access public --tag latest
npm error code ENEEDAUTH
npm error need auth This command requires you to be logged in to https://registry.npmmirror.com
```

本机 `npm config get registry` = `https://registry.npmmirror.com`（镜像，不是 npmjs），且环境里没有 `NPM_TOKEN`、仓库无 `.npmrc`。镜像站不接受发布。**凭据属用户本人，PM 不读取也不代填。**

用户在自己手上执行（二选一）：

```bash
# A. 直接对 npmjs 暂存（网页 2FA 批准后才算发布）
npm stage publish --access public --tag latest --registry https://registry.npmjs.org

# B. 先配置 token（用户自己写入，PM 不接触），再发布
npm config set //registry.npmjs.org/:_authToken=<用户自己的 token>
npm stage publish --access public --tag latest --registry https://registry.npmjs.org
```

## 四、本次未做（写明边界）

- 没有构建/推送容器镜像：`ci/Containerfile` 的 OpenSpec 1.16 层仍未在本机实测（依赖宿主机 podman 与联网装层），首次公开 CI 才会验证它。
- nightly 元套件作业（`cron 47 3 * * *`，`timeout-minutes: 150`）首次上线，要在推 main 后看 Actions 首跑。
- `0.1.1 → 0.4.0` 的会话内版本差仍在：当前 PM 会话加载的是 0.1.1，`team version --check` 会提示这一行，属预期。
