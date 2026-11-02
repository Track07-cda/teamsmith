#!/usr/bin/env python3
"""P393 · delivery-truth 脏框 A/B 判据（**严格单次运行**，只判 P163_DRAFT_AB 现场）。

三条等价运行，同一个真草稿、同一个 mock 后端、同一个 0.99.2 运行时：

  tmux-p163-base-default-dirty      基线 ec78b6c622ad 的默认 say  → 无可用 watcher：旧行为排队
  tmux-p163-base-now-dirty          基线自带的 say --now          → 旧 forced 动作，直投那个脏框
  tmux-p163-candidate-default-dirty 候选的默认 say                → 必须与上一行等价

判据只信现场的证据文件（请求正文、say 输出、forced 审计、队列与草稿字节），不用 pane 回显、rc=0
或「我以为它会」代替。单次运行/版本/旧现场的严格检查复用 judge-second.py 的一处实现（同一个种子
问题不应有两个答案）。

用法：
    P163_EVIDENCE=<证据目录> python3 judge-dirty-ab.py <case> [<case> …]
"""
import importlib.util
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent


def _load_second():
    """把 judge-second.py 的单次运行/版本/旧现场检查装进来（文件名带连字符，用 importlib）。"""
    spec = importlib.util.spec_from_file_location('judge_second', HERE / 'judge-second.py')
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


JS = _load_second()

DIRECT_CASES = ('tmux-p163-base-now-dirty', 'tmux-p163-candidate-default-dirty')
QUEUED_CASES = ('tmux-p163-base-default-dirty',)
FORCED_RE = r'^[^ ]+ kind=say from=pm target=p138:dev entry=none$'


def refuse(name, why):
    JS.refuse(name, why)


def user_texts(request):
    return [str(m.get('content', '')) for m in request.get('messages', []) if m.get('role') == 'user']


def q_files(scene, sub=''):
    d = scene / 'state-after-say' / 'outbox'
    if sub:
        d = d / sub
    return sorted(d.glob('*.msg')) if d.is_dir() else []


def forced_lines(scene):
    f = scene / 'state-after-say' / 'outbox' / 'forced.log'
    return [x for x in f.read_text().splitlines() if x.strip()] if f.is_file() else []


def main(argv):
    names = argv[1:]
    if not names:
        print('usage: judge-dirty-ab.py <case> [case…]（P163_EVIDENCE=<证据目录>）', file=sys.stderr)
        return 2
    failed = 0
    for name in names:
        scene = JS.load_scene(name)
        if name not in DIRECT_CASES and name not in QUEUED_CASES:
            refuse(name, '不是 P393 的三条脏框 A/B case 名之一')
        draft_file = scene / 'draft-typed.txt'
        if not draft_file.is_file():
            refuse(name, '缺 draft-typed.txt（现场没有跑 P163_DRAFT_AB=1 的真草稿模式）')
        draft = draft_file.read_text()
        msg = 'P138-SAY-' + name
        say_txt = (scene / 'say.txt').read_text() if (scene / 'say.txt').is_file() else ''
        requests = [json.loads(x) for x in (scene / 'requests.jsonl').read_text().splitlines()
                    if x.strip() and '"run_start"' not in x]
        hits = [r for r in requests if any(draft in c and msg in c for c in user_texts(r))]
        queued = q_files(scene)
        held = q_files(scene, 'held')
        forced = forced_lines(scene)
        after = (scene / 'dev-after-say.frame').read_text() if (scene / 'dev-after-say.frame').is_file() else ''
        # 发送**前**的帧必须已经含有那真草稿（draft-typed-before.frame 是键入之后、send 之前拍的）
        before = (scene / 'draft-typed-before.frame').read_text() if (scene / 'draft-typed-before.frame').is_file() else ''
        problems = []
        if not before:
            problems.append('缺 draft-typed-before.frame（现场没有真草稿的发送前帧）')
        elif draft not in before:
            problems.append('发送前的帧里没有那真草稿（夹具前提不成立）')
        if queued and not any(msg in p.read_text() for p in queued):
            problems.append('活动队列条目里没有这次 payload')

        if name in QUEUED_CASES:
            if 'queued' not in say_txt:
                problems.append('基线的默认 say 没有报 queued（旧行为不再被保留）')
            if '已确认送达' in say_txt:
                problems.append('排队却报「已确认送达」')
            if hits:
                problems.append(f'基线默认 say 居然产生了含草稿+修正的模型请求（{len(hits)} 条）')
            if forced:
                problems.append(f'基线默认 say 写了 {len(forced)} 条 forced 审计（排队不该直投）')
            if len(queued) != 1:
                problems.append(f'活动队列应恰好 1 条，实际 {len(queued)}')
            if draft not in after:
                problems.append('排队之后草稿不在框里了（被改动）')
            verdict = 'queued (no model request)'
        else:
            if len(hits) != 1:
                problems.append(f'含草稿+修正的模型请求应恰好 1 条，实际 {len(hits)}')
            if name in ('tmux-p163-base-now-dirty',):
                # 基线自带的显式旗标：它的措辞就是旧的「--now 跳过守卫直投」——只否认证回执
                if '--now' not in say_txt:
                    problems.append('基线 --now 的输出没有点名 --now（等价性证据不完整）')
            elif '已尝试立即发送' not in say_txt and 'attempted immediate send' not in say_txt:
                problems.append('候选直投的输出没有说明这是一次立即尝试（不许暗示回执）')
            if name != 'tmux-p163-base-now-dirty' and '--now' in say_txt:
                problems.append('候选输出提到了已退休的 say --now')
            if '已确认送达' in say_txt:
                problems.append('直投冒充「已确认送达」')
            if len(forced) != 1:
                problems.append(f'forced 审计应恰好 1 条，实际 {len(forced)}')
            elif not __import__('re').match(FORCED_RE, forced[0]):
                problems.append(f'forced 审计格式不是既有格式：{forced[0]!r}')
            if queued:
                problems.append(f'直投之后还留下 {len(queued)} 条活动队列条目')
            if held:
                problems.append(f'直投之后出现了 {len(held)} 条 held/ 条目')
            verdict = 'direct (draft+correction in one request)'

        print(f'{name}: requests_matching_draft_and_correction={len(hits)} '
              f'queued={len(queued)} held={len(held)} forced={len(forced)}')
        if problems:
            for why in problems:
                print(f'  ✗ {why}')
            print(f'FAIL dirty A/B {name}')
            failed += 1
        else:
            print(f'PASS dirty A/B {name}: {verdict}')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
