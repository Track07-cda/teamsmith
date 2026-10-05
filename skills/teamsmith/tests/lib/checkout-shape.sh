#!/usr/bin/env bash
# checkout-shape.sh — 检出形状判据（change: product-checkout-gate · verification#A gate that cannot judge says so）
#
# 纯文件、零副作用、零外部命令（只用内建与 case）：只看**被检出的那棵树**里有没有六个内部开发面。
# 不读 TEAM_ROOT / TEAM_MAIN_ROOT / git（更不读 git common/main worktree）/ CI 提供商变量 /
# 夹具自己的 $REPO —— 那些都由调用方按「脚本所在树」解析后传进来（smoke 用 $SKILL_DIR/../..，
# 选段器用它已有的 $ROOT，含显式 --root）。
#
# 为什么是这六个：publish-public.sh 的白名单（skills / bin / install.sh / openspec/specs / README.md /
# LICENSE / package.json / .gitignore / ci）按构造不含 docs/team、openspec/changes、AGENTS.md、
# SCOPE.md、.pi/prompts、.pi/skills。它们是**这个开发仓库**的内部面，不是产品的一部分。
#
# 「缺失」= 没有任何文件系统条目（`! -e && ! -L`）。空目录、坏软链、不可读文件、类型不对（文件当目录）
# 一律算**存在**：保守方向是「当成内部/半内部树，照旧跑、照旧判红」，绝不能拿来换一次跳过。
#
# 三类面（P222 把「机器生成面」从内部面里单列出来）：
#   * 产品面：`skills/` 与 `openspec/specs/` 都在位；
#   * 内部开发面：六个 —— 任何一个在位就不是产品面检出（门禁不许因此少跑一条产品断言）；
#   * **机器生成面**（六个里的两个：`.pi/prompts`、`.pi/skills`）：由 `openspec init --tools pi` 之类的
#     工具在**本机**生成、被 `.gitignore` 忽略（`.gitignore` 的 `.pi/` 与 `.pi/skills/`）。任何 checkout
#     （公开仓 CI、干净 clone、导出的产品树）都按构造可能没有它们 —— **整棵面不在**时，落在面里的检查
#     以可见 SKIP 点名跳过（不是判红）；面在位（哪怕是空目录）而面里的文件缺失时**照旧判定**：一个人
#     真装了生成器却少了文件，那是真问题，不许被这条跳过吞掉（P222 的牙齿）。
#
# 「缺席的证据层」（P222）：两份历史豁免清单（`tmux-lint-legacy.txt` / `signal-lint-legacy.txt`）按
# sha256 冻结的是 `docs/team/reports/*/pkg/**` —— 证据包刻意不进仓库（`.gitignore`）。清单里**每一条
# 都落在内部面、且都确实不在**这棵检出里时，这一册账在检出里无法裁决，两个消费者改用空清单跑并各记
# 一次可见 SKIP；只要有一条在位（或落在产品面），就照旧逐条核对（`checkout_registered_paths_absent`）。
#
# API（两边共用同一份判据，避免「选择器放行、门禁照旧红」或反过来）：
#   checkout_shape <root>                          → product-only | internal
#   checkout_surface_path <rel>                    → 0 = <rel> 落在六个内部面之一或其下（只看路径）
#   checkout_generated_surface_absent <root> <rel> → 0 = <rel> 落在机器生成面里，且那个面**整棵**不在
#   checkout_prereq_missing <root> <shape> <rel>   → 0 = 这条前提按构造可以缺失（smoke 口径：允许跳过）
#   checkout_literal_skippable <root> <shape> <rel>
#                                                  → 0 = 选段器 --check 的**字面存在性**检查可按前提缺失跳过
#                                                    （精确白名单，不是前缀豁免；见下）
#   checkout_registered_paths_absent <root> <list> → 0 = 清单里每一条路径都不在这棵检出里
#   checkout_entry_exists <path> / checkout_entry_absent <path>
#
# 口径来源（design 决议 2/3）：产品面检出的形状 = `skills/` 与 `openspec/specs/` 都在位，并且六个内部面
# **全部**不在了。混入一个内部面（哪怕只是个空目录）就不再是产品面检出 —— 门禁不许因此少跑。

# 六个内部开发面（相对仓库根）
CHECKOUT_INTERNAL_SURFACES=(docs/team openspec/changes AGENTS.md SCOPE.md .pi/prompts .pi/skills)

# 机器生成面：内部面的子集，由工具在本机生成、永不进 git（见文件头）。判定单位是**整棵面**。
CHECKOUT_GENERATED_SURFACES=(.pi/prompts .pi/skills)

# 选段器 --check 只放这几个**精确**路径。设计决议 3 的原文口径：这是「存在性例外」，不是「前缀豁免」；
# 没见过的拼写（例如 openspec/changes/typo-planning-file.md）与任意 .pi/ 下的新路径照旧红。
# 每加一条都要能点名它的行：`AGENTS.md`/`SCOPE.md` 是 18 与 12k 的，`.pi/skills` 与
# `openspec/changes/archive` 是 19 与 20 的，`openspec/changes` 是 18c 的（P150 的走查在内部面里读
# 未归档 change 的 delta；产品面检出里它按构造不存在 —— 精确相等，不豁免它下面的任何拼写）。
# `.pi/skills` 同时是机器生成面之一：面**整棵**不在时那条规则先命中（面里的任意路径都算），这里的
# 条目管的是「这个字面本身」—— 两条各管一层，都写是故意的，不是重复。
CHECKOUT_SELECTOR_LITERALS=(AGENTS.md SCOPE.md .pi/skills openspec/changes/archive openspec/changes)

# ── 条目存在性（空目录 / 坏软链 / 类型不对都算**有**）────────────────────────────────────────
checkout_entry_exists() { [ -e "$1" ] || [ -L "$1" ]; }
checkout_entry_absent() { [ ! -e "$1" ] && [ ! -L "$1" ]; }

# ── 形状 ────────────────────────────────────────────────────────────────────────────────
checkout_shape() { # <root> → product-only | internal
  local root="$1" s
  # 产品面必须在位：skills/ 与 openspec/specs/ 都得是目录（符号链接指向目录也算在位）
  [ -d "$root/skills" ] && [ -d "$root/openspec/specs" ] || { printf 'internal'; return 0; }
  for s in "${CHECKOUT_INTERNAL_SURFACES[@]}"; do
    checkout_entry_exists "$root/$s" && { printf 'internal'; return 0; }
  done
  printf 'product-only'
}

# ── 路径归属（只看路径本身，不看形状）────────────────────────────────────────────────────
checkout_surface_path() { # <rel> → 0 = 内部面之一或其下
  local s
  for s in "${CHECKOUT_INTERNAL_SURFACES[@]}"; do
    case "$1" in "$s"|"$s"/*) return 0 ;; esac
  done
  return 1
}

# ── 机器生成面：<rel> 落在面里、且**整棵面**不在这棵检出里 → 0 ───────────────────────────────
# 只看面的顶层（`.pi/prompts` / `.pi/skills`）：面在（哪怕空目录）就不成立 —— 面里的文件缺失照旧判定。
checkout_generated_surface_absent() { # <root> <rel>
  local s
  for s in "${CHECKOUT_GENERATED_SURFACES[@]}"; do
    case "$2" in
      "$s"|"$s"/*) checkout_entry_absent "$1/$s" && return 0 || return 1 ;;
    esac
  done
  return 1
}

# ── 两个消费者各自的口径 ─────────────────────────────────────────────────────────────────
# smoke：机器生成面整棵不在（任何形状都可能如此）→ 可跳过；此外只有「产品面检出 + 这条检查的前提是
# 内部面」才允许跳过（每条跳过仍要经过 smoke 的跳过出口）。面在位而文件缺失 → 不可跳过（照旧判定）。
checkout_prereq_missing() { # <root> <shape> <rel>
  checkout_generated_surface_absent "$1" "$3" && return 0
  [ "$2" = "product-only" ] || return 1
  checkout_surface_path "$3"
}

# 选段器 --check 的字面存在性：机器生成面（整棵不在）或产品面检出里的精确白名单（形状 + 逐字相等）。
checkout_literal_skippable() { # <root> <shape> <rel>
  checkout_generated_surface_absent "$1" "$3" && return 0
  local l
  [ "$2" = "product-only" ] || return 1
  for l in "${CHECKOUT_SELECTOR_LITERALS[@]}"; do
    [ "$3" = "$l" ] && return 0
  done
  return 1
}

# ── 豁免清单：这一册账在检出里能不能裁决 ─────────────────────────────────────────────────
# 清单格式：`<sha256>  <条数>  <仓库相对路径>  # 理由`（见 tmux-lint-legacy.txt / signal-lint-legacy.txt）。
# 0 = 清单里每一条路径都不在这棵检出里（证据层刻意不进仓库 → 空清单跑 + 一次可见 SKIP）；
# 1 = 至少一条在位、或清单读不了 —— 那就照旧逐条核对（缺一行、改一个字节都照旧判红）。
checkout_registered_paths_absent() { # <root> <list-file>
  local root="$1" list="$2" line sha cnt path rest
  [ -f "$list" ] || return 1
  while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    read -r sha cnt path rest <<<"$line"
    [ -n "${path:-}" ] || continue
    checkout_entry_absent "$root/$path" || return 1
  done < "$list"
  return 0
}
