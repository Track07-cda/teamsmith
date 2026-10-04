# trust-prompt-and-fixtures · PM proposal review

time: 2026-09-22T14:1xZ · reviewer: pm · verdict: **ACCEPTED**

```
change:  trust-prompt-and-fixtures（P57，propose=verify）
tip:     （P57-propose 分支）· 现场=P54 的 F2
```

## Findings

1. **夹具侧（verification）**：判定必须**区分"未预期的整屏覆盖层"与"非空输入框"**——
   实测案例就是 Pi 的项目信任弹窗；**不许**把它报成 `idle-read=NOT-EMPTY`（那个 token 断言的是"框里有文字"，
   而弹窗里一个字都没有；它的两种误判路径（找不到框 / 光标落在弹窗里把选项当框内容）都写进了 requirement）✓
2. **就绪等待只认"真的空输入框"**，不认"出现的第一个整行分隔线"（弹窗自带分隔线，会骗过裸的等待）✓
3. **弹窗在场而等待到期**：输出**点名覆盖层**、保留最后一帧、非零退出，**一个键都不许敲进弹窗**（不许在没定位到输入框时跑投递步骤）✓
4. **夹具必须仍然跑在装了 `.pi/skills` 的项目里**——**不许**用 `--no-skills` 绕过去（那就把要验的形状丢掉了）；
   也不许手工回答弹窗；它用**单次运行的信任覆盖**（不动 Pi 的 trust store）✓ —— 这条正是我裁定里要的"两头都要做"
5. **可证伪**：用**存下来的真实帧**（`tests/frames/` 约定）+ 可见红侧（关掉覆盖层判据 → 同一帧必须被判成草稿）✓
6. **产品侧（init-skill）**：安装步**必须打印一行**说明信任后果（触发资源 + `pi --approve` / `/trust` /
   `team init --no-skills` 三条出路），**不改退出码**；`--no-skills` 时**不打**；
   由 `init`/`bootstrap` 共用的那一个实现打印；skill 与 `bootstrap.md` 同步 ✓

## 结论

**ACCEPTED**。apply 交下一个实现席位；verify 换人。
