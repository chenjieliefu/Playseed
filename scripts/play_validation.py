"""Open a saved validation game through the same isolated runner as Playseed."""
import argparse
import sys
import subprocess
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import backend
import producer


def play(run_name, genre, revision=None):
    runs = ROOT / '.playseed' / 'validation'
    run = (runs / run_name).resolve()
    if run.parent != runs.resolve():
        raise ValueError('无效的验收目录。')
    summary = backend.read_json(run / 'summary.json')
    record = next(item for item in summary['results']
                  if item['slug'] == genre and item['build'] == 'passed')
    backend.DATA = run / 'data'
    idea_id = record['idea_id']
    game = producer.read_game(backend, idea_id)
    selected = game['current_revision'] if revision is None else revision
    if not any(item['revision'] == selected for item in game['versions']):
        raise ValueError('找不到所选游戏版本。')
    project = producer.game_root(backend, idea_id) / 'revisions' / f"{selected:04d}"
    job = backend.DATA / 'jobs' / ('manual-play-' + uuid.uuid4().hex)
    job.mkdir(parents=True)
    # Recheck the saved files before running them; keep OS isolation in place.
    producer.check(backend, project, job)
    with (job / 'play.log').open('w') as log:
        process = subprocess.Popen(producer.sandbox_command(backend, project, job, ['--max-fps', '60']),
                                   cwd=project, stdout=log, stderr=log, start_new_session=True,
                                   env=producer.runtime_env())
    try:
        process.wait(timeout=1.2)
    except subprocess.TimeoutExpired:
        result = {'summary': f'第 {selected} 版试玩已打开。', 'pid': process.pid}
    else:
        raise RuntimeError('试玩窗口未能启动，请查看本次运行日志。')
    print(record['title'] + '：' + result['summary'])
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='试玩已通过检查的验收游戏。')
    parser.add_argument('run')
    parser.add_argument('genre')
    parser.add_argument('--revision', type=int, help='只试玩指定版本，不更改当前版本。')
    args = parser.parse_args()
    try:
        play(args.run, args.genre, args.revision)
    except Exception as exc:
        print('未能打开试玩：' + str(exc), file=sys.stderr)
        raise SystemExit(1)
