import base64
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import backend as b
import resources as r
import sprite_assets as s
from test_resources import png


class SpriteAssetsTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(); self.addCleanup(temp.cleanup)
        self.root=Path(temp.name)
        change=patch.object(b,'DATA',self.root);change.start();self.addCleanup(change.stop)
        self.idea_id='f'*32
        self.path=self.root/'ideas'/self.idea_id/'idea.json'
        b.atomic_json(self.path,{'id':self.idea_id,'title':'帧动画','revision':1,'confirmed_revision':1,'status':'confirmed','plan':{}})
        self.job=self.root/'job';self.job.mkdir()
        result=b.process_request({'action':'import_asset','idea_id':self.idea_id,'png_base64':base64.b64encode(png()).decode(),'name':'生长','role':'道具'},self.job)
        self.asset_id=result['asset_id']
        self.config={'columns':2,'rows':2,'first_frame':1,'frame_count':3,'fps':8,'loop':False}
        self.request={'action':'configure_asset_animation','idea_id':self.idea_id,'revision':1,'asset_id':self.asset_id,'animation':self.config}

    def test_configuration_reaches_model_snapshot_without_changing_png(self):
        b.process_request(self.request,self.job)
        manifest=r.library(b,self.idea_id)
        self.assertEqual(manifest['assets'][0]['animation']['frame_width'],8)
        self.assertEqual((r.library_root(b,self.idea_id)/(self.asset_id+'.png')).read_bytes(),png())
        context,paths=r.model_images(b,self.idea_id,self.job)
        self.assertEqual(context['attached_images'][0]['animation']['frame_count'],3)
        stage=self.root/'stage';stage.mkdir()
        r.prepare_runtime(b,self.idea_id,stage)
        self.assertEqual(b.read_json(stage/'assets/animations.json')[self.asset_id]['first_frame'],1)
        self.assertTrue((stage/'playseed_sprite_frames.gd').exists())
        b.process_request({**self.request,'action':'clear_asset_animation'},self.job)
        self.assertNotIn('animation',r.library(b,self.idea_id)['assets'][0])
        restored=self.root/'restored';restored.mkdir()
        r.prepare_runtime(b,self.idea_id,restored,restored=stage)
        self.assertEqual((stage/'assets/animations.json').read_bytes(),(restored/'assets/animations.json').read_bytes())
        self.assertFalse((r.library_root(b,self.idea_id).parent/'game.json').exists())

    def test_invalid_old_cancelled_and_corrupt_never_commit(self):
        manifest=r.library_root(b,self.idea_id)/'library.json'
        before=manifest.read_bytes()
        for config in [{**self.config,'columns':3},{**self.config,'rows':True},{**self.config,'first_frame':2},{**self.config,'fps':31},{**self.config,'loop':'true'}]:
            with self.assertRaises(ValueError): b.process_request({**self.request,'animation':config},self.job)
        for extra in [{'revision':2},{'asset_id':'a'*32},{'asset_id':'../x'}]:
            with self.assertRaises(ValueError): b.process_request({**self.request,**extra},self.job)
        (self.job/'cancel').touch()
        with self.assertRaises(InterruptedError): b.process_request(self.request,self.job)
        (self.job/'cancel').unlink()
        (r.library_root(b,self.idea_id)/(self.asset_id+'.png')).write_bytes(b'bad')
        with self.assertRaises(ValueError): b.process_request(self.request,self.job)
        self.assertEqual(manifest.read_bytes(),before)

    def test_chinese_chat_configuration_validates_and_saves(self):
        b.process_request({**self.request,'action':'configure_asset_animation_text','prompt':'设置动画：「生长」，2列，2行，从2格开始，3帧，每秒12帧，不循环'},self.job)
        animation=r.library(b,self.idea_id)['assets'][0]['animation']
        self.assertEqual(animation['first_frame'],1)
        self.assertEqual(animation['fps'],12)
        self.assertFalse(animation['loop'])
        with self.assertRaises(ValueError):
            b.process_request({**self.request,'action':'configure_asset_animation_text','prompt':'设置动画：随便设置'},self.job)

    def test_game_versions_keep_their_animation_settings_on_restore(self):
        import producer as p
        b.process_request(self.request,self.job)
        script = '''extends "res://playseed_base.gd"
var actor: AnimatedSprite2D
var progress_value = 0
func _ready():
 actor = AnimatedSprite2D.new()
 actor.sprite_frames = asset_animation("ASSET")
 assert(actor.sprite_frames != null)
 assert(actor.sprite_frames.get_frame_count("default") == 3)
 add_child(actor)
 reset_game()
func reset_game():
 progress_value = 0
 actor.stop()
 actor.frame = 0
 actor.frame_progress = 0
func playseed_action(action: String, at: Vector2 = Vector2.ZERO):
 if action == "primary":
  progress_value += 1
  actor.play("default")
func playseed_snapshot() -> Dictionary:
 return {"won":false,"lost":false,"progress":progress_value}
'''.replace('ASSET',self.asset_id)
        answer={'script':script,'summary':'三帧验证','implemented':['帧动画'],'limitations':[], 'controls':['primary=播放'], 'test':{'action':'primary','at':[0,0],'changed_field':'progress','wait_frames':10}}
        request={'action':'build_game','idea_id':self.idea_id,'revision':1,'game_revision':0}
        with patch.object(b,'request_structured',return_value=answer),patch.object(p,'render_preview'):
            b.process_request(request,self.job)
        first=p.game_root(b,self.idea_id)/'revisions/0001'
        original=(first/'assets/animations.json').read_bytes()
        b.process_request({**self.request,'animation':{**self.config,'fps':20}},self.job)
        with patch.object(p,'render_preview'):
            result=b.process_request({**request,'action':'restore_created','game_revision':1,'restore_revision':1},self.job)
        second=p.game_root(b,self.idea_id)/'revisions/0002'
        self.assertEqual(result['game']['current_revision'],2)
        self.assertEqual((second/'assets/animations.json').read_bytes(),original)
        self.assertEqual((first/'assets/animations.json').read_bytes(),original)
        self.assertEqual(r.library(b,self.idea_id)['assets'][0]['animation']['fps'],20)

    def test_optional_alignment_survives_chat_speed_change_and_rejects_invalid(self):
        b.process_request({**self.request,'animation':{**self.config,'align_bottom':True}},self.job)
        b.process_request({**self.request,'action':'configure_asset_animation_text','prompt':'设置动画：「生长」，2列，2行，从2格开始，3帧，每秒12帧，不循环'},self.job)
        self.assertTrue(r.library(b,self.idea_id)['assets'][0]['animation']['align_bottom'])
        b.process_request({**self.request,'action':'configure_asset_animation_text','prompt':'设置动画：「生长」，2列，2行，从2格开始，3帧，每秒12帧，不循环，保留原位'},self.job)
        self.assertFalse(r.library(b,self.idea_id)['assets'][0]['animation']['align_bottom'])
        with self.assertRaises(ValueError):
            b.process_request({**self.request,'animation':{**self.config,'align_bottom':'true'}},self.job)
