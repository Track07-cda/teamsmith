#!/usr/bin/env python3
"""P228 scratch-only mutations; print exact byte hashes and require one target."""
import hashlib
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1]).resolve()
name = sys.argv[2]
assert (root / '.routing-mutant').is_file(), 'not a marked owned scratch tree'
lib = root / 'skills/teamsmith/scripts/lib'
changes = []


def replace(path, old, new):
    text = path.read_text()
    assert text.count(old) == 1, (name, str(path), text.count(old))
    before = hashlib.sha256(text.encode()).hexdigest()
    text = text.replace(old, new)
    assert text.count(new) == 1
    path.write_text(text)
    after = hashlib.sha256(text.encode()).hexdigest()
    assert before != after
    changes.append(dict(file=str(path), matched=1, before=before, after=after))


def function(path, symbol, body):
    text = path.read_text()
    begin = text.index(symbol + '() {')
    line_end = text.index('\n', begin)
    end = line_end if text[begin:line_end].rstrip().endswith('}') else text.index('\n}', begin) + 2
    old = text[begin:end]
    replace(path, old, '# P228_FLIP_' + name + '\n' + symbol + '() {\n' + body + '\n}')


if name == 'unmapped-override':
    replace(lib / 'cmd-agents.sh',
            '  local policy_model; policy_model="$(team_task_policy_model "$category")" || { team_err "category 未映射：$category；config set-task-model $category <model>（override 仍须映射）"; return 1; }',
            '  # P228_FLIP_unmapped-override\n  local policy_model; policy_model="${override:-$(team_task_policy_model "$category" || true)}"')
elif name == 'required-categories':
    # F6 red side: restore the hardcoded analysis/verify requirement the contract forbids.
    replace(lib / 'common.sh',
            '  # 唯一非法的映射是**空映射**',
            '  for cat in analysis verify; do\n    case "$seen" in *" $cat "*) ;; *) printf \'required category missing: %s\\n\' "$cat"; return 1 ;; esac\n  done # P228_FLIP_required-categories\n  # 唯一非法的映射是**空映射**')
elif name == 'identity-overclaim':
    # R6/OBS1 red side: publish the complete identity no matter what the template delivered.
    function(lib / 'common.sh', 'team_launch_identity_fields', "  printf 'provider,model,session_id\\n'")
elif name == 'fingerprint':
    function(lib / 'cmd-config.sh', 'team_config_fingerprint', "  printf '%064d\\n' 0")
elif name == 'expanding-quote':
    replace(lib / 'cmd-bootstrap.sh', 'newline="${form}${k}=\'${quoted}\'${comment}"',
            'newline="${form}${k}=\\"${v}\\"${comment}" # P228_FLIP_expanding-quote')
    replace(lib / 'cmd-bootstrap.sh', 'newline="${form}${k}=\'${quoted}\'"',
            'newline="${form}${k}=\\"${v}\\"" # P228_FLIP_expanding-quote')
elif name == 'recovery-drift':
    replace(lib / 'cmd-agents.sh', 'TEAM_SELECTED_MODEL="$oldmodel"; TEAM_SELECTED_SID="$oldsid";',
            'TEAM_SELECTED_MODEL="$(team_task_policy_model "$category" || true)"; TEAM_SELECTED_SID="$TEAM_SESSION-$agent";')
elif name == 'partial-publication':
    replace(lib / 'cmd-agents.sh', '  TEAM_ASSIGN_TMP="$TEAM_STATE_DIR/.assignment-$seat-$nonce"',
            '  TEAM_ASSIGN_TMP="$TEAM_STATE_DIR/.assignment-$seat-$nonce"\n  printf "model=forbidden/partial\\n" > "$TEAM_STATE_DIR/$seat.env" # P228_FLIP_partial-publication')
elif name == 'unknown-as-zero':
    replace(lib / 'common.sh', '  running="$TEAM_MODEL_KNOWN_COUNT"; rule="$(team_model_limit_pattern_for "$model")"',
            '  running="$TEAM_MODEL_KNOWN_COUNT"; rule="$(team_model_limit_pattern_for "$model")"\n  TEAM_MODEL_UNKNOWN="" # P228_FLIP_unknown-as-zero')
elif name == 'latest-shell':
    function(lib / 'common.sh', 'team_session_file',
             '  local d; d="$(team_pi_session_dir "$2")"\n  find "$d" -maxdepth 1 -type f -name "*.jsonl" -print 2>/dev/null | sort | tail -1')
elif name == 'latest-monitor':
    replace(root / 'skills/teamsmith/scripts/monitor.mjs', '(!match || f.endsWith(match))', 'true /* P228_FLIP_latest-monitor */')
elif name == 'pm-fallback':
    function(lib / 'common.sh', 'team_pm_model_resolve', "  printf '%s\\n' vendor/routine")
elif name == 'pm-publication':
    function(lib / 'common.sh', 'team_pm_abort_uncommitted', '  return 0 # leave uncommitted process and proof alive')
elif name == 'extra-shadow':
    function(lib / 'common.sh', 'team_identity_extra_guard', '  return 0 # identity shadow accepted')
elif name == 'template-shadow':
    function(lib / 'common.sh', 'team_template_identity_guard', '  return 0 # hardcoded template identity accepted')
elif name == 'literal-shell-expansion':
    path = lib / 'common.sh'
    text = path.read_text()
    start = text.index("      '*'|'?'|'['|']'|'~')\n")
    end = text.index("      ' '|$'\\t')", start)
    replace(path, text[start:end], '      # P228_FLIP_literal-shell-expansion: launch shell expands unchecked argv\n')
elif name == 'init-legacy-proceeds':
    # P235 red side: the legacy-model gate is removed, so init/bootstrap migrate by overwrite.
    function(lib / 'cmd-project.sh', 'team_config_legacy_model_keys', '  return 0 # P235_FLIP_init-legacy-proceeds')
    # P238: 拆掉退休键闸门后，plain 路径仍被 P235 的模型策略解析器独立拦住（这份夹具没有合法新策略
    # → 拒绝），于是 `init-legacy-plain-refused` 永远不红 —— 臂头的命名期望形同虚设（P238 实测：
    # 8 条红里没有它，且改前改后一模一样）。把解析器也一并短路，才真的是「闸门被拆掉」：
    # plain / force / bootstrap 三条都按覆盖式迁移红出来。
    function(lib / 'cmd-project.sh', 'team_init_model_policy_resolve',
             '  printf \'%s\\n\' vendor/light; printf \'%s\\n\' vendor/pm:high # P238_FLIP_init-legacy-proceeds-policy')
elif name == 'template-retired-key':
    # P235 red side: the shipped template carries the retired worker key again.
    replace(root / 'skills/teamsmith/templates/config.sh.tmpl',
            'TEAM_TASK_MODELS=""',
            'TEAM_DEFAULT_MODEL="{{PROJECT}}" # P235_FLIP_template-retired-key\nTEAM_TASK_MODELS=""')
elif name == 'worker-literal-resplit':
    replace(lib / 'cmd-agents.sh',
            '    team_literal_argv "$TEAM_EXTRA_PI_ARGS" || return 1\n    piargs+=("${TEAM_LITERAL_TOKENS[@]}")',
            '    piargs+=($TEAM_EXTRA_PI_ARGS) # P228_FLIP_worker-literal-resplit')
elif name == 'pm-literal-resplit':
    replace(lib / 'common.sh',
            '    team_literal_argv "$TEAM_PM_RESUME_ARGS" || return 1\n    args+=("${TEAM_LITERAL_TOKENS[@]}")',
            '    args+=($TEAM_PM_RESUME_ARGS) # P228_FLIP_pm-literal-resplit-resume')
    replace(lib / 'common.sh',
            '    team_literal_argv "$TEAM_PM_EXTRA_PI_ARGS" || return 1\n    args+=("${TEAM_LITERAL_TOKENS[@]}")',
            '    args+=($TEAM_PM_EXTRA_PI_ARGS) # P228_FLIP_pm-literal-resplit-extra')
elif name == 'template-roles':
    # Restore F5's lexical-only walk on a real copied source, including the
    # resume selector-as-data path. No assertion/test code is changed.
    function(lib / 'common.sh', 'team_argv_roles_guard', '  return 0 # argv roles ignored')
    replace(lib / 'common.sh',
            '      -e|--skill) i=$((i+1)); continue ;; # proved scalar data, never a selector',
            '      # P228_FLIP_template-roles: tool data mistaken for selectors')
    replace(lib / 'common.sh',
            '      -e|--skill) i=$((i+1)) ;; # scalar role already proved; its data is not continuity',
            '      # P228_FLIP_template-roles: tool data mistaken for continuity')
elif name == 'template-unbound':
    # Restore F4: occurrence is mistaken for an owned selector binding.
    # The new surrounding-role proof independently refuses identity-as-tool-data,
    # so restore that part of the older source as well; leave tests untouched.
    function(lib / 'common.sh', 'team_argv_roles_guard', '  return 0 # old unbound data walk')
    path = lib / 'common.sh'
    text = path.read_text()
    start = text.index('  # Presence is not ownership:')
    end = text.index('  if [ "$mode" = continued ]; then', start)
    replace(path, text[start:end], '  # P228_FLIP_template-unbound: no binding proof\n')
    replace(path, '[ "${seen[$token]:-0}" = 1 ] || { team_err',
                  '[ "${refs[$token]:-0}" = 1 ] || { team_err')
elif name == 'monitor-record-drift':
    replace(root / 'skills/teamsmith/scripts/monitor.mjs',
            '      team_assignment_parse "$2" "$data" || exit 1',
            '      data="$(printf "%s" "$data" | sed "s/malformed nonce/fixture-nonce/")" # P228_FLIP_monitor-record-drift\n      team_assignment_parse "$2" "$data" || exit 1')
elif name == 'migration-row-removed':
    # P261 red side: the derivation table loses its only migration row -> the legacy project must be refused
    # (missing-migration-row named), not silently passed through with the old keys.
    replace(lib / 'cmd-config.sh', 'm1|1|2|0.2.0', '# P228_FLIP_migration-row-removed')
elif name == 'no-backup':
    # P261 red side: write no timestamped backup but still report one.
    replace(lib / 'cmd-config.sh',
            'cp -p "$path" "$dir/$name" || return 1',
            ': # P228_FLIP_no-backup')
elif name == 'no-shape-number':
    # P261 red side: init/bootstrap stop writing the configuration shape number.
    replace(root / 'skills/teamsmith/scripts/lib/cmd-project.sh',
            '      "CONFIG_VERSION=$TEAM_CONFIG_SHAPE_CURRENT" > "$cfg"; then',
            '      > "$cfg"; then # P228_FLIP_no-shape-number')
elif name == 'missing-record-refused':
    # P261 red side: restore the old single refusal for "no metadata at all".
    replace(lib / 'common.sh',
            '  if [ ! -f "$TEAM_STATE_DIR/pm-launch.env" ]; then\n    TEAM_PM_IDENTITY_REGISTER=1',
            '  if [ ! -f "$TEAM_STATE_DIR/pm-launch.env" ]; then\n    team_err "PM launch identity missing"; return 1 # P228_FLIP_missing-record-refused\n    TEAM_PM_IDENTITY_REGISTER=1')
elif name == 'adopt-ignores-yes':
    # P261 red side: --adopt-pm-identity writes a differing record without the explicit --yes.
    replace(lib / 'common.sh',
            """    if [ "$yes" != "1" ]; then
      team_err "--adopt-pm-identity 需要 --yes：这是把现在的解析声明成这次续跑的身份"
      team_dim "  记录 model=$TEAM_PM_SELECTED_MODEL（suffix 显式）／现在 model=$want_model；记录 resume_key=$TEAM_PM_RECORDED_RESUME_KEY／现在 resume_key=$want_resume" >&2
      team_dim "  要新开一场对话而不是认领：$TEAM_CLI up --fresh-pm" >&2
      return 1
    fi""",
            '    : # P228_FLIP_adopt-ignores-yes')
elif name == 'legacy-route-placeholder':
    # P261 返修（V35 F2/O1）红侧：拒绝建议退回占位符（不读项目自己的配置也不走推导表）
    # → init / bootstrap / config 写路径的「推导命令逐字节」与粘贴现场必红。
    function(lib / 'common.sh', 'team_legacy_model_route_lines',
             "  local cfg=\"${1:-${TEAM_CONFIG:-}}\"\n"
             "  team_dim \"  路线 ① 手工事务（先预览）：$TEAM_CLI config upgrade-models --task-models '<category=provider/model …>' --pm-model '<provider/model>' --dry-run\"\n"
             "  team_dim \"  路线 ② 启动事务（机械形状由它迁移）：$TEAM_CLI up（--print 只预告，--no-migrate 只报告）\"")
elif name == 'updatecheck-equal-prints':
    # P261 red side: an equal published version is reported as newer.
    replace(lib / 'cmd-watch.sh',
            '    [ "$b" -gt "$a" ] && return 0',
            '    [ "$b" -ge "$a" ] && return 0 # P228_FLIP_updatecheck-equal-prints')
elif name == 'updatecheck-ignores-off':
    # P261 red side: TEAM_UPDATE_CHECK=0 no longer suppresses the lookup.
    replace(lib / 'cmd-watch.sh',
            '  [ "${TEAM_UPDATE_CHECK:-1}" = "0" ] && return 0',
            ': # P228_FLIP_updatecheck-ignores-off')
elif name == 'updatecheck-print-writes-cache':
    # P261 red side: the preview performs the lookup and writes the cache.
    replace(lib / 'cmd-watch.sh',
            "    printf '（本可检查 npm 上的新版本：--print 下不联网、不写缓存）\\n'\n    return 0\n  fi",
            "    team_update_check_notice # P228_FLIP_updatecheck-print-writes-cache\n    printf '（本可检查 npm 上的新版本：--print 下不联网、不写缓存）\\n'\n    return 0\n  fi")
else:
    raise SystemExit('unknown mutation: ' + name)
print(json.dumps(dict(mutation=name, changes=changes), ensure_ascii=False))
