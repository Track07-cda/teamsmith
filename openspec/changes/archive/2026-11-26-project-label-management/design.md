## Context

P506 (`d411b13a`) and D271 settle the placement and scope. The current panel already has `nav` rows, a settings back stack, text and choice editors, and a project-local command runner (`scripts/panel/src/{layout.ts,App.tsx,main.tsx}` under `skills/teamsmith/`). The frozen label candidate `4cbc5bc7` is interface evidence only: its `board label ls` lists name, RGB and weight, whereas its panel board payload omits definition weights. The candidate is not the implementation base until the original label change passes independent acceptance with the recent-first board and is merged.

## Goals / Non-Goals

Reuse the settings interaction, board reader and single label owner without tying definitions to task rows or the configuration schema. Do not add a second label writer, a full settings table, a new top-level page, a new refresh loop or concurrency protocol.

## Decisions

### A destination, not another settings schema

Append a third `nav` entry to the existing Project settings list, after Project commands and Model records. Reuse the settings list window, focus and back-stack state; opening the destination reads the catalog on demand. Default settings filter can find the entry, not its contents. The three-category example adds one focusable row, from 10 to 11; the original configuration-editing count does not change. The verification spec's existing two-secondary-destination coverage is for Project commands and Model records from the selected-settings batch; both remain covered, not retired by this addition.

```text
项目设置 / Project settings
  …现有模型与自动检查…
  项目命令 / Project commands
  模型记录 / Model records
  任务标签 / Task labels       ›

任务标签 / Task labels         编辑标签 / Edit label
  新增标签 / Add label          名称 / Name      用户反馈
  用户反馈   ● 蓝色   3          颜色 / Color    ● 蓝色 / Blue
  文档       ● 自定义颜色  0      权重 / Weight   3
                               保存 / Save    取消 / Cancel
                               删除标签 / Delete label
```

Use the existing text editor for name and weight, and the choice list for common colors with named swatches, e.g. 蓝色 / Blue, 绿色 / Green, 红色 / Red. A custom current color displays 自定义颜色 / Custom color with 保留当前颜色 / Keep current color. Choosing a color changes only the form draft; no field saves until Save. No palette code entry, explanatory weight paragraph or configuration metadata. Open deletion confirmation separately with the exact name and Delete/Cancel buttons. Apply the existing wheel, first-click focus, second-click activation and keyboard handling to the active list or picker; let narrow rows wrap or use the existing list window rather than hide actions. Return via the same stack to the originating row/filter/offset and then to the settings overlay. Use the existing zh/en tables; no persisted UI state.

### One project, one definition owner

Read `team board label ls` when opening and on explicit returns from writes/cancel. Use the accepted command's full name, color and decimal-weight columns and the result status; a nonzero or malformed read is not a valid empty result. Do not use optional label fields on the board frame or read or write the catalog file from the UI. Follow the project's own label command's association and validation behavior (`Project labels are managed by name beside the board`), not the configuration command's fingerprint/validation path.

Use the existing runner and identity cleanup, `cwd` from the resolved project root and argv such as `[teamCli, '--root', root, 'board', 'label', 'edit', '--json', '--weight', '-9007199254740993', '--', '-用户 反馈']`. Put options before `--` and pass the untouched original name as one argument; new name, when changed, is one `--name` value. Do not interpolate a shell command or scan for `--json` inside an option value or after `--`. Decode bytes as complete UTF-8 (a decoder stream or one decode at completion, not per chunk). Keep weights as text end to end; comparing edits with an original form value must not run through `Number`. Define submits the new fields, edit submits only changed fields, no-change and Cancel submit no write. Delete calls only `delete`. The original command still resolves names literally with no normalization, rewrites associations on rename and refuses an attached label. No writes to BOARD, config, its audit, preferences or task times.

### Separate the draft, the published catalog and the result

Extend only the three definition writes with the opt-in result in the board-and-status delta. Emit it where the original command knows the reason and whether it published, not in a second command, a panel copy of validation, or an English-stderr parser. Confirm success only when the exit status and complete structured result agree. Duplicate, invalid field and in-use use localized prompts, e.g. 此名称已存在 / This name already exists; 请输入整数 / Enter a whole number; 标签仍在使用，无法删除 / This label is in use and can’t be deleted. Show returned task IDs without detaching them. Classify an unrecognized reply, a timeout or an interrupted command after launch as unconfirmed, not as a known rollback. A readback after timeout shows only currently visible data, not proof that the original operation settled or its data was persisted.

Keep only one pending save/delete for the form; block duplicate submission while it settles. Cancel discards edit input, writes nothing and reads current definitions. Refusal keeps the attempted values and reads current definitions separately; the user can correct and explicitly save again. When a previous outcome is unclear, show 保存结果未确认 / Save not confirmed (or the deletion equivalent) and current readback separately. No automatic retries, including when the read happens to show the requested value. If a fresh read fails, show 无法读取任务标签 / Couldn’t read task labels and do not write against the unverified list. A confirmed write followed by a failed refresh is a refresh error, not a claim that the write was rejected or that the stale list is now current.

### Read after writing without a new timer

On a confirmed definition write, start a fresh catalog read and refresh only the existing interactive `board` block. In current `data.ts`, `refresh({force:true})` can join a read already in flight. Wait out the `board` request in flight at the success boundary without adopting it as the write's readback, then request a forced board refresh; a normal refresh that starts after the write can satisfy it. Keep the next board view/explicit priority selection pending or mark it unavailable until a current board result is adopted, not the earlier sample. Use the existing cache/settle route rather than polling or reading all blocks twice. The same board path supplies labels and scores; a definition read is not a score calculation. Refresh also reconciles a changed filter choice using the accepted label behavior. Default recent-first remains independent of explicit per-lane priority; ties in priority use original row order, not recent-first position. No change to CLI defaults or machine exits.

## Risks / Trade-offs

- **Concurrent edits.** The original command rereads under the ledger lock. Sending only changed fields preserves unrelated peer edits; concurrent writes to the same field of the same still-named definition use the last successful value. A peer rename/delete can make the exact name unavailable; recreating that name does not create a detectable identity for the old form. This page adds neither revision comparison nor a stable label ID. Use fresh readback and explicit correction instead of promising conflict detection.
- **Frozen code versus accepted code.** On this base `openspec/specs/board-and-status/spec.md` lacks `Project labels are managed by name beside the board`. Its authoritative pending text is in `openspec/changes/task-labels/specs/board-and-status/spec.md`. The ADDED outcome requirement is a separate optional response, not a second definition requirement or a partial MODIFIED over a missing target. Before Apply, compare the accepted/merged command and that requirement (in the active original delta or its archived base) plus its panel read-only views to this proposal. Keep the original requirements and scenarios intact. If the accepted implementation already defines an outcome interface, align this delta with it and return any observable change to independent proposal review instead of adding two formats or silently changing the old spec. Before archive, confirm the original requirement is in the formal base and the supplemental delta applies cleanly.

## Migration Plan

One apply brief after both the accepted proposal and the independent original-label acceptance/merge. No config/data migration, preset records or new file format. A rollback can remove the new UI and opt-in result without altering definitions or associations created via the original commands. Leave the existing label and recent-first behavior in place.
