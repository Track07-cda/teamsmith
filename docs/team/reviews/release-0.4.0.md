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

## 三、npm 暂存完成（等用户 2FA 批准）

凭据在 `~/.npm-token`（用户提供）。PM 用一份**临时 userconfig**（`/var/tmp/npmrc-publish.*`，600 权限，用后 shred）注入，token 值不进对话、不进 argv、不进日志：

```
$ npm whoami --userconfig <temp>            → track07-cda
$ npm stage publish --access public --tag latest --userconfig <temp>
+ teamsmith@0.4.0 (staged with id 4af296c4-78dd-4ae4-8920-36bfd67d5e96)
npm notice stage package teamsmith@0.4.0 has been staged with tag latest
publish_rc=0
$ npm stage list
status: validating | access: public | shasum: d007d317654c2dfe0cdcf62f37b67a423ddee277 | staged by track07-cda
```

**还没真正发布**：`npm stage publish` 只做到暂存，要用户在 npmjs 网页批准 2FA 才生效。批准后核对 `npm view teamsmith@0.4.0 version dist.tarball` 与 `npm view teamsmith dist-tags`。

## 四、本次未做（写明边界）

- 没有构建/推送容器镜像：`ci/Containerfile` 的 OpenSpec 1.16 层仍未在本机实测（依赖宿主机 podman 与联网装层），首次公开 CI 才会验证它。
- nightly 元套件作业（`cron 47 3 * * *`，`timeout-minutes: 150`）首次上线，要在推 main 后看 Actions 首跑。
- `0.1.1 → 0.4.0` 的会话内版本差仍在：当前 PM 会话加载的是 0.1.1，`team version --check` 会提示这一行，属预期。
