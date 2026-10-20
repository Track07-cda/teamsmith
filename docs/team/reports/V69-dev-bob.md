# V69 · 独立验证 P331：降级容量块里的临时根、落盘字节与完整路径

task: V69   status: delivered   time: 2026-10-20T07:18Z   agent: dev-bob   phase: verify   change: `-`
specs: panel#`C-v` pastes a clipboard image as a temporary file path
branch: `task/V69-paste-repair-review`（local 模式；本分支只放这份报告，未 push）
受检: `950ac8af`（产品 `6c749518` · 理由框断言 `6f516b42` · 作者报告 `950ac8af`）
红侧基线: `b57db390^`（`2502625b`）里的 `panel.js`
独立克隆: `/var/tmp/v69-dev-bob-1792480240-11848/tree`（`git clone --no-hardlinks` → `checkout 950ac8af`，
树干净；作者树与主检出一个字节没动）

## 判定：PASS —— 可合入

任务书那个问题的答案是**能**，四条判据各自独立成立（证据在 §二–§六）：

- **无 `capacity.log` 的新建项目里，容量块仍降级，粘贴照样落盘**：夹具项目 `state/` 里只有 `draft.md`、
  容量块画 `—`，同一次运行里 `TMPDIR` 恰好一个 `teamsmith-paste-*.png`、内容是剪贴板的 8 字节、
  完整路径进了草稿与理由框（✓26 ✗0）。
- **红侧只由 bundle 决定**：同一个克隆、同一套夹具、只把 bundle 换成 `b57db390^`，四条落盘/字节/路径
  断言同时变红（✓22 ✗4，rc=1）；那条「路径插在插入点」在旧 bundle 下反而是绿的（空路径的 `a${file}d`
  等于 `ad`）—— 空心绿的具体形状被这次对照抓到了。
- **数据层只留 capacity 的 `temp_root` 一个字符串**，且**无效 payload 不冒充本次结果**：我把候选的
  `createPanelCache` 接到一个按块作答的替身上逐轮驱（七轮），旧实现同样的七轮全 `null`——探针不是真空的。
- **外部输出逐字节没变**：同一项目、同一参数下旧/新 bundle 的 `--json`（831 字节）与 `--print`（30 行）
  在归一化时钟后 `diff` 为空，`tempRoot` 一次都没出现在输出里。

无 BLOCKED。两条缺口与三条边界在 §八、§十，都不是本候选引入的，也不阻止合入。

## 一 · 源码最终 diff：只有 capacity 的 `temp_root` 穿过了失败

受检范围 `b57db390^..950ac8af` 一共改了 6 个文件，产品面只有两个源文件 + 重建的 bundle（另外是三行
注释与夹具、作者报告）：

```
$ git diff --stat b57db390^ 950ac8af
 docs/team/reports/P331-dev2.md                  | 162 ++++++++++++++++++++++++
 skills/teamsmith/scripts/panel/panel.js         | 128 +++++++++----------
 skills/teamsmith/scripts/panel/src/clipboard.ts |   3 +-
 skills/teamsmith/scripts/panel/src/data.ts      |  42 +++++-
 skills/teamsmith/scripts/panel/src/main.tsx     |   6 +-
 skills/teamsmith/tests/panel-b2.sh              |  17 ++-
$ git diff --stat b57db390^ 950ac8af -- skills/teamsmith/scripts/lib skills/teamsmith/scripts/*.sh
（空 = bash/CLI 侧一行没改）
$ git diff b57db390^ 950ac8af -- skills/teamsmith/scripts/panel/src/clipboard.ts
- * tool prints (`capacity.temp_root` in the panel data). Deriving it here again would be a second
+ * tool prints (`capacity.temp_root` in the panel data, taken even when that block degrades to `—`
+ * for want of a capacity log, P331). Deriving it here again would be a second
```

读代码的结论（不是转述作者的说辞）：

1. `runBlock` 的失败分支只多一个字段：`tempRoot: name === 'capacity' ? tempRootOf(out) : undefined`；
   `error`（`rc=…: tail`）与 `ok:false` 原样，`degraded`/`errors` 的算法**一行未动**。
   `tempRootOf` 只认**整段 stdout 是合法 JSON** 且 `temp_root` 是**非空字符串**；任何解析失败返回
   `undefined`。
2. `build()`：成功时 `s.tempRoot = undefined`（清掉上一轮），失败时 `s.tempRoot = outcome.tempRoot`
   （本轮的值，无效就是 `undefined`）。`refresh()` 里没有第二条写它的路径。
3. `snapshot()`：`data.capacity?.temp_root ?? state.capacity?.tempRoot`，两者都没有就**不给字段**，
   于是 `writePasteFile(bytes, mime, undefined)` → `pasteFilePath` 直接返 `null`（`if (!ext || !dir)`）——
   粘贴什么都不写，也不猜根。仍然只有一份解析（bash 的 `team_tmp_root`），面板侧没有第二次推导。
4. `main.tsx` 只改了粘贴读的这一个字段；`clipboard.ts` 只改注释。
5. `panel.js` 是生成物：见 §二，提交的 bundle 与从提交的源码重建出来的逐字节相同，所以 bundle 里不可能
   有源码之外的东西。

## 二 · 钉住工具链重建：提交的 bundle 逐字节可复现

```
$ cd /var/tmp/v69-dev-bob-1792480240-11848/tree/skills/teamsmith/scripts/panel
$ $HOME/.bun/bin/bun install --frozen-lockfile          # bun 1.3.14
+ react-devtools-core@8.0.0
45 packages installed [607.00ms]                        # rc=0
$ bash build.sh
Bundled 561 modules in 47ms
panel.js written (978626 bytes, sha256 295d3e88f4b6a0172353f557d281790cac3e64f55836d100b4ced21f033cf79d)
$ git show 950ac8af:skills/teamsmith/scripts/panel/panel.js > /var/tmp/v69-dev-bob-1792480240-11848/logs/panel.committed.js
$ cmp panel.js /var/tmp/v69-dev-bob-1792480240-11848/logs/panel.committed.js && echo "cmp: IDENTICAL"
cmp: IDENTICAL
$ git status --porcelain --untracked-files=all          # 空
```

时间：`bun install` 07:11:26Z、重建 07:11:28Z。旧基线**没有**重建（任务书要求），它直接从 git 取
（`b57db390^` 的 `panel.js` = 978 356 字节 / `sha256 bf40c98f…`）；这个字节数与作者报告里「未改动的树上
978 356 字节、`cmp` IDENTICAL」一致。

## 三 · 同一个固定克隆上的两次夹具运行（只换 bundle）

**修复候选（全绿）**，07:11:38Z → 07:12:53Z（约 75 s）：

```
$ TMPDIR=/var/tmp/v69-dev-bob-1792480240-11848/tmp TEAM_B2_KEEP=1 \
    bash skills/teamsmith/tests/panel-b2.sh clipboard
  ✓ B4 模型夹具：panel-clipboard-model: 9/9 passed
  ✓ B4 TMPDIR 里恰好一个 teamsmith-paste-*.png
  ✓ B4 文件内容就是剪贴板的 8 字节
  ✓ B4 路径插在插入点（a<path>d）
  ✓ B4 探测先问 wl-paste
  ✓ B4 Wayland 命中时 xclip 没有被调用
  ✓ B4 粘贴后继续打字落到草稿（插入点之后）
  ✓ B4 X11 回退：文件内容 XCLIPDATA
  ✓ B4 X11 回退：路径进草稿
  ✓ B4 调用顺序：wl-paste(1) 先于 xclip(2)
  ✓ B4 文本回退：afrom the clipboardd
  ✓ B4 文本回退不写临时文件
  ✓ B4 文本回退不调用 xclip
  ✓ B4 无工具：草稿不变   ✓ B4 无工具：没有文件   ✓ B4 无工具：帧照常、没有错误行
  ✓ B4 无工具后仍能打字
  ✓ B4 挂死工具 5s 内：草稿不变   ✓ B4 挂死工具：没有文件
  ✓ B4 挂死工具期间仍能打字   ✓ B4 Esc 仍关掉输入行并保留草稿
  ✓ B4 理由行里有图片路径
  ✓ B4 理由模式仍不写 state/draft.md
  ✓ B4 只读：C-v 没有触发任何 team 动作
  ✓ B4 空闲 5s（写信关着/开着两段）都没有调用剪贴板工具
== 结果 ==  ✓ 26  ✗ 0        # rc=0
```

这个夹具项目就是「新建项目」的形状：`state/` 里只有 `draft.md`（没有 `capacity.log`），同一次捕获里
容量块是 `│  —`：

```
$ ls /var/tmp/…/clipboard/root/.pi/team/state/
draft.md
$ sed -n '4,6p' /var/tmp/…/clipboard/reason.txt
╭─ 容量 ──────────────────────────────────────────────╮
│  —                                                  │
╰─────────────────────────────────────────────────────╯
```

**旧 bundle（预期红）**，07:13:05Z → 07:14:27Z（约 82 s）：

```
$ git show b57db390^:skills/teamsmith/scripts/panel/panel.js > /var/tmp/…/logs/panel.pre-p331.js   # 978 356 B
$ TMPDIR=… TEAM_B2_KEEP=1 TEAM_B2_PANEL=/var/tmp/…/logs/panel.pre-p331.js \
    bash skills/teamsmith/tests/panel-b2.sh clipboard
  ✗ B4 TMPDIR 里恰好一个 teamsmith-paste-*.png（期望 [1]，实际 [0]）
  ✗ B4 文件内容就是剪贴板的 8 字节（期望 [PNGDATA8]，实际 []）
  ✓ B4 路径插在插入点（a<path>d）          # 空心绿：file 为空，a${file}d 恰好等于 ad
  ✗ B4 X11 回退：文件内容 XCLIPDATA（期望 [XCLIPDATA]，实际 []）
  ✗ B4 理由行里有图片路径（理由模式没有文件落地：路径为空）
== 结果 ==  ✓ 22  ✗ 4        # rc=1 —— 这是预期反例，不是「测试通过」
```

旧 bundle 的夹具目录也留着，形状与因果对得上：`tmpdir` 0 个文件、理由框最后一行只有 `│ > why`
（路径为空），而修复后的同一条命令在同一个框里画出了完整路径。

## 四 · 数据层：七轮私有探针（受检树外，`/var/tmp/v69-dev-bob-1792480240-11848/probe/`）

只跑夹具不够回答任务书那句「失败块的 payload 不能被悄悄当成功数据」——夹具只有一个成功路径。我写了一个
按块作答的替身 CLI，把候选的 `createPanelCache` 真实驱七轮；每轮切换替身的行为，看 **`snapshot().tempRoot`
/ `degraded` / `data.capacity` / `errors`** 四个字段：

```
$ $HOME/.bun/bin/bun run probe.ts <root> <stub.sh>            # 候选 data.ts
{"mode":"cap_degraded_valid","tempRoot":"/var/tmp/v69probe/cap-degraded","degraded":["capacity"],"dataCapacity":"absent","errors":["capacity"],"ok":true}
{"mode":"cap_degraded_garbage","tempRoot":null,"degraded":["capacity"],"dataCapacity":"absent","errors":["capacity"],"ok":true}
{"mode":"cap_ok","tempRoot":"/var/tmp/v69probe/cap-ok","degraded":[],"dataCapacity":"present","errors":[],"ok":true}
{"mode":"cap_ok_no_root","tempRoot":null,"degraded":[],"dataCapacity":"present","errors":[],"ok":true}
{"mode":"other_failed_valid","tempRoot":null,"degraded":["pending"],"dataCapacity":"present","errors":["pending"],"ok":true}
{"mode":"cap_degraded_nonstring","tempRoot":null,"degraded":["capacity"],"dataCapacity":"absent","errors":["capacity"],"ok":true}
{"mode":"cap_degraded_valid","tempRoot":"/var/tmp/v69probe/cap-degraded","degraded":["capacity"],"dataCapacity":"absent","errors":["capacity"],"ok":true}
```

逐条读：①降级但 payload 合法 → 只交出 `temp_root`，块**照旧**在 `degraded` 里、`errors` 里、`data.capacity`
不存在（还是画 `—`）；②上一轮有过根、这一轮 payload 是垃圾 → `null`，**没有拿上一轮冒充**；③成功 → 新鲜值；
④成功但没有 `temp_root` → `null`；⑤**别的块**（pending）失败且 payload 里有 `temp_root` → `null`（只有
capacity 这一个块有这条路）；⑥`temp_root` 不是字符串 → `null`；⑦恢复正常 → 根回来。

探针本身不是真空的：同样的七轮接到 `b57db390^` 的 `data.ts` 上，`tempRoot` **全 `null`**，而
`degraded`/`errors`/`dataCapacity` 三列与候选**逐字相同**——差分只落在 `tempRoot` 上：

```
$ $HOME/.bun/bin/bun run probe-old.ts <root> <stub.sh>        # 旧 data.ts
{"mode":"cap_degraded_valid","tempRoot":null,…}   {"mode":"cap_ok","tempRoot":null,…}
（七轮全 null；其余三列与上一块逐行一致）
```

## 五 · 外部输出没变：`--json` 与 `--print` 逐字节对照

同一项目、同一参数，只换 bundle，归一化 `timestamp` 与时钟后 `diff` 为空：

```
$ node <old bundle> --root <proj> --team-cli <clone>/skills/teamsmith/scripts/team --json  --refresh 3 > old2-json.txt
$ node <new bundle> --root <proj> --json --refresh 3                                          > new2-json.txt
$ diff <(norm old2-json.txt) <(norm new2-json.txt) && echo IDENTICAL
IDENTICAL                                        # 两侧各 831 字节
$ node <old bundle> … --print --width 120 --height 30 --refresh 3 > old2-print.txt
$ node <new bundle> … --print --width 120 --height 30 --refresh 3 > new2-print.txt
$ diff <(norm old2-print.txt) <(norm new2-print.txt) && echo IDENTICAL
IDENTICAL                                        # 两侧各 30 行，容量块都是 │  — │
$ grep -c tempRoot new2-json.txt new2-print.txt
new2-json.txt:0
new2-print.txt:0
```

（第一次对照我写错了必须的 `--team-cli`，旧 bundle 站在克隆外找不到 CLI，两边都输出空 → 那次「相同」是假的，
已作废重跑；上面是重跑后的读数。）源码侧也一致：`--json` 走 `buildJson()` = `{panel, activity}`，`tempRoot`
根本不在 `data` 里，所以不是靠「碰巧没打印」。仓库里原有的降级断言也没有被动到：`smoke.sh:12329-12333`
（§27-b：`待办 —`、容量标题、其余块照常、`延后投递 —` 不出现）与本次 `--print` 的逐行相同互相对上。

## 六 · 理由框断言：只读那一框，且路径为空时直接红

从修复后保留下来的捕获里直接核对（不是重跑）：

- `待命原因` 在整屏里只出现 **1** 次（`grep -c` = 1，即标题行）；框体是没有底边的托盘，框后就是文件尾，
  所以「取到第一行别的东西为止」正好是这一框的两行，框外的帧行（同屏 9 行以 `│ ` 开头）一行都进不来
  （框里那两行是 `│ > why…` 与 `│   te-…png`，拼接规则见夹具注释：去掉 `│ `、首行 `> `、续行缩进）。
- 复原出来的文字 = `why` + **155** 字符的完整路径 = 158 字节，与草稿里插进去的路径逐字相同：

```
$ cat reason.joined                              # 断言读的那份拼接文本
why/var/tmp/v69-dev-bob-1792480240-11848/tmp/teamsmith-panel-b2-tree-6900b672.DTXRFa/clipboard/tmpdir/teamsmith-paste-c0e5e72a-8170-42c9-9847-bba1dfd0ebcf.png
$ sed 's/^why//' reason.joined | wc -c
155
```

- 空路径**不是**退化成 `grep -F ''` 的通真：旧 bundle 那次走的是 `bad "…（理由模式没有文件落地：路径为空）"`，
  如实记红（§三）。
- 没有拼接整屏：读取的起点是字面标题 `待命原因`、止于第一行不以 `│ ` 开头的行，中间只有这一框的行。
  它依赖两件事，记在 §十：标题是中文、输入面是 boxed（comfortable 密度）。两种前提不成立时结果是**红**，
  不是假绿。

## 七 · 作者报告里 `/tmp` → `/var/tmp` 的改写（按任务书要求只核对历史，不重跑代码）

`f21b3e97`（第一版）的现场是 `W=/tmp/p331-dev2-uKMrEq`，并带具体读数：`avail_mb 4930`、`free_inodes
3192312`、剪贴板 PNG `sha256 59edf555…529e15`。`950ac8af`（修订版）把它写成

> 两轮，都在 `$HOME` 之外、`/var/tmp` 下 …… 第一轮 `W=/var/tmp/p331-dev2-uKMrEq`（返修前记录，`/tmp` 下那次
> 同形实验已删）

但**读数一个没换**：还是 `avail_mb 4930`、`free_inodes 3192312`、`sha256 59edf555…529e15`。所以那一块是
`f21b3e97` 的 **`/tmp` 那次运行换了路径前缀**，不是新实验；「两轮都在 `/var/tmp` 下」这句在第一轮上不成立，
而括号里新出现的「`/tmp` 下那次同形实验」在两版报告里都没有任何记录，且树已删，无法核对。

这条改写对我的判定**只影响取证口径**：真环境证据只按第二轮（`W=/var/tmp/p331-dev2-r2-NTs6CT`、
`sha256 2b2b9bff…2bacfc`，是新增的独立读数）看，而第二轮**没有记录它跑的是哪个提交/bundle**，所以它仍只是
背景证据，不是本候选的判据；本候选的证据是 §二–§六，全部在受检 ref 上可复现。作者报告措辞失真这件事本身
由 PM 处置（任务书已列为在办），我不改他的文件。

## 八 · 缺口（登记给 PM，本次不新开用例）

1. **这条行为仍没有门禁承载者**：`panel-b2.sh` 的 `clipboard` 场景不在任何段里（P318 已实测），所以
   `tempRoot` 一旦退回去，门禁是绿的。P326 负责接线，本任务不接（任务书边界）。
2. **「失败的 payload 不外溢」在树里没有断言**：§四 那七轮是我在受检树外做的，树里没有任何一条会因
   `tempRootOf` 放宽（比如其它块也保留 payload、或失败时沿用上一轮的值）而变红的测试。要不要把它做成
   树内断言，需要一条测试面任务书；本次未擅自加。
3. **`--json` 从来不含 `degraded`/`errors`**（`buildJson` 只有 `panel`+`activity`）。所以「原 `degraded`/
   `errors` 不变」这句只能由帧渲染（§五 的 `--print` 逐行相同）与 `DataResult` 的字段（§四 探针）证明，
   不能指望外部 JSON 里看到它们。

## 九 · 验收命令与原始输出位置

原始输出（本席位自己的路径，全部保留供 PM 复验）：

```
/var/tmp/v69-dev-bob-1792480240-11848/logs/rebuild.log            重建 + cmp 对照
/var/tmp/v69-dev-bob-1792480240-11848/logs/b2-clipboard-fixed.log     修复候选 ✓26 ✗0
/var/tmp/v69-dev-bob-1792480240-11848/logs/b2-clipboard-oldbundle.log 旧 bundle ✓22 ✗4
/var/tmp/v69-dev-bob-1792480240-11848/logs/{old2,new2}-{json,print}.txt（及 .n 归一化副本）
/var/tmp/v69-dev-bob-1792480240-11848/logs/probe.txt、probe-old.txt
/var/tmp/v69-dev-bob-1792480240-11848/tmp/teamsmith-panel-b2-tree-*.{DTXRFa,JEmtgP}/clipboard/   两次运行的捕获
/var/tmp/v69-dev-bob-1792480240-11848/probe/                     七轮探针（probe.ts / probe-old.ts / stub.sh）
/var/tmp/v69-dev-bob-1792480240-11848/tree/                      受检克隆（HEAD=950ac8af，树干净）
```

本席位工作树上的命令（报告提交前跑）：

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
$ git diff --check && git status --short
```

## 十 · 边界

- 没有操作真实桌面剪贴板、没有复演作者的真环境实验（任务书边界）；§七 只读 git 历史。
- 没有重跑 26/27/28/38 整批，也没有接门禁；§五 用 `--print` 的逐行同一性替代「其它段会不会变红」。
- 夹具真跑覆盖 Wayland；X11 分支仍是夹具的假 `xclip`。
- 理由框读取的两个前提：标题字面量是中文 `待命原因`、输入面是 boxed（`density=comfortable`）；前提不成立时
  断言变红而不是假绿。
- 清理：本次只碰自己的三条具体路径（上面 `logs/`、`tmp/teamsmith-panel-b2-tree-*`、`probe/`、`tree/`），
  没有用项目级或 ns 级通配；复验完可按这三条路径自行删除。
