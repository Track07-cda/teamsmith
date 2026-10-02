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
# API（两边共用同一份判据，避免「选择器放行、门禁照旧红」或反过来）：
#   checkout_shape <root>                → product-only | internal
#   checkout_surface_path <rel>          → 0 = <rel> 落在六个内部面之一或其下（只看路径）
#   checkout_prereq_missing <shape> <rel>→ 0 = 形状是产品面，且 <rel> 的前提按构造缺失（smoke 口径）
#   checkout_literal_skippable <shape> <rel>
#                                        → 0 = 选段器 --check 的**字面存在性**检查可按前提缺失跳过
#                                          （精确白名单，不是前缀豁免；见下）
#   checkout_entry_exists <path> / checkout_entry_absent <path>
#
# 口径来源（design 决议 2/3）：产品面检出的形状 = `skills/` 与 `openspec/specs/` 都在位，并且六个内部面
# **全部**不在了。混入一个内部面（哪怕只是个空目录）就不再是产品面检出 —— 门禁不许因此少跑。

# 六个内部开发面（相对仓库根）
CHECKOUT_INTERNAL_SURFACES=(docs/team openspec/changes AGENTS.md SCOPE.md .pi/prompts .pi/skills)

# 选段器 --check 只放这几个**精确**路径。设计决议 3 的原文口径：这是「存在性例外」，不是「前缀豁免」；
# 没见过的拼写（例如 openspec/changes/typo-planning-file.md）与任意 .pi/ 下的新路径照旧红。
# 每加一条都要能点名它的行：`AGENTS.md`/`SCOPE.md` 是 18 与 12k 的，`.pi/skills` 与
# `openspec/changes/archive` 是 19 与 20 的，`openspec/changes` 是 18c 的（P150 的走查在内部面里读
# 未归档 change 的 delta；产品面检出里它按构造不存在 —— 精确相等，不豁免它下面的任何拼写）。
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

# ── 两个消费者各自的口径 ─────────────────────────────────────────────────────────────────
# smoke：只有「产品面检出 + 这条检查的前提是内部面」才允许跳过（每条跳过仍要经过 smoke 的跳过出口）。
checkout_prereq_missing() { # <shape> <rel>
  [ "$1" = "product-only" ] || return 1
  checkout_surface_path "$2"
}

# 选段器 --check 的字面存在性：精确白名单（形状 + 逐字相等）。
checkout_literal_skippable() { # <shape> <rel>
  local l
  [ "$1" = "product-only" ] || return 1
  for l in "${CHECKOUT_SELECTOR_LITERALS[@]}"; do
    [ "$2" = "$l" ] && return 0
  done
  return 1
}
