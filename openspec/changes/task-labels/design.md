# Design

## Context

- `scripts/lib/common.sh` uses the header for column positions, but `team_board_add` gets its column count from a header starting with `ID` and finds its insertion point by the resolved ID column. Use no label column: labeling does not participate in board writes or disturb the existing optional rightmost update-time column, including on customized boards. The existing `team_board_duplicate_ids` already identifies the contiguous task table rather than the risk table. `team_board_row` answers with just the first row of an ID; it cannot enumerate the choices or drive either view.
- `scripts/lib/cmd-watch.sh:team_panel_board_json` emits the original board rows in file order and supplements `phase` from briefs, including a placeholder when there is none. `data.ts` caches the board block for 15 seconds and `App.tsx` already refreshes it with `r`. The existing board uses raw row identity and a recent-first lane order for display and navigation. Add filtering and explicit priority to that same display path, rather than sorting only the rendered cards or replacing the existing order.
- Code paths below are relative to `skills/teamsmith/` unless qualified from the repository root.

## Goals / Non-Goals

One owner for label writes, one reader for label interpretation and scoring, and one derived row order for the interactive board. Do not change the old readers/writers to rely on labels. Do not create a second event source or change what the patrol calls pending. Task books, Git issues and settings are not alternate storage locations.

## Decisions

### 1. File, name and writer

Use `$TEAM_DOCS_ABS/task-labels.tsv`, with the same resolved ledger as `BOARD.md` (not the invoking worktree's relative `docs/team`). The UTF-8 file is persistent ledger data, not panel preferences or transient runtime state. It contains only two record shapes, tab separated, LF terminated: `label<TAB>name<TAB>#rrggbb<TAB>weight` and `task<TAB>ID<TAB>name`. IDs are literal board values; use the task-table header and contiguous body bounds for membership, using the existing column resolver's recognized header names. Skip placeholder/header/separator rows and never search another table by bare ID. Check parsing errors as errors (wrong shape, invalid name/color/number, duplicate definitions, orphan **label name**). An absent **board ID** in a saved association is valid historical data. Treat repeated associations as one even if present on disk. Emit no generated score records, timestamps, or bundled label definitions. Encode user names as data, never evaluated arguments to a shell or format string.

```
team board label define <name> --color <#RRGGBB> [--weight <n>]
team board label ls
team board label edit <name> [--name <new>] [--color <#RRGGBB>] [--weight <n>]
team board label delete <name>
team board label add|remove <ID> <name>...
team board ls [--label <name>] [--sort priority]
```

Keep the existing `ls` case as-is for zero args (including the bare `board` default). For explicit options, reject duplicates, unknown switches and missing operands before doing work. Option values are literal argv entries; support `--` before positional label arguments in the label command group, e.g. `define --color '#0969da' -- '-Follow-up'`. Match names exactly; no mandatory slugs, internal IDs, case conversion or automatic renaming. Require a nonblank name with no surrounding whitespace, tabs or line breaks, and require the existing panel `sanitize` function to leave it byte-for-byte unchanged. Share that pure string primitive with the label reader and writer rather than copying its rules or altering `sanitizeDeep`; reject, never normalize, a disallowed name. For example `Bug` remains unchanged, while `B\u200Bug` with U+200B between `B` and `u` is refused. The full accepted name is the chooser value, not the clipped text of its chip. Transport the catalog and selected names as strings in arrays or fixed fields, not object keys made from project data. `All` in the chooser is a distinct choice, not a reserved user label name. An edit needs at least one field, an attach/detach at least one name. Normalize color hex case and decimal weight when writing. Status 2 for syntax errors; 1 for refused changes/failed reads/writes; 0 for success, no-op or a known filter with no matches. Output `label ls` as name/color/weight; explicit task listing has one row per matching board row with ID/state/score/names/title and retains the duplicate warning. No `--json` public format or writable `/team` variant; add usage to the existing `board` manifest and bilingual help rows. The slash whitelist's existing no-option forms stay as they are.

The label command group is the only writer. Serialize read/validate/modify/replace with an exclusive `flock` on the opened canonical ledger directory, so no new persistent lock file appears on first use and repeated writers do not lock the inode being replaced. Use existing project/ledger identity, accept normal aliases to that directory and 664/775 permissions; an existing label symlink can be followed to a regular file within the canonical ledger, replacing the target rather than the link. Reject a wrong target (a link outside the ledger, directory/FIFO, broken link), not the presence of group-write bits. Preserve file permissions on replacement; new file follows normal project umask. A missing file is identified by absence, not by a generic failed read. No lock or temporary file for readers. While locked, re-read the current source and validate the whole batch, write an exclusive same-directory temporary file, sync it, rename atomically and sync the containing directory before acknowledging success. Follow the existing descriptor-lock and write/sync/rename/sync sequence in `scripts/remind-capability.mjs`, not its reminder-specific authority checks. Failure before rename leaves the old source in place and cleans that operation's unreplaced temporary file on normal error exits. An interruption cannot expose a partially written catalog; never treat a leftover temporary file as input. A sync error after rename is explicitly an uncertain durable result: report it with the path and tell the caller to re-read before retrying, without attempting a reverse write that could discard a later edit. This is crash/concurrent-write handling, not a permission-bit policy. No index or additional audit file: a user can review the one Git diff; the command does not commit it.

### 2. Compute once; consume in three places without sharing presentation

Use one read-only catalog/score helper at the shell CLI boundary, called by both explicit `board ls` and the existing `board` block. Use the repository's existing JS runtime and `team_js_runner`, not a new package/tool. The helper parses the file once, indexes definitions by name and associations by exact ID internally, and computes each distinct ID's sum once with `BigInt`. Export scores as decimal text. CLI sorts task rows across all states; the panel only compares the same scores within a lane. A future patrol consumer can ask this helper for scores for IDs it already selected by its own rules; no patrol call or contract in this change.

On the existing `__panel-data --block board` path, add an opt-in argument only for the TUI and its snapshot mode. The board parser that emits the original rows must classify each row **at emission** using the header and contiguous task-table bounds. The opt-in result carries that row fact by position, not by ID; a same-ID row in a later table remains a distinct original row and is ineligible, even when its state is valid. Keep raw order, `rows`, `counts`, `total`, `deliveries` and the existing internal per-row update time; no label opt-in or new fields reach `MACHINE_BLOCKS` callers, including `--print --page 4`. Join scores only after identifying eligible rows and while the original ID is still intact. Send their computed names/score aligned to their original row (or an array-position reference to the shared score); send no score or names for an outside row. Explicit CLI listings operate on task-table rows only. Pulse without a label filter leaves the outside row visible as before; if priority is selected it is unranked, after ranked rows in its lane and in file order among other unranked rows. No label filter can match it.

Use the same detail-opening path for the board and work pages. Alongside the unchanged `entry` file lookup, capture the original row reference (ID plus occurrence among **all** original rows of that ID) and whether the row belonged to the task table **when opened**. Keep that opening-time fact fixed until the detail closes: an outside source never gets a task-label area in that detail, even if a newly inserted same-ID task later occupies its old occurrence. For an inside source, show live metadata only if the original reference still resolves to a task-table row in the current board cache; if it does not resolve or now points outside, show no label area. Neither condition replaces the other. An eligible row gets its own metadata even if the file request returns an empty list. These are in-memory detail inputs only; no persistent row number or change to focus or storage. Keep both legitimate duplicate rows separately focusable with the same metadata, and keep the existing file lookup by ID, including for an outside row. Make the color value participate in line signatures and renderer tones (`rowKey` and the Ink/ANSI display); a color-only edit must repaint the open detail. Dynamic RGB goes on swatches only, with text visible without color.

A confirmed missing label entry takes the empty path without starting the label helper; a readable valid file with zero definitions is also a normal empty catalog. Do not infer absence from a failed lookup or broken link. For a present entry check its resolved target is a regular file before reading; a wrong target, read/parse error, or runtime startup failure is an explicit label error. On the opted-in board request, complete the original board read and return successful JSON for those rows/counts/deliveries, adding only `labels unavailable` status for the label result and no previous scores. Reserve nonzero exit for failure of the board itself. The panel replaces its previous label payload on that refresh using the same cache; once repaired, the next board refresh exposes the current data. Keep this in the one existing board request and label helper, without a diagnostic child, new polling block or label-specific timeout. Plain CLI, patrol and machine modes still do not ask for labels.

### 3. Make the displayed card order the order the controls use

Keep raw row occurrence (ID and nth occurrence in file order) independent of the view. Build one lane projection with references to those rows and give it to layout, key moves, click targets, offset calculation and Enter. Never recompute occurrence from an already filtered lane, or derive Enter's row from its screen index. Keep the existing row identity, window and focus behavior, including each key in a batch continuing from the previous key's selection and Enter opening the last selection. When changing views, keep the retained card visible where needed; unchanged-view wheel and fold rules still apply. An empty filtered lane follows the usual empty-lane behavior. Default order uses the existing recent-first lanes, including each lane's undated fallback and the initial history window at the top of that order. Explicit priority starts at the high end, with original file order for ties regardless of update time. Apply a filter by retaining matching rows in the selected order. Clearing it restores all rows without changing the selected order. If the catalog becomes unavailable or empty, fall back to recent-first order and all tasks; if a selected name alone disappeared, clear just that filter. A folded lane may still open its selected matching card as before; a filtered-out card may never open.

The view choices are in-session only, persistent across page changes but not restart. Put two compact chips at the top of the board body, not in a settings menu or in each card. `t` opens the label choice, `o` opens the order choice; clicking either chip opens the same list. Reuse the existing choice-list presentation and cursor/scroll handling, not the settings writer. Up/down or wheel navigates that list; Enter or click on a choice accepts, Esc cancels. While the choice is open arrows, wheel, clicks, Enter and Esc are handled by the list and cannot navigate or act on the board behind it. Only unmodified `t` and `o` on the board page with no modal open launch a picker; `Ctrl+o` remains the editor relay in compose. Keep enough room for both control labels at 59 columns by shortening only the **displayed value** of a long label to fit; never match by the shortened text. Let the width-tier's existing bounded window account for that one belt of controls. In detail, render priority and wrap the names in the existing scrollable area ahead of the file body (keeping the tabs and empty/error notice); no new action or fields on file previews for specs, changes or decisions.

### 4. Use words users can select, not a help paragraph

| Use | 中文 | English |
|---|---|---|
| Filter chip/list | 标签 | Labels |
| Filter off | 全部任务 | All tasks |
| Order chip/list | 排序 | Sort |
| Default order | 最近更新 | Recent updates |
| Priority order/detail number | 优先级 | Priority |
| Unlabeled task on a board using labels | 无标签 | No labels |
| Filter has no results | 无匹配任务 | No matching tasks |
| Read error | 标签不可用 | Labels unavailable |

Normal width — selection chips above the existing lanes; headers show match counts:

```text
看板
[t 标签：● Bug ▾]   [o 排序：优先级 ▾]
待办 2                    进行中 0         …
› · T2 修复离线草稿恢复
  · T9 修正通知数量
```

59 columns — same two choices, one column of state groups, no extra card field:

```text
看板
[t 标签：● Bug ▾] [o 排序：优先级 ▾]
待办 2
› · T2 修复离线草稿恢复
  · T9 修正通知数量
… 进行中 0
```

Enter on T2 (no files in this example):

```text
详情 T2
优先级 8
标签 ● Bug  ● Urgent
没有关联文件
```

Complete path: PM defines `Bug` at 3, `Urgent` at 5 and `Docs` at zero and attaches Bug and Urgent to T2 in one `team board label add T2 Bug Urgent`. In Pulse `r` updates the cached board. Start with all tasks in recent-first order, focus T2, press `o` and choose priority: in the example T2 moves in front of T9 but focus remains on the same row. Press `t`, choose Bug: both remain and T2 still has focus. Enter opens the detail above, Esc returns to T2. If PM changes Bug to 6, the next detail shows 11, no reattachment. Change the filter to Docs (only T5): it focuses T5 in the same lane; if the only result were in another lane it would move there. Choose all tasks and recent updates to restore the previous presentation, including the default history windows, without editing board data. None of these labels are product defaults.

## Risks / Trade-offs

- **Old layout assumptions.** Use the task-table bounds for label membership, not raw `board ls` pipe lines or first-row lookup. Do not rewrite the legacy scan to improve unsupported `编号` layouts or move an ID column for `board add`; read existing supported column names in any supported order and test old writes only on their known layouts.
- **History or duplicate identity can be lost in a display-only sort.** Store neither rank nor occurrence in the file. Key original rows before deriving the lane windows, and test movement with separate titles for identical IDs. Clear a filter after rename rather than adding new stable IDs solely for a temporary choice.
- **Catalog damage is not a board outage.** Treat explicitly unavailable labels differently from an actually empty catalog. Do not remove labels silently when a board row is hand-edited, and do not cascade delete a definition across tasks.
- **Changes to handoffs outside the two capabilities are not needed.** The help requirement already covers adding valid usages to the owning manifest (the preservation clause scopes the earlier help rewrite). The slash whitelist stays exact. Fold behavior operates on presented cards and retains its existing control and persistence rules; detail file discovery and its missing-source reporting remain untouched. The modified kanban requirement carries the current recent-first scenarios forward without replacing them with pre-update examples. Existing performance thresholds and patrol provisions are unchanged; no new performance verdict.

## Migration Plan

No migration, backfill, template file, or automatic startup work. Use the unchanged board immediately after upgrade; first define opts in. Downgrading uses the original board and ignores `task-labels.tsv`; keep the file to recover labels when re-upgrading. Do not script deleting the file on downgrade, display fallback, or an I/O error.
