"""Replay the P2 game plus real event-triggered audio and UI volume checks."""
import argparse
import json
from pathlib import Path
import re
import shutil
import sys
import uuid
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
import backend as b
import producer
from scripts.check_progression import parse_report
from scripts.validate_revisions import hashes


def check(revision, outcome='won', choice='damage', visual=False):
    run=ROOT/'.playseed/qa/audio-20260907'
    setup=b.read_json(run/'report.json')
    source=run/'project/revisions'/f'{revision:04d}'
    before=hashes(source)
    job=run/'data/jobs'/('audio-play-'+uuid.uuid4().hex);job.mkdir(parents=True)
    scratch=job/'project';shutil.copytree(source,scratch,ignore=shutil.ignore_patterns('.godot'))
    script=(ROOT/'scripts/playthrough_checks/progression.gd').read_text()
    script=script.replace('var game\n','var game\nvar observed_audio: Dictionary = {}\n')
    script=script.replace('    var initial = snap()','''    var initial = snap()
    require(game.audio_snapshot().music_playing, "开局音乐未播放")
    require(game.audio_snapshot().music_id == TRACKS["海岛节拍"], "背景音乐编号错误")''')
    script=script.replace('    require(snap().shots > 0,','    require(game.audio_snapshot().events.get(TRACKS["开火"], 0) == 1, "开火音效未真实触发")\n    require(snap().shots > 0,')
    script=script.replace('        var s = snap()','''        var s = snap()
        var audio_state = game.audio_snapshot()
        for id in audio_state.events: observed_audio[id] = maxi(int(observed_audio.get(id,0)), int(audio_state.events[id]))
        if s.phase in ["combat","intermission"]: require(audio_state.music_playing, "战斗或休整音乐意外停止")''',1)
    script=script.replace('                var choice = KEY_1', '                var previous_upgrade_sounds = game.audio_snapshot().events.get(TRACKS["升级"],0)\n                var choice = KEY_1')
    script=script.replace('                require(selected.upgrade_chosen,','                require(game.audio_snapshot().events.get(TRACKS["升级"],0) == previous_upgrade_sounds + 1, "升级成功未播放一次音效")\n                require(selected.upgrade_chosen,')
    script=script.replace('                var duplicate = snap()', '                var duplicate = snap()\n                require(game.audio_snapshot().events.get(TRACKS["升级"],0) == previous_upgrade_sounds + 1, "重复选择又触发升级音效")')
    script=script.replace('    await capture("end")','''    var ending_audio = game.audio_snapshot()
    require(not ending_audio.music_playing, "结局音乐未停止")
    var cue = TRACKS["胜利"] if OUTCOME == "won" else TRACKS["失败"]
    require(ending_audio.events.get(cue,0) == 1, "结局音效未单次触发")
    if OUTCOME == "won": require(observed_audio.get(TRACKS["命中"],0) > 0, "没有真实命中音效")
    await capture("end")
    click(Vector2(912,28))
    await tick()
    require(game._audio().panel.visible, "声音按钮未打开设置")
    for control in game._audio().panel.get_child(0).get_children():
        if control is HSlider: control.value = 0
    require(game._audio().music.volume_linear == 0 and game._audio().effects[0].volume_linear == 0, "声音滑杆未静音")
    await tick()
    await capture("audio-controls")
    click(Vector2(912,28))''')
    script=script.replace('    for attempt in range(20):','    require(game.audio_snapshot().events.get(cue,0) == 1, "结局后重复播放音效")\n    for attempt in range(20):')
    script=script.replace('        var reset = snap()','''        var reset = snap()
        var restarted_audio = game.audio_snapshot()
        require(restarted_audio.music_playing and restarted_audio.players == 9, "重开未恢复单一音乐播放器")
        require(restarted_audio.active_sfx == 0 and restarted_audio.events.is_empty(), "重开残留音效")
        require(restarted_audio.levels.music == 0 and restarted_audio.levels.sfx == 0, "重开丢失本次静音选择")''')
    script=script.replace('"reset_count":20,','"reset_count":20,"audio_events_observed":observed_audio,"ending_audio":ending_audio,')
    if revision == 7: script=(ROOT/'scripts/playthrough_checks/progression.gd').read_text()
    constants=dict(REVISION=4,TOTAL=4,OUTCOME=outcome,CHOICE=choice,CAPTURE_DIR=str(job/'runtime') if visual else '',TRACKS=setup['tracks'])
    script+='\n'+'\n'.join(f'const {k} = {json.dumps(v,ensure_ascii=False)}' for k,v in constants.items())+'\n'
    (scratch/'_audio_check.gd').write_text(script);(job/'driver.gd').write_text(script)
    report=dict(revision=revision,outcome=outcome,choice=choice,job=str(job))
    try:
        extra=[] if visual else ['--headless']
        out=b.run_process(producer.sandbox_command(b,scratch,job,extra+['--audio-driver','Dummy','--max-fps','60','--script','_audio_check.gd','--quit-after','12000']),job,120,'playthrough',cwd=scratch,child_env=producer.runtime_env())
        report.update(parse_report(out))
    except Exception as exc:
        log=job/'playthrough.log'
        if log.exists():
            try: report.update(parse_report(log.read_text()))
            except Exception: pass
        report.update(passed=False,error=str(exc))
    finally: shutil.rmtree(scratch)
    report['source_unchanged']=before==hashes(source)
    if not report['source_unchanged']: report['passed']=False
    b.atomic_json(run/'playthrough-reports'/f'v{revision}-{outcome}-{choice}-{job.name}.json',report)
    print(json.dumps(report,ensure_ascii=False),flush=True)
    return report.get('passed',False)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('revision',type=int);p.add_argument('--outcome',default='won',choices=['won','lost']);p.add_argument('--choice',default='damage',choices=['damage','heal']);p.add_argument('--visual',action='store_true')
    args=p.parse_args();raise SystemExit(0 if check(args.revision,args.outcome,args.choice,args.visual) else 1)
