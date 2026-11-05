#!/usr/bin/env perl
# teamsmith · 段副本自足检查（P413 · change: -）
#
#   perl tests/lib/section-calls.pl --suite <tests/smoke.sh> --plan - < plan
#
#   plan（标准输入，一行一键）：<key> <TAB> <源码行区间，逗号分隔的 a-b>
#     —— 区间就是 `--select <key>` 裁出来的那份副本包含的**源码行**（按源序、含端点）。
#        唯一来源是 section-select.sh 的 emit_copy 几何（同一份 mark_kept_groups），这里不重算。
#
#   判定（红）：副本里**调用**了一个「段体里定义的函数」（定义落在某个 section 的段体内），而这份
#     副本自己**没有**它的定义。这就是 P413 的现场：`make_pm_idle` / `pm_state_now` 定义在 §11b 的
#     段体里，`--select 11b4` 裁出的副本调用它们 → `command not found`，随后八条断言塌掉。
#     处理方式只有两种：定义搬进 tests/lib/（任何选段都 source 带上），或把那段声明进映射表的 needs。
#
#   附带（同一族，顶掉 §0c 旧的那条 grep）：`assert_*` 在套件里被调用、却在**任何地方**都没有定义
#     → 红（那种断言会静默空跑，M5.1 的 assert_has_echo 就是这么漏的）。旧检查 grep 文件里的
#     `assert_` 字样（在字符串里提到也算），这里只看命令位，所以不再误报。
#
#   成本：不跑任何段、不写任何临时文件。整份套件解析一次（词法），每个**区间**再解析一次并被缓存
#     —— 不同键的副本共用同一批组，139 个键合计仍只解析整棵树一遍多。实测见报告。
#
#   已知边界（别当成保证）：
#     * 只看「段体里定义的函数」。定义在 tests/lib/*.sh 或 scripts/lib/*.sh 的函数算可用（由被
#       source 的 lib 提供）；「段调了某 lib 却没 source 它」不在这条射程内。
#     * 定义按源码行 `name () {` 认（与 §0c 的老约定一致）。heredoc 体里写出来的同名函数会让那个名字
#       算「有定义」—— 假绿方向，本项目的夹具没有这个形状。
#     * 变量与目录的跨段假设不在射程内：`set -u` 下未定义变量是 rc=127 的响亮失败，不是静默塌陷。
#
#   exit: 0 = 每个键的副本都自足 ｜ 1 = 有自足缺口 ｜ 2 = 用法/环境错误。
use strict;
use warnings;
use File::Basename qw(dirname);

my ($SUITE, $PLAN);
my $SELF = dirname(__FILE__);
while (@ARGV) {
    my $a = shift @ARGV;
    if    ($a eq '--suite') { $SUITE = shift @ARGV // die "section-calls: --suite 需要文件\n" }
    elsif ($a eq '--plan')  { $PLAN  = shift @ARGV // die "section-calls: --plan 需要文件或 -\n" }
    elsif ($a eq '-h' || $a eq '--help') { open my $s, '<', __FILE__; print while <$s>; exit 0 }
    else { die "section-calls: 未知参数 $a（用法见 --help）\n" }
}
defined $SUITE or die "section-calls: 缺 --suite（用法见 --help）\n";
defined $PLAN  or die "section-calls: 缺 --plan（用法见 --help）\n";
require "$SELF/shell-lex.pl";

open my $sf, '<', $SUITE or die "section-calls: 读不到 $SUITE：$!\n";
my @L = <$sf>;
close $sf;
chomp @L;
my $NLINE = scalar @L;

# ── 段边界：段头行号与段 key（报错时点名「定义在哪一段」）────────────────────────────────────
my (@SEC_LINE, @SEC_KEY);
for my $i (0 .. $#L) {
    next unless $L[$i] =~ /^\s*section\s+"([^"]+)"/;
    my $key = $1; $key =~ s/ · .*//;
    push @SEC_LINE, $i + 1;
    push @SEC_KEY, $key;
}
die "section-calls: $SUITE 里一个 section 都没解析到\n" unless @SEC_LINE;
my $FIRST_SEC = $SEC_LINE[0];

sub sec_of_line {    # <行号> → 段 key（段头之前 = 前导）
    my $ln = shift;
    my $hit = '前导';
    for my $i (0 .. $#SEC_LINE) {
        last if $SEC_LINE[$i] > $ln;
        $hit = $SEC_KEY[$i];
    }
    return $hit;
}
sub def_name {       # <源码行> → 函数名（不是定义行 = undef）
    my $line = shift;
    return $1 if $line =~ /^\s*(?:function\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*\(\s*\)\s*\{/;
    return undef;
}

# ── 一个「单元」（一段连续源码行）的调用/定义集合；按区间缓存 ────────────────────────────────────
# 副本 = 前导 + 若干组 + 收尾，每块都是 bash -n 可解析的（build_groups 的契约），所以逐块词法等价于
# 整份副本词法：命令不会跨块（跨段构造已经被并进同一组）。这也让行号问题彻底消失 —— 这里只需要集合。
my (%U_CALLS, %U_DEFS);
sub unit {            # <a> <b> → (调用集合引用, 定义集合引用)
    my ($a, $b) = @_;
    my $id = "$a-$b";
    if (exists $U_CALLS{$id}) { return ($U_CALLS{$id}, $U_DEFS{$id}) }
    $a = 1 if $a < 1;
    $b = $NLINE if $b > $NLINE;
    my @slice = @L[ $a - 1 .. $b - 1 ];
    my (%calls, %defs);
    for my $line (@slice) {
        my $n = def_name($line);
        $defs{$n} = 1 if defined $n;
    }
    my @cmds = ShellLex::parse_source(join("\n", @slice) . "\n", $SUITE, 0);
    for my $c (@cmds) {
        for my $w (@{ $c->{words} }) {
            $calls{ $w->{t} } = 1 if $w->{cmd} && $w->{t} =~ /^[A-Za-z_][A-Za-z0-9_]*$/;
            # 命令替换里的命令词：`x="$(make_pm_idle)"` 与 `if foo=$(pm_state_now)` 都要算调用
            for my $h (@{ $w->{subst} || [] }) { $calls{$h} = 1 if $h =~ /^[A-Za-z_][A-Za-z0-9_]*$/ }
        }
    }
    $U_CALLS{$id} = \%calls;
    $U_DEFS{$id}  = \%defs;
    return (\%calls, \%defs);
}

# ── 段体函数的宇宙（定义行在第一个段头之后）+ 断言宇宙（两份都从整份套件来）────────────────────
my (%BODY_DEF_LINE, %DEF_ANYWHERE);
for my $i (0 .. $#L) {
    my $n = def_name($L[$i]) // next;
    $DEF_ANYWHERE{$n} = $i + 1;
    next if ($i + 1) < $FIRST_SEC;
    $BODY_DEF_LINE{$n} = $i + 1;
}
my ($all_calls) = unit(1, $NLINE);

# ── plan ──────────────────────────────────────────────────────────────────────────────────────
my $plan_fh;
if ($PLAN eq '-') { $plan_fh = \*STDIN }
else { open $plan_fh, '<', $PLAN or die "section-calls: 读不到 $PLAN：$!\n" }

my ($n_ok, $n_bad, $n_keys) = (0, 0, 0);
my @OUT;
while (my $row = <$plan_fh>) {
    chomp $row;
    next if $row =~ /^\s*$/;
    my ($key, $spec) = split /\t/, $row, 2;
    unless (defined $spec && length $key) {
        push @OUT, "bad: plan 行不是「key<TAB>区间」：$row";
        $n_bad++;
        next;
    }
    $n_keys++;
    my (@ranges, %calls, %defs);
    for my $seg (split /,/, $spec) {
        if    ($seg =~ /^(\d+)-(\d+)$/) { push @ranges, [ $1, $2 ] }
        elsif ($seg =~ /^(\d+)$/)       { push @ranges, [ $1, $1 ] }
        else { die "section-calls: plan 里键 $key 的区间接不懂：[$seg]\n" }
    }
    for my $r (@ranges) {
        my ($c, $d) = unit(@$r);
        $calls{$_} = 1 for keys %$c;
        $defs{$_}  = 1 for keys %$d;
    }
    my @missing = sort grep { $BODY_DEF_LINE{$_} && !$defs{$_} && $calls{$_} } keys %BODY_DEF_LINE;
    if (@missing) {
        $n_bad++;
        for my $name (@missing) {
            push @OUT, sprintf(
                'bad: %s · 段体函数 %s 在这份副本里没有定义（%s 的源码行 %d，%s）—— 定义搬进 tests/lib/ 或把 needs 写进映射表',
                $key, $name, $SUITE, $BODY_DEF_LINE{$name}, sec_of_line($BODY_DEF_LINE{$name}));
        }
    }
    else { $n_ok++ }
}

# ── 附带：assert_* 用了没定义（§0c 旧检查的替代）──────────────────────────────────────────────
my %assert_bad;
for my $name (keys %$all_calls) {
    next unless $name =~ /^assert_[a-z_]+$/ && !$DEF_ANYWHERE{$name};
    $assert_bad{$name} = 1;
}
push @OUT, "bad: $_ 用了没定义 —— 那种断言会静默空跑" for sort keys %assert_bad;
$n_bad += scalar keys %assert_bad;

print map { "$_\n" } @OUT;
printf "== 段副本自足 == ok %d bad %d（%d 个键；段体函数 %d 个，assert_* 未定义 %d 个，整份套件的命令词 %d 个）\n",
    $n_ok, $n_bad, $n_keys, scalar(keys %BODY_DEF_LINE), scalar(keys %assert_bad), scalar(keys %$all_calls);
exit(1) if $n_bad;
exit(0);
