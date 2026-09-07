"""Open the checked Blender-produced prop sample without changing the user's project list."""
from pathlib import Path
import sys
import subprocess
import uuid
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
import backend as b
import producer


def play():
    run=ROOT/'.playseed/qa/blender-props-20260907/real'
    state=b.read_json(run/'progress.json')
    if len(state['steps'])!=7 or any(row['status']!='passed' for row in state['steps']):
        raise ValueError('Blender道具与恢复验收尚未完成。')
    project=run/'project/revisions/0009'
    job=run/'data/jobs'/('manual-'+uuid.uuid4().hex);job.mkdir(parents=True)
    producer.check(b,project,job)
    with (job/'play.log').open('w') as log:
        process=subprocess.Popen(producer.sandbox_command(b,project,job,['--max-fps','60']),cwd=project,
            stdout=log,stderr=log,start_new_session=True,env=producer.runtime_env())
    try: process.wait(timeout=1.2)
    except subprocess.TimeoutExpired:
        print('种植箱温室寻物已打开。WASD移动，靠近按E互动，R重开，Esc暂停。')
        return process.pid
    raise RuntimeError('试玩未能打开，请检查日志。')


if __name__=='__main__': play()
