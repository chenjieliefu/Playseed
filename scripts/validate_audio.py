"""Isolated real-model audio revision on a copy of the checked P2 sample."""
import base64
import json
from pathlib import Path
import shutil
import sys
import uuid
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
import backend as b
import producer
from scripts.make_audio_fixture import signals
from scripts.validate_revisions import hashes


def run():
    destination=ROOT/'.playseed/qa/audio-20260907'
    if destination.exists(): raise ValueError('不覆盖已有声音验收，请先查看记录。')
    original=ROOT/'.playseed/validation/p2-20260907'
    source=b.read_json(original/'progression.json')
    ident=source['idea_id']
    shutil.copytree(original/'project',destination/'project',ignore=shutil.ignore_patterns('.godot'))
    b.DATA=destination/'data'
    idea=b.read_json(original/'data/ideas'/ident/'idea.json')
    idea['project_directory']=str(destination/'project')
    b.atomic_json(b.DATA/'ideas'/ident/'idea.json',idea)
    manifest=b.read_json(destination/'project/game.json')
    manifest['current_revision']=4
    b.atomic_json(destination/'project/game.json',manifest)
    report=dict(idea_id=ident,source=str(original),selected_revision=4,tracks={},status='preparing')
    b.atomic_json(destination/'report.json',report)
    files=destination/'fixtures';files.mkdir()
    for name,data in signals().items():
        (files/(name+'.wav')).write_bytes(data)
        job=b.DATA/'jobs'/('import-'+uuid.uuid4().hex);job.mkdir(parents=True)
        request=dict(action='import_audio',idea_id=ident,revision=1,name=name,role='背景音乐' if name=='海岛节拍' else '音效',
                     source='Playseed验收程序合成；原创音符序列、振荡器和固定噪声，无外部录音或采样。制作入口scripts/make_audio_fixture.py',
                     license='其他（见来源说明）',wav_base64=base64.b64encode(data).decode())
        result=b.process_request(request,job)
        b.atomic_json(job/'result.json',result)
        report['tracks'][name]=result['audio_id']
    prompt='为当前四波灯塔守卫加入已导入的声音：海岛节拍循环背景音乐，开火只在炮弹实际发射时播放，命中只在炮弹碰撞时播放，升级在增强火力或修复成功时播放，胜利/失败各在结局时播放一次并停止背景音乐。改为继承可信playseed_base.gd，reset_game先reset_audio再开启背景音乐；保留全部四波、快速船/装甲船、升级/修复、输入、快照及原画面。声音组件自带右上角声音按钮，请把顶部状态文字范围缩到x=860以内避免遮挡。所有播放使用给出的真实编号，音量来自快照，重开不叠播。'
    job=b.DATA/'jobs'/('revise-'+uuid.uuid4().hex);job.mkdir(parents=True)
    request=dict(action='revise_game',idea_id=ident,revision=1,game_revision=4,prompt=prompt,model='gpt-5.6-sol',reasoning_effort='medium')
    before=hashes(destination/'project/revisions')
    b.atomic_json(job/'request.json',request)
    report.update(status='building',job=str(job))
    b.atomic_json(destination/'report.json',report)
    try:
        result=b.process_request(request,job)
        b.atomic_json(job/'result.json',result)
        report.update(status='production_passed',revision=result['game']['current_revision'],repair_count=result['game']['versions'][-1]['repair_count'])
        b.status(job,'done',result['summary'])
    except Exception as exc:
        report.update(status='failed',error=str(exc))
        b.status(job,'error',str(exc))
    after=hashes(destination/'project/revisions')
    report['old_versions_unchanged']=all(after.get(k)==v for k,v in before.items())
    b.atomic_json(destination/'report.json',report)
    print(json.dumps(report,ensure_ascii=False),flush=True)
    return report['status']=='production_passed' and report['old_versions_unchanged']

if __name__=='__main__': raise SystemExit(0 if run() else 1)
