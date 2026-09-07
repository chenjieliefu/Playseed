"""Open the saved audio sample using the same sandbox as the application."""
import argparse
from pathlib import Path
import subprocess
import sys
import uuid
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
import backend as b
import producer


def play(revision=8):
    run=ROOT/'.playseed/qa/audio-20260907'
    setup=b.read_json(run/'report.json')
    b.DATA=run/'data'
    game=producer.read_game(b,setup['idea_id'])
    if revision not in [v['revision'] for v in game['versions']]: raise ValueError('该版本不存在。')
    source=run/'project/revisions'/f'{revision:04d}'
    job=b.DATA/'jobs'/('manual-audio-'+uuid.uuid4().hex);job.mkdir(parents=True)
    producer.check(b,source,job)
    with (job/'play.log').open('w') as log:
        process=subprocess.Popen(producer.sandbox_command(b,source,job,['--max-fps','60']),cwd=source,stdout=log,stderr=log,start_new_session=True,env=producer.runtime_env())
    try: process.wait(timeout=1.2)
    except subprocess.TimeoutExpired:
        print(f'灯塔守卫第{revision}版已打开，可在右上角调节声音。')
        return process.pid
    raise RuntimeError('试玩窗口未启动，请查看本次日志。')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--revision',type=int,default=8)
    play(parser.parse_args().revision)
