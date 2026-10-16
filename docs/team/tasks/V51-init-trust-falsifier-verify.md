# V51 · `init` 信任提示那半条的 falsifier（`slash-team` 3.3）：定点复检

task: V51
agent: verify
phase: verify
category: verify
change: slash-team
specs: init-skill
deltas: -
branch: task/V51-init-trust-falsifier-verify
deps: P299（已交付，冻结 tip 见派单消息）｜P298 的 G1（我方复核记录：`docs/team/reviews/P298.md`）

## 复验对象

P299 加的两组 falsifier：① 安装面夹具里「信任提示行必须**一行**同时点名 `.pi/skills/` + `.pi/extensions/` + 三条出路（`pi --approve` / `/trust` / `team init --no-skills`）且**只出现一次**」；② 两处 init 文档同页带「触发资源 + 三条答案」的稳定 token；③ 对应的红侧臂。

## 必须自己做的（不许只复跑作者脚本）

1. **红侧自己造**（三处）：① 从输出行删掉 `.pi/extensions/` → 必须红并点名**那一行**；② 让该行出现**两次** → 必须红（「只能一次」那条）；③ 从任一 init 文档删掉那个稳定 token → 必须红。
2. **不许放宽**：核作者没有把既有断言改松（例如把「同一行」改成「同一输出」、把 token 匹配改成子串随便命中）——逐行看 diff。
3. **`--no-skills` 的安静**：自己造现场验一次「`--no-skills` 时该行不出现」（这是 3.3 的另一半）。
4. **不把测试改坏**：`install-shape.sh` 在**无参数**（全组）与 `--flip` 两种模式下各跑一次并贴结果；`smoke.sh --select <闭包段>` 贴结果；跑前跑后 `/tmp` 根数。
5. 计时类判据按 D192；容器里先 `mkdir -p` 再设 `TMPDIR`（D189）。

## 交付

`docs/team/reviews/V51.md`（抬头含 `判定: **PASS**` / `判定: **FAIL**`；逐条命令 + rc；你造的三条红侧原始输出；写明运行模型与 loadavg）；不改候选、不合并、不推送；结论通知 PM。
