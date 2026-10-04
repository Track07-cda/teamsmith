# tmux-gate-grant-redesign · PM proposal review

time: 2026-09-21T17:2x:00Z · reviewer: pm · verdict: **ACCEPTED**

```
change:  tmux-gate-grant-redesign
owner:   dev-bob（propose）
tip:     a4b9c7c（task/M63-argv-2）
user:    方案 2（2026-09-21「2」）
```

## Commands run

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict   → Totals: 18 passed, 0 failed
# delta：boundary ADDED ×3 requirement / 14 scenario（无 REMOVED/MODIFIED）
```

## Findings（逐条对着用户的五条方向）

1. **按目标归属判定 — PASS。** kill-server 与 kill-session -a 对共享默认 socket**永远拒绝**；
   其余三个子命令只有在 `-t X` 非空、session 段**字面等于** `TEAM_SESSION` 且身份**绑定到调用者**
   （M40 的 TEAM_ROOT/TEAM_MAIN_ROOT ↔ cwd 祖先判据）时才算"自己的具名对象"（`act=allowed-owned`）；
   空目标/相对目标/`%N`/`@N`/裸窗名一律"不可证明 → 拒绝"。M41 的私有 socket 与两个假隔离形态**原样保留**。
2. **逃生口不可继承 — PASS。** 唯一的放行是 argv 级 `--teamsmith-allow-destructive`（**仅全局参数位**、
   消费后从 argv 剥掉、不进环境、记 `act=explicit-flag`；`=1` 形式不认识 → 落到 tmux 报错 = fail closed；
   子命令之后的同名词是**数据**，原样透传——`send-keys` 载荷不会被误剥）或绝对路径（闸门看不见）。
   「带 token 的调用对任何 socket 都执行」是**调用者的显式授权 + 审计**——第 7 次死亡的那种形状从此是
   "故意的、留痕的"，不再是"继承来的"。
3. **D5 的结论比任务书更好**：**CLI 没有任何调用点需要 token**——`teardown`/`review` 清理/加窗清理全都指向
   自己会话的具名对象（ownership 直接过），`scripts/team:19` 的 export 直接删掉。这把方案 2 的"CLI 自带
   argv 标志"修正成了更干净的形态，理由写清了，我认可。
4. **环境变量退役为 refuse 级"墓碑" — PASS（D4）**。shim 不再读它、CLI 不再导出它、schema 保留一行
   只读的退役说明（存量项目配置不会突然变成未知键）、doctor 加一行"server 全局环境还留着这个退休键"的提示。
   墓碑不能被重新武装（refuse 类写不进去）。
5. **夹具纪律 — PASS（D6）**：refused/allowed-owned 的探针把 `TEAM_TMUX_REAL` 钉到 argv 记录 stub
   （错判 = 执行一个 shell 脚本，不是杀 server）；真实破坏调用只在私有 socket 或容器里；**泄漏形状在容器里复现**
   （容器里的"默认 socket"是容器自己的，宿主指纹逐字节不变）。这正好补上我那次事故违反的规则。
6. **D2 的取舍明确**：拒绝了"向 server 查询调用者会话"的替代方案（多一次往返 + 新失败面 + 闸门自己会去
   碰共享 server），理由成立；并留了"若 PM 偏好查询变体只改一段"的活口。我维持它的选择。
7. **规模**：3 requirement / 14 scenario，在任务书 3–5 / 12–20 的框内；`override` 一词从闸门词汇表移除。

## 过程项（已让 dev-bob 补）

- 交付时**报告文件未提交**（`?? docs/team/reports/M63-dev-bob.md`）——已提醒它提交后再合并。

## 结论

**ACCEPTED**。apply 按 tasks.md 的 B1（判定 + token）→ B2（夹具/lint/翻转）→ B3（台账）走；
verify 必须换人。M62 在本 change 落地后解除 blocked（那条 requirement 的措辞不用改，届时为真）。
