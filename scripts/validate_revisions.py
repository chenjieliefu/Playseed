"""Resume three real revisions on an existing isolated P0 sample."""
import argparse
import hashlib
import json
import shutil
import sys
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import backend as b
import producer
from validation_cases import validate_cases


def hashes(directory):
    return {str(p.relative_to(directory)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in directory.rglob('*') if p.is_file() and '.godot' not in p.parts}


def check_previous_probes(project, versions, job):
    """Run old actions against a copy, never edit an immutable game version."""
    scratch = job / 'regression-project'
    shutil.copytree(project, scratch, ignore=shutil.ignore_patterns('.godot'))
    probes = []
    try:
        for version in versions:
            probe = version.get('test')
            if not probe or probe in probes:
                continue
            probes.append(probe)
            (scratch / '_check.gd').write_text(producer.smoke_script(probe))
            probe_job = job / ('probe-' + str(version['revision']))
            probe_job.mkdir()
            producer.check(b, scratch, probe_job)
        return probes
    finally:
        shutil.rmtree(scratch)


def run(run_name, genre):
    runs = ROOT / '.playseed' / 'validation'
    run_root = (runs / run_name).resolve()
    if run_root.parent != runs.resolve():
        raise ValueError('验收目录必须位于 .playseed/validation 下。')
    sample = next(row for row in b.read_json(run_root / 'summary.json')['results']
                  if row['slug'] == genre and row['build'] == 'passed')
    case = next(row for row in validate_cases() if row['slug'] == genre)
    b.DATA = run_root / 'data'
    idea_id = sample['idea_id']
    report_path = run_root / 'revision-reports' / (genre + '.json')
    report = b.read_json(report_path) if report_path.exists() else {
        'genre': genre, 'title': case['title'], 'started_at': b.now(), 'rounds': [],
        'semantic_review': 'pending', 'model': 'gpt-5.6-sol', 'reasoning_effort': 'medium'}
    base = producer.game_root(b, idea_id)
    for number, prompt in enumerate(case['revisions'], 1):
        done = next((row for row in report['rounds'] if row['round'] == number), None)
        if done:
            if done['status'] != 'passed':
                raise RuntimeError('该轮已有未通过记录，需先检查原因，不能自动跳过。')
            continue
        old = producer.read_game(b, idea_id)
        before = hashes(base / 'revisions')
        job = b.DATA / 'jobs' / ('revision-check-' + genre + '-' + uuid.uuid4().hex)
        job.mkdir(parents=True)
        row = {'round': number, 'prompt': prompt, 'status': 'running',
               'previous_revision': old['current_revision'], 'job': str(job), 'started_at': b.now()}
        report['rounds'].append(row)
        b.atomic_json(report_path, report)
        request = {'action': 'revise_game', 'idea_id': idea_id,
                   'revision': b.read_json(b.DATA / 'ideas' / idea_id / 'idea.json')['revision'],
                   'game_revision': old['current_revision'], 'prompt': prompt,
                   'model': report['model'], 'reasoning_effort': report['reasoning_effort']}
        b.atomic_json(job / 'request.json', request)
        print(genre, '开始修改', number, flush=True)
        try:
            result = b.process_request(request, job)
            b.atomic_json(job / 'result.json', result)
            game = result['game']
            row['revision'] = game['current_revision']
            row['repair_count'] = game['versions'][-1]['repair_count']
            project = base / 'revisions' / f"{game['current_revision']:04d}"
            row['previous_probes'] = check_previous_probes(project, old['versions'], job)
            row['status'] = 'passed'
            b.status(job, 'done', '本轮运行及旧操作回归检查通过，玩法语义仍需核验。')
        except Exception as exc:
            row['status'] = 'failed'
            row['error'] = str(exc)
            b.status(job, 'error', str(exc))
        after = hashes(base / 'revisions')
        row['old_files_unchanged'] = all(after.get(name) == digest for name, digest in before.items())
        if not row['old_files_unchanged']:
            row['status'] = 'failed'
            row['error'] = '旧版文件发生变化。'
        row['finished_at'] = b.now()
        b.atomic_json(report_path, report)
        print(genre, '第', number, '轮', row['status'], row.get('error', ''), flush=True)
        if row['status'] != 'passed':
            return False
    report['finished_at'] = b.now()
    b.atomic_json(report_path, report)
    return True


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='在已有验收游戏上执行三轮连续修改及旧操作回归。')
    parser.add_argument('run')
    parser.add_argument('genre', choices=[row['slug'] for row in validate_cases()])
    args = parser.parse_args()
    raise SystemExit(0 if run(args.run, args.genre) else 1)
