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
+ teamsmith@0.4.0 (staged with id 4af296c4-…)      ← 第一次，来自 e5d565b0
→ 用户 reject 后重新暂存（见 §三之二）
+ teamsmith@0.4.0 (staged with id 004eedeb-287d-4655-a018-2af34b442f36)  shasum 34a978e7…
publish_rc=0
$ npm stage list
status: validating | access: public | shasum: d007d317654c2dfe0cdcf62f37b67a423ddee277 | staged by track07-cda
```

### 三之二、为什么重新暂存了一次（PM 的操作失误，记下来）

P413（CI 里那八条 `command not found`）修完后，为了「标签指向含修复的提交」，我把**已推的** `v0.4.0` 标签强制移到了 `d64f5a34`，却发现 npm 侧仍是 `e5d565b0` 的暂存，而 npm 不允许同版本二次暂存（`409 Conflict`）。撤回需要 2FA，只能由用户在网页 reject；用户 reject 后从 `d64f5a34` 重新暂存成功（id `004eedeb`、shasum `34a978e7…`）。现在的三方一致：tag `d64f5a34` = 暂存来源 = 将要发布的 tarball。

教训写在这里：**推出去的标签不要动**。正确顺序是先确认要发哪棵树（门禁全绿），再打 tag；这次的代价是用户手动 reject 一次。

**已发布（用户在网页批准 2FA 后）**。PM 用只读命令核对：

```
$ npm view teamsmith version dist-tags        → 0.4.0 / { latest: '0.4.0' }
$ npm view teamsmith@0.4.0 dist.shasum        → 34a978e73d5d93f3192c326576abf27deb6212f9   （与暂存时一致）
$ npm view teamsmith@0.4.0 dist.tarball       → https://registry.npmjs.org/teamsmith/-/teamsmith-0.4.0.tgz
```

**包内容也核对过**（`npm pack teamsmith@0.4.0` 后解包）：`package.json` 版本 `0.4.0`、`SKILL.md` 的 `version: "0.4.0"`、`tests/lib/pm-window.sh` 在包里、`section-select.sh` 含 `self-sufficient`（10 处）——也就是说发布出去的那份带着 P413 的修复，与 tag `d64f5a34` 一致。

## 四、本次未做（写明边界）

- 没有构建/推送容器镜像：`ci/Containerfile` 的 OpenSpec 1.16 层仍未在本机实测（依赖宿主机 podman 与联网装层），首次公开 CI 才会验证它。
- nightly 元套件作业（`cron 47 3 * * *`，`timeout-minutes: 150`）首次上线，要在推 main 后看 Actions 首跑。
- `0.1.1 → 0.4.0` 的会话内版本差仍在：当前 PM 会话加载的是 0.1.1，`team version --check` 会提示这一行，属预期。
