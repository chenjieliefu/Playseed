"""Independent, fixture-based gameplay checks for the five saved P0 samples.

These are sample-specific developer checks, not a claim of general game QA.
Fixtures may place a character or set resources to reach a state quickly; the
resulting action and simulation are always executed by the generated game.
"""
import argparse
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

DRIVER = '''extends SceneTree
var failed: bool = false
func _initialize():
    call_deferred("run_checks")
func expect(condition: bool, explanation: String):
    if not condition:
        failed = true
        push_error(explanation)
    else:
        print("VERIFIED: " + explanation)
func run_checks():
    var game = load("res://main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.set_process(false)
    game.set_physics_process(false)
    game.reset_game()
    test_game(game, %d)
    if not failed:
        print("PLAYSEED_SEMANTICS_OK")
    quit(1 if failed else 0)
'''


def check(run_name, genre, revision, suite=None):
    suite = suite or genre
    if suite not in ['platformer', 'shooter', 'management', 'puzzle', 'tower_defense', 'shooter_fatal']:
        raise ValueError('未知专项检查。')
    runs = ROOT / '.playseed/validation'
    run = (runs / run_name).resolve()
    if run.parent != runs.resolve():
        raise ValueError('无效验收目录。')
    row = next(item for item in b.read_json(run / 'summary.json')['results'] if item['slug'] == genre)
    project = Path(row['project_directory']) / 'revisions' / f'{revision:04d}'
    body = (ROOT / 'scripts/validation_checks' / (suite + '.gd')).read_text()
    job = run / 'data/jobs' / ('semantics-' + genre + '-' + uuid.uuid4().hex)
    job.mkdir(parents=True)
    scratch = job / 'project'
    shutil.copytree(project, scratch, ignore=shutil.ignore_patterns('.godot'))
    script = DRIVER % revision + '\n' + body
    (scratch / '_semantics.gd').write_text(script)
    (job / 'checks.gd').write_text(script)
    report = {'genre': genre, 'suite': suite, 'revision': revision, 'job': str(job),
              'scope': 'sample-specific deterministic fixtures, not a full playthrough'}
    try:
        output = b.run_process(producer.sandbox_command(b, scratch, job, [
            '--headless', '--script', '_semantics.gd', '--quit-after', '300']),
            job, 25, 'semantics', cwd=scratch, child_env=producer.runtime_env())
        if re.search(r'(?m)(SCRIPT ERROR:|ERROR:)', output) or 'PLAYSEED_SEMANTICS_OK' not in output:
            raise RuntimeError('玩法专项检查未通过。')
        report.update(status='passed', verified=[line.removeprefix('VERIFIED: ')
                                                for line in output.splitlines() if line.startswith('VERIFIED: ')])
    except Exception as exc:
        report.update(status='failed', error=str(exc))
    finally:
        shutil.rmtree(scratch)
        b.atomic_json(run / 'semantic-reports' / f'{suite}-v{revision}.json', report)
    print(json.dumps(report, ensure_ascii=False), flush=True)
    return report['status'] == 'passed'


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='检查固定验收样本的具体玩法。')
    parser.add_argument('run')
    parser.add_argument('genre', choices=['platformer', 'shooter', 'management', 'puzzle', 'tower_defense'])
    parser.add_argument('revision', type=int)
    parser.add_argument('--suite', choices=['shooter_fatal'])
    args = parser.parse_args()
    raise SystemExit(0 if check(args.run, args.genre, args.revision, args.suite) else 1)
