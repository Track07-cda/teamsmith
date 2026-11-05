---
id: P415
title: 捕获扩展在 775 的项目根下拒绝注册（safeDirectory 把「自己组可写」当危险），且 doctor 不报原因
agent: dev2
category: code
phase: apply
change: agent-self-reminder
specs: key-replies
anchor: openspec/specs/key-replies/spec.md
deltas: -
branch: task/P415-safe-dir-own-group
---

# P415 · 关键回复在 0.4.0 里全线不工作

## 现场（用户在 erp 项目实测，PM 复现并定性）

`erp` 起了 PM、`team-reply.ts` 在 Pi 的扩展列表里（`team-bg.ts, team-inbox-watch.ts, team-reply.ts` 都在），但：

- `.pi/team/state/reply-capture/` **不存在**（扩展没有注册成功）；
- `team doctor` 只报 `关键回复运行 ! unknown … registration:Error`，**不说是为什么**；
- 回复里的 `[[team-reply:…]]` 没有被剥离。

PM 用同一份 `resolvePMIdentity` 对着那个 PM 进程的真实 env/context 复算，拿到确切原因：

```
REFUSED: unsafe directory ancestry
```

`reply-capture.mjs:187` 的判据是每个祖先目录都不许 `mode & 0o022`（组/他人可写）除非有 sticky 位。而这台机器上：

```
drwxrwxr-x yikdata yikdata  /…/Documents/syncthing/Work/Projects
drwxrwxr-x yikdata yikdata  /…/Work/Projects/erp
drwxrwxr-x yikdata yikdata  /…/erp/.pi
```

全是 775，组就是用户自己的组（`id -g` = 1000，与目录组一致）。于是**所有位于这个同步目录下的项目全部拒绝注册**——包括 pm-skills 自己（它的 `state/reply-capture/` 同样不存在）。

## 为什么这是缺陷

775 + 自己的组不是他人可写：只有**同一组**的进程能写，而该组就是用户自己。判据真正要防的是「别的用户/别的信任域能替换我的记录」，那对应的是 `0o002`（other-writable），以及「组可写且组不是本进程的有效组」。现在这条把最常见的 umask 002 布局一律判死，代价是整个 0.4.0 的核心功能在用户机器上一个都不工作。

## 要做的

1. **改判据**（`safeDirectory`）：拒绝条件收窄到「他人可写（`0o002`）且无 sticky」，以及「组可写（`0o020`）且该组的 gid **不在**本进程的有效组集合里（`process.getgroups()` + `getgid()`）且无 sticky」。祖先链上每一级同样适用；这条规则里 gid 取 `statSync(at).gid`。
2. **doctor 要说出原因**：`关键回复运行` 读不到注册时，用同一套解析把拒绝原因打出来（一行，形如 `✗ 未注册：unsafe directory ancestry（/…/Work/Projects 组可写且组不在有效组内）`），不要只给 `registration:Error`。原因里**必须带那个目录的路径**，否则下一个人还得复算一次。
3. **红侧两条都要**：
   - 造一个 `0o777` 的祖先目录（他人可写、无 sticky）→ 必须仍然拒绝；
   - 造一个 775、组=别的组、且该组不在有效组内的目录 → 必须仍然拒绝；
   - 775、组=自己的有效组 → 必须接受（这就是本机现状）；
   - 把 `safeDirectory` 改回旧判据 → 第三条必须变红。
4. 用真实项目验证：在一个 775 的临时项目里起一份捕获（不必起 PM，用 `resolvePMIdentity` 的同一入口），`runtime.json` 必须写出来；再把那个项目根改成 777，必须回到拒绝。

## 验收（自己跑，贴输出）

- 上面四条红/绿侧的输出
- `bash skills/teamsmith/tests/reply-capture.mjs --all`（或该套件入口）与 `bash skills/teamsmith/tests/key-replies.sh --select workflow`
- `section-select.sh --check` 与 `--self-sufficient`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 报告 `docs/team/reports/P415-dev2.md`，提交推分支，通知 PM

## 边界

只改 `skills/teamsmith/scripts/reply-capture.mjs`、`extension/team-reply.ts`（若需）、`scripts/lib/cmd-project.sh` 的 doctor 分支与相关测试。不改用户项目的权限、不改 `team up` 的注入、不改 0.4.0 的 tag。
