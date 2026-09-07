"""Verify real mixer output (sound then zero gain) using Godot's WAV capture."""
import json
from pathlib import Path
import shutil
import struct
import sys
import wave
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
import backend as b
import producer
import resources


def run():
    run=ROOT/'.playseed/qa/audio-20260907'
    report=b.read_json(run/'report.json')
    b.DATA=run/'data'
    job=b.DATA/'jobs/mixer-capture'
    if job.exists(): raise ValueError('保留已有声音输出证据。')
    job.mkdir(parents=True)
    project=job/'project';project.mkdir()
    resources.prepare_runtime(b,report['idea_id'],project)
    settings=producer.PROJECT.format(title='"声音输出检查"').replace('960','320').replace('600','180')
    (project/'project.godot').write_text(settings)
    (project/'main.tscn').write_text(producer.SCENE)
    (project/'game.gd').write_text('''extends "res://playseed_base.gd"
var frames = 0
func _ready(): play_music("MUSIC")
func _process(_delta):
    frames += 1
    if frames == 60:
        set_audio_volume("music", 0)
        set_audio_volume("sfx", 0)
        play_sound("SHOT")
'''.replace('MUSIC',report['tracks']['海岛节拍']).replace('SHOT',report['tracks']['开火']))
    output=b.run_process(producer.sandbox_command(b,project,job,['--write-movie',str(job/'runtime/mix.png'),'--fixed-fps','60','--quit-after','120']),job,30,'mix',cwd=project,child_env=producer.runtime_env())
    if 'SCRIPT ERROR:' in output: raise RuntimeError(output)
    wav=job/'runtime/mix.wav'
    with wave.open(str(wav),'rb') as reader:
        rate,channels,width=reader.getframerate(),reader.getnchannels(),reader.getsampwidth()
        raw=reader.readframes(reader.getnframes())
    fmt={2:'h',4:'i'}[width]
    samples=[x[0]/(2**(width*8-1)) for x in struct.iter_unpack('<'+fmt,raw)]
    audible=samples[int(.25*rate)*channels:int(.75*rate)*channels]
    muted=samples[int(1.35*rate)*channels:int(1.8*rate)*channels]
    peaks=dict(audible=max(abs(x) for x in audible),muted=max(abs(x) for x in muted))
    result=dict(passed=peaks['audible']>.001 and peaks['muted']<.00001,peaks=peaks,wav=str(wav),sample_rate=rate,channels=channels)
    b.atomic_json(run/'mixer-report.json',result)
    print(json.dumps(result,ensure_ascii=False))
    if not result['passed']: raise RuntimeError('实际混音或静音检查失败')
    # Frame sequence is transient; retain output WAV, script, logs and one frame.
    for frame in (job/'runtime').glob('mix*.png'):
        if frame.name!='mix00000000.png': frame.unlink()
    return result

if __name__=='__main__': run()
