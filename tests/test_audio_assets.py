import base64
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import wave
import zipfile
import backend as b
import audio_assets as a
import producer as p
import resources
from scripts.make_audio_fixture import signals


class AudioAssetsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sounds = signals()

    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name).resolve()
        patched = patch.object(b, 'DATA', self.root / 'data')
        patched.start(); self.addCleanup(patched.stop)
        self.id = 'a' * 32
        b.atomic_json(b.DATA / 'ideas' / self.id / 'idea.json', dict(id=self.id, title='声音测试', revision=1,status='confirmed',confirmed_revision=1,plan={'core_loop':['点击']}))
        self.job = b.DATA / 'jobs/test'; self.job.mkdir(parents=True)
        self.request = dict(action='import_audio',idea_id=self.id,revision=1,name='开火',role='音效',source='Playseed程序合成测试，无外部录音',license='其他（见来源说明）',wav_base64=base64.b64encode(self.sounds['开火']).decode())

    def test_import_deduplicates_keeps_sources_and_never_attaches_as_image(self):
        result = b.process_request(self.request,self.job)
        before = a.library(b,self.id)
        b.process_request({**self.request,'source':'不覆盖原记录'},self.job)
        self.assertEqual(a.library(b,self.id),before)
        self.assertEqual(before['tracks'][0]['source'],self.request['source'])
        self.assertEqual(resources.model_images(b,self.id,self.job)[1],[])
        self.assertFalse((p.game_root(b,self.id)/'game.json').exists())
        self.assertTrue((a.root_for(b,self.id)/(result['audio_id']+'.wav')).exists())

    def test_invalid_format_sources_stale_cancel_and_levels_do_not_write(self):
        for change in [{'wav_base64':'bad'}, {'source':''}, {'license':'猜测授权'}, {'revision':2}, {'revision':True}, {'role':'参考图'}]:
            with self.subTest(change=change), self.assertRaises(ValueError): b.process_request({**self.request,**change},self.job)
        self.assertFalse(a.root_for(b,self.id).exists())
        (self.job/'cancel').touch()
        with self.assertRaises(InterruptedError): b.process_request(self.request,self.job)
        (self.job/'cancel').unlink()
        for value in [dict(music=-1,sfx=.5),dict(music=float('nan'),sfx=.5),dict(music=True,sfx=.5),dict(music=.5)]:
            with self.assertRaises(ValueError): b.process_request(dict(action='set_audio_levels',idea_id=self.id,revision=1,levels=value),self.job)
        self.assertFalse(a.root_for(b,self.id).exists())

    def test_wav_limits_reject_truncated_silent_and_wrong_bit_depth(self):
        with self.assertRaises(ValueError): a.decode_wav(self.sounds['开火'][:-2])
        for width,raw in [(1,b'\x80'*40),(2,b'\x00'*40)]:
            buffer=io.BytesIO()
            with wave.open(buffer,'wb') as w:
                w.setnchannels(1);w.setsampwidth(width);w.setframerate(22050);w.writeframes(raw)
            with self.assertRaises(ValueError): a.decode_wav(buffer.getvalue())
        with self.assertRaises(ValueError): a.decode_wav(b'0'*(a.MAX_BYTES+1))

    def test_tamper_symlink_and_missing_audio_block_new_version(self):
        result=b.process_request(self.request,self.job)
        file=a.root_for(b,self.id)/(result['audio_id']+'.wav')
        original=file.read_bytes()
        for mode in ['changed','missing','symlink']:
            if file.exists() or file.is_symlink(): file.unlink()
            if mode=='changed': file.write_bytes(self.sounds['命中'])
            if mode=='symlink':
                outside=self.root/'outside.wav';outside.write_bytes(original);file.symlink_to(outside)
            stage=self.root/mode;stage.mkdir()
            with self.subTest(mode=mode), self.assertRaises(ValueError): resources.prepare_runtime(b,self.id,stage)

    def test_version_snapshot_export_and_restore_do_not_follow_new_library_levels(self):
        result=b.process_request(self.request,self.job)
        first=self.root/'first';first.mkdir()
        resources.prepare_runtime(b,self.id,first)
        b.process_request(dict(action='set_audio_levels',idea_id=self.id,revision=1,levels={'music':0,'sfx':.2}),self.job)
        restored=self.root/'restored';restored.mkdir()
        resources.prepare_runtime(b,self.id,restored,first)
        self.assertEqual((restored/'audio/manifest.json').read_bytes(),(first/'audio/manifest.json').read_bytes())
        self.assertEqual((restored/'playseed_audio.gd').read_bytes(),(first/'playseed_audio.gd').read_bytes())
        new=self.root/'new';new.mkdir();resources.prepare_runtime(b,self.id,new)
        self.assertEqual(json.loads((new/'audio/manifest.json').read_text())['levels']['music'],0)
        base=p.game_root(b,self.id);version=base/'revisions/0001'
        import shutil
        shutil.copytree(first,version)
        b.atomic_json(base/'game.json',{'current_revision':1})
        target=self.root/'export.zip'
        resources.export_project({'idea_id':self.id,'game_revision':1,'export_path':str(target)},self.job,b)
        with zipfile.ZipFile(target) as z:
            self.assertEqual(z.read('audio/'+result['audio_id']+'.wav'),self.sounds['开火'])
            self.assertEqual(z.read('audio/manifest.json'),(first/'audio/manifest.json').read_bytes())

    def test_actual_runtime_sound_music_volume_pause_and_reset(self):
        shot=b.process_request(self.request,self.job)['audio_id']
        music=b.process_request({**self.request,'name':'海岛节拍','role':'背景音乐','wav_base64':base64.b64encode(self.sounds['海岛节拍']).decode()},self.job)['audio_id']
        stage=self.root/'runtime';stage.mkdir();resources.prepare_runtime(b,self.id,stage)
        (stage/'project.godot').write_text(p.PROJECT.format(title='"声音检查"'))
        (stage/'main.tscn').write_text(p.SCENE)
        (stage/'game.gd').write_text('extends "res://playseed_base.gd"\nfunc reset_game(): reset_audio()\nfunc playseed_action(action: String, at: Vector2=Vector2.ZERO): pass\nfunc playseed_snapshot() -> Dictionary: return {"won":false,"lost":false,"progress":0.0}\n')
        script='''extends SceneTree
func _initialize(): call_deferred("run")
func run():
    var game = load("res://main.tscn").instantiate()
    root.add_child(game)
    assert(not game.play_sound("../bad"))
    assert(game.play_music("MUSIC"))
    assert(game.play_music("MUSIC"))
    assert(not game.play_music("SHOT"))
    assert(game.play_sound("SHOT"))
    assert(game.audio_snapshot().music_playing)
    assert(game.audio_snapshot().events["SHOT"] == 1)
    for i in range(30): game.play_sound("SHOT")
    assert(game.audio_snapshot().active_sfx <= 8)
    game.set_audio_volume("music",0)
    game.set_audio_volume("sfx",0.25)
    assert(game._audio().music.volume_linear == 0)
    assert(is_equal_approx(game._audio().effects[0].volume_linear,0.25))
    game.pause_audio(true)
    assert(game._audio().music.stream_paused and not game.play_sound("SHOT"))
    game.pause_audio(false)
    for i in range(20):
        game.reset_game()
        assert(not game.audio_snapshot().music_playing and game.audio_snapshot().active_sfx == 0)
        assert(game.audio_snapshot().levels.music == 0)
        assert(game.play_music("MUSIC"))
    assert(game.audio_snapshot().players == 9)
    print("PLAYSEED_CHECK_OK")
    quit()
'''.replace('MUSIC',music).replace('SHOT',shot)
        (stage/'_check.gd').write_text(script)
        p.check(b,stage,self.job)

    def test_generation_gets_audio_metadata_without_image_attachment_or_raw_bytes(self):
        ident=b.process_request(self.request,self.job)['audio_id']
        answer=dict(summary='保持玩法',controls=['primary=点击'],implemented=['点击'],limitations=[],
                    test=dict(action='primary',at=[0,0],changed_field='shots',wait_frames=0),
                    script='extends Node2D\nvar shots=0\nfunc reset_game(): shots=0\nfunc playseed_action(action: String, at: Vector2=Vector2.ZERO): shots+=1\nfunc playseed_snapshot() -> Dictionary: return {"won":false,"lost":false,"progress":0.0,"shots":shots}\n')
        with patch.object(b,'request_structured',return_value=answer) as model, patch.object(p,'check'), patch.object(p,'render_preview'):
            b.process_request(dict(action='build_game',idea_id=self.id,revision=1,game_revision=0),self.job)
        prompt=model.call_args.args[0]
        self.assertIn('available_audio',prompt)
        self.assertIn(ident,prompt)
        self.assertIn(self.request['source'],prompt)
        self.assertNotIn('wav_base64',prompt)
        self.assertNotIn('images',model.call_args.kwargs)
