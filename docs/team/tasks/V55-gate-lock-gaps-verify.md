# V55 · 门禁锁：8 项留空补齐 + F1 修复的独立复验（决定性：那条腿必须真的往回找）

task: V55
agent: verify
phase: verify
category: verify
change: gate-lock-external-deletion
specs: verification, boundary
deltas: -
branch: task/V55-gate-lock-gaps-verify
deps: P305（已交付，冻结 tip 见**收据文件** `reviews/V55/freeze-receipt.txt`）｜你上一轮的 V53（两轮）｜P303 的 8 项留空（`docs/team/reports/P303-dev-bob.md` §留空项与原因）

## 复验对象

F1 修复 + 8 项补齐（1.1/2.1/2.4/4.1/5.2/5.3/7.1/7.2）。

## 必须自己做的（不许只复跑作者脚本）

1. **F1 的决定性检验**（这条腿以前是**真空通过**的）：
   - `flip-p287-lock.sh --self-test` 必须**真的往回找**——你要**独立确认它选中的「改动前」树里确实没有伴生锁**（例如把你自己的标记放进当前树、看它是否出现在该腿的证据里；或直接读它的基线变量并在那棵树上 `ls` 一次）；
   - **自己造两条红侧**：① 把探测改回 `git show … | grep -q` 的旧写法 → 该腿必须**再次红**（旧现场）；② 把基线指回 `main` 的 tip → 也必须红（不许真空通过）；
   - **不许**用作者提供的 `--break=` 开关当唯一证据（那只能证明开关接线，不能证明腿非真空）。
2. **三条新断言有牙**：① `team_project_ns` 的「非 git 检出 / PATH 无 git」断言——把它改成会报错的实现 → 必须红；② `mtime >= claimed`——把 `touch` 去掉 → 必须红；③ 5.2 的 `legacy` 标注——把标注去掉 → 必须红。
3. **4.1 的逐字 diff 证据**：核作者产出的「冻结集合逐字相同」证据（上限算式 / token 闭集 / 退出码集合 / `team_review_verdict`）**自己复算一次**；并按 PM 裁定（两条防御性文案的消失算机制改写的必然）核「加锁失败路径」的现行为证据（非零退出 + 一行点名）。
4. **不回退**：V53 两轮已验的绿面随机抽 ≥4 条复跑（同树 A/B 两个方向、真平铺旧名红、兼容声明互斥、性能锁同族、察觉被删的安全停跑）；`smoke.sh --select 34,34b,34c,34d,0e` 贴结果。
5. 计时类按 D192；容器里先 `mkdir -p` 再设 `TMPDIR`（D189）；`/tmp` 根数前后对比；受检 tip 以收据文件为准（D196）。

## 交付

`docs/team/reviews/V55.md`（抬头含 `判定: **PASS**` / `判定: **FAIL**`；逐条命令 + rc；你对「这条腿是否真的往回找」的**独立取证**；两条红侧与三条断言红侧的原始输出；写明运行模型与 loadavg）；不改候选、不合并、不推送；结论通知 PM。
