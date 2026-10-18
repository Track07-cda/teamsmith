#!/usr/bin/env bash
# P255 · 升级配方（references/migration.md §6）的每一步可证伪。
#
# 为什么有这一套：用户 2026-10-14 拿一个 0.1.2 的项目照文档升级，第一步就撞在身份拒绝上 —— §6 当时
# 还写着「git pull 一个 checkout」，而 0.2.0 起技能来源是 npm 包；配置迁移、PM 启动身份、席位续跑、
# 回滚这些步骤文档里也没有。文档承诺的东西必须有人守：本夹具把 §6 的每一步落成一条可跑、可证伪的断言。
#
# 三件事：
#   ① 文档面：§6 必须仍然承诺每条步骤（DOC_LITERALS），并且不许出现把 `--no-migrate` 与推导命令
#      无条件连起来的旧句子（DOC_FORBIDDEN）；删掉任一步或让它回潮 → 这里红。
#   ② 工具面：每条承诺都要能在真 CLI 上兑现（promise：文档承诺的串 → 工具真的打印它）；
#      反向对照（promise_red）证明这个探针能红，不是恒真。
#   ③ 现场：在一个 0.1.x 形状的临时项目里走完整条配方 —— 工具升级（夹具桩）→ 备份 → 迁移前被拒 →
#      `team up` 自动迁移（私有 tmux + 假 PM，绝不碰共享 server）→ 迁移后 `config list` rc=0 →
#      身份（缺记录自动登记 / 记录不符两条出路 / --fresh-pm 的 fresh 判定）→ 收尾验证 → 回滚。
#
# 分组：--select doc,walk,identity,rollback,selftest（默认全跑）。
# 退出码：0 = 全绿；1 = 有失败；2 = 用法错误；3 = 建不出临时根。
set -uo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib/tmp-root.sh
source "$here/lib/tmp-root.sh"
# shellcheck source=tests/lib/tmux-iso.sh
source "$here/lib/tmux-iso.sh"

TREE="${TEAM_RECIPE_TREE:-$(cd "$here/../../.." && pwd)}"
SKILL="$TREE/skills/teamsmith"
CLI="$SKILL/scripts/team"
DOC="$SKILL/references/migration.md"

SELECT='doc,walk,identity,rollback,selftest'
while [ $# -gt 0 ]; do
  case "$1" in
    --select) SELECT="${2:?}"; shift 2 ;;
    *) printf 'unknown option: %s\n' "$1"; exit 2 ;;
  esac
done
for g in ${SELECT//,/ }; do
  case "$g" in doc|walk|identity|rollback|selftest) ;; *) printf 'unknown group: %s\n' "$g"; exit 2 ;; esac
done
has() { case ",$SELECT," in *",$1,"*) return 0 ;; esac; return 1; }
# identity / rollback 的现场是 walk 的产物（迁移后的配置 + 启动记录）：选它们就把 walk 一并拉进来。
if has identity || has rollback; then
  case ",$SELECT," in *",walk,"*) ;; *) SELECT="$SELECT,walk" ;; esac
fi

# 绝不继承父进程的 TEAM_*（门禁是嵌套跑的）；身份一律按 cwd 推导。
while IFS='=' read -r k _; do case "$k" in TEAM_*) unset "$k" 2>/dev/null || true ;; esac; done < <(env)
# M36 闸门在 PATH 里的那一格也属于「调用者身份」（smoke.sh 文件头同一条纪律，原因见那里）：
# 从 PM/worker 会话派生的夹具里 `command -v tmux` 会解析到 scripts/shim/tmux 而不是真 tmux ——
# 本夹具要拿真身来建私有 server（P255 实测：没剥掉时 tmux_iso_probe 里的 `tmux ls` 卡死不动）。
_rcp=""; _rcifs="$IFS"; IFS=:
for _rcd in $PATH; do case "$_rcd" in */scripts/shim) ;; *) _rcp="${_rcp:+$_rcp:}$_rcd" ;; esac; done
IFS="$_rcifs"; [ -n "$_rcp" ] && PATH="$_rcp"; export PATH; unset _rcp _rcifs _rcd
unset TEAM_ALLOW_DESTRUCTIVE_TMUX TEAM_TMUX_CALLS_LOG TEAM_TMUX_REAL TEAM_SIGNAL_CALLS_LOG \
      TEAM_SIGNAL_REAL TEAM_TMUX_ISO_LOG 2>/dev/null || true
unset TEAM_TMP_RUN_ID TEAM_TMP_LEDGER 2>/dev/null || true
[ -n "${RECIPE_TMP_RUN_ID:-}" ] || export RECIPE_TMP_RUN_ID="recipe-$$-$(date +%s)"
TMP="$(tmp_root_create upgrade-recipe)" || exit 3
unset TMUX TMUX_PANE
export HOME="$TMP/home"; mkdir -p "$HOME"
PASS=0; FAIL=0; LIVE_SOCKET=''
cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  if [ -n "$LIVE_SOCKET" ] && tmux_iso_guard_soft recipe cleanup \
       --tmpdir "${TMUX_TMPDIR:-}" --sock-name "$LIVE_SOCKET" --own-root "$TMP" --own-root "$TMUX_TMPDIR"; then
    tmux -L "$LIVE_SOCKET" kill-server 2>/dev/null || true
  fi
  tmp_root_reap_all
}
trap cleanup EXIT

pass() { PASS=$((PASS + 1)); printf 'PASS %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$1"; }
check() { local n="$1"; shift; if "$@"; then pass "$n"; else fail "$n"; fi; }
not() { ! "$@"; }   # 否定一条 shell 函数断言（不能用 bash -c：新 shell 里没有这些函数）
eq() { [ "$1" = "$2" ]; }
contains() { [[ "$1" == *"$2"* ]]; }
# 迁移拒绝里**完整推导映射**的判据：`--task-models '…'` 的值串里没有占位符（`<`）。
complete_map_line() { grep -qE -- "--task-models '[^<]*'" "$1"; }
sha() { if [ -f "$1" ]; then sha256sum "$1" | cut -d' ' -f1; else printf absent; fi; }
section6_of() { sed -n '/^## 6\. Upgrade recipe/,/^## 7\./p' "$1"; }
# 各组共享的工具输出文件（单独 --select 某组时它们不存在，负向对照就自然判红）。
UP_PRINT_OLD=''; UP_NOMIGRATE=''; UP_REAL=''; UP_CONT=''; UP_FRESH=''; UP_MISMATCH=''; UP_NOREC=''
CONFIG_LIST=''; DISPATCH=''; VERSION=''; ROLLBACK_LIST=''; ORIG_SHA=''

# ── ① 文档面：§6 必须承诺的每一步（删一步 → 这里红）──────────────────────────────────────────
# 每条对应任务书「升级配方」里的一步；值取 §6 里逐字出现的片段（改动 §6 的措辞时同步这里）。
DOC_LITERALS=(
  'npm i -g teamsmith@'          # 1 工具升级：npm 包路线
  'install.sh'                   # 1 刷新共享软链
  'readlink -f'                  # 1 验证技能来源
  'team version'                 # 1 版本自检
  'cp .pi/team/config.sh'        # 2 迁移前先备份
  'team up --print'              # 2 只看不写
  'team up --no-migrate'         # 2 拒绝并给可粘贴命令
  'team config upgrade-models'   # 2 手工路线
  '--dry-run'                    # 2 手工路线预览
  '--yes'                        # 2 手工路线唯一一次写
  'team config list'             # 2 形状确认 / 5 收尾验证
  'state/pm-launch.env'          # 3 PM 启动身份是什么
  '--fresh-pm'                   # 3 新对话出路
  '--adopt-pm-identity'          # 3 认领记录出路
  'team up --agents'             # 4 席位一并拉起
  'team resume'                  # 4 续跑清单
  'team doctor'                  # 5 收尾验证
  'team dispatch --print'        # 5 category: 与模型解析
  'TEAM_CONFIG_VERSION'          # 2 形状号
  'migration_required'           # 6 回滚后旧形状复现
  'placeholder route'            # 2（F1）推导停住时给的是占位符路线，不是推导命令
  'bracketed placeholder'        # 2（F1）占位符路线的形态（文档侧的字面，工具侧判据与语言无关）
  'whichever of the two command forms'   # 2（F3）`--no-migrate` 那句也把两种形态写出来，不是无条件承诺推导命令
  'team pulse up'                # 4（F2）巡检窗口由 pulse up 建立，不是 team up 重建
)
doc_coverage_check() { # <file> → 0 = §6 里每一步都在
  local t lit; t="$(section6_of "$1")"
  for lit in "${DOC_LITERALS[@]}"; do case "$t" in *"$lit"*) ;; *) return 1 ;; esac; done
  return 0
}
doc_missing() { # <file> → 逐行打印 §6 缺的片段
  local t lit; t="$(section6_of "$1")"
  for lit in "${DOC_LITERALS[@]}"; do case "$t" in *"$lit"*) ;; *) printf '%s\n' "$lit" ;; esac; done
}
# F3（V40 第二轮）：这些片段把 `--no-migrate` 与「推导出来的命令」无条件连起来 —— §6 里不许再出现。
# 同一条承诺的条件形态由 DOC_LITERALS 的 `whichever of the two command forms` 正向钉住，这里是反向。
DOC_FORBIDDEN=(
  'manual command derived'       # F3 旧句子：prints the manual command derived from *your* configuration
)
doc_forbidden_check() { # <file> → 0 = §6 里一个禁列短语都不出现
  local t ph; t="$(section6_of "$1")"
  for ph in "${DOC_FORBIDDEN[@]}"; do case "$t" in *"$ph"*) return 1 ;; esac; done
  return 0
}
doc_forbidden_hits() { # <file> → 逐行打印 §6 命中的禁列短语
  local t ph; t="$(section6_of "$1")"
  for ph in "${DOC_FORBIDDEN[@]}"; do case "$t" in *"$ph"*) printf '%s\n' "$ph" ;; esac; done
}
# ② 工具面：文档承诺的片段（doc-literal）+ 工具真的打印的串（want）都要成立。
promise_check() { # <doc-literal> <工具输出文件> <want> → 0 = 两半都成立
  grep -qF -- "$1" "$DOC" || return 1
  grep -qF -- "$3" "$2" || return 1
  return 0
}
promise_red() { ! promise_check "$1" "$2" "$3"; }   # 反向对照：探针必须能红
promise() { # <name> <doc-literal> <输出文件> <want>
  local name="$1" lit="$2" f="$3" want="$4"
  if ! grep -qF -- "$lit" "$DOC"; then fail "doc-promise:$name（§6 不再承诺 $lit）"; return; fi
  if ! grep -qF -- "$want" "$f"; then fail "doc-promise:$name（§6 承诺 $lit，但工具没有打印 $want）"; return; fi
  pass "doc-promise:$name"
}

CLEAN_ENV=(env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_ROOT_SOURCE -u TEAM_ROOT_WAS -u TEAM_PROJECT \
  -u TEAM_SESSION -u TEAM_SESSION_FROM -u TEAM_PM_WINDOW -u TEAM_AGENTS -u TEAM_DOCS_DIR \
  -u TEAM_WORKTREES_DIR -u TEAM_GATES -u TEAM_VCS -u TEAM_CONFIG -u TEAM_CONFIG_FILE \
  -u TEAM_STATE_DIR -u TEAM_SKILL_DIR -u TEAM_PULSE_WINDOW -u TEAM_MODEL_RETIRED_ENV -u TEAM_UPDATE_CHECK)
run() { # <dir> -- <team args…>：真 CLI、干净环境、私有 PATH（私有 tmux + pi 桩）
  local d="$1"; shift
  [ "${1:-}" = '--' ] && shift
  printf 'RUN %s %s\n' "$d" "$*"   # 挂住时这一行就是最后一个线索
  RC=0; OUT="$( cd "$d" && "${CLEAN_ENV[@]}" timeout "${RECIPE_CMD_TIMEOUT:-120}" bash "$CLI" "$@" 2>&1 )" || RC=$?
  printf 'command=%q ' "$@"; printf '\nrc=%s\n%s\n' "$RC" "$OUT"
}
capture() { printf '%s\n' "$OUT" > "$1"; }
cmd_line() { grep -F '完整命令：' "$1" | head -1; }

# ── ① 文档面 ────────────────────────────────────────────────────────────────────────────
if has doc; then
  check doc-section-present test -f "$DOC"
  check doc-coverage doc_coverage_check "$DOC"
  if ! doc_coverage_check "$DOC"; then
    printf '  §6 缺的片段：\n'
    doc_missing "$DOC" | sed 's/^/    /'
  fi
  check doc-forbidden-phrases doc_forbidden_check "$DOC"
  if ! doc_forbidden_check "$DOC"; then
    printf '  §6 命中的禁列短语：\n'
    doc_forbidden_hits "$DOC" | sed 's/^/    /'
  fi
fi

# ── ③ 现场：0.1.x 形状的临时项目 ─────────────────────────────────────────────────────────
R="$TMP/repo"; BIN="$TMP/bin"
if has walk || has identity || has rollback; then
  mkdir -p "$R/.pi/team" "$R/docs/team/tasks" "$R/docs/team/reports" "$R/docs/team/threads" \
           "$R/docs/team/inbox" "$R/docs/team/reviews" "$BIN"
  ( cd "$R" && git init -q -b main && git config user.name fixture && git config user.email fixture@example.invalid \
      && printf '# upgrade recipe fixture\n' > README.md && git add -A && git commit -qm fixture ) >/dev/null 2>&1

  # 工具升级那一步用夹具桩：假 npm（记 argv、答 root -g）+ 包内 install.sh（记运行），
  # 再加一条 ~/.agents/skills/teamsmith → 包内技能的软链，配方第 1 步的 readlink 验证才有对象。
  NPMROOT="$R/npmroot"; TOOL="$R/toolbin"
  mkdir -p "$TOOL" "$NPMROOT/teamsmith/skills/teamsmith" "$HOME/.agents/skills"
  cat > "$TOOL/npm" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$R/npm-args.log"
if [ "\${1:-}" = root ] && [ "\${2:-}" = -g ]; then printf '%s\n' "$NPMROOT"; exit 0; fi
exit 0
EOF
  chmod +x "$TOOL/npm"
  cat > "$NPMROOT/teamsmith/install.sh" <<EOF
#!/usr/bin/env bash
printf 'install.sh %s\n' "\$*" >> "$R/install-ran.log"
exit 0
EOF
  chmod +x "$NPMROOT/teamsmith/install.sh"
  ln -sfn "$NPMROOT/teamsmith/skills/teamsmith" "$HOME/.agents/skills/teamsmith"

  # pi 桩（doctor 的 pi 检查看 PATH）；假 openspec + 假 settings（必需依赖的确定性夹具）。
  cat > "$BIN/pi" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  --version) printf '0.99.0-recipe-fixture\n'; exit 0 ;;
  --help) printf 'Usage: pi [options]\n  --session-id <id>\n'; exit 0 ;;
esac
exit 0
EOF
  chmod +x "$BIN/pi"
  mkdir -p "$R/deps/npm/node_modules/@cortexkit/pi-magic-context" "$R/openspec"
  printf '{"packages":["npm:@cortexkit/pi-magic-context"]}\n' > "$R/deps/settings.json"
  printf '{"name":"@cortexkit/pi-magic-context","version":"9.9.9"}\n' \
    > "$R/deps/npm/node_modules/@cortexkit/pi-magic-context/package.json"
  cat > "$R/deps/openspec" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = "--version" ] && printf 'openspec 9.9.9 (recipe-fixture)\n'
exit 0
EOF
  chmod +x "$R/deps/openspec"
  # 真 `team up` 起的「PM」：记 argv 后长睡（绝不起真 pi、不连 provider）。
  cat > "$R/recording-pi" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >> "$R/pi-argv.log"
sleep 180
EOF
  chmod +x "$R/recording-pi"

  # 0.1.x 形状的配置：退休键 TEAM_AGENT_MODELS / TEAM_DEFAULT_MODEL，没有 TEAM_CONFIG_VERSION。
  cat > "$R/.pi/team/config.sh" <<EOF
TEAM_PROJECT='recipe-fixture'
TEAM_SESSION='recipe-fixture'
TEAM_PM_WINDOW='pm'
TEAM_DOCS_DIR='docs/team'
TEAM_AGENTS='dev verify'
TEAM_AGENT_MODELS='dev=vendor/light verify=vendor/strong:high'
TEAM_DEFAULT_MODEL='vendor/base'
TEAM_PM_MODEL='vendor/pm:high'
TEAM_WORKTREES_DIR='.worktrees'
TEAM_VCS='local'
TEAM_GATES='true'
TEAM_MIN_FREE_SWAP_MB=0
TEAM_MIN_TOTAL_MB=0
TEAM_MIN_AVAIL_MB=0
TEAM_TMP_MIN_FREE_MB=0
TEAM_TMP_MIN_FREE_INODES=0
TEAM_MODEL_LIMITS=''
TEAM_UPDATE_CHECK=0
TEAM_PI_BIN='$R/recording-pi'
TEAM_PI_SETTINGS_FILE='$R/deps/settings.json'
TEAM_OPENSPEC_BIN='$R/deps/openspec'
TEAM_SPEC_DIR='$R/openspec'
EOF
  cat > "$R/docs/team/tasks/H1-fixture.md" <<'EOF'
# H1 · fixture
agent: dev
phase: apply
category: default
change: -
anchor: none (infra) — isolated upgrade-recipe fixture
branch: task/H1-fixture
## Scope
fixture only
EOF
  mkdir -p "$R/.worktrees"
  ( cd "$R" && git worktree add -qb task/H1-fixture .worktrees/dev ) >/dev/null 2>&1
fi

if has walk; then
  ORIG_SHA="$(sha "$R/.pi/team/config.sh")"

  # 配方第 1 步（逐字照 §6 的代码块跑；npm 与 install.sh 是上面的桩）。
  ( export PATH="$TOOL:$PATH" HOME="$HOME"
    npm i -g teamsmith@0.2.0 --registry https://registry.npmjs.org
    bash "$(npm root -g)/teamsmith/install.sh" ) >/dev/null 2>&1
  check tool-upgrade-npm grep -qF -- 'i -g teamsmith@0.2.0 --registry https://registry.npmjs.org' "$R/npm-args.log"
  check tool-upgrade-installer test -f "$R/install-ran.log"
  check tool-upgrade-link eq "$(readlink -f "$HOME/.agents/skills/teamsmith")" \
    "$NPMROOT/teamsmith/skills/teamsmith"

  # 迁移前的写路径被拒（形状不明时不许写），配置一个字节都不动。
  run "$R" -- config set TEAM_MONITOR_REFRESH 5
  check pre-migration-write-refused bash -c '[ "$1" != 0 ]' _ "$RC"
  check pre-migration-write-names-route contains "$OUT" 'upgrade-models'
  check pre-migration-write-pure eq "$(sha "$R/.pi/team/config.sh")" "$ORIG_SHA"

  # 配方第 2 步：--print 只预告；--no-migrate 拒绝并给可粘贴命令；粘回去 --dry-run 必须绿。
  run "$R" -- up --print
  UP_PRINT_OLD="$TMP/up-print-old.log"; capture "$UP_PRINT_OLD"
  check preview-rc eq "$RC" 0
  check preview-pairs contains "$OUT" 'TEAM_AGENT_MODELS dev=vendor/light → TEAM_TASK_MODELS dev=vendor/light'
  check preview-default-pair contains "$OUT" 'TEAM_DEFAULT_MODEL vendor/base → TEAM_TASK_MODELS default=vendor/base'
  check preview-backup-line contains "$OUT" '备份：'
  check preview-restore-line contains "$OUT" '还原：cp '
  check preview-identity-line contains "$OUT" '身份预告：此前没有启动记录'
  check preview-pure eq "$(sha "$R/.pi/team/config.sh")" "$ORIG_SHA"

  run "$R" -- up --no-migrate
  UP_NOMIGRATE="$TMP/up-nomigrate.log"; capture "$UP_NOMIGRATE"
  check nomigrate-refused bash -c '[ "$1" != 0 ]' _ "$RC"
  check nomigrate-names-route contains "$OUT" 'config upgrade-models'
  check nomigrate-pure eq "$(sha "$R/.pi/team/config.sh")" "$ORIG_SHA"
  derived_map="$(printf '%s\n' "$OUT" | awk -F"'" '/^ *--task-models /{print $2}' | head -1)"
  derived_pm="$(printf '%s\n' "$OUT" | awk -F"'" '/^ *--pm-model /{print $2}' | head -1)"
  check nomigrate-derived bash -c '[ -n "$1" ] && [ -n "$2" ]' _ "$derived_map" "$derived_pm"
  run "$R" -- config upgrade-models --task-models "$derived_map" --pm-model "$derived_pm" --dry-run
  check nomigrate-pasted-dryrun eq "$RC" 0
  check nomigrate-pasted-dryrun-pure eq "$(sha "$R/.pi/team/config.sh")" "$ORIG_SHA"

  # F1（V40 返修）：三种「推导停住」的形状都必须给**占位符路线**，不是推导命令 —— 返修的起因就是这里
  # 文档说错了一半（拒绝一律给推导命令）。每条形状：拒绝 + 点名障碍 + 占位符 + 没有 `dev=` 推导映射。
  SHAPE_KEEP="$R/.pi/team/config.sh.keep"; cp -p "$R/.pi/team/config.sh" "$SHAPE_KEEP"
  shape_refusal() { # <名字> <sed 表达式>
    sed -i "$2" "$R/.pi/team/config.sh"
    local after_sed; after_sed="$(sha "$R/.pi/team/config.sh")"
    run "$R" -- up --print
    local log="$TMP/refusal-$1.log"; capture "$log"
    check "refusal-$1-rejected" bash -c '[ "$1" != 0 ]' _ "$RC"
    check "refusal-$1-names-obstacle" contains "$OUT" '启动迁移拒绝'
    check "refusal-$1-placeholder" contains "$OUT" "--pm-model '<独立模型>'"
    check "refusal-$1-no-complete-map" not complete_map_line "$log"
    check "refusal-$1-pure" eq "$(sha "$R/.pi/team/config.sh")" "$after_sed"
    cp -p "$SHAPE_KEEP" "$R/.pi/team/config.sh"
  }
  shape_refusal not-locatable 's|^TEAM_DEFAULT_MODEL=.*$|TEAM_DEFAULT_MODEL="${MISSING:-vendor/base}"|'
  shape_refusal fallback-collision "s|^TEAM_AGENT_MODELS=.*|TEAM_AGENT_MODELS='default=vendor/light'|"
  shape_refusal invalid-value "s|^TEAM_AGENT_MODELS=.*|TEAM_AGENT_MODELS='dev=vendor/light verify=not-a-model'|"
  check refusal-shape-restored eq "$(sha "$R/.pi/team/config.sh")" "$ORIG_SHA"
  # 部分推导：非法值那一条保留已推出的对（dev=…），非法的那一对用占位符 —— 正是文档承诺的形态。
  check refusal-invalid-value-partial-marker grep -qF -- '<非法那一对用占位符>' "$TMP/refusal-invalid-value.log"
  check refusal-invalid-value-keeps-resolved grep -qF -- 'dev=vendor/light' "$TMP/refusal-invalid-value.log"
  rm -f "$SHAPE_KEEP"

  # 配方第 2 步：先备份配置，再让第一次 team up 自己迁移（私有 tmux + 假 PM，绝不碰共享 server）。
  cp -p "$R/.pi/team/config.sh" "$R/.pi/team/config.sh.pre-upgrade"
  check backup-copy eq "$(sha "$R/.pi/team/config.sh.pre-upgrade")" "$ORIG_SHA"
  if command -v tmux >/dev/null 2>&1; then
    LIVE_SOCKET="recipe-${BASHPID}-${RANDOM}"
    # P309：socket 基址要短（见 tmp-root.sh 的 tmp_root_socket_dir）；放不下才退回临时根下
    TMUX_TMPDIR="$(tmp_root_socket_dir tmux "tmux-$(id -u)/default")" || TMUX_TMPDIR="$TMP/tmux"
    export TMUX_TMPDIR; mkdir -p "$TMUX_TMPDIR"
    REAL_TMUX="$(command -v tmux)"
    printf '#!/usr/bin/env bash\nexec %q -L %q "$@"\n' "$REAL_TMUX" "$LIVE_SOCKET" > "$BIN/tmux"
    chmod +x "$BIN/tmux"
    export PATH="$BIN:$PATH"
    tmux_iso_require recipe launch --tmpdir "$TMUX_TMPDIR" --sock-name "$LIVE_SOCKET" --own-root "$TMP" --own-root "$TMUX_TMPDIR"
    run "$R" -- up
    UP_REAL="$TMP/up-real.log"; capture "$UP_REAL"
    check auto-migrate-rc eq "$RC" 0
    check auto-migrate-pairs contains "$OUT" 'TEAM_AGENT_MODELS verify=vendor/strong:high → TEAM_TASK_MODELS verify=vendor/strong:high'
    check auto-migrate-backup-line contains "$OUT" '备份：'
    check auto-migrate-restore-line contains "$OUT" '还原：cp '
    check auto-migrate-commit contains "$OUT" 'committed: before='
    check auto-migrate-registration contains "$OUT" \
      '已登记本次启动身份：model=vendor/pm:high resume_key=default mode=continued'
    check auto-migrate-task-models grep -qxF \
      "TEAM_TASK_MODELS='dev=vendor/light verify=vendor/strong:high default=vendor/base'" "$R/.pi/team/config.sh"
    check auto-migrate-shape-number grep -qxF "TEAM_CONFIG_VERSION='2'" "$R/.pi/team/config.sh"
    check auto-migrate-retired-gone bash -c '! grep -qE "^TEAM_(AGENT_MODELS|DEFAULT_MODEL)=" "$1"' _ "$R/.pi/team/config.sh"
    check auto-migrate-backup-count eq \
      "$(find "$R/.pi/team/state/config-backups" -maxdepth 1 -type f -name 'config.sh.pre-*' | wc -l | tr -d ' ')" 1
    check auto-migrate-backup-bytes bash -c 'cmp -s "$1" "$2"' _ \
      "$(find "$R/.pi/team/state/config-backups" -maxdepth 1 -type f -name 'config.sh.pre-*' | head -1)" \
      "$R/.pi/team/config.sh.pre-upgrade"
    check auto-migrate-audit contains "$(tail -1 "$R/.pi/team/state/config.log")" 'actor=up-migration'
    check auto-migrate-record bash -c 'grep -qx "model=vendor/pm:high" "$1" && grep -qx "mode=continued" "$1"' _ \
      "$R/.pi/team/state/pm-launch.env"
    # F2（V40 返修）：`team up` 只起 PM；巡检窗口（pulse）不在它的产物里 —— 建它的是 `team pulse up`。
    UP_WINDOWS="$("$REAL_TMUX" -L "$LIVE_SOCKET" list-windows -t recipe-fixture -F '#{window_name}' 2>/dev/null || true)"
    check up-creates-pm-window contains "$UP_WINDOWS" 'pm'
    check up-leaves-pulse-to-pulse-up bash -c '! grep -qx -- pulse <<<"$1"' _ "$UP_WINDOWS"
  else
    printf 'SKIP auto-route（本机没有 tmux：真 up 的自动迁移子用例跳过；预览 / 拒绝 / 手工路线仍然跑）\n'
  fi

  # 迁移后：config list rc=0 且不再要求迁移；doctor 绿；dispatch --print 证明 category 解析生效。
  run "$R" -- config list
  CONFIG_LIST="$TMP/config-list.log"; capture "$CONFIG_LIST"
  check config-list-rc eq "$RC" 0
  check config-list-task-models contains "$OUT" 'TEAM_TASK_MODELS'
  check config-list-no-migration bash -c '! grep -qF "migration_required" "$1"' _ "$CONFIG_LIST"
  run "$R" -- doctor
  DOCTOR="$TMP/doctor.log"; capture "$DOCTOR"
  check doctor-rc eq "$RC" 0
  run "$R" -- version
  VERSION="$TMP/version.log"; capture "$VERSION"
  check version-rc eq "$RC" 0
  run "$R" -- dispatch dev H1 docs/team/tasks/H1-fixture.md --print
  DISPATCH="$TMP/dispatch.log"; capture "$DISPATCH"
  check dispatch-rc eq "$RC" 0
  check dispatch-category contains "$OUT" 'category=default model=vendor/base'

  # ② 文档承诺 → 工具兑现（“文档写了但工具不做”就在这里红）。
  promise preview-migration 'team up --print' "$UP_PRINT_OLD" '检测到旧形状配置'
  promise preview-restore 'cp "<the backup path the migration printed>"' "$UP_PRINT_OLD" '还原：cp '
  promise nomigrate-pastable 'team config upgrade-models' "$UP_NOMIGRATE" 'config upgrade-models'
  if [ -n "$UP_REAL" ]; then
    promise registration 'state/pm-launch.env' "$UP_REAL" \
      '已登记本次启动身份：model=vendor/pm:high resume_key=default mode=continued'
  else
    printf 'SKIP doc-promise:registration（自动迁移子用例跳过：没有 tmux，登记行不产生）\n'
  fi
  promise config-list-clean 'team config list' "$CONFIG_LIST" 'TEAM_TASK_MODELS'
  promise dispatch-category 'team dispatch --print' "$DISPATCH" 'category=default model=vendor/base'
  promise version-line 'team version' "$VERSION" 'teamsmith '
  # F1：文档承诺的两种形态必须在工具输出里成对成立（推导停住 → **未填**的映射，而不是推导命令）。
  # 两侧都不依赖语言：文档侧的字面是 `placeholder route`；工具侧的判据是「`--task-models` 的引号里
  # 以 `<` 开头」——推导命令的值是 `dev=…`，占位符路线的值以占位符开头，两者一眼可分。
  promise refusal-placeholder-route 'placeholder route' "$TMP/refusal-fallback-collision.log" \
    "upgrade-models --task-models '<"
fi

# ── ③ 现场：PM 启动身份（缺记录 / 记录不符 / --fresh-pm）──────────────────────────────────
if has identity; then
  # 记录与解析一致 → 完整预览 + continued 判定；迁移预告不再出现。
  run "$R" -- up --print
  UP_CONT="$TMP/up-continued.log"; capture "$UP_CONT"
  check identity-matches-rc eq "$RC" 0
  check identity-matches-line contains "$OUT" '身份预告：记录与当前解析一致'
  check identity-continued-verdict contains "$OUT" '会话判定：continued:pi -c（本目录上一个会话）'
  check identity-complete-command contains "$OUT" '完整命令：'
  check identity-continued-has-c contains "$(cmd_line "$UP_CONT")" ' -c '
  check identity-no-migration-preview bash -c '! grep -qF "检测到旧形状配置" "$1"' _ "$UP_CONT"

  # --fresh-pm → 这一次新开会话（不带 -c）；记录一个字节都不动。
  REC0="$(sha "$R/.pi/team/state/pm-launch.env")"
  run "$R" -- up --print --fresh-pm
  UP_FRESH="$TMP/up-fresh.log"; capture "$UP_FRESH"
  check identity-fresh-rc eq "$RC" 0
  check identity-fresh-verdict contains "$OUT" '会话判定：fresh:--fresh-pm'
  check identity-fresh-no-c bash -c '! grep -qF -- " -c " <<<"$(grep -F "完整命令：" "$1" | head -1)"' _ "$UP_FRESH"
  check identity-fresh-record-untouched eq "$(sha "$R/.pi/team/state/pm-launch.env")" "$REC0"

  # 记录存在但与现在解析不一致 → 拒绝，并点名两条出路；记录不动。
  sed -i "s|^TEAM_PM_MODEL='vendor/pm:high'|TEAM_PM_MODEL='vendor/pm:other'|" "$R/.pi/team/config.sh"
  run "$R" -- up --print
  UP_MISMATCH="$TMP/up-mismatch.log"; capture "$UP_MISMATCH"
  check identity-mismatch-refused bash -c '[ "$1" != 0 ]' _ "$RC"
  check identity-mismatch-named contains "$OUT" 'PM launch identity changed'
  check identity-mismatch-exit1 contains "$OUT" '出路 ①'
  check identity-mismatch-exit1-cmd contains "$OUT" '--fresh-pm'
  check identity-mismatch-exit2 contains "$OUT" '出路 ②'
  check identity-mismatch-exit2-cmd contains "$OUT" '--adopt-pm-identity --yes'
  check identity-mismatch-record-pure eq "$(sha "$R/.pi/team/state/pm-launch.env")" "$REC0"
  sed -i "s|^TEAM_PM_MODEL='vendor/pm:other'|TEAM_PM_MODEL='vendor/pm:high'|" "$R/.pi/team/config.sh"

  # 0.1.x 升上来的项目就是缺这条记录：--print 预告「会登记」，且不预写文件。
  mv "$R/.pi/team/state/pm-launch.env" "$TMP/pm-launch.saved"
  run "$R" -- up --print
  UP_NOREC="$TMP/up-norecord.log"; capture "$UP_NOREC"
  check identity-missing-rc eq "$RC" 0
  check identity-missing-will-register contains "$OUT" '身份预告：此前没有启动记录'
  check identity-missing-line contains "$OUT" '这次启动会登记 model=vendor/pm:high resume_key=default mode=continued'
  check identity-missing-not-precreated bash -c '[ ! -e "$1" ]' _ "$R/.pi/team/state/pm-launch.env"
  mv "$TMP/pm-launch.saved" "$R/.pi/team/state/pm-launch.env"

  # 承诺 → 工具：两条出路与 fresh 判定都真的打出来。
  promise identity-mismatch-exits '--adopt-pm-identity' "$UP_MISMATCH" '--adopt-pm-identity --yes'
  promise fresh-verdict '--fresh-pm' "$UP_FRESH" '会话判定：fresh:--fresh-pm'
  promise missing-record 'state/pm-launch.env' "$UP_NOREC" '身份预告：此前没有启动记录'
fi

# ── ③ 现场：回滚（配置回 cp 备份；旧形状复现）──────────────────────────────────────────────
if has rollback; then
  cp -p "$R/.pi/team/config.sh.pre-upgrade" "$R/.pi/team/config.sh"
  check rollback-bytes eq "$(sha "$R/.pi/team/config.sh")" "$ORIG_SHA"
  run "$R" -- config list
  ROLLBACK_LIST="$TMP/rollback-list.log"; capture "$ROLLBACK_LIST"
  check rollback-rc eq "$RC" 0
  check rollback-shape-back contains "$OUT" 'migration_required'
  promise rollback-shape 'migration_required' "$ROLLBACK_LIST" 'migration_required'
fi

# ── ① 红侧：删掉 §6 的任一步 → 文档面必须红（探针不是恒真）────────────────────────────────
if has selftest; then
  SB="$TMP/selftest"; mkdir -p "$SB"
  cp "$DOC" "$SB/migration.md"
  check selftest-green doc_coverage_check "$SB/migration.md"

  # 删掉 §6 的一步 → 文档面必须红，并点名缺的那一步
  sed -i '/team up --no-migrate/d' "$SB/migration.md"
  check selftest-red-missing-step not doc_coverage_check "$SB/migration.md"
  check selftest-names-the-step eq "$(doc_missing "$SB/migration.md" | head -1)" 'team up --no-migrate'
  cp "$DOC" "$SB/migration.md"
  check selftest-restored doc_coverage_check "$SB/migration.md"

  # 再删一步（工具升级）→ 同样红（不是只钉住某一行）
  sed -i '/npm i -g teamsmith@/d' "$SB/migration.md"
  check selftest-red-tool-upgrade not doc_coverage_check "$SB/migration.md"
  cp "$DOC" "$SB/migration.md"
  check selftest-restored-2 doc_coverage_check "$SB/migration.md"

  # F1/F2 的两条新断言也必须能红：把承诺句子删掉 → 文档面红，且 doc_missing 点名缺的是它们。
  sed -i '/placeholder route/d; /team pulse up/d' "$SB/migration.md"
  F1F2_MISSING="$(doc_missing "$SB/migration.md")"
  check selftest-red-f1f2 not doc_coverage_check "$SB/migration.md"
  check selftest-red-f1f2-names contains "$F1F2_MISSING" 'placeholder route'
  check selftest-red-f1f2-names-pulse contains "$F1F2_MISSING" 'team pulse up'
  cp "$DOC" "$SB/migration.md"
  check selftest-restored-3 doc_coverage_check "$SB/migration.md"

  # F3（V40 第二轮）：把 §6 里 `--no-migrate` 那句换回旧的无条件承诺（“推导出来的命令”）→ 文档面必须
  # 两侧都红：正向 needle 丢失（doc_missing 点名它）+ 禁列短语命中（doc_forbidden_hits 点名它）。
  awk '/is the same promise from the other side:/{print;
         print "it refuses, writes nothing, and prints the manual command derived from *your* configuration.";
         drop=1; next}
       drop && /the placeholder route when it is not\./{drop=0; next}
       drop{next}
       {print}' "$DOC" > "$SB/migration.md"
  check selftest-red-f3 not doc_coverage_check "$SB/migration.md"
  F3_MISSING="$(doc_missing "$SB/migration.md")"
  check selftest-red-f3-needle contains "$F3_MISSING" 'whichever of the two command forms'
  check selftest-red-f3-forbidden not doc_forbidden_check "$SB/migration.md"
  check selftest-red-f3-names eq "$(doc_forbidden_hits "$SB/migration.md" | head -1)" 'manual command derived'
  cp "$DOC" "$SB/migration.md"
  check selftest-restored-f3 doc_coverage_check "$SB/migration.md"
  check selftest-restored-f3-forbidden doc_forbidden_check "$SB/migration.md"

  # 承诺探针的反向对照（自带的合成工具输出，不依赖 walk 组是否跑过）：
  #   ① 文档承诺了、工具输出里没有 → 红；② 文档根本没承诺 → 红；③ 两半都在 → 绿。
  printf 'teamsmith 0.2.0\nno restore line here\n' > "$SB/tool-output.txt"
  check selftest-promise-positive promise_check 'team version' "$SB/tool-output.txt" 'teamsmith '
  check selftest-promise-negative promise_red 'team up --print' "$SB/tool-output.txt" '还原：cp '
  check selftest-promise-negative-doc promise_red 'THIS STRING IS NOT IN THE GUIDE' "$SB/tool-output.txt" 'teamsmith '
fi

printf '\nRESULT pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
