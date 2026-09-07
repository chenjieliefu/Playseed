"""Real GLB import, two AI revisions, restore and export in an isolated project."""
import argparse
import base64
import json
from pathlib import Path
import shutil
import sys
import uuid
import zipfile
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
import backend as b
import producer
import resources
from scripts.novice_playtest import file_hashes

RUN=ROOT/'.playseed/qa/glb-20260907'

def run(step):
    source=ROOT/'.playseed/validation/p3-room-20260907'
    state_path=RUN/'progress.json'
    b.DATA=RUN/'data'
    if not state_path.exists():
        if step!='model' or RUN.exists(): raise ValueError('从新的独立目录开始。')
        ident=b.read_json(source/'progress.json')['idea_id']
        shutil.copytree(source/'project',RUN/'project',ignore=shutil.ignore_patterns('.godot'))
        shutil.copytree(source/'data/ideas'/ident,b.DATA/'ideas'/ident)
        idea=b.read_json(b.DATA/'ideas'/ident/'idea.json');idea['project_directory']=str(RUN/'project')
        b.atomic_json(b.DATA/'ideas'/ident/'idea.json',idea)
        job=b.DATA/'jobs'/('import-'+uuid.uuid4().hex);job.mkdir(parents=True)
        raw=(ROOT/'.playseed/qa/material-closeout/blender/planter.glb').read_bytes()
        request=dict(action='import_model',idea_id=ident,revision=1,name='低多边形花盆',purpose='替换中央花台的外观，保持盒形碰撞',
          source='本机Blender5.2.1制作的五部件原创花盆；花盆、泥土、茎与左右叶。制作记录research/blender-2026-09-07/接入验证.md，无外部采样。',
          license='其他（见来源说明）',glb_base64=base64.b64encode(raw).decode())
        result=b.process_request(request,job);b.atomic_json(job/'result.json',result)
        b.atomic_json(state_path,dict(idea_id=ident,model_id=result['model']['id'],steps=[],source=str(source)))
    state=b.read_json(state_path)
    expected=['model','resize','restore_plain','restore_model']
    if len(state['steps'])>=4 or step!=expected[len(state['steps'])] or any(row['status']!='passed' for row in state['steps']): raise ValueError('先处理已有记录，不能重复推进。')
    ident=state['idea_id'];base=RUN/'project'
    game=producer.read_game(b,ident);before=file_hashes(base/'revisions')
    job=b.DATA/'jobs'/(step+'-'+uuid.uuid4().hex);job.mkdir(parents=True)
    request=dict(action='restore_created' if step.startswith('restore') else 'revise_game',idea_id=ident,revision=1,game_revision=game['current_revision'],model='gpt-5.6-sol',reasoning_effort='medium')
    if step=='model': request['prompt']=f"把中央花台换成已入库的低多边形花盆模型，编号{state['model_id']}。仅为中央花台增加model_id；完整保留当前所有其他字段和游戏玩法，包括三枚种子、位置、尺寸、速度、出口、颜色和目标。"
    if step=='resize': request['prompt']='把中央花台外盒尺寸从2×1.5×2调整为3×2×3，让花盆按原比例一起变大。只改该障碍的size，其他所有字段包括model_id、位置、物品、出口、速度和颜色保持。'
    if step=='restore_plain': request['restore_revision']=4
    if step=='restore_model': request['restore_revision']=5
    row=dict(step=step,status='running',job=str(job));state['steps'].append(row);b.atomic_json(state_path,state)
    b.atomic_json(job/'request.json',request)
    try:
        result=b.process_request(request,job);b.atomic_json(job/'result.json',result)
        version=result['game']['current_revision'];folder=base/'revisions'/f'{version:04d}'
        world=b.read_json(folder/'world.json')
        previous=b.read_json(base/'revisions'/f"{game['current_revision']:04d}"/'world.json')
        if step=='model':
            expected_world=json.loads(json.dumps(previous));expected_world['obstacles'][0]['model_id']=state['model_id']
            assert world==expected_world,'修改改变了模型编号之外的内容'
            assert (folder/'models'/(state['model_id']+'.glb')).is_file()
        if step=='resize':
            expected_world=json.loads(json.dumps(previous));expected_world['obstacles'][0]['size']=[3,2,3]
            assert world==expected_world,'修改改变了尺寸之外的内容'
        if step.startswith('restore'):
            target=base/'revisions'/f"{request['restore_revision']:04d}"
            hashes=file_hashes(folder)
            assert all(hashes.get(name)==digest for name,digest in file_hashes(target).items() if name not in ['version.json','preview.png'])
        if step=='restore_plain': assert not (folder/'models').exists()
        if step=='restore_model':
            archive=RUN/'温室寻物-模型版源工程.zip'
            resources.export_project(dict(idea_id=ident,game_revision=version,export_path=str(archive)),job,b)
            extracted=job/'exported';extracted.mkdir()
            with zipfile.ZipFile(archive) as bundle:
                bundle.extractall(extracted)
                for name in bundle.namelist(): assert bundle.read(name)==(folder/name).read_bytes()
            producer.check(b,extracted,job)
        after=file_hashes(base/'revisions')
        assert all(after.get(name)==digest for name,digest in before.items()),'旧版发生变化'
        row.update(status='passed',revision=version,repair_count=result['game']['versions'][-1]['repair_count'],old_versions_unchanged=True,source_hashes=file_hashes(folder))
    except Exception as exc:
        row.update(status='failed',error=str(exc));raise
    finally:
        b.atomic_json(state_path,state);print(json.dumps(row,ensure_ascii=False),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('step',choices=['model','resize','restore_plain','restore_model']);run(p.parse_args().step)
