"""Isolated real model draft -> explicit adoption -> game revision -> restore/export."""
import argparse
import json
from pathlib import Path
import shutil
import sys
import uuid
import zipfile
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
import backend as b
import producer
import resources
from scripts.novice_playtest import file_hashes
RUN=ROOT/'.playseed/qa/blender-props-20260907/real'

def run(step):
    b.DATA=RUN/'data';state_path=RUN/'progress.json'
    if not state_path.exists():
        if step!='generate' or RUN.exists():raise ValueError('需要新的独立目录。')
        source=ROOT/'.playseed/qa/glb-20260907';old=b.read_json(source/'progress.json');ident=old['idea_id']
        shutil.copytree(source/'project',RUN/'project',ignore=shutil.ignore_patterns('.godot'))
        shutil.copytree(source/'data/ideas'/ident,b.DATA/'ideas'/ident)
        idea=b.read_json(b.DATA/'ideas'/ident/'idea.json');idea['project_directory']=str(RUN/'project');b.atomic_json(b.DATA/'ideas'/ident/'idea.json',idea)
        b.atomic_json(state_path,dict(idea_id=ident,steps=[]))
    state=b.read_json(state_path);order=['generate','discard','regenerate','adopt','game','export','restore']
    if len(state['steps'])>=len(order) or step!=order[len(state['steps'])] or any(x['status']!='passed' for x in state['steps']):raise ValueError('已有记录需处理，不能重复执行。')
    job=b.DATA/'jobs'/(step+'-'+uuid.uuid4().hex);job.mkdir(parents=True)
    project=RUN/'project';before=file_hashes(project/'revisions');game=producer.read_game(b,state['idea_id'])
    request=dict(idea_id=state['idea_id'],revision=1,model='gpt-5.6-sol',reasoning_effort='medium')
    if step=='generate':request.update(action='generate_model',prompt='制作一个温室里的低多边形木质种植箱：方形矮木箱、深色泥土、两株带茎和绿色椭圆叶片的小苗。基础色、无文字无贴图，部件相接，能从正背面看清。作为中央静态障碍外观。')
    if step=='discard':request.update(action='discard_model',draft_id=state['draft_id'])
    if step=='regenerate':request.update(action='generate_model',prompt='重做低多边形木质种植箱：方形矮箱、深色泥土、两株带绿色椭圆叶片的小苗。基础色无贴图。上一稿叶片悬空，箱底与侧壁外表面共面出现黑缝：这次每株仅两片叶，叶片长轴朝向茎并明确交叠，茎插入泥土；箱底缩进四侧板内部且与侧板接触，避免共面表面重叠。所有部件相接，正背面清楚。')
    if step=='adopt':request.update(action='accept_model',draft_id=state['draft_id'])
    if step=='game':request.update(action='revise_game',game_revision=game['current_revision'],prompt='把中央花台的模型换成新采用的木质种植箱，模型编号'+state['model_id']+'。仅改中央障碍的model_id，其他全部字段与玩法保持。')
    if step=='restore':request.update(action='restore_created',game_revision=game['current_revision'],restore_revision=8)
    row=dict(step=step,status='running',job=str(job));state['steps'].append(row);b.atomic_json(state_path,state)
    try:
        if step=='export':
            archive=RUN/'种植箱源工程.zip';request.update(action='export_project',game_revision=9,export_path=str(archive))
            result=resources.export_project(request,job,b);extracted=job/'extracted';extracted.mkdir()
            with zipfile.ZipFile(archive) as z:
                z.extractall(extracted)
                for name in z.namelist():assert z.read(name)==(project/'revisions/0009'/name).read_bytes()
            producer.check(b,extracted,job)
        else:result=b.process_request(request,job)
        b.atomic_json(job/'request.json',request);b.atomic_json(job/'result.json',result)
        if step in ['generate','regenerate']:
            if step=='regenerate':state['discarded_draft_id']=state['draft_id']
            state['draft_id']=result['model_draft']['id'];assert len(__import__('model_assets').library(project,state['idea_id'])['models'])==1
        if step=='adopt':state['model_id']=result['model_draft']['model_id']
        if step=='game':
            old=b.read_json(project/'revisions/0008/world.json');old['obstacles'][0]['model_id']=state['model_id'];assert b.read_json(project/'revisions/0009/world.json')==old
        if step=='restore':
            assert b.read_json(project/'revisions/0010/world.json')==b.read_json(project/'revisions/0008/world.json')
        after=file_hashes(project/'revisions');assert all(after.get(k)==v for k,v in before.items())
        row.update(status='passed',old_versions_unchanged=True)
    except Exception as e:row.update(status='failed',error=str(e));raise
    finally:b.atomic_json(state_path,state);print(json.dumps(state,ensure_ascii=False),flush=True)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('step',choices=['generate','discard','regenerate','adopt','game','restore','export']);run(p.parse_args().step)
