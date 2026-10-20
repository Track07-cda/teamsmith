# behavior-focused-ci · tasks

阶段口径：**apply** 由收到本 change 的席位完成，拆成四张单（A 表与选择器、B 工作流与发布清单、C 探针与 §58 的
`needs`、D 生效文档），每张单只做**定点证据**；**最终一次固定环境整体运行**是交付门槛。**verify** 由没写过 apply
的席位在独立克隆上重跑**改变的部分 + 少量针对性反例**，未改变的 perf/锁/等待行为引用 P316、V65、V66 的既成独立证据，
不生成翻转配额。本文件不是规格：合同文本在 `specs/verification/spec.md`。

写集（apply 需要逐条明授；未授 → `BLOCKED:` 交回 PM）：

- A：`skills/teamsmith/tests/section-paths.tsv`（表头一行）、`skills/teamsmith/tests/section-select.sh`（装载、`--check`
  规则、`--floor`）、`skills/teamsmith/tests/smoke.sh`（`--floor` 透传）
- B：`.github/workflows/gates.yml`、`docs/team/RELEASE-PUBLIC.md`（PM 独占，需明授或由 PM 改）
- C：`skills/teamsmith/tests/checkout-shape-probe.sh`、`section-paths.tsv` 的 `58` 行、`skills/teamsmith/tests/perf.sh`
  （只改一行过时注释）
- D：`skills/teamsmith/SKILL.md`、`skills/teamsmith/references/protocol.md`

不碰：`skills/teamsmith/tests/signal-gate.sh` 与 `install-shape.sh`（P321 冻结）、`ci/collect-scene.sh` 与两个回收探针
的临时根接线（P324）、`openspec/specs/**` 基线正文（归档时由 delta 写入）、CI 的 60 分钟上限、任何墙钟阈值、探针的
29 个用例集合（只许合并，不许删）、`docs/team/PUBLISH.md`（不存在，不再引用）。

顺序：**A → B → C → D → 最终一次运行**。B 必须等 **P324 冻结并合入**后再改 `gates.yml` 与 `smoke.sh`；C 的 `58` 行要在
A 的表上做。每张单跑完自己的定点证据即可，不要求每步全套。

## 1 · A：表头声明 + `--floor`（路径复用既有 `--paths`）

- [ ] 1.1 `section-paths.tsv` 表头加**一行** `# gate-self-check: 0e 0f 0g 0h 0i 36 61b`，表头注释写明「没被点名的段是产品
  基线、默认方向是在基线里」以及`61b` 入选的理由（它的主体是夹具的牙齿，D147）。按 `design.md` §3.2 的表逐行核对分类，
  有争议的段在报告里点名。
- [ ] 1.2 `section-select.sh` 装载这一行；`--check` 加一条纯逻辑规则：每个 key 命中恰好一行、不重复、不点名前导段。
  红侧（纯逻辑，不跑套件）：表副本删一个 key（该段进基线，`61b` 是显式举出的那个例子）、加一个不存在的 key（`--check`
  红并点名）。**净零**：这条规则替掉的是 1.1 里「默认方向」原先靠人工记的约定，不新增第二次检查。
- [ ] 1.3 `--floor [--paths <path>…]`：`add_prologue` + 每一行基线段 + `add_needs_closure`，有路径时并入路径选集；
  `--floor` 与 `--select` 同用 → `die`；基线段为空 → `die` 并点名空基线。**不加**任何按行读文件的接口。
  定点证据（纯逻辑）：`--floor` 的 key 集合 = 全部段 − 表头点名的段；`--floor --paths <section-select.sh>` 含 `36` 与
  闭包；`--floor --paths <task-model-routing.sh>` 含 `61b`；`--floor --paths ci/some-new-thing` = `FULL`；空基线 → `die`。
- [ ] 1.4 `smoke.sh` 透传 `--floor`（与 `--paths` 同一条代码路径），披露契约一字不改：`decision=`、跑了多少段、未跑清单、
  `== 选段结果 ==`、不打印 `smoke 全绿`；前提跳过仍与通过分开计数。
- [ ] 1.5 路径形状（纯逻辑，不跑套件）：把 `--floor --paths` 用数组传入三个形状 —— 含空格、含双引号与反斜杠、含换行
  （`$'a\nb'`）的文件名 —— 选段器必须对**真实存在的那个字节串**作答（`RUN`/`FULL`，不是被转义或截断的变体）；报告里给出
  命令与输出。逐行读文件的写法会在换行那一条上给出错误的集合，这是 R3 的红侧，写进报告作对照即可（不必保留在树里）。

## 2 · B：工作流 + 发布清单

- [ ] 2.1 `gates.yml` 的 Checkout 取到基点（`fetch-depth: 0`，或显式 fetch `github.event.before`）；新增一步在**宿主侧**
  算出 changed paths：`git diff --name-only -z <base> <tip>` 用 `while IFS= read -r -d ''` 读进 bash 数组（不用
  `-z` 以外的默认列表，不做行切分），基点不可解析（全零 / 不在仓里）时打一条 `::warning::` 并传空数组 → 下一步跑全套。
- [ ] 2.2 正确性步的命令换成 `bash -c 'openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh --floor
  --keep </dev/null --paths "$@"' _ "${PATHS[@]}"`（工作区仍只读挂载，路径作为**参数**进容器）：阻塞步、无 `FAST`、
  无 `continue-on-error`、不注入 `CI`/`GITHUB_*`、`ci/collect-scene.sh` 的自证照旧。性能步保持 `continue-on-error: true`
  的独立、不阻塞、只参考。
- [ ] 2.3 `docs/team/RELEASE-PUBLIC.md` §1 加一条前置：发布前在钉死镜像里跑 `team perf`（参考读数），把打印的数字贴进
  当次发布记录 `docs/team/reviews/release-<version>.md`。**不写**「两次读数应相同」这类承诺。该文件是 PM 的，
  未明授 → `BLOCKED:` 交回。
- [ ] 2.4 B 的定点证据：在钉死镜像里带一个产品路径跑**一次** 2.2 的命令，记录退出码与尾部 25 行；再在副本里改坏一条
  产品断言 → 同一命令非零。「门禁自检自己的源」和「未声明路径」两个形状用纯逻辑回答（选段器即可，不必再起容器）。

## 3 · C：探针的重复执行与 §58 的 `needs`

- [ ] 3.1 **反例对**（`design.md` §4.1，先做再改表）：
  - A：把表里 `58` 那一行改成 `needs: -` 的 scratch 树上 `--select 58` → key 集合 `0,0b,0c,0d,58`、§58 收口行计数
    （✓/✗/SKIP）与带闭包的同树运行**相同**、退出码 0；
  - B：同一套机制仍然有牙 —— 一条**真有**前导依赖的段（§17 要 §15b 建的那棵假项目树，smoke.sh 自己的注释这么写）
    去掉前导后必红、加回后绿。
  两条都成立才进 3.2；A 不成立 → 撤销 `58` 那一行的改动并写明原因，其余照做；B 不成立 → 停手写 `BLOCKED:`（`needs`
  机制本身坏了，不是本 change 能顺手修的）。
- [ ] 3.2 把 `58` 的 `needs` 改成 `-`（前提是 3.1 成立），同一次提交里确认 `--check` 仍绿。
- [ ] 3.3 `checkout-shape-probe.sh` 按 `design.md` §4.2 合并 5 处嵌套：`hy` 的 `19/31/58` → `19,31,58`；`hyteeth` 的
  `31/58` → `31,58`；`in2`+证据层的 `31/58` → `31,58`；`mix` 的 `19` 与 `18` → `18,19`。每条断言仍读自己那段的行，只把
  「那条 run 的退出码」改成「这一次 run 的退出码」并保留每段的行级断言；**用例集合保持 24 次 run，不许删用例**。
- [ ] 3.4 C 的定点证据：`bash skills/teamsmith/tests/smoke.sh --select 36` 在真树上绿（本 change 唯一需要跑 §36 的运行，
  时长如实记录）；3.1 的 A/B 两条；把 `--select 58` 的耗时与 `design.md` §1 的记录（55.9 s / 10 s / 42 s）对照，写出
  **实测**差值（不是投影）。
- [ ] 3.5 顺手改 `skills/teamsmith/tests/perf.sh` 里那行仍写「0/2/3/4」的注释（只改注释）。

## 4 · D：生效文档对齐

- [ ] 4.1 `skills/teamsmith/SKILL.md`：Performance 行改成「只测量并打印参考读数；退出码只有 `0`（读到了）/`3`（建立失败或
  拿不到性能锁）；没有阈值、没有前提因子、没有 `2`/`4`」；删掉/改写 `panel-cpu-premise`+可见 `SKIP` 那一句（夹具已按 P316
  退役）。Diagnostics 行「the gate judges correctness only」保留（它今天仍成立）。
- [ ] 4.2 `skills/teamsmith/references/protocol.md`：§9b-2 标题去掉「measurement premise」，perf 段（785–790 行附近）
  改成同一口径：读数、环境自述、自己的锁、永不进复验判定；删掉阈值/前提因子/「skips visibly」/退出码 `2`/`4`。
- [ ] 4.3 两份文档里搜一遍 `2000 ms`、`premise`、`section-budgets`、`0/2/4/3`，确认没有第二处旧红线（`grep -n` 的输出
  贴进报告）。
- [ ] 4.4 D 的定点证据：`openspec validate --all --strict` + `spec-refs.sh --check` 绿；文档不变量段（英文正文 /
  `team review` 用法）不需要全量，改为 `--select 18`（英文正文不变量）跑一次即可。

## 5 · 最终一次固定环境整体运行（交付门槛）

- [ ] 5.1 在钉死镜像里跑一次 `smoke.sh --floor --paths <本 change 触碰的路径> --keep </dev/null`：它同时是基线的实测
  墙钟（`design.md` §3.4）、合并后断言的合跑（§4.2）、披露检查。记录：退出码、`decision=`、运行/未跑的段数、尾部 25 行、
  总时长。**不**把它说成全量门禁；§61b 与其他重段明确不在其中。
- [ ] 5.2 同一棵树上：`openspec validate --all --strict`、`spec-refs.sh --check`、一次磁盘副本试归档 + 归档后 validate、
  `git diff --check`、固定 `ledger-ban`（名单从 git common-dir 上一层 `.pi/team/forbidden-names.txt`）。
- [ ] 5.3 报告里逐条给出：3.1 的 A/B、1.5 的三形状、2.4 的退出码与尾部、5.1 的时长与尾部、D 的 grep 输出，
  以及**未验**项（§61b 未在本轮重跑；性能读数未重测 —— 引用 P316/V65/V66）。

## 6 · verify（独立席位，非 apply 作者）

- [ ] 6.1 复验**改变的部分**，逐条给红→绿或「破坏实现 → 该断言必红 → 还原」：A（`--check` 新规则两向、`--floor` 的
  FULL/RUN/空基线）、B（工作流的 NUL 链与三形状、披露尾部、改坏产品断言必红）、C（反例对 A/B、合并后各段的行级断言
  仍在）、D（两份文档无旧红线、`--select 18` 绿）。
- [ ] 6.2 少量针对性反例（不复用 apply 的日志）：`--floor --paths` 的换行/引号/反斜杠三种文件名各一次（纯逻辑）；
  `61b` 从声明行删掉 → 它进基线（纯逻辑）；未声明路径 → `FULL`。
- [ ] 6.3 **不重跑** §61b、性能套件、其它重段：在记录里引用 P316、V65、V66 的既成独立证据，并写明「本次未重测」。
- [ ] 6.4 复验记录写 `docs/team/reviews/<ID>.md`：改变部分的命令与输出尾部、判定，以及未重测项的引用来源。只有复验
  通过且用户确认后，PM 才执行归档。
