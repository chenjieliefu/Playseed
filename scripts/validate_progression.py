"""Run one resumable P2 production step with immutable-version evidence."""
import argparse
import hashlib
import json
import sys
import uuid
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import backend as b
import producer
from progression_case import PLAN, TITLE, REVISIONS
from scripts.validate_revisions import hashes, check_previous_probes



def require_playthrough(run_root, revision):
    """Do not spend the next round's quota while current gameplay is unverified."""
    digest = hashlib.sha256((ROOT / 'scripts/playthrough_checks/progression.gd').read_bytes()).hexdigest()
    current = hashes(run_root / 'project/revisions' / f'{revision:04d}')
    reports = [b.read_json(p) for p in (run_root / 'playthrough-reports').glob(f'v{revision}-*.json')]
    for outcome, choice in [('won', 'damage'), ('won', 'heal'), ('lost', 'damage')]:
        matching = [r for r in reports if r.get('outcome') == outcome and r.get('choice') == choice
                    and r.get('source_hashes') == current and r.get('checker_sha256') == digest]
        if not matching or not all(r.get('passed') is True and r.get('source_unchanged') is True for r in matching):
            raise ValueError('先完成当前版火力、修复和失败三条试玩；有失败记录需审阅后处理，不能自动推进。')


def run(run_root, step):
    run_root = run_root.resolve()
    if run_root.parent != (ROOT / '.playseed/validation').resolve():
        raise ValueError('验收必须在独立的 validation 子目录。')
    b.DATA = run_root / 'data'
    state_path = run_root / 'progression.json'
    if not state_path.exists():
        if step != 'build' or (run_root.exists() and any(run_root.iterdir())):
            raise ValueError('第一步必须在新目录制作。')
        project = run_root / 'project'
        project.mkdir(parents=True)
        ident = uuid.uuid4().hex
        idea = dict(id=ident, title=TITLE, revision=1, ready=True, status='confirmed',
                    confirmed_revision=1, confirmed_by='validation_run', created_at=b.now(),
                    updated_at=b.now(), confirmed_at=b.now(), project_directory=str(project),
                    messages=[], questions=[], history=[], plan=PLAN)
        b.atomic_json(b.DATA / 'ideas' / ident / 'idea.json', idea)
        b.atomic_json(state_path, dict(idea_id=ident, steps=[], scope='固定已确认方案的制作验收，非新手对话验收'))
    state = b.read_json(state_path)
    if any(x['step'] == step for x in state['steps']):
        raise ValueError('该步骤已有记录，请先审阅，不能重复消耗额度。')
    expected = ['build', 'revise1', 'revise2', 'revise3', 'restore']
    if step != expected[len(state['steps'])] or any(x['status'] != 'passed' for x in state['steps']):
        raise ValueError('按制作、三轮修改、恢复顺序执行，先解决失败。')
    ident = state['idea_id']
    old = producer.read_game(b, ident)
    if old:
        require_playthrough(run_root, old['current_revision'])
    base = producer.game_root(b, ident)
    before = hashes(base / 'revisions')
    job = b.DATA / 'jobs' / (step + '-' + uuid.uuid4().hex)
    job.mkdir(parents=True)
    request = dict(action='build_game' if step == 'build' else 'restore_created' if step == 'restore' else 'revise_game',
                   idea_id=ident, revision=1, game_revision=old['current_revision'] if old else 0,
                   model='gpt-5.6-sol', reasoning_effort='medium')
    if step.startswith('revise'):
        request['prompt'] = REVISIONS[int(step[-1])-1]
    if step == 'restore':
        request['restore_revision'] = 1
    row = dict(step=step, status='running', job=str(job), started_at=b.now())
    state['steps'].append(row)
    b.atomic_json(state_path, state)
    b.atomic_json(job / 'request.json', request)
    try:
        if step == 'build':
            prepared = b.process_request(dict(action='prepare_build', idea_id=ident, revision=1), job)
            b.atomic_json(job / 'build-plan.json', prepared['build_plan'])
        result = b.process_request(request, job)
        b.atomic_json(job / 'result.json', result)
        game = result['game']
        version = game['current_revision']
        project = base / 'revisions' / f'{version:04d}'
        row.update(revision=version, repair_count=game['versions'][-1]['repair_count'])
        if old and step != 'restore':
            row['previous_probes'] = check_previous_probes(project, old['versions'], job)
        if step == 'restore':
            # Metadata differs intentionally; the runtime script must be identical.
            if (project / 'game.gd').read_bytes() != (base / 'revisions/0001/game.gd').read_bytes():
                raise RuntimeError('恢复脚本与第1版不一致。')
        row['status'] = 'passed'
    except Exception as exc:
        row.update(status='failed', error=str(exc))
    after = hashes(base / 'revisions')
    row['old_files_unchanged'] = all(after.get(k) == v for k, v in before.items())
    if not row['old_files_unchanged']:
        row.update(status='failed', error='旧版本文件被改变')
    if row['status'] == 'passed':
        b.atomic_json(run_root / 'summary.json', {'results': [dict(
            slug='progression', title=TITLE, genre='波次防守', build='passed', idea_id=ident,
            current_revision=row['revision'], project_directory=str(base))]})
    row['finished_at'] = b.now()
    b.status(job, 'done' if row['status'] == 'passed' else 'error', '制作检查通过，专项试玩另外验收。' if row['status'] == 'passed' else row['error'])
    b.atomic_json(state_path, state)
    print(json.dumps(row, ensure_ascii=False), flush=True)
    return row['status'] == 'passed'


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('run')
    parser.add_argument('step', choices=['build', 'revise1', 'revise2', 'revise3', 'restore'])
    args = parser.parse_args()
    raise SystemExit(0 if run(ROOT / '.playseed/validation' / args.run, args.step) else 1)
