#!/usr/bin/env perl
# M28 · tmux 隔离 lint
#
#   扫描团队脚本里**会改变 tmux 状态**的命令（kill-server / kill-session / kill-window /
#   new-session / new-window / kill-pane / respawn-pane / split-window），判定每一条是否被证明
#   「打不到调用者的 tmux server」。没有证明 → 红（exit 1）。
#
#   为什么要有这条门禁：五次 tmux server 全灭事故的根因都是「一次没有隔离的 tmux 调用」。tmux 客户端
#   的 socket 解析优先级（M28 实测，见 tests/container-tmux.sh --selftest 的输出）：
#       -L/-S（命令行显式）  >  $TMUX（环境变量）  >  ${TMUX_TMPDIR:-/tmp}/tmux-<uid>/default
#   所以在 tmux 会话里跑夹具时：
#       * `tmux kill-server`（裸调用）                  → 打调用者的 server：事故形状；
#       * `unset TMUX; tmux kill-server`（无私有目录）  → 还是默认 socket，同样致命；
#       * `tmux -L <名字≠default>`                      → 私有 server：安全；
#       * `env -u TMUX … TMUX_TMPDIR=<私有目录> tmux …` → 私有 socket 目录：安全；
#       * 光有 PATH shim（`exec /usr/bin/tmux -L …`）   → **不算**：shim 会被登录 shell 洗掉
#         （M23 实测：`bash -lc` 重建 PATH 后夹具回落默认 server，165 条红）。
#
#   判定口径（每条变更命令必须命中其一，缺一即红）：
#     A. 命令里带 `-L <名字≠default>` 或 `-S <路径，不以 /default 结尾>`；
#     B. `env -u TMUX`（或同一命令里 `unset TMUX`）**且**同一命令里 `TMUX_TMPDIR=<非默认目录的值>`；
#     C. 调用的是**本文件/同目录**里定义的隔离包装（体内命中 A 或 B，例如
#        `m24_tmux() { env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$D" tmux "$@"; }`）；
#     D. 文件级白名单：文件在**使用之前**顶层 `unset …TMUX…`，并在顶层把 TMUX_TMPDIR 指到私有目录
#        （smoke.sh 第 42 行式的 unset 就是这一条），且此后没再把 TMUX 导回来。
#     M41 追加一条**否定式**规则：变更命令**不许写字面绝对路径**（`/usr/bin/tmux kill-server`）——
#     运行时闸门是 PATH 里的可执行文件（scripts/shim/tmux），绝对路径直接 exec、绕过记录与拒绝
#     （2026-09-19 第 8 次默认 server 死亡：绝对路径 + 不存在的 TMUX_TMPDIR）。这条**不受 A–D 影响**：
#     带 `-L 私有` 也红（闸门看不到它）。`"$REAL_TMUX"`/`${TMUX_BIN}` 这类**变量**是「REAL_TMUX 解析类」
#     例外，照旧走 A–D（变量里就算装的是绝对路径，也不是本规则能静态看出来的）。
#     注：`command tmux` / `env tmux` **仍然**经 PATH 解析（`command` 只跳过函数/别名），命中闸门，不算绕过。
#     M67 追加一条（闸 gate 的 argv token）：`tmux --teamsmith-allow-destructive kill-server` 里的 token
#     按**全局选项**跳过 —— 变更调用照旧被识别（token 不能把调用藏起来），但 token **不是**隔离证据
#     （带 token 没有 -L/-S/私有 TMPDIR 仍然红）；带私有 `-L` 的一条照旧净。
#
#   扫描范围：skills/teamsmith/tests/** 与 docs/team/reports/*/pkg/** 的脚本类文件（日志/patch 不扫）。
#
#   用法：
#     perl tests/tmux-lint.pl [--root DIR]… [--list] [--quiet]   # 默认扫上面两个范围
#     perl tests/tmux-lint.pl --selftest                        # 双向夹具（该红的红、该净的净）
#   exit: 0 干净 ｜ 1 有未隔离的变更命令 ｜ 2 用法/环境错误
#
#   已知边界（免得被当成保证）：
#     * 非 shell 文件（.py/.mjs）里用字符串对拼 argv 的调用（`["tmux","kill-server"]`）不在命令位
#       判据内；这些夹具的 tmux 调用都走 `-L`，真要藏成字符串对只能人工看。
#     * `tmux new-window … "<窗口命令串>"` 里嵌的 tmux 调用不递归扫描（窗口命令串按数据看）。
#     * `-L "$v"`/`-S "$p"` 用变量时按字面量判：只挡得住字面写 `default` 的。
use strict;
use warnings;
use File::Basename qw(dirname basename);
use File::Find ();
use Cwd qw(abs_path);
use File::Spec;

my %MUTATING = map { $_ => 1 } qw(kill-server kill-session kill-window new-session new-window kill-pane respawn-pane split-window);
my %EXTS     = map { $_ => 1 } qw(.sh .bash .pl .py .mjs .cjs .js .ts);
# 需要在命令位"透明"的保留字（后面仍期待命令词）
my %KEYWORD = map { $_ => 1 } qw(if then else elif while until do done fi case esac in for select ! time function);

my (@ROOTS, $LIST, $QUIET, $SELFTEST, $NO_LEGACY, $LEGACY_FILE, $WRITE_LEGACY, $EXPLICIT_ROOTS, $EXPLICIT_LEGACY);
while (@ARGV) {
    my $a = shift @ARGV;
    if    ($a eq '--root')        { push @ROOTS, shift @ARGV // die "--root 需要目录\n"; $EXPLICIT_ROOTS = 1 }
    elsif ($a =~ /^--root=(.*)$/) { push @ROOTS, $1; $EXPLICIT_ROOTS = 1 }
    elsif ($a eq '--list')        { $LIST = 1 }
    elsif ($a eq '--quiet')       { $QUIET = 1 }
    elsif ($a eq '--selftest')    { $SELFTEST = 1 }
    elsif ($a eq '--no-legacy')   { $NO_LEGACY = 1 }
    elsif ($a eq '--legacy')      { $LEGACY_FILE = shift @ARGV // die "--legacy 需要文件\n"; $EXPLICIT_LEGACY = 1 }
    elsif ($a =~ /^--legacy=(.*)$/) { $LEGACY_FILE = $1; $EXPLICIT_LEGACY = 1 }
    elsif ($a eq '--write-legacy') { $WRITE_LEGACY = shift @ARGV // die "--write-legacy 需要文件\n" }
    elsif ($a eq '--help' || $a eq '-h') { print "用法见文件头注释\n"; exit 0 }
    else { print STDERR "tmux-lint: 未知参数 $a\n"; exit 2 }
}

my $REPO = abs_path(File::Spec->catdir(dirname(abs_path($0)), '..', '..', '..'));
die "tmux-lint: 解析不到仓库根（$0）\n" unless defined $REPO && -d $REPO;

# ── 扫描范围 ─────────────────────────────────────────────────────────────────────────────────────
sub default_roots {
    my @r = (File::Spec->catdir($REPO, 'skills', 'teamsmith', 'tests'));
    my $rp = File::Spec->catdir($REPO, 'docs', 'team', 'reports');
    if (opendir(my $dh, $rp)) {
        for my $d (sort readdir $dh) {
            next if $d =~ /^\./;
            my $pkg = File::Spec->catdir($rp, $d, 'pkg');
            push @r, $pkg if -d $pkg;
        }
        closedir $dh;
    }
    return @r;
}
@ROOTS = default_roots() unless @ROOTS;
@ROOTS = map { abs_path($_) // $_ } @ROOTS;    # 显式 --root 也规范化（pretty/baseline 都按引用比较路径）

my @FILES;
for my $root (@ROOTS) {
    next unless -e $root;
    File::Find::find({
        no_chdir => 1,
        wanted   => sub {
            my $p = $File::Find::name;
            return if -d $p;
            return if $p =~ m{/(__pycache__|node_modules|logs|snapshots)/};
            my ($ext) = $p =~ /(\.[A-Za-z0-9]+)$/;
            return unless defined $ext && $EXTS{lc $ext};
            push @FILES, abs_path($p);
        },
    }, $root);
}
@FILES = sort { $a cmp $b } @FILES;

# ── 解析器：shell 源码 → 命令数组 ────────────────────────────────────────────────────────────────
# 命令：{ file, line, words => [ { t => 文本, cmd => 是否命令位首词, q => 词里有没有引号 } ], depth }
# 附：{ shell_strings => [ 脚本文本 … ] }（bash -c '…' 这类，后面递归判定）

# 读一段平衡结构（从 $from 开始，$open/$close 单字符）。返回 (内容, 结束后的下标, 内容换行数)。
sub read_balanced {
    my ($s, $from, $open, $close) = @_;
    my ($d, $j, $buf, $nl, $nn) = (1, $from, '', 0, length $s);
    while ($j < $nn) {
        my $c = substr($s, $j, 1);
        if ($c eq '\\') { $buf .= substr($s, $j, 2); $j += 2; next }
        if ($c eq "'") {
            $buf .= $c; $j++;
            while ($j < $nn) { my $x = substr($s, $j, 1); $buf .= $x; $j++; last if $x eq "'" }
            next;
        }
        if ($c eq '"') {
            $buf .= $c; $j++;
            while ($j < $nn) {
                my $x = substr($s, $j, 1);
                if ($x eq '\\') { $buf .= substr($s, $j, 2); $j += 2; next }
                $buf .= $x; $nl++ if $x eq "\n"; $j++;
                last if $x eq '"';
            }
            next;
        }
        if    ($c eq $open)  { $d++ }
        elsif ($c eq $close) { $d--; return ($buf, $j + 1, $nl) if $d == 0 }
        $nl++ if $c eq "\n";
        $buf .= $c; $j++;
    }
    return ($buf, $nn, $nl);
}

sub parse_source {
    my ($src, $file, $base_depth) = @_;
    my @cmds;
    my $cur = { file => $file, line => 1, depth => $base_depth, words => [], shell_strings => [] };
    my ($cmd_pos, $word, $word_q, $redirect_next, $line, $i, $n) = (1, '', 0, 0, 1, 0, length $src);
    my @heredocs;
    my @scopes;    # 'subshell' | 'func' | 'fnparen' | 'block'（决定命令是不是"文件顶层"）
    my $depth_now = sub { $base_depth + scalar grep { $_->{type} ne 'block' } @scopes };

    my $finish = sub {
        push @cmds, $cur if @{ $cur->{words} } || @{ $cur->{shell_strings} };
        $cur = { file => $file, line => $line, depth => $depth_now->(), words => [], shell_strings => [] };
        $cmd_pos = 1;
    };
    my $flush = sub {
        return if $word eq '';
        my $w = { t => $word, q => $word_q };
        $word = ''; $word_q = 0;
        push @{ $cur->{words} }, $w;
        $redirect_next = 0;
        if ($cmd_pos) {
            return if $w->{t} =~ /^[A-Za-z_][A-Za-z0-9_]*(\+)?=/;    # 赋值前缀：仍在命令位
            return if $KEYWORD{ $w->{t} };                            # 保留字：仍在命令位
            if ($w->{t} eq '-' || $w->{t} =~ /^\$\{?[@*]\}?$/) { return }   # 重定向目标一类，不进命令位
            $w->{cmd} = 1;
            $cmd_pos = 0;
        }
    };
    my $word_q_ctx;    # 供 $read_quoted 用的上下文
    my $read_quoted = sub {
        my $buf = '';
        $i++;
        while ($i < $n) {
            my $c = substr($src, $i, 1);
            if ($c eq '\\' && $word_q_ctx->{dbl}) {
                my $nx = substr($src, $i + 1, 1);
                if ($nx eq "\n") { $line++; $i += 2; next }
                $buf .= $nx; $i += 2; next;
            }
            last if $c eq $word_q_ctx->{close};
            if ($c eq "\n") { $line++ }
            if ($word_q_ctx->{dbl} && $c eq '$' && substr($src, $i + 1, 1) eq '(') {
                my ($body, $ni, $nl) = read_balanced($src, $i + 2, '(', ')');
                # 双引号里的命令替换真会执行 → 记下来
                push @cmds, parse_source($body, $file, $base_depth + 1);
                $line += $nl; $i = $ni; $buf .= '@CMD@';
                next;
            }
            $buf .= $c; $i++;
        }
        $i++;    # 吃掉闭引号
        return $buf;
    };

    while ($i < $n) {
        my $c = substr($src, $i, 1);
        if ($c eq "\n") {
            $line++; $i++;
            if (@heredocs) {
                while (@heredocs) {
                    my $hd = shift @heredocs;
                    my $body = '';
                    while ($i < $n) {
                        my $eol = index($src, "\n", $i);
                        my $l = $eol < 0 ? substr($src, $i) : substr($src, $i, $eol - $i);
                        my $cand = $hd->{strip} ? do { (my $t = $l) =~ s/^\t+//; $t } : $l;
                        if ($cand eq $hd->{tag}) { $i = $eol < 0 ? $n : $eol + 1; last }
                        $body .= "$l\n";
                        last if $eol < 0;
                        $i = $eol + 1; $line++;
                    }
                    # 未加引号的 heredoc 会展开/执行 → 递归解析；加引号的是纯数据，跳过
                    push @cmds, parse_source($body, $file, $base_depth + 1) if !$hd->{quoted};
                }
                $flush->();
                $finish->();
                next;
            }
            $flush->();
            $finish->();
            next;
        }
        if ($c eq "\\") {
            my $nx = substr($src, $i + 1, 1);
            if ($nx eq "\n") { $line++; $i += 2; next }
            $word .= $nx; $word_q = 1; $i += 2; next;
        }
        if ($c =~ /[ \t\r]/) { $flush->(); $i++; next }
        if ($c eq '#' && $word eq '') { my $e = index($src, "\n", $i); $i = $e < 0 ? $n : $e; next }
        if ($c eq "'" || $c eq '"') {
            $word_q_ctx = { close => $c, dbl => ($c eq '"') };
            $word .= $read_quoted->();
            $word_q = 1;
            next;
        }
        if ($c eq '`') {
            my ($j, $buf, $nl) = ($i + 1, '', 0);
            while ($j < $n) {
                my $x = substr($src, $j, 1);
                if ($x eq '\\') { $buf .= substr($src, $j, 2); $j += 2; next }
                last if $x eq '`';
                $nl++ if $x eq "\n";
                $buf .= $x; $j++;
            }
            push @cmds, parse_source($buf, $file, $base_depth + 1);
            $line += $nl; $i = $j + 1;
            $word .= '@CMD@'; $word_q = 1;
            next;
        }
        if ($c eq '$' && substr($src, $i + 1, 1) eq '(') {
            my ($body, $ni, $nl) = read_balanced($src, $i + 2, '(', ')');
            push @cmds, parse_source($body, $file, $base_depth + 1);
            $line += $nl; $i = $ni;
            $word .= '@CMD@';
            next;
        }
        if ($c eq '$' && substr($src, $i + 1, 1) eq '{') {
            my ($body, $ni, $nl) = read_balanced($src, $i + 2, '{', '}');
            if ($body =~ /\$\(/) {                 # ${x:-$(tmux …)}：里面的命令替换会执行
                my $p = 0;
                while (($p = index($body, '$(', $p)) >= 0) {
                    my ($b2, $n2, $nl2) = read_balanced($body, $p + 2, '(', ')');
                    push @cmds, parse_source($b2, $file, $base_depth + 1);
                    $p = $n2;
                }
            }
            $line += $nl; $i = $ni;
            $word .= '${' . $body . '}';
            next;
        }
        if ($c eq '(' || $c eq '{' || $c eq ')' || $c eq '}') {
            if ($c eq '(') {
                # `NAME (` 且只有一个词 → 可能是函数头；否则是子 shell（里面的状态变化不外泄）
                my $is_fn_head = (@{ $cur->{words} } == 1
                    && $cur->{words}[0]{t} =~ /^[A-Za-z_][A-Za-z0-9_]*$/) ? 1 : 0;
                $flush->(); $finish->();
                push @scopes, { type => ($is_fn_head ? 'fnparen' : 'subshell') };
            } elsif ($c eq '{') {
                $flush->(); $finish->();
                # `NAME () {` → 函数体（局部 unset 不算文件顶层）；否则是 `{ ... }` 块（同一 shell）
                my $is_fn = (@scopes && $scopes[-1]{type} eq 'fnparen') ? 1 : 0;
                push @scopes, { type => ($is_fn ? 'func' : 'block') };
            } elsif ($c eq ')' || $c eq '}') {
                $flush->(); $finish->();
                pop @scopes if @scopes;
            }
            $i++;
            next;
        }
        if ($c eq ';' || $c eq '&' || $c eq '|') {
            $flush->(); $finish->(); $i++;
            $i++ if $i < $n && (substr($src, $i, 1) eq '&' || substr($src, $i, 1) eq '|');
            next;
        }
        if ($c eq '<' && substr($src, $i + 1, 1) eq '<') {
            my $j = $i + 2; my $strip = 0;
            if (substr($src, $j, 1) eq '-') { $strip = 1; $j++ }
            $j++ while $j < $n && substr($src, $j, 1) =~ /[ \t]/;
            my ($tag, $quoted) = ('', 0);
            my $open = substr($src, $j, 1);
            if ($open eq "'" || $open eq '"') {
                my $e = index($src, $open, $j + 1);
                $tag = $e < 0 ? '' : substr($src, $j + 1, $e - $j - 1);
                $quoted = 1; $j = $e < 0 ? $n : $e + 1;
            } else {
                while ($j < $n && substr($src, $j, 1) =~ /[A-Za-z0-9_.-]/) { $tag .= substr($src, $j, 1); $j++ }
            }
            push @heredocs, { tag => $tag, strip => $strip, quoted => $quoted } if $tag ne '';
            $flush->(); $i = $j; $redirect_next = 1;
            next;
        }
        if ($c eq '>' || $c eq '<') {
            $flush->(); $i++;
            $i++ while $i < $n && substr($src, $i, 1) =~ /[><&]/;
            $redirect_next = 1;
            next;
        }
        $word .= $c; $i++;
    }
    $flush->();
    $finish->();
    return @cmds;
}

# ── 隔离判据 ─────────────────────────────────────────────────────────────────────────────────────
my %VALUE_FLAG = map { $_ => 1 } qw(-L -S -f -c -t -F -n -x -y -e -T -w);
my %CMD_PREFIX = map { $_ => 1 } qw(command exec nohup builtin time setsid stdbuf nice ionice timeout sudo xargs);
my %SHELLS     = map { $_ => 1 } qw(bash sh dash zsh ksh ash sh5);

sub cmd_name { my $t = shift; $t =~ s{^.*/}{}; $t =~ s/^(['"])(.*)\1$/$2/; return $t }

sub is_tmux_word {
    my $n = cmd_name(shift);
    return 1 if $n eq 'tmux';
    return 1 if $n =~ m{(^|/)tmux$};                             # $SHIM/tmux
    return 1 if $n =~ /^\$\{?[A-Za-z_][A-Za-z0-9_]*\}?$/ && $n =~ /TMUX/;   # $TMUX_BIN
    return 0;
}

# M41：命令位是不是**字面绝对路径**的 tmux（`/usr/bin/tmux` / `"/usr/bin/tmux"`）？
# 变量形式（`"$REAL_TMUX"` / `${TMUX_BIN}`）不算 —— 那是「REAL_TMUX 解析类」例外，照旧按 A–D 判。
sub is_literal_abs_path_word {
    my $t = shift // '';
    $t =~ s/^(['"])(.*)\1$/$2/s;
    return 0 unless $t =~ m{^/};
    return cmd_name($t) eq 'tmux' ? 1 : 0;
}

# 私有 TMUX_TMPDIR 赋值？（值不是默认 socket 目录）
sub private_tmpdir_word {
    my $t = shift // '';
    return 0 unless $t =~ /^TMUX_TMPDIR=(.*)$/s;
    my $v = $1;
    $v =~ s/^(['"])(.*)\1$/$2/s;
    $v =~ s/^\s+|\s+$//g;
    return 0 if $v eq '' || $v eq '/' || $v eq '/tmp';
    return 0 if $v =~ m{^['"]?/tmp/?['"]?$};
    return 0 if $v =~ /^\$\{?TMPDIR/i;          # ${TMPDIR:-/tmp} 还是默认目录
    return 1;
}

# 命令词 → 命令位解析（跳过赋值/env/包装；识别 shell -c 脚本串）
# 返回 (cmd_index, env_unset_tmux?, private_dir?, shell_string, shell_index)
sub resolve_command {
    my ($words) = @_;
    my (%unset, $private, $shellscript) = ();
    # 命令位首词（保留字 `if`/`then`/`do`/`!` 等不占命令位）
    my $start = 0;
    $start++ while $start < @$words && !$words->[$start]{cmd};
    # 前缀里的赋值（`TMUX_TMPDIR=x env … tmux` 这类）也要看
    for my $j (0 .. $start - 1) { $private = 1 if private_tmpdir_word($words->[$j]{t}) }
    my $k = $start;
    while ($k < @$words) {
        my $t = $words->[$k]{t};
        if ($t =~ /^[A-Za-z_][A-Za-z0-9_]*(\+)?=/) { $private = 1 if private_tmpdir_word($t); $k++; next }
        my $n = cmd_name($t);
        if ($n eq 'env') {
            $k++;
            while ($k < @$words) {
                my $a = $words->[$k]{t};
                if ($a eq '-u' || $a eq '--unset') { $unset{ $words->[$k + 1]{t} // '' } = 1; $k += 2; next }
                if ($a =~ /^-u(.*)$/ && $1 ne '') { $unset{$1} = 1; $k++; next }
                if ($a =~ /^--unset=(.*)$/) { $unset{$1} = 1; $k++; next }
                if ($a =~ /^[A-Za-z_][A-Za-z0-9_]*=/) { $private = 1 if private_tmpdir_word($a); $k++; next }
                if ($a =~ /^-/) { $k++; next }
                last;
            }
            return ($k, $unset{TMUX} ? 1 : 0, $private, undef) if $k < @$words;
            return (undef, 0, $private, undef);
        }
        if ($SHELLS{$n}) {
            # bash -c '…' / bash -lc "…"：字符串是真会执行的脚本 → 交给调用方递归判定
            my $j = $k + 1;
            my $cflag = 0;
            while ($j < @$words && $words->[$j]{t} =~ /^-/) {
                $cflag = 1 if $words->[$j]{t} =~ /^-[A-Za-z]*c[A-Za-z]*$/;
                $j++;
            }
            if ($cflag && $j < @$words && $words->[$j]{q}) {
                return (undef, 0, $private, $words->[$j]{t});
            }
            return (undef, 0, $private, undef);
        }
        if ($CMD_PREFIX{$n}) {
            $k++;
            $k++ if $n eq 'timeout' && $k < @$words && $words->[$k]{t} =~ /^[0-9.]+[smhd]?$/;
            while ($k < @$words && $words->[$k]{t} =~ /^-/) {
                my $a = $words->[$k]{t};
                if ($VALUE_FLAG{$a}) { $k += 2 } else { $k++ }
            }
            return ($k, 0, $private, undef) if $k < @$words;
            return (undef, 0, $private, undef);
        }
        return ($k, $unset{TMUX} ? 1 : 0, $private, undef);
    }
    return (undef, 0, 0, undef);
}

# 从命令词里取子命令与 -L/-S 证据
sub subcommand_and_route {
    my ($words, $ci) = @_;
    my ($minus_L, $minus_S, $sub) = (undef, undef, '');
    # 先扫全命令里的 -L/-S（写在子命令后面也算）
    for (my $j = $ci + 1; $j < @$words; $j++) {
        my $a = $words->[$j]{t};
        if ($a =~ /^-L(.*)$/s && !defined $minus_L) { $minus_L = $1 ne '' ? $1 : ($words->[$j + 1]{t} // '') }
        if ($a =~ /^-S(.*)$/s && !defined $minus_S) { $minus_S = $1 ne '' ? $1 : ($words->[$j + 1]{t} // '') }
    }
    my $k = $ci + 1;      # 跳过选项；带值的选项把值一起跳掉（-L name / -S path / -t target …）
    # M67：闸门的 argv token 是**全局选项**（`tmux --teamsmith-allow-destructive kill-server`）——
    # 按普通开关跳过，子命令照旧被识别（token 既不能藏调用，也不算隔离证据）。
    while ($k < @$words && $words->[$k]{t} =~ /^-/) {
        if ($VALUE_FLAG{ $words->[$k]{t} }) { $k += 2; next }
        $k++;
    }
    $sub = $words->[$k]{t} if $k < @$words;
    my $plus_L = defined($minus_L) && $minus_L ne '' && $minus_L ne 'default';
    my $plus_S = defined($minus_S) && $minus_S ne '' && $minus_S !~ m{/default$};
    return ($sub, $plus_L, $plus_S, $minus_L, $minus_S);
}

# 包装表：目录/文件 → 名字 → 1（自身隔离）/ 0（碰 tmux 但不隔离）
my (%WRAP_DIR, %WRAP_FILE);
sub collect_wrappers {
    my ($file, $src) = @_;
    my @lines = split /\n/, $src, -1;
    for my $idx (0 .. $#lines) {
        next unless $lines[$idx] =~ /^\s*(?:function\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{?/;
        my $name = $1;
        my $body = $lines[$idx];
        my $j = $idx;
        while ($j < $#lines && $j < $idx + 6) {
            last if $j > $idx && $lines[$j] =~ /^\s*\}\s*$/;
            $body .= "\n" . $lines[$j + 1];
            $j++;
        }
        next unless $body =~ /(^|[^\w.\/-])tmux([^\w.\/-]|$)/;      # 函数体里碰了 tmux → 当成 tmux 包装
        my $L  = ($body =~ /-[LS]\s+(?!default\b)\S/) ? 1 : 0;
        my $un = ($body =~ /env\s[^\n]*?-u\s+TMUX\b/ || $body =~ /(^|\n)\s*unset\b[^\n]*\bTMUX\b/) ? 1 : 0;
        my $td = ($body =~ /TMUX_TMPDIR=(?:"[^"]+"|'[^']+'|\$\{?[A-Za-z_][A-Za-z0-9_]*\}?|[\w.\/-]+)/) ? 1 : 0;
        my $iso = ($L || ($un && $td)) ? 1 : 0;
        $WRAP_FILE{$file}{$name} = $iso;
        my $d = dirname($file);
        $WRAP_DIR{$d}{$name} = 1 if !exists $WRAP_DIR{$d}{$name};
        $WRAP_DIR{$d}{$name} = $iso if $iso;
    }
}
sub wrapper_iso {
    my ($file, $name) = @_;
    return $WRAP_FILE{$file}{$name} if exists $WRAP_FILE{$file}{$name};
    my $d = dirname($file);
    return $WRAP_DIR{$d}{$name} if exists $WRAP_DIR{$d}{$name};
    return undef;    # 不是已知包装
}

# ── 一个文件的分析 ───────────────────────────────────────────────────────────────────────────────
# 返回 (@invocations, @hits)。$file_state = { unset => 0/1, private => 0/1 }（跨命令累计）
sub analyze_source {
    my ($file, $src, $state) = @_;
    my (@inv, @hits);
    for my $cmd (parse_source($src, $file, 0)) {
        my @w = @{ $cmd->{words} };
        if (@w) {
            my ($ci, $env_unset, $private_here, $shellscript) = resolve_command(\@w);
            if (defined $ci) {
                my $cw = $w[$ci]{t};
                my $wrap_iso = wrapper_iso($file, cmd_name($cw));
                my $wrapper  = defined $wrap_iso ? 1 : 0;
                if (is_tmux_word($cw) || $wrapper) {
                    my ($sub, $plus_L, $plus_S, $mL, $mS) = subcommand_and_route(\@w, $ci);
                    if ($MUTATING{$sub}) {
                        my $unset_ok = $wrap_iso ? 1 : ($env_unset || ($state->{unset} ? 1 : 0));
                        my $dir_ok   = $wrap_iso ? 1 : ($private_here || ($state->{private} ? 1 : 0));
                        my $abs_bypass = is_literal_abs_path_word($cw);
                        my $ok = ($wrap_iso || $plus_L || $plus_S || ($unset_ok && $dir_ok)) ? 1 : 0;
                        $ok = 0 if $abs_bypass;                       # M41：绝对路径绕过 PATH 闸门，证据再多也红
                        my @missing;
                        push @missing, '-L/-S' unless ($wrap_iso || $plus_L || $plus_S);
                        push @missing, 'unset TMUX' unless $unset_ok;
                        push @missing, '私有 TMUX_TMPDIR' unless $dir_ok;
                        @missing = ("包装 " . cmd_name($cw) . " 自己没隔离（调用点也没带）") if ($wrapper && !$wrap_iso);
                        unshift @missing, '字面绝对路径（绕过 PATH 里的 tmux 闸门；M41 起禁止）' if $abs_bypass;
                        my $why = $ok ? '' : join(' + ', @missing);
                        my %ev = (L => $plus_L, S => $plus_S, unset => $unset_ok, dir => $dir_ok, wrapper => $wrap_iso ? 1 : 0,
                                  abs => $abs_bypass);
                        my $rec = { file => $file, line => $cmd->{line}, sub => $sub, ok => $ok, why => $why, ev => \%ev,
                                    text => join(' ', map { $_->{t} } @w[$ci .. $#w]) };
                        push @inv, $rec;
                        push @hits, $rec unless $ok;
                    }
                }
            }
            # bash -c '…'：递归（字符串里的调用同样要证据；文件级白名单不继承给字符串？——
            # 字符串在同一个 shell 进程里跑，继承文件级状态，所以照样传下去）
            if (defined $shellscript) {
                my ($i2, $h2) = analyze_source($file, $shellscript, $state);
                for my $r (@$i2) { $r->{line} = $cmd->{line}; $r->{text} = "(bash -c) " . $r->{text}; $r->{shell_string} = 1 }
                push @inv, @$i2;
                push @hits, @$h2;
            }
            # 顶层命令 → 更新文件级白名单状态（口径 D）
            if (!$cmd->{depth} && $cmd->{line}) {
                my $joined = join ' ', map { $_->{t} } @w;
                if ($w[0]{t} eq 'unset' || ($w[0]{t} eq 'export' && ($w[1]{t} // '') eq '-n')) {
                    my $names = join ' ', map { $_->{t} } @w[1 .. $#w];
                    $state->{unset} = 1 if $names =~ /\bTMUX\b/;
                }
                if ($joined =~ /(^|\s)(?:export\s+)?TMUX=(\S*)/) {
                    # 又把 TMUX 指回默认 socket（字面 /default）→ 文件级白名单失效；指向私有 socket 不算
                    $state->{unset} = 0 if $2 =~ m{/default};
                }
                if (grep { private_tmpdir_word($_->{t}) } @w) { $state->{private} = 1 }
            }
        }
    }
    return (\@inv, \@hits);
}

# 两趟：先收包装（同目录互认），再判定
for my $file (@FILES) {
    open(my $fh, '<', $file) or next;
    local $/; my $src = <$fh>; close $fh;
    next unless defined $src && $src =~ /tmux/;
    collect_wrappers($file, $src);
}
my (@ALL_INV, @ALL_HITS, @SCANNED);
for my $file (@FILES) {
    open(my $fh, '<', $file) or next;
    local $/; my $src = <$fh>; close $fh;
    next unless defined $src && $src =~ /tmux/;
    push @SCANNED, $file;
    my $state = { unset => 0, private => 0 };
    my ($inv, $hits) = analyze_source($file, $src, $state);
    push @ALL_INV, @$inv;
    push @ALL_HITS, @$hits;
}

# ── 历史豁免（M28 之前的证据包：按内容哈希冻结；文件一改豁免就失效）──────────────────────────────
# 为什么要有这一条：M28 之前的对抗性证据包（docs/team/reports/*/pkg/）写于隔离纪律成型之前，它们
# 里的裸 tmux 调用不能就地改（那是别人验过的证据，改了就动了账本）。豁免必须**可审计**：
#   * 按 sha256 冻结 —— 文件被改（包括修掉裸调用）→ 豁免失效，按普通文件重新判定；
#   * 条数记在清单里，与实际不符 → 红（baseline 过期）；
#   * 每轮都打印豁免条数与文件（不静默），--no-legacy 让它们全部报红（人工审计用）。
my %LEGACY;    # 相对路径 → { sha, count, reason }
my %LEGACY_SHA;
sub load_legacy {
    my ($f) = @_;
    return unless defined $f && -f $f;
    open(my $fh, '<', $f) or die "tmux-lint: 读不了豁免清单 $f: $!\n";
    while (my $l = <$fh>) {
        next if $l =~ /^\s*#/ || $l =~ /^\s*$/;
        if ($l =~ /^\s*([0-9a-f]{64})\s+(\d+)\s+(\S+)\s*(?:#\s*(.*?))?\s*$/) {
            my ($sha, $n, $p, $why) = ($1, $2, $3, $4 // '');
            $LEGACY{$p} = { sha => $sha, count => $n, reason => $why };
            $LEGACY_SHA{$sha} = $p;
        } else {
            die "tmux-lint: 豁免清单格式不对：$l";
        }
    }
    close $fh;
}
sub sha256_file {
    require Digest::SHA;
    open(my $fh, '<', $_[0]) or return '';
    binmode $fh;
    my $d = Digest::SHA->new(256);
    $d->addfile($fh);
    close $fh;
    return $d->hexdigest;
}

# ── 输出 ─────────────────────────────────────────────────────────────────────────────────────────
sub pretty { my $p = shift; my $r = "$REPO/"; $p =~ s/^\Q$r\E//; return $p }
my $n_mut = scalar @ALL_INV;
my $n_hits = scalar @ALL_HITS;

# ── 历史豁免判定（sha256 冻结；文件一改豁免就失效）───────────────────────────────────────
my $LEGACY_DEFAULT = File::Spec->catfile(dirname(abs_path($0)), 'tmux-lint-legacy.txt');
$LEGACY_FILE = $LEGACY_DEFAULT if !defined $LEGACY_FILE;
load_legacy($LEGACY_FILE) unless ($NO_LEGACY || ($EXPLICIT_ROOTS && !$EXPLICIT_LEGACY));
my (%sha_cache, %legacy_hits, %legacy_files, @red_hits, @baseline_problems);
sub file_hash { my $f = shift; $sha_cache{$f} //= sha256_file($f); return $sha_cache{$f} }
sub rel_abs   { my $rel = shift; return (-f $rel) ? $rel : File::Spec->catfile($REPO, $rel) }

# ① 先按豁免把命中分成两类
for my $r (@ALL_HITS) {
    my $rel   = pretty($r->{file});
    my $entry = $LEGACY{$rel};
    if ($entry && file_hash($r->{file}) eq $entry->{sha}) {
        $legacy_hits{$rel}++;
        $legacy_files{$rel} = $entry;
    } else {
        push @red_hits, $r;
    }
}
# ② 清单本身要诚实：文件不在了 / 条数对不上 / 文件改了都要说清楚
for my $rel (sort keys %LEGACY) {
    my $abs   = rel_abs($rel);
    my $entry = $LEGACY{$rel};
    if (!-f $abs) { push @baseline_problems, "$rel：清单里的文件不在了（删文件就同时删豁免行）"; next }
    my $actual = scalar grep { pretty($_->{file}) eq $rel } @ALL_HITS;
    if (file_hash($abs) eq $entry->{sha}) {
        push @baseline_problems, "$rel：豁免清单记 $entry->{count} 条，实际 $actual 条（baseline 过期）"
            if $actual != $entry->{count};
    } elsif ($actual > 0) {
        push @red_hits, grep { pretty($_->{file}) eq $rel } @ALL_HITS;
        push @baseline_problems, "$rel：文件已改（sha 不再匹配）→ 豁免失效，本文件按普通文件判（$actual 条红）";
    }
}
my $n_legacy = 0; $n_legacy += $_ for values %legacy_hits;

# --write-legacy：把当前未豁免的命中写成清单（只允许写 docs/ 历史证据包；tests/ 必须真修）
if (defined $WRITE_LEGACY) {
    if ($EXPLICIT_ROOTS) { print STDERR "tmux-lint: --write-legacy 只在默认扫描范围下有意义（不用 --root）\n"; exit 2 }
    my %by_file;
    push @{ $by_file{ pretty($_->{file}) } }, $_ for grep { pretty($_->{file}) !~ m{^skills/teamsmith/tests/} } @ALL_HITS;
    open(my $out, '>', $WRITE_LEGACY) or die "tmux-lint: 写不了 $WRITE_LEGACY: $!\n";
    print $out "# M28 tmux-lint 历史豁免清单（--write-legacy 生成）：M28 之前的对抗性证据包，写于隔离纪律成型之前。\n";
    print $out "# 格式：<sha256>  <未隔离条数>  <仓库相对路径>  # 理由\n";
    print $out "# 冻结语义：这些文件的 sha256 一旦变化（包括修掉裸调用）豁免就失效，按普通文件重新判定。\n";
    for my $rel (sort keys %by_file) {
        my $abs = rel_abs($rel);
        my $rule = ($rel =~ m{^docs/team/reports/([^/]+)/}) ? "$1 证据包（M28 之前）" : '历史文件（M28 之前）';
        printf $out "%s  %d  %s  # %s\n", file_hash($abs), scalar @{ $by_file{$rel} }, $rel, $rule;
    }
    close $out;
    my $n = 0; $n += @$_ for values %by_file;
    printf "tmux-lint: 写了豁免清单 %s（%d 个文件 / %d 条）\n", $WRITE_LEGACY, scalar(keys %by_file), $n;
    if (grep { pretty($_->{file}) =~ m{^skills/teamsmith/tests/} } @ALL_HITS) {
        printf STDERR "tmux-lint: 注意：tests/ 里还有未隔离的调用，它们**没有**被写入豁免（tests/ 必须真修）\n";
    }
    exit 0;
}

if (!$QUIET && $LIST) {
    for my $r (sort { $a->{file} cmp $b->{file} || $a->{line} <=> $b->{line} } @ALL_INV) {
        printf "%-4s %s:%d  %s\n", ($r->{ok} ? 'ok' : 'RED'), pretty($r->{file}), $r->{line}, $r->{text};
    }
}
if (!$QUIET) {
    for my $r (sort { $a->{file} cmp $b->{file} || $a->{line} <=> $b->{line} } @red_hits) {
        printf "  RED  %s:%d  %s\n", pretty($r->{file}), $r->{line}, $r->{text};
        printf "       缺：%s%s\n", $r->{why}, ($r->{shell_string} ? "（bash -c 字符串里）" : "");
    }
    for my $rel (sort keys %legacy_hits) {
        printf "  LEGACY  %s  ×%d  —— %s\n", $rel, $legacy_hits{$rel},
            ($legacy_files{$rel}{reason} || 'M28 之前的历史证据包');
    }
    printf "  ✗ tmux-lint: baseline —— %s\n", $_ for @baseline_problems;
    if (@red_hits) {
        printf "tmux-lint：%d 条变更命令没有隔离证据（扫描 %d 个脚本，其中 %d 条变更命令；历史豁免另算 %d 条）\n",
            scalar @red_hits, scalar @SCANNED, $n_mut, $n_legacy;
    } elsif (@baseline_problems) {
        printf "tmux-lint：豁免清单过期（%d 个问题；扫描 %d 个脚本）\n", scalar @baseline_problems, scalar @SCANNED;
    } elsif ($n_legacy) {
        printf "tmux-lint：红 0 条；另有 %d 条落在**历史豁免**的 %d 个文件里（M28 之前的证据包，按 sha256 冻结；--no-legacy 可让它们全部报红）\n",
            $n_legacy, scalar(keys %legacy_hits);
    } else {
        printf "tmux-lint：干净（扫描 %d 个脚本，%d 条变更命令全部有隔离证据）\n", scalar @SCANNED, $n_mut;
    }
}
$n_hits = scalar(@red_hits) + scalar(@baseline_problems);

# ── 自检：双向夹具 ───────────────────────────────────────────────────────────────────────────────
if ($SELFTEST) {
    require File::Temp;
    require File::Path;
    my $tmp = File::Temp::tempdir('tmux-lint-selftest.XXXXXX', TMPDIR => 1, CLEANUP => 1);
    my @cases = (
        ['bare',                   "tmux kill-server\n", 1],
        ['bare_new_session',       "tmux new-session -d -s x 'sleep 5'\n", 1],
        ['unset_without_private',  "unset TMUX\nTMUX_TMPDIR=/tmp\ntmux kill-server\n", 1],
        ['env_u_without_dir',      "env -u TMUX -u TMUX_PANE tmux kill-server\n", 1],
        ['env_u_private_dir',      "env -u TMUX -u TMUX_PANE TMUX_TMPDIR=\"\$D\" tmux kill-server\n", 0],
        ['minus_L',                "tmux -L private-name kill-server\n", 0],
        ['minus_L_default',        "tmux -L default kill-server\n", 1],
        ['minus_S_private',        "tmux -S \"\$TD/tmux-\$(id -u)/own\" kill-server\n", 0],
        ['wrapper',                "xtm() { env -u TMUX -u TMUX_PANE TMUX_TMPDIR=\"\$D\" tmux \"\$@\"; }\nxtm kill-session -t x\n", 0],
        ['wrapper_L',              "wtm() { tmux -L wtm-private \"\$@\"; }\nwtm new-window -d\n", 0],
        ['wrapper_not_isolated',   "btm() { tmux \"\$@\"; }\nbtm kill-server\n", 1],
        ['file_level_unset_dir',   "unset TMUX TMUX_PANE\nTMUX_TMPDIR=\"\$D\"\nexport TMUX_TMPDIR\ntmux kill-session -t x\n", 0],
        ['file_level_order',       "tmux kill-session -t x\nunset TMUX TMUX_PANE\nTMUX_TMPDIR=\"\$D\"\nexport TMUX_TMPDIR\n", 1],
        ['bash_c_string',          "bash -c 'tmux kill-server'\n", 1],
        ['bash_c_string_isolated', "bash -c 'env -u TMUX TMUX_TMPDIR=\"\$D\" tmux kill-server'\n", 0],
        ['comment',               "# tmux kill-server\n", 0],
        ['doc_quoted_string',      "echo 'tmux kill-server 的说明文字'\n", 0],
        ['readonly_cmd',           "tmux capture-pane -p -t x\n", 0],
        ['if_then',                "if true; then tmux kill-server; fi\n", 1],
        ['quoted_heredoc_data',    "cat > f <<'EOT'\ntmux kill-server\nEOT\n", 0],
        ['unquoted_heredoc_code',  "cat > f <<EOT\ntmux kill-server\nEOT\n", 1],
        ['flag_value_skip',        "tmux -L private-name -f /dev/null new-session -d -s y\n", 0],
        ['multi_line_cont',        "tmux -L private-name \\\n  kill-server\n", 0],
        ['inside_subst',           "x=\"\$(tmux -L private-name list-sessions)\"; tmux kill-server\n", 1],
        ['shim_not_enough',        "SH=\"\$T/shim\"\nPATH=\"\$SH:\$PATH\"\n\"\$SH/tmux\" kill-server\n", 1],
        # M67：闸门的 argv token 是全局选项 —— 变更调用照旧被识别（token 不能藏调用），
        # 但 token 不是隔离证据（裸的仍红）；带私有 -L 的照旧净。
        ['gate_token_bare',        "tmux --teamsmith-allow-destructive kill-server\n", 1],
        ['gate_token_private',     "tmux --teamsmith-allow-destructive -L private-name kill-server\n", 0],
        ['gate_token_after_sub',   "tmux kill-window --teamsmith-allow-destructive\n", 1],
        # M41：字面绝对路径 = 绕过 PATH 闸门 —— 变更命令一律红（带隔离证据也红）；变量形式照旧
        ['abs_path_bare',          "/usr/bin/tmux kill-server\n", 1],
        ['abs_path_with_private',  "/usr/bin/tmux -L private-name kill-server\n", 1],
        ['abs_path_readonly',      "/usr/bin/tmux ls\n", 0],
        ['command_abs_path',       "command /usr/bin/tmux kill-server\n", 1],
        ['real_tmux_var_iso',      "REAL_TMUX=/usr/bin/tmux\n\"\$REAL_TMUX\" -L private-name kill-server\n", 0],
        ['real_tmux_var_no_iso',   "REAL_TMUX=/usr/bin/tmux\n\"\$REAL_TMUX\" kill-server\n", 1],
        ['braced_tmux_var_iso',    "TMUX_BIN=/usr/bin/tmux\n\"\${TMUX_BIN}\" -L private-name kill-server\n", 0],
    );
    my $bad = 0;
    for my $c (@cases) {
        my ($name, $src, $want) = @$c;
        my $dir = File::Spec->catdir($tmp, $name);
        File::Path::make_path($dir);
        my $f = File::Spec->catfile($dir, 'case.sh');
        open(my $o, '>', $f) or die "写不了 $f: $!";
        print $o $src;
        close $o;
        my $rc = system($^X, abs_path($0), '--root', $dir, '--quiet') >> 8;
        my $got = $rc ? 1 : 0;
        my $ok = ($got == $want);
        printf "  %s selftest %-22s 期望%s 实际%s%s\n",
            ($ok ? 'ok ' : 'BAD'), $name, ($want ? '红' : '净'), ($got ? '红' : '净'),
            ($ok ? '' : "   ← 夹具 $f");
        $bad++ unless $ok;
    }
    if ($bad) { printf "✗ tmux-lint --selftest：%d/%d 个夹具不符合预期\n", $bad, scalar @cases; exit 1 }

    # 历史豁免机制的双向自检：哈希锁定住 → 净；文件一改 → 红；条数不对 → 红。
    my $lg_dir  = File::Spec->catdir($tmp, 'legacy');
    File::Path::make_path($lg_dir);
    my $lg_file = File::Spec->catfile($lg_dir, 'case.sh');
    open(my $lo, '>', $lg_file) or die "写不了 $lg_file: $!";
    print $lo "tmux kill-server\n";
    close $lo;
    my $lg_sha = sha256_file($lg_file);
    my $lg_list = File::Spec->catfile($tmp, 'legacy.txt');
    my $write_list = sub {
        my ($sha, $n) = @_;
        open(my $lf, '>', $lg_list) or die "写不了 $lg_list: $!";
        print $lf "$sha  $n  $lg_file  # selftest 夹具\n";
        close $lf;
    };
    my $lg_check = sub {    # <说明> <期望> <跑法…>
        my ($what, $want, @args) = @_;
        my $rc = system($^X, abs_path($0), '--root', $lg_dir, '--legacy', $lg_list, '--quiet', @args) >> 8;
        my $got = $rc ? 1 : 0;
        my $ok = ($got == $want);
        printf "  %s selftest %-22s 期望%s 实际%s\n", ($ok ? 'ok ' : 'BAD'), $what,
            ($want ? '红' : '净'), ($got ? '红' : '净');
        $bad++ unless $ok;
    };
    $write_list->($lg_sha, 1);
    $lg_check->('exempt_hash_pinned', 0);
    $write_list->($lg_sha, 2);
    $lg_check->('exempt_bad_count', 1);
    $write_list->('0' x 64, 1);
    $lg_check->('exempt_stale_hash', 1);
    printf "\n";

    if ($bad) { printf "✗ tmux-lint --selftest：%d 个夹具不符合预期（含豁免机制）\n", $bad; exit 1 }
    printf "✓ tmux-lint --selftest：%d 个夹具 + 历史豁免机制全部符合预期（该红的红、该净的净）\n", scalar @cases;
    # --selftest 的退出码只对**夹具结果**负责（真树由不带 --selftest 的那一次判定）——否则门禁里
    # 「真树有裸调用」会让 selftest 这一条也红，翻转信号就变成两条、看不出是谁在报。
    printf "  （注：本次只判夹具；真树扫描见不带 --selftest 的那一次）\n" if $n_hits;
    exit 0;
}

exit($n_hits ? 1 : 0);
