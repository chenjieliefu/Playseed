"""Read-only policy, real input, fixed 60fps, isolated disposable game copy."""
import argparse
import hashlib
import json
import re
import shutil
import sys
import uuid
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import backend as b
import producer
from scripts.validate_revisions import hashes


def parse_report(output):
    match = re.search(r'PROGRESSION_REPORT:(.*)', output)
    if not match:
        raise RuntimeError('未得到完整试玩报告。')
    report = json.loads(match[1])
    if re.search(r'(?m)(SCRIPT ERROR:|ERROR:)', output):
        report['passed'] = False
        report.setdefault('failures', []).append('运行时错误')
    return report


def check(run, revision, outcome='won', choice='damage', visual=False):
    run = (ROOT / '.playseed/validation' / run).resolve()
    if run.parent != (ROOT / '.playseed/validation').resolve():
        raise ValueError('无效验收目录')
    source = run / 'project/revisions' / f'{revision:04d}'
    before = hashes(source)
    job = run / 'data/jobs' / ('play-' + uuid.uuid4().hex)
    job.mkdir(parents=True)
    scratch = job / 'project'
    shutil.copytree(source, scratch, ignore=shutil.ignore_patterns('.godot'))
    script = (ROOT / 'scripts/playthrough_checks/progression.gd').read_text()
    constants = dict(REVISION=revision, TOTAL=4 if revision in (3, 4) else 3,
                     OUTCOME=outcome, CHOICE=choice, CAPTURE_DIR=str(job / 'runtime') if visual else '')
    script += '\n' + '\n'.join(f'const {k} = {json.dumps(v)}' for k, v in constants.items()) + '\n'
    (scratch / '_progression.gd').write_text(script)
    (job / 'driver.gd').write_text(script)
    report = dict(revision=revision, outcome=outcome, choice=choice, job=str(job),
                  scope='真实输入、固定60帧、只读状态策略；不是人工新手体验',
                  source_hashes=before,
                  checker_sha256=hashlib.sha256((ROOT / 'scripts/playthrough_checks/progression.gd').read_bytes()).hexdigest())
    try:
        extra = [] if visual else ['--headless']
        output = b.run_process(producer.sandbox_command(b, scratch, job, extra + [
            '--fixed-fps', '60', '--script', '_progression.gd', '--quit-after', '24000']),
            job, 100, 'playthrough', cwd=scratch, child_env=producer.runtime_env())
        report.update(parse_report(output))
    except Exception as exc:
        log = job / 'playthrough.log'
        if log.exists():
            try: report.update(parse_report(log.read_text()))
            except (ValueError, RuntimeError): pass
        report.update(passed=False, error=str(exc))
    finally:
        shutil.rmtree(scratch)
    report['source_unchanged'] = hashes(source) == before
    if not report['source_unchanged']: report['passed'] = False
    b.atomic_json(run / 'playthrough-reports' / f'v{revision}-{outcome}-{choice}-{job.name}.json', report)
    print(json.dumps(report, ensure_ascii=False), flush=True)
    return report.get('passed', False)


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('run'); p.add_argument('revision', type=int)
    p.add_argument('--outcome', choices=['won', 'lost'], default='won')
    p.add_argument('--choice', choices=['damage', 'heal'], default='damage')
    p.add_argument('--visual', action='store_true')
    a = p.parse_args()
    raise SystemExit(0 if check(a.run, a.revision, a.outcome, a.choice, a.visual) else 1)
