# P259 · 关键回复页去掉「自称」：默认信任发布者标签

task: P259
agent: dev
phase: propose
category: analysis
change: key-replies-trusted-labels
specs: key-replies
deltas: key-replies
branch: task/P259-trusted-labels-propose
deps: -

## 用户的裁定（原文，2026-10-14）

> 自称去掉，默认信任

指的是关键回复页与命令行里对发布者标签的处理：今天界面写「自称来自 pm」，正文上方还写「只读 · 发布者自称，未经核验」；`team reply --help` 的用法文本里也写「`--from` 是自称的平坦标识符」、`reply list` 的文本模式写「`<自称发布者>`」。用户要求**去掉「自称」，默认信任**。

## 现状（PM 已定位）

- 面板字符串：`scripts/panel/src/strings/zh.ts` 396–401 行 `replyDeclared: '自称来自 {from} · {at}'`、`replyDeclaredShort`、`replyBodyHint: '只读 · 发布者自称，未经核验'`（英文表同形 `declared by …` / `not verified`）。
- 命令行：`scripts/lib/cmd-reply.sh` 的用法文本（第 16、22 行附近）与 `reply list` 文本模式的列名。
- 规格：`openspec/specs/key-replies/spec.md` 的 requirement「Reply storage paths and declared identity are untrusted data」里写着 **`Publisher labels SHALL be displayed as declared, not verified`**，并配了场景「Declared label and hostile markdown remain data」——它断言「标签要**可见地**呈现为自称」。**这条要被改动**（这是我们自己的合同，改它就要走变更）。
- 夹具：`tests/key-replies.sh`、`tests/key-replies-pty.sh`、`tests/lib/reply-fixture.sh` 等有断言盯着上面那些字。

## 要解决的（写进 delta 的合同）

1. **显示**：面板与命令行都只显示发布者标签本身（例如「来自 pm · 时间」「发布者 pm」），不再出现「自称」「未经核验」「declared / not verified」这类限定语；正文上方那行的「只读」保留（它说的是这一页不能编辑，与身份无关——如果 implementation 认为「只读」也会引起误解，可在 design 里提出替代措辞，但要保住「这一页是查看不是编辑」这层意思）。
2. **规格**：把那条 requirement 改成与显示一致的说法（标签按原样显示、默认信任），**但保住它的安全部分**：存储路径与记录名仍按不可信数据处理（拒绝软链/非普通文件/路径穿越/外来根）、读取接口不接受任意路径、正文里的 Markdown 链接与图片、嵌入命令、终端控制序列仍然是惰性文本、显示时仍然消毒。**这些一条都不许弱化**，红侧也要继续在。
3. **记录**：存储里记录的仍是**发布者声明的标签原文**（数据层不变，仍是逐字记录）。design 里写清「显示信任」与「记录原样」这两层的关系，以及为什么这不矛盾。
4. **一处如实说明**（写进 design 的 Non-Goals 或 Risks）：标签是调用方自己声明的，工具不认证；因此界面上一个标签**不构成**「这句话确实是某个席位说的」的证明。这条不体现在界面上（按用户裁定），但要留在文档里。
5. **红侧**：① 面板渲染里再出现「自称/未经核验/not verified」→ 红；② 命令行文本模式再出现「自称」→ 红；③ 恶意正文（shell 语法、本地链接、远程图片、终端控制序列）仍必须惰性渲染且不触发任何动作 → 红侧照旧；④ 软链/FIFO/穿越仍然被拒 → 红侧照旧。

## 边界

- 只写提案；apply 与 verify 另行换人。
- 范围：`scripts/panel/src/strings/{zh,en}.ts` 里那三四个键、`scripts/lib/cmd-reply.sh` 的用法与列表文本、`openspec/specs/key-replies/spec.md` 的那一条 requirement 与它的场景、以及盯着这些字的夹具。**不要**改存储格式、`--from` 的校验规则（仍是 1–48 个 `[A-Za-z0-9._-]` 的平坦标识）、编号与并发语义、面板其他页。
- 与 P234 的既有断言：**安全那半必须留**（见上），不许用「用户要信任」当理由删消毒与拒绝面。
- 不合并、不推送；做完 `team notify pm`。
- **排期**：todo（席位空出来再派）。落地并合并后，需要**重启 Pulse 面板**才会看到新文案（这条写进交付说明）。

## 验收（本阶段）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/P259-dev.md
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
