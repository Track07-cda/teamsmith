#!/usr/bin/env perl
# P159 · 信号纪律 lint（safe-signal-discipline · boundary#Scripts select processes by recorded pid）
#
#   扫描仓库脚本/夹具里的**按名字或谓词选进程**的调用，没有记录过的 pid → 红（exit 1）。
#
#   为什么要有这条门禁：三次同族事故（D37 dev3 按模式 SIGSTOP 冻结别人的夹具；D57/#1529 用
#   pgrep -f 取到自己的 shell 并给自己发信号；D72 pkill -f 误杀同期门禁客户端）都发生在
#   窗口里的 ad-hoc 调用上 —— 运行时那一半由 scripts/shim/signal-gate 管，**仓库脚本这一半**
#   只能静态管，这条 lint 就是那一半。
#
#   判定（红）：
#     A. `pkill` / `killall` 命令词（含 `command`/`env` 前缀；含字面绝对路径 /usr/bin/pkill）；
#     B. `xargs` 的参数里有 kill/pkill/killall（stdin 就是选择，没有记录过的 pid）；
#     C. `kill` 的参数里带对 pgrep/pidof/ps/fuser 的命令替换（谓词选出进程集合）。
#   判定（净）：pid 精确形态 —— `kill -TERM "$pid"`、`kill -0 "$pid"`、`kill -- -"$pgid"`、
#     `kill "$pid1" "$pid2"`、`kill "$(cat "$pidfile")"`。
#
#   已知边界（免得被当成保证）：变量里的可执行路径（`"$GATE/pkill"`）静态看不出来 —— 那是
#   闸门自己的入口形态，也是本 lint 的明说边界；绝对路径与裸名字是静态能看见的两类。
#
#   扫描范围与 tmux 隔离 lint 相同：skills/teamsmith/tests/** 与 docs/team/reports/*/pkg/**。
#   tests/ **不许**进豁免清单（必须真修）；M28 之前的历史证据包按 sha256 冻结在
#   tests/signal-lint-legacy.txt（条数每轮核对、每轮打印，--no-legacy 让它们全部报红）。
#
#   用法：
#     perl tests/signal-lint.pl [--root DIR]… [--list] [--quiet] [--legacy FILE] [--no-legacy]
#     perl tests/signal-lint.pl --selftest                        # 双向夹具（该红的红、该净的净）
#   exit: 0 干净 ｜ 1 有按名字/谓词选进程的调用 ｜ 2 用法/环境错误
use strict;
use warnings;
use File::Basename qw(dirname basename);
use File::Find ();
use Cwd qw(abs_path);
use File::Spec;

my %EXTS = map { $_ => 1 } qw(.sh .bash .pl .py .mjs .cjs .js .ts);
# 命令位包装（后面仍期待真正的命令词）
my %CMD_PREFIX = map { $_ => 1 } qw(command exec nohup builtin time setsid stdbuf nice ionice timeout sudo);
my %SHELLS     = map { $_ => 1 } qw(bash sh dash zsh ksh ash sh5);
my %VALUE_FLAG = map { $_ => 1 } qw(-c -f -n -s -u -x -y --user --signal -t);

my (@ROOTS, $LIST, $QUIET, $SELFTEST, $NO_LEGACY, $LEGACY_FILE, $EXPLICIT_ROOTS, $EXPLICIT_LEGACY);
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
    elsif ($a eq '--help' || $a eq '-h') { print "用法见文件头注释\n"; exit 0 }
    else { print STDERR "signal-lint: 未知参数 $a\n"; exit 2 }
}

my $REPO = abs_path(File::Spec->catdir(dirname(abs_path($0)), '..', '..', '..'));
die "signal-lint: 解析不到仓库根（$0）\n" unless defined $REPO && -d $REPO;

# ── 扫描范围（与 tmux-lint.pl 相同）────────────────────────────────────────────────────────────
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
@ROOTS = map { abs_path($_) // $_ } @ROOTS;

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

# ── 词法分析器（与 tmux 隔离 lint 共用一份）────────────────────────────────────────────────────
require File::Spec->catfile(dirname(abs_path($0)), 'lib', 'shell-lex.pl');

sub cmd_name { my $t = shift // ''; $t =~ s{^.*/}{}; $t =~ s/^(['"])(.*)\1$/$2/; return $t }

# 字面名字（可带引号）是不是 pkill/killall：裸名字，或**字面绝对路径**。/usr/bin/pkill 是静态能
# 看见的；`"$GATE/pkill"` 这种变量路径静态看不见（明说的边界，见文件头）。
sub is_signal_tool {
    my $t = shift // '';
    $t =~ s/^(['"])(.*)\1$/$2/s;
    return 1 if $t eq 'pkill' || $t eq 'killall';
    return 1 if $t =~ m{^/} && cmd_name($t) =~ /^(pkill|killall)$/;
    return 0;
}

# 命令词 → 命令位解析（跳过赋值/env/包装；识别 shell -c 脚本串）。
# 返回 (cmd_index, shell_string)。
sub resolve_command {
    my ($words) = @_;
    my $start = 0;
    $start++ while $start < @$words && !$words->[$start]{cmd};
    my $k = $start;
    while ($k < @$words) {
        my $t = $words->[$k]{t};
        if ($t =~ /^[A-Za-z_][A-Za-z0-9_]*(\+)?=/) { $k++; next }
        my $n = cmd_name($t);
        if ($n eq 'env') {
            $k++;
            while ($k < @$words) {
                my $a = $words->[$k]{t};
                if ($a =~ /^[A-Za-z_][A-Za-z0-9_]*=/) { $k++; next }
                if ($a =~ /^-/) { $k++; next }
                last;
            }
            next;
        }
        if ($SHELLS{$n}) {
            my $j = $k + 1;
            my $cflag = 0;
            while ($j < @$words && $words->[$j]{t} =~ /^-/) {
                $cflag = 1 if $words->[$j]{t} =~ /^-[A-Za-z]*c[A-Za-z]*$/;
                $j++;
            }
            return (undef, $words->[$j]{t}) if $cflag && $j < @$words && $words->[$j]{q};
            return (undef, undef);
        }
        if ($CMD_PREFIX{$n}) {
            # `command -v killall` / `type -v pkill` 是**查名字**不是发信号 → 只读，净
            my $lookup = ($n eq 'command' || $n eq 'type' || $n eq 'builtin') ? 1 : 0;
            $k++;
            $k++ if $n eq 'timeout' && $k < @$words && $words->[$k]{t} =~ /^[0-9.]+[smhd]?$/;
            while ($k < @$words && $words->[$k]{t} =~ /^-/) {
                my $a = $words->[$k]{t};
                return (undef, undef) if $lookup && ($a eq '-v' || $a eq '-V');
                if ($VALUE_FLAG{$a}) { $k += 2 } else { $k++ }
            }
            next;
        }
        return ($k, undef);
    }
    return (undef, undef);
}

# ── 一个文件的分析 ───────────────────────────────────────────────────────────────────────────────
# 返回 (@inv, @hits)：inv = 每个信号相关命令（ok/red + 理由），hits = 红的那些。
sub analyze_source {
    my ($file, $src, $line_base) = @_;
    my (@inv, @hits);
    for my $cmd (ShellLex::parse_source($src, $file, 0)) {
        my @w = @{ $cmd->{words} };
        next unless @w;
        my $line = $cmd->{line} + ($line_base // 0);
        my ($ci, $shellscript) = resolve_command(\@w);
        if (defined $ci) {
            my $cw = $w[$ci]{t};
            my $text = join(' ', map { $_->{t} } @w[$ci .. $#w]);
            my $rec;
            my $relevant = 0;
            if (is_signal_tool($cw)) {
                $relevant = 1;
                $rec = { file => $file, line => $line, text => $text,
                         why => '按名字/模式选进程（pkill/killall）：名字不是身份' };
            } elsif (cmd_name($cw) eq 'xargs') {
                $relevant = 1;
                for my $j ($ci + 1 .. $#w) {
                    my $a = cmd_name($w[$j]{t});
                    if ($a eq 'kill' || $a eq 'pkill' || $a eq 'killall') {
                        $rec = { file => $file, line => $line, text => $text,
                                 why => "xargs 的 $a：stdin 就是选择，没有记录过的 pid" };
                        last;
                    }
                }
            } elsif (cmd_name($cw) eq 'kill') {
                $relevant = 1;
                for my $j ($ci + 1 .. $#w) {
                    my @sub = @{ $w[$j]{subst} || [] };
                    my @bad = grep { my $b = cmd_name($_); $b eq 'pgrep' || $b eq 'pidof' || $b eq 'ps' || $b eq 'fuser' } @sub;
                    if (@bad) {
                        $rec = { file => $file, line => $line, text => $text,
                                 why => 'kill 的参数里有对 ' . join('/', @bad) . ' 的命令替换：进程集合由谓词选出' };
                        last;
                    }
                }
            }
            if ($relevant) {
                if ($rec) { push @inv, { %$rec, ok => 0 }; push @hits, $rec }
                else      { push @inv, { file => $file, line => $line, text => $text, ok => 1 } }
            }
        }
        if (defined $shellscript) {
            my ($i2, $h2) = analyze_source($file, $shellscript, $line - 1);
            for my $r (@$i2) { $r->{text} = "(bash -c) " . $r->{text}; $r->{shell_string} = 1 }
            push @inv, @$i2;
            push @hits, @$h2;
        }
    }
    return (\@inv, \@hits);
}

my (@ALL_INV, @ALL_HITS, @SCANNED);
for my $file (@FILES) {
    open(my $fh, '<', $file) or next;
    local $/; my $src = <$fh>; close $fh;
    next unless defined $src && $src =~ /(pkill|killall|xargs|kill)/;
    push @SCANNED, $file;
    my ($inv, $hits) = analyze_source($file, $src, 0);
    push @ALL_INV, @$inv;
    push @ALL_HITS, @$hits;
}

# ── 历史豁免（与 tmux 家族同形：sha256 冻结、条数核对、每轮打印、--no-legacy 全红）───────────────
my %LEGACY;
my %LEGACY_SHA;
sub load_legacy {
    my ($f) = @_;
    return unless defined $f && -f $f;
    open(my $fh, '<', $f) or die "signal-lint: 读不了豁免清单 $f: $!\n";
    while (my $l = <$fh>) {
        next if $l =~ /^\s*#/ || $l =~ /^\s*$/;
        if ($l =~ /^\s*([0-9a-f]{64})\s+(\d+)\s+(\S+)\s*(?:#\s*(.*?))?\s*$/) {
            my ($sha, $n, $p, $why) = ($1, $2, $3, $4 // '');
            $LEGACY{$p} = { sha => $sha, count => $n, reason => $why };
            $LEGACY_SHA{$sha} = $p;
        } else {
            die "signal-lint: 豁免清单格式不对：$l";
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
sub pretty { my $p = shift; my $r = "$REPO/"; $p =~ s/^\Q$r\E//; return $p }
sub rel_abs { my $rel = shift; return (-f $rel) ? $rel : File::Spec->catfile($REPO, $rel) }

my $LEGACY_DEFAULT = File::Spec->catfile(dirname(abs_path($0)), 'signal-lint-legacy.txt');
$LEGACY_FILE = $LEGACY_DEFAULT if !defined $LEGACY_FILE;
load_legacy($LEGACY_FILE) unless ($NO_LEGACY || ($EXPLICIT_ROOTS && !$EXPLICIT_LEGACY));

my (%sha_cache, %legacy_hits, %legacy_files, @red_hits, @baseline_problems);
sub file_hash { my $f = shift; $sha_cache{$f} //= sha256_file($f); return $sha_cache{$f} }
sub in_tests { my $rel = shift; return $rel =~ m{^skills/teamsmith/tests/} ? 1 : 0 }

# ① 豁免只对**不在 tests/ 下**的命中生效：tests/ 的违规必须真修，永远不进豁免
for my $r (@ALL_HITS) {
    my $rel   = pretty($r->{file});
    my $entry = in_tests($rel) ? undef : $LEGACY{$rel};
    if ($entry && file_hash($r->{file}) eq $entry->{sha}) {
        $legacy_hits{$rel}++;
        $legacy_files{$rel} = $entry;
    } else {
        push @red_hits, $r;
    }
}
# ② 清单本身要诚实：文件不在了 / 条数对不上 / 文件改了 / 试图豁免 tests/ 都要说清楚
for my $rel (sort keys %LEGACY) {
    my $abs   = rel_abs($rel);
    my $entry = $LEGACY{$rel};
    if (in_tests($rel)) {
        push @baseline_problems, "$rel：tests/ 不许进豁免清单（必须真修）；它的命中照红";
        push @red_hits, grep { pretty($_->{file}) eq $rel } @ALL_HITS;
        next;
    }
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

if (!$QUIET && $LIST) {
    for my $r (sort { $a->{file} cmp $b->{file} || $a->{line} <=> $b->{line} } @ALL_INV) {
        printf "%-4s %s:%d  %s\n", ($r->{ok} ? 'ok' : 'RED'), pretty($r->{file}), $r->{line}, $r->{text};
    }
}
if (!$QUIET) {
    for my $r (sort { $a->{file} cmp $b->{file} || $a->{line} <=> $b->{line} } @red_hits) {
        printf "  RED  %s:%d  %s\n", pretty($r->{file}), $r->{line}, $r->{text};
        printf "       %s%s\n", $r->{why}, ($r->{shell_string} ? "（bash -c 字符串里）" : "");
    }
    for my $rel (sort keys %legacy_hits) {
        printf "  LEGACY  %s  ×%d  —— %s\n", $rel, $legacy_hits{$rel},
            ($legacy_files{$rel}{reason} || 'M28 之前的历史证据包');
    }
    printf "  ✗ signal-lint: baseline —— %s\n", $_ for @baseline_problems;
    if (@red_hits) {
        printf "signal-lint：%d 条按名字/谓词选进程的调用（扫描 %d 个脚本；历史豁免另算 %d 条）\n",
            scalar @red_hits, scalar @SCANNED, $n_legacy;
    } elsif (@baseline_problems) {
        printf "signal-lint：豁免清单过期（%d 个问题；扫描 %d 个脚本）\n", scalar @baseline_problems, scalar @SCANNED;
    } elsif ($n_legacy) {
        printf "signal-lint：红 0 条；另有 %d 条落在**历史豁免**的 %d 个文件里（按 sha256 冻结；--no-legacy 可让它们全部报红）\n",
            $n_legacy, scalar(keys %legacy_hits);
    } else {
        printf "signal-lint：干净（扫描 %d 个脚本；pid 精确形态全部干净）\n", scalar @SCANNED;
    }
}

# ── 自检：双向夹具 ───────────────────────────────────────────────────────────────────────────────
if ($SELFTEST) {
    require File::Temp;
    require File::Path;
    my $tmp = File::Temp::tempdir('signal-lint-selftest.XXXXXX', TMPDIR => 1, CLEANUP => 1);
    # 夹具表在 tests/fixtures/signal-lint-cases.txt（纯数据；见那个文件头的「为什么不是数组」）：
    # 一行一例 `<name><TAB><red|clean><TAB><源码>`，源码补一个换行喂给词法解析器。
    my $cases_file = File::Spec->catfile(dirname(abs_path($0)), 'fixtures', 'signal-lint-cases.txt');
    open(my $cf, '<', $cases_file) or die "signal-lint: 读不了夹具表 $cases_file: $!\n";
    my @cases;
    while (my $l = <$cf>) {
        next if $l =~ /^\s*#/ || $l =~ /^\s*$/;
        chomp $l;
        my ($name, $want, $src) = split(/\t/, $l, 3);
        next unless defined $name && defined $want && defined $src && $name ne '';
        push @cases, [$name, "$src\n", ($want eq 'red' ? 1 : 0)];
    }
    close $cf;
    die "signal-lint: 夹具表 $cases_file 里没有可用例子\n" unless @cases;
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

    # 自身干净（self_clean）：把本文件自己的源码放进 scratch 再扫一次 —— 必须是 0。
    # 这是本 lint 对自己的不变量：源码里新增的字面词/引号不能让自己的 shell 解析误报成红。
    {
        my $dir = File::Spec->catdir($tmp, 'self_clean');
        File::Path::make_path($dir);
        my $f = File::Spec->catfile($dir, 'signal-lint-self.pl');
        my $self = do { open(my $sf, '<', abs_path($0)) or die "读不了本文件: $!"; local $/; <$sf> };
        open(my $o, '>', $f) or die "写不了 $f: $!";
        print $o $self;
        close $o;
        my $rc = system($^X, abs_path($0), '--root', $dir, '--quiet') >> 8;
        my $ok = ($rc == 0);
        printf "  %s selftest %-22s 期望净 实际%s%s\n", ($ok ? 'ok ' : 'BAD'), 'self_clean', ($rc ? '红' : '净'),
            ($ok ? '' : "   ← 本 lint 自己的源码被误报（$f）");
        $bad++ unless $ok;
    }

    # 豁免机制的双向自检：哈希锁定 → 净；文件一改 → 红；条数不对 → 红；tests/ 进清单 → 红。
    my $lg_dir  = File::Spec->catdir($tmp, 'legacy');
    File::Path::make_path($lg_dir);
    my $lg_file = File::Spec->catfile($lg_dir, 'case.sh');
    open(my $lo, '>', $lg_file) or die "写不了 $lg_file: $!";
    print $lo "pkill -f x\n";
    close $lo;
    my $lg_sha = sha256_file($lg_file);
    my $lg_list = File::Spec->catfile($tmp, 'legacy.txt');
    my $write_list = sub {
        my ($sha, $n, $path) = @_;
        open(my $lf, '>', $lg_list) or die "写不了 $lg_list: $!";
        print $lf "$sha  $n  $path  # selftest 夹具\n";
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
    $write_list->($lg_sha, 1, $lg_file);
    $lg_check->('exempt_hash_pinned', 0);
    $write_list->($lg_sha, 2, $lg_file);
    $lg_check->('exempt_bad_count', 1);
    $write_list->('0' x 64, 1, $lg_file);
    $lg_check->('exempt_stale_hash', 1);
    $write_list->($lg_sha, 1, 'skills/teamsmith/tests/smoke.sh');
    $lg_check->('exempt_tests_refused', 1);

    printf "\n";
    if ($bad) { printf "✗ signal-lint --selftest：%d 个夹具不符合预期（含豁免机制）\n", $bad; exit 1 }
    printf "✓ signal-lint --selftest：%d 个夹具 + 豁免机制全部符合预期（该红的红、该净的净）\n", scalar @cases;
    exit 0;
}

exit((scalar(@red_hits) + scalar(@baseline_problems)) ? 1 : 0);
