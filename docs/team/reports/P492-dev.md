# P492 · 让公开设置检查按新版页面操作

**候选已提交，作者静态检查通过；真实操作及正反对照待非作者验证。** 原公开 CI 的失败原件保留，本单只更新两份测试脚本，不改产品、规格或已发布的 0.4.8。

agent: dev   status: DELIVERED（静态）   time: 2026-11-24 UTC

branch: `task/P492-ci-current-project-settings-checks`   PR/MR: -

## 交付物

| 路径 | 变更与保留 |
|---|---|
| `skills/teamsmith/tests/smoke.sh` · `1f3c9f39` | §28 用现有 `panel-strings.mjs` 的正常结果；分别从中英文表删实际显示的 `label_TEAM_PULSE_INTERVAL` 和 `settingsChecks`，要求点名两种语言。退役全表标签、schema 分组与界面绑定、旧布局形状、夹具描述字句检查。§33 的 CLI schema 完备性检查、§38-a 的真实选项读取和 §38-e 的滚轮分派正反对照保留。 |
| `skills/teamsmith/tests/panel-p21.sh` · `6ce69f3c` | 从项目命令页的目标行打开，确认首选 `› 30 秒 · 当前`。危险值第一次只用原指纹验证、不写不增审计，第二次要求同指纹、`--allow-danger`、一次写入和一条审计。规则从主设置目标行打开，等待实际字段、确认页和结果再按键；保留整值写一笔、取消不写、旧指纹不覆盖及两条真实 argv 零读取断言。 |
| `skills/teamsmith/tests/panel-p21.sh` · `f3a99344` | 读稳定可见帧，要求对应卡片、焦点、完整边框及设置专用键栏；只在识别成功后算行数，继续检查 10/1/3、45/33/30/25 四档的可见加隐藏共 68、填高和 45 比 30 至少多 8 行。原分组样例在同一副本里移动已有键的 CLI 分组并增加一个未展示键及新组，检查界面用途和标题数量不变；原窄屏返回、焦点及滚轮不穿透仍在。未改等待轮数或间隔。 |

## 规格与范围

- 完整性：锚点 `openspec/specs/panel/spec.md#Selected settings editors preserve owning-command choices and writes` 已逐条对照目标路径；分组、键栏与窗口沿用现有行为，没有 OpenSpec 变更目录。
- 正确性：脚本语法、内嵌 Python 语法及变更范围已核。尚无本候选的交互结论；原件证明旧检查失败，不代替候选的通过证据。
- 一致性：`git diff --name-only 47d62d28..f3a99344` 只列上述两份测试脚本；§10、§67、产品源、配置、CLI schema、规格、CI 工作流、标签和 npm 包均未改。
- 未发现本次需要另报的新产品缺陷；本次没有运行产品，不能据此裁定原失败中的写入或高度行为已经通过。

## 证据：旧失败与待验证的修复

公开 run `45318204605` 的 `public-ci-logs/138190141503.log:3470,4015–4059` 及 `public-ci-scenes/s4.zip` 两份子日志已只读核对。原记录仍为失败：

```text
28-a2 契约键标签：断言失败
38-b panel-p21.sh choices 有失败                         43 通过 / 29 失败
38-d ... 找不到 [按键→帧之间零读取]
38-e 组标签：绿侧就红了；同一输出里的 panel-strings: ok
38-f panel-p21.sh groups/settings/wheel 有失败           53 通过 / 7 失败
```

`panel-p21-choices.log:54–74` 首个未到达目标是 `30 · 当前`；第 285 行迟到的危险确认出现在规则步骤。`panel-p21-view.log:23,39,58,81–115` 记录三项 `-3` 和四档未读到整帧，帧尾已经显示 `Esc 返回 · ↑/↓ 行 · Enter 编辑 · / 筛选`。候选改用当前目标、分开判断卡片读取失败与计数失败；旧失败不证明产品缺操作行或写入错误。

**待非作者验证：** 正常双语检查通过，两次删标签分别点名两种语言，恢复后通过；现有 CLI schema 检查仍覆盖完整 CLI 声明。使用原有 `choices` 和 `groups settings wheel` 场景验证上述写入、取消、冲突、真实 argv、分组及读屏。记录四档的实际可见/隐藏数和焦点。新候选的红绿对照、真实操作及合入后检查未由作者执行；没有运行全套、整片公开 CI、Pi 或其他段落。

## 实际静态检查

```text
$ bash -n skills/teamsmith/tests/smoke.sh
rc=0
$ bash -n skills/teamsmith/tests/panel-p21.sh
rc=0
$ python3 - <<'PY'
from pathlib import Path
import re
p = Path('skills/teamsmith/tests/panel-p21.sh')
blocks = re.findall(r"<<'(PY\w*)'[^\n]*\n(.*?)\n\1(?=\n|$)", p.read_text(), re.S)
for i, (delimiter, script) in enumerate(blocks, 1):
    compile(script, f'{p}:{delimiter}:{i}', 'exec')
print(f'{len(blocks)} inline Python blocks compiled, not executed')
PY
13 inline Python blocks compiled, not executed
rc=0
$ git diff --check 47d62d28..HEAD
rc=0（脚本候选）
$ git diff --cached --check
rc=0（脚本提交）
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev scope=published files=3024 hits=0 names=ok user=resolved
ledger-ban rc=0
```

## 偏差与交接

无范围变更。当前任务分支保留小步提交供独立验证；未推送、合并或发布。

## V193 返修 · 2026-11-24 UTC

**只修落盘断言，提交 `1eba5b18`。** V193 独立实跑原结果仍为 441 通过、1 失败，其中选择器 56 通过、1 失败。原件第 86 行确为 `TEAM_REVIEW_TIMEOUT='30'`；旧断言返回 1，V193 的原样整行检查返回 0。唯一变动要求精确匹配该键和单引号内的 `30`。确认前不写、原指纹、`--allow-danger`、一次调用和一条审计的判据及所有交互字节不变。

```text
$ bash -n skills/teamsmith/tests/panel-p21.sh
bash -n rc=0
$ git diff --check
git diff --check rc=0
$ git diff --numstat
1  1  skills/teamsmith/tests/panel-p21.sh
$ git diff --unified=0 -- skills/teamsmith/tests/panel-p21.sh
@@ -733 +733 @@ PYCFG
-  assert_match "$(cfg)" '^TEAM_REVIEW_TIMEOUT=("30"|30)([[:space:]]*(#.*)?)?$' "危险确认后仍为30秒"
+  assert_match "$(cfg)" "^TEAM_REVIEW_TIMEOUT='30'\$" "危险确认后仍为30秒"
```

本次未执行新断言、界面或整组检查。交 V193 用原保存文件和错值、纯注释副本核对断言；其余操作沿用已保存原件，不改原失败记录。
