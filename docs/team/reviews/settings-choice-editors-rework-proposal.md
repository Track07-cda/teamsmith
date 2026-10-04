# settings-choice-editors（M65 修订）· PM proposal review

time: 2026-09-21T17:4x:00Z · reviewer: pm · verdict: **ACCEPTED**

```
change:  settings-choice-editors（同一 change 的修订；未归档）
owner:   dev2（propose 修订）
tip:     27586d0（task/M65-m65）
user:    2026-09-21「设置选择可以这样做」
```

## Commands run

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict（dev2 分支）→ Totals: 18 passed, 0 failed
# 修订面：design +194 / proposal +49 / panel delta +148-67 / tasks +53
```

## Findings

1. **先测后改，方法正确**：三段+写入两段全部有原始样本（view 3446 / open 3303 / move 6.2 / pick 3393 /
   dry 88.9 / write 176.1 ms），瓶颈定位为"每次进视图/开行/选项都同步起 `config list --json`（3.2–3.4s）"，
   排除了视图构造（~67ms）、按键渲染（6.2ms）、写入子进程（89/176ms）——四个候选逐一用数据裁决。
2. **修法由数据得出**：`settings` 块本有 15s TTL，**删掉"强制重读"**而非加长 TTL；
   交互路径不等待读取写成**行为契约**（按键与帧之间不得出现 `config list`/`__panel-data` 调用；
   编辑器由视图已读的 settings 块构建；accept 的第一个子进程是 `config set --dry-run`、第二个是 `--yes`；
   回执帧不等待后台重读）——可证伪、且不把墙钟塞进正确性门禁（守 D33）。
3. **用户的四条逐一落进 scenario**：② 选中即写（无第二确认帧）③「其他」才走手动输入+校验+确认
   ④ 危险值（即使来自选项）保留一次确认（第一次 accept 只出示警告、不写、不审计；第二次才带
   danger allowance 写入）① 读取不再阻塞交互。另有"编辑器下发生冲突 → 拒绝且不覆盖"的新 scenario。
4. **MODIFIED 语义一致**：typed 值仍过确认帧（write 要求的危险值 scenario 保留），与"选项直写、危险例外"
   不矛盾；base 的既有 scenario 未见丢失（修订是加新 + 按新交互改写相关条）。
5. **翻转已列**（design §5.6 + proposal）：直写的 argv 序列（dry-run→--yes、无确认帧、审计 +1）、
   交互路径无读子进程、危险值仍一次确认、「其他」仍走编辑器——apply 报告要给每条的红侧。

## 结论

**ACCEPTED**。apply 须在 **M59 合并之后**再派（两者都改 `tests/panel-p21.sh`——错峰，避免对冲）；
verify 必须换人（修订者 dev2 不得自验）。
