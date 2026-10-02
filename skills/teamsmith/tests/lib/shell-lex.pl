#!/usr/bin/env perl
# teamsmith · shell 词法分析（P159 · safe-signal-discipline）
#
# 从 tests/tmux-lint.pl 抽出的解析器（命令位 / 引号 / heredoc / 命令替换 / bash -c 字符串），
# tmux 隔离 lint 与信号 lint 共用一份。抽取是**有不变量的**：同一棵树上
# `perl tests/tmux-lint.pl --list` 在抽取前后逐字节一致（P159 报告里留了 before/after 与 diff）。
#
# 本模块只对原解析器加一条**注解**，不改任何判定：词上多一个 `subst`
#   subst => [ 这个词里的命令替换各自的首个命令词（含嵌套，递归收集）… ]
# 于是 `kill $(pgrep -f x)` 与 `kill "$(cat job.pid)"` 在词法上就能区分开。
package ShellLex;
use strict;
use warnings;

# 需要在命令位"透明"的保留字（后面仍期待命令词）
our %KEYWORD = map { $_ => 1 } qw(if then else elif while until do done fi case esac in for select ! time function);

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

# 命令替换里的**命令词**（含嵌套：递归解析的结果是拍平的，逐个取首个 cmd 词）——给词的
# `subst` 注解用。不改变任何解析行为。
sub _cmd_heads {
    my (@cmds) = @_;
    my @out;
    for my $c (@cmds) {
        for my $w (@{ $c->{words} }) {
            next unless $w->{cmd};
            push @out, $w->{t};
            last;    # 一个命令只有一个首命令词
        }
    }
    return @out;
}

sub parse_source {
    my ($src, $file, $base_depth) = @_;
    my @cmds;
    my $cur = { file => $file, line => 1, depth => $base_depth, words => [], shell_strings => [] };
    my ($cmd_pos, $word, $word_q, $redirect_next, $line, $i, $n) = (1, '', 0, 0, 1, 0, length $src);
    my @heredocs;
    my @scopes;    # 'subshell' | 'func' | 'fnparen' | 'block'（决定命令是不是"文件顶层"）
    my @word_subst;    # 当前词里命令替换的命令词（注解，不参与判定）
    my $depth_now = sub { $base_depth + scalar grep { $_->{type} ne 'block' } @scopes };

    my $finish = sub {
        push @cmds, $cur if @{ $cur->{words} } || @{ $cur->{shell_strings} };
        $cur = { file => $file, line => $line, depth => $depth_now->(), words => [], shell_strings => [] };
        $cmd_pos = 1;
    };
    my $flush = sub {
        if ($word eq '') { @word_subst = (); return }
        my $w = { t => $word, q => $word_q };
        $w->{subst} = [@word_subst] if @word_subst;
        $word = ''; $word_q = 0; @word_subst = ();
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
                # 双引号里的命令替换真会执行 → 记下来（并把它的命令词记进当前词的 subst 注解）
                my @sub = parse_source($body, $file, $base_depth + 1);
                push @cmds, @sub;
                push @word_subst, _cmd_heads(@sub);
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
            my @sub = parse_source($buf, $file, $base_depth + 1);
            push @cmds, @sub;
            push @word_subst, _cmd_heads(@sub);
            $line += $nl; $i = $j + 1;
            $word .= '@CMD@'; $word_q = 1;
            next;
        }
        if ($c eq '$' && substr($src, $i + 1, 1) eq '(') {
            my ($body, $ni, $nl) = read_balanced($src, $i + 2, '(', ')');
            my @sub = parse_source($body, $file, $base_depth + 1);
            push @cmds, @sub;
            push @word_subst, _cmd_heads(@sub);
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
                    my @sub = parse_source($b2, $file, $base_depth + 1);
                    push @cmds, @sub;
                    push @word_subst, _cmd_heads(@sub);
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

1;
