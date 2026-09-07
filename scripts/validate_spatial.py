"""Exercise the normal 3D build, modify, restore and export paths in isolation."""
import argparse
import json
from pathlib import Path
import sys
import uuid
import zipfile

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
import backend as b
import producer
import spatial
import resources
from scripts.novice_playtest import file_hashes

RUN=ROOT/'.playseed/validation/p3-room-20260907'
PLAN=dict(title='温室寻物',premise='玩家进入一间低多边形3D温室，寻找两枚种子，然后走到出口离开。',
    player_goal='找到金色种子和蓝色种子，再到花园出口按E完成。',
    core_loop=['WASD或方向键在房间内行走，绕过实体花台','靠近种子按E拾取','收集齐后到出口按E完成，R重来'],
    visual_style='低多边形三维温室，鼠尾草绿地面、木色花台、橙色角色，奶油白中文界面。',
    first_version=['一个12×10的3D房间，固定俯斜相机和实体外墙','中央一座2×1.5×2花台阻挡行走，两枚种子分置房间两侧',
                   '角色从入口开始，靠近按E拾取，重复按E不能重复计数','两枚种子未齐不能完成；齐后到出口按E完成并停止移动','R恢复角色、种子、出口条件，Esc暂停'],
    asset_plan=['本轮明确使用程序几何体临时形象，不使用图片、GLB或音频'],
    later=['GLB模型、骨骼、跳跃、战斗与3D声音'],assumptions=['实验性3D固定房间寻物范围，用于技术验证，不代表任意3D玩法'])


def run(step):
    b.DATA=RUN/'data'
    state_path=RUN/'progress.json'
    if not state_path.exists():
        if step!='build': raise ValueError('先制作首版。')
        ident=uuid.uuid4().hex
        project=RUN/'project';project.mkdir(parents=True)
        idea=dict(id=ident,title=PLAN['title'],revision=1,status='confirmed',confirmed_revision=1,
            ready=True,messages=[],questions=[],history=[],created_at=b.now(),updated_at=b.now(),
            confirmed_at=b.now(),confirmed_by='fixed_validation_brief',project_directory=str(project),plan=PLAN)
        b.atomic_json(b.DATA/'ideas'/ident/'idea.json',idea)
        b.atomic_json(project/'.playseed-project.json',dict(id=ident))
        b.atomic_json(state_path,dict(idea_id=ident,steps=[],scope='固定已确认3D方案，非新手全对话验收'))
    state=b.read_json(state_path)
    expected=['build','modify','restore','restore_modified']
    if len(state['steps'])>=4 or step!=expected[len(state['steps'])] or any(row['status']!='passed' for row in state['steps']):
        raise ValueError('按制作、修改、恢复顺序推进，失败先处理。')
    ident=state['idea_id']; old=producer.read_game(b,ident)
    base=producer.game_root(b,ident)
    before=file_hashes(base/'revisions')
    job=b.DATA/'jobs'/(step+'-'+uuid.uuid4().hex);job.mkdir(parents=True)
    request=dict(action={'build':'build_game','modify':'revise_game','restore':'restore_created','restore_modified':'restore_created'}[step],
        idea_id=ident,revision=1,game_revision=old['current_revision'] if old else 0,
        format=spatial.FORMAT,model='gpt-5.6-sol',reasoning_effort='medium')
    if step=='modify': request['prompt']='增加第三枚红色种子，放在可达且独立的位置。其余两枚种子、房间尺寸、出生点、障碍、出口和速度全部保持；目标改成找到三枚种子再到原出口完成。'
    if step=='restore': request['restore_revision']=1
    if step=='restore_modified': request['restore_revision']=2
    row=dict(step=step,status='running',job=str(job));state['steps'].append(row);b.atomic_json(state_path,state)
    b.atomic_json(job/'request.json',request)
    try:
        if step=='build': b.process_request(dict(action='prepare_build',idea_id=ident,revision=1),job)
        result=b.process_request(request,job);b.atomic_json(job/'result.json',result)
        version=result['game']['current_revision']; source=base/'revisions'/f'{version:04d}'
        world=b.read_json(source/'world.json')
        if step=='build':
            assert len(world['items'])==2 and len(world['obstacles'])==1 and world['size']==[12,10]
        if step=='modify':
            previous=b.read_json(base/'revisions/0001/world.json')
            assert len(world['items'])==3
            for key in ['size','spawn','obstacles','exit','speed']: assert world[key]==previous[key],key
            assert all(item in world['items'] for item in previous['items'])
        after=file_hashes(base/'revisions')
        assert all(after.get(path)==digest for path,digest in before.items()),'旧版被修改'
        if step in ['restore','restore_modified']:
            first=file_hashes(base/'revisions'/f"{request['restore_revision']:04d}");restored=file_hashes(source)
            assert all(restored.get(path)==digest for path,digest in first.items() if path not in ['version.json','preview.png'])
        if step=='restore_modified':
            archive=RUN/'温室寻物-3D源工程.zip'
            resources.export_project(dict(idea_id=ident,game_revision=version,export_path=str(archive)),job,b)
            extracted=job/'exported';extracted.mkdir()
            with zipfile.ZipFile(archive) as bundle:
                bundle.extractall(extracted)
                for name in bundle.namelist(): assert bundle.read(name)==(source/name).read_bytes()
            producer.check(b,extracted,job)
        row.update(status='passed',revision=version,source_hashes=file_hashes(source),
            repair_count=result['game']['versions'][-1]['repair_count'],old_versions_unchanged=True)
    except Exception as exc:
        row.update(status='failed',error=str(exc));raise
    finally:
        b.atomic_json(state_path,state)
        print(json.dumps(row,ensure_ascii=False),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('step',choices=['build','modify','restore','restore_modified'])
    run(parser.parse_args().step)
