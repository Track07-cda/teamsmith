#!/usr/bin/env python3
"""P163 · delivery-truth 第二投递判据（**严格单次运行**版，P147/P157 配方的夹具版）。

用法：
    P163_EVIDENCE=<证据目录> python3 judge-second.py <case> [<case> …]
    （P163_EVIDENCE 默认 = 本文件所在目录的上一级：$E/pkg/judge-second.py → $E）

P163 F1：只对「由 run-case.sh 清空过、且只跑过一次」的现场出判据，拒绝（exit 2）时点名原因，
绝不静默地把两次运行算成一条：
  * 现场缺 run.json 运行戳（旧现场 / 从没跑过 run-case.sh）；
  * run.json.case / run_id 与现场不符；
  * run.json.mode != verdict（host 路线是人工观察，不作为判据）；
  * run.json.pi_version != 0.99.2（判据版本钉死）；
  * 判据读的事件文件里 run_start 标记不是**恰好一条**（P197：集合相等会吞掉同 ID 的重复标记），
    或它不在**第一行**，或它的 run 与 run.json.run_id 不一致（跨次累积）；
  * run-start.txt 缺 / 空 / 里面的 run= 戳不是本次 run id（P197：P194-F1，单次运行戳必须被核）；
  * 现场里有早于本次运行开始的残留文件（没有清空现场）。

计数沿用 P147/P157：second_received 恰好 1、后台模型请求恰好 1、settle 在收到之后且编辑器为空。
"""
import json
import os
import pathlib
import re
import sys

ROOT = pathlib.Path(os.environ.get('P163_EVIDENCE') or pathlib.Path(__file__).resolve().parent.parent)
VERDICT_RUNTIME = '0.99.2'
SCENE_FILES = ('dev-events.jsonl', 'requests.jsonl')


def refuse(name, why):
    print(f'judge-second: 拒绝出判据（{name}）：{why}', file=sys.stderr)
    sys.exit(2)


def check_single_run_mark(name, rel, lines, run_id):
    """P197：run_start 标记必须恰好一条、在第一行、且 run == run.json.run_id。

    用集合比较（`sorted({m.get('run') …})`）会把同 ID 的重复标记吞成一条 —— 现场跨次累积
    最坏的形状恰恰是「同一次运行的标记被追加了第二遍」：必须数**条数**，不是比**集合**。
    """
    marks = [(i, json.loads(x)) for i, x in enumerate(lines) if '"run_start"' in x]
    if len(marks) != 1:
        refuse(name, f'{rel} 的 run_start 标记 {len(marks)} 条（要求恰好一条）：'
                    f'{[m.get("run") for _, m in marks]}')
    idx, mark = marks[0]
    if idx != 0:
        refuse(name, f'{rel} 的 run_start 在第 {idx + 1} 行（要求第一行）')
    if mark.get('run') != run_id:
        refuse(name, f'{rel} 的 run_start.run={mark.get("run")!r} != run.json.run_id={run_id!r}')


def check_run_start_stamp(name, scene, run_id):
    """P197（P194-F1）：run-start.txt 是 run-case.sh 写给现场的单次运行戳，判据必须核它 ——
    存在、非空、且里面的 run= 与 run.json.run_id 一致。留一个「看起来是戳、判据却不看」的文件
    只会让人以为它被检查过。"""
    stamp = scene / 'run-start.txt'
    if not stamp.is_file():
        refuse(name, '缺 run-start.txt（run-case.sh 的单次运行戳；判据不猜）')
    text = stamp.read_text().strip()
    if not text:
        refuse(name, 'run-start.txt 是空的（没有单次运行戳）')
    m = re.search(r'(?:^|\s)run=(\S+)', text)
    if not m:
        refuse(name, f'run-start.txt 里没有 run= 戳：{text!r}')
    if m.group(1) != run_id:
        refuse(name, f'run-start.txt run={m.group(1)!r} != run.json.run_id={run_id!r}（不是本次运行的戳）')


def load_scene(name):
    scene = ROOT / 'logs' / name
    if not scene.is_dir():
        refuse(name, f'现场目录不存在：{scene}')
    rp = scene / 'run.json'
    if not rp.is_file():
        refuse(name, '现场没有 run.json 运行戳（旧现场 / 没跑过 run-case.sh；判据不猜）')
    try:
        run = json.loads(rp.read_text())
    except Exception as exc:  # noqa: BLE001 - 任何读不了都是拒绝
        refuse(name, f'run.json 读不了：{exc}')
    if run.get('case') != name:
        refuse(name, f"run.json.case={run.get('case')!r} 与现场目录名不符")
    if not run.get('run_id'):
        refuse(name, 'run.json.run_id 缺失')
    if run.get('mode') != 'verdict':
        refuse(name, f"run.json.mode={run.get('mode')!r} 是人工观察（host 路线），不作为判据")
    if run.get('pi_version') != VERDICT_RUNTIME:
        refuse(name, f"run.json.pi_version={run.get('pi_version')!r} != 判据版本 {VERDICT_RUNTIME}")
    started = float(run.get('started_at') or 0)
    if started <= 0:
        refuse(name, 'run.json.started_at 缺失/非正数')
    for rel in SCENE_FILES:
        p = scene / rel
        if not p.is_file():
            refuse(name, f'缺 {rel}')
        lines = [x for x in p.read_text().splitlines() if x.strip()]
        if not lines:
            refuse(name, f'{rel} 是空的')
        check_single_run_mark(name, rel, lines, run['run_id'])
    check_run_start_stamp(name, scene, run['run_id'])
    for f in sorted(scene.rglob('*')):
        if f.is_dir() or f == rp:
            continue
        if f.stat().st_mtime < started - 5:
            refuse(name, f'现场里有早于本次运行的文件 {f.relative_to(scene)}（没有清空现场）')
    ver = scene / 'pi-version.txt'
    got = ver.read_text().strip() if ver.is_file() else '缺失'
    if got != VERDICT_RUNTIME:
        refuse(name, f'pi-version.txt={got!r} != {VERDICT_RUNTIME}')
    return scene


def main(argv):
    names = argv[1:]
    if not names:
        print('usage: judge-second.py <case> [case…]（P163_EVIDENCE=<证据目录>）', file=sys.stderr)
        return 2
    failed = 0
    for name in names:
        scene = load_scene(name)
        events = [json.loads(x) for x in (scene / 'dev-events.jsonl').read_text().splitlines()]
        marker = 'P138-SECOND-' + name
        received = [e for e in events if e['event'] == 'message_end' and e.get('message', {}).get('role') in ('user', 'custom')
                    and marker in json.dumps(e.get('message', {}), ensure_ascii=False)]
        requests = [json.loads(x) for x in (scene / 'requests.jsonl').read_text().splitlines()]
        backend_count = sum(marker in json.dumps(r['messages'][-1], ensure_ascii=False) for r in requests if r.get('messages'))
        backend = backend_count == 1
        settles = [e for e in events if e['event'] == 'agent_settled']
        empty = bool(settles) and all(e['editor'] == '' and e['idle'] for e in settles)
        print(f'{name}: second_received={len(received)} backend={int(backend)} backend_requests={backend_count} settled={len(settles)} settle_editors_empty={int(empty)}')
        ok = empty and len(received) == 1 and backend and any(e['ts'] > received[0]['ts'] for e in settles)
        print('PASS second say delivered' if ok else 'FAIL second say stranded despite idle empty editor')
        failed += not ok
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
