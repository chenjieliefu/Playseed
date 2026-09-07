import copy
import json
from pathlib import Path
import tempfile
import socket
import unittest
from unittest.mock import patch
import backend as b
import producer as p

REAL_RENDER = p.render_preview

SCRIPT = '''extends Node2D
var shots = 0
func reset_game():
    shots = 0
func playseed_action(action: String, at: Vector2 = Vector2.ZERO):
    if action == "shoot": shots += 1
func playseed_snapshot() -> Dictionary:
    return {"won": false, "lost": false, "progress": float(shots)}
'''

def output(script=SCRIPT):
    return {'script': script, 'summary': '制作了射击原型', 'controls': ['shoot=射击'],
            'implemented': ['发射'], 'limitations': ['验证脚本'],
            'test': {'action': 'shoot', 'at': [0, 0], 'changed_field': 'progress', 'wait_frames': 1}}

class ProducerTests(unittest.TestCase):
    def setUp(self):
        temp=tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.data=Path(temp.name).resolve()
        change=patch.object(b,'DATA',self.data)
        change.start();self.addCleanup(change.stop)
        preview_patch=patch.object(p,'render_preview')
        preview_patch.start();self.addCleanup(preview_patch.stop)
        self.id='a'*32
        self.idea={'id':self.id,'revision':1,'status':'confirmed','confirmed_revision':1,'title':'验证',
                   'plan':{'title':'验证','core_loop':['射击']}}
        self.path=self.data/'ideas'/self.id/'idea.json'
        b.atomic_json(self.path,self.idea)
        self.job=self.data/'jobs'/'test';self.job.mkdir(parents=True)
        self.request={'action':'build_game','idea_id':self.id,'revision':1,'game_revision':0}

    def build(self):
        with patch.object(b,'request_structured',return_value=output()), patch.object(p,'check'):
            return b.process_request(self.request,self.job)['game']

    def test_stale_play_request_never_launches_another_version(self):
        self.build()
        for value in [0,2,True,None]:
            with patch.object(p.subprocess,'Popen') as launch,self.assertRaisesRegex(ValueError,'版本已更新'):
                b.process_request(dict(self.request,action='play_created',game_revision=value),self.job)
            launch.assert_not_called()

    def test_model_and_reasoning_strength_reach_game_generation(self):
        request = {**self.request, 'model': 'gpt-6-astra', 'reasoning_effort': 'xhigh'}
        with patch.object(b, 'request_structured', return_value=output()) as model, patch.object(p, 'check'):
            b.process_request(request, self.job)
        self.assertEqual(model.call_args.kwargs['model'], 'gpt-6-astra')
        self.assertEqual(model.call_args.kwargs['reasoning_effort'], 'xhigh')

    def test_atomic_versions_modify_restore_and_stale_rejection(self):
        first=self.build()
        before=(p.game_root(b,self.id)/'revisions/0001/game.gd').read_bytes()
        changed=output(SCRIPT.replace('shots += 1','shots += 2'))
        with patch.object(b,'request_structured',return_value=changed),patch.object(p,'check'):
            second=b.process_request({**self.request,'action':'revise_game','game_revision':1,'prompt':'一次射两发'},self.job)['game']
        self.assertEqual(second['current_revision'],2)
        self.assertEqual((p.game_root(b,self.id)/'revisions/0001/game.gd').read_bytes(),before)
        with self.assertRaises(ValueError):
            b.process_request(self.request,self.job)
        with patch.object(p,'check'):
            restored=b.process_request({**self.request,'action':'restore_created','game_revision':2,'restore_revision':1},self.job)['game']
        self.assertEqual(restored['current_revision'],3)
        self.assertEqual((p.game_root(b,self.id)/'revisions/0003/game.gd').read_bytes(),before)
        self.assertEqual(len(restored['versions']),3)

    def test_selected_storage_preserves_versions_and_future_restores(self):
        import storage
        first = self.build()
        original = p.game_root(b, self.id)
        parent = self.data / '用户选择的目录'
        parent.mkdir()
        b.process_request({'action': 'set_games_directory', 'parent_directory': str(parent)}, self.job)
        new_root = p.game_root(b, self.id)
        self.assertEqual(new_root, parent / 'Playseed游戏' / self.id)
        self.assertEqual(p.read_game(b, self.id), first)
        self.assertEqual((new_root / 'revisions/0001/game.gd').read_bytes(), (original / 'revisions/0001/game.gd').read_bytes())
        with patch.object(p, 'check'):
            restored = b.process_request({**self.request, 'action': 'restore_created', 'game_revision': 1, 'restore_revision': 1}, self.job)
        self.assertEqual(restored['game']['current_revision'], 2)
        self.assertTrue((new_root / 'revisions/0002/project.godot').exists())
        self.assertFalse((original / 'revisions/0002').exists())

    def test_legacy_version_without_action_probe_can_still_be_restored(self):
        self.build()
        root = p.game_root(b, self.id)
        manifest = b.read_json(root / 'game.json')
        manifest['versions'][0].pop('test')
        b.atomic_json(root / 'game.json', manifest)
        version = b.read_json(root / 'revisions/0001/version.json')
        version.pop('test')
        b.atomic_json(root / 'revisions/0001/version.json', version)
        with patch.object(p, 'check'):
            restored = b.process_request({**self.request, 'action': 'restore_created', 'game_revision': 1, 'restore_revision': 1}, self.job)['game']
        self.assertEqual(restored['current_revision'], 2)
        self.assertNotIn('test', restored['versions'][-1])
        self.assertIn('legacy restored version', restored['versions'][-1]['validation'])

    def test_preview_action_keeps_manifest_and_revision_unchanged(self):
        self.build()
        manifest=p.game_root(b,self.id)/'game.json'
        before=manifest.read_bytes()
        result=b.process_request({**self.request,'action':'preview_created','game_revision':1},self.job)
        self.assertTrue(result['preview'])
        self.assertEqual(manifest.read_bytes(),before)
        with self.assertRaises(ValueError):
            b.process_request({**self.request,'action':'preview_created','game_revision':0},self.job)

    def test_failed_repair_or_cancel_never_overwrites_playable_version(self):
        self.build()
        manifest=p.game_root(b,self.id)/'game.json';before=manifest.read_bytes()
        request={**self.request,'action':'revise_game','game_revision':1,'prompt':'改变弹道'}
        with patch.object(b,'request_structured',return_value=output(SCRIPT+'\n# revised')),patch.object(p,'check',side_effect=RuntimeError('parse failed')) as checks:
            with self.assertRaises(RuntimeError): b.process_request(request,self.job)
            self.assertEqual(checks.call_count,3)
        self.assertEqual(manifest.read_bytes(),before)
        self.assertFalse(list((manifest.parent/'revisions').glob('.pending-*')))
        def cancel(*args): (self.job/'cancel').touch()
        with patch.object(b,'request_structured',return_value=output(SCRIPT+'\n# change')),patch.object(p,'check',side_effect=cancel):
            with self.assertRaises(InterruptedError): b.process_request(request,self.job)
        self.assertEqual(manifest.read_bytes(),before)

    def test_no_changes_unconfirmed_or_unsafe_code_do_not_publish(self):
        self.build()
        with patch.object(b,'request_structured',return_value=output()),patch.object(p,'check'):
            with self.assertRaises(ValueError):
                b.process_request({**self.request,'action':'revise_game','game_revision':1,'prompt':'改一下'},self.job)
        self.idea['status']='drafting';b.atomic_json(self.path,self.idea)
        with self.assertRaises(ValueError):
            b.process_request({**self.request,'game_revision':1},self.job)
        for code in ['OS.execute("sh", [])', 'FileAccess.open("secret", 1)', 'load("res://other.gd")', 'Expression.new()']:
            with self.assertRaises(ValueError): p.validate_answer(output(SCRIPT+'\n'+code))
        for probe in [
            {'action': '带空格', 'at': [0, 0], 'changed_field': 'progress', 'wait_frames': 1},
            {'action': 'shoot', 'at': [0], 'changed_field': 'progress', 'wait_frames': 1},
            {'action': 'shoot', 'at': [0, 0], 'changed_field': 'progress', 'wait_frames': 121},
            {'action': 'shoot', 'at': [0, 0], 'changed_field': '不合法', 'wait_frames': 1},
        ]:
            with self.assertRaises(ValueError): p.validate_answer({**output(), 'test': probe})

    @unittest.skipUnless(Path('/usr/bin/sandbox-exec').exists(), 'macOS sandbox integration')
    def test_real_engine_startup_and_reset_inside_sandbox(self):
        project=self.data/'generated';project.mkdir()
        for name,text in [('game.gd',SCRIPT),('main.tscn',p.SCENE),('project.godot',p.PROJECT.format(title='"Sandbox Test"')),('_check.gd',p.smoke_script(output()['test']))]:
            (project/name).write_text(text)
        p.check(b,project,self.job)
        (project/'game.gd').write_text(SCRIPT.replace('if action == "shoot": shots += 1', 'pass'))
        with self.assertRaises(RuntimeError):
            p.check(b,project,self.job)
        (project/'game.gd').write_text(SCRIPT)
        REAL_RENDER(b,project,self.job)
        self.assertEqual((project/'preview.png').read_bytes()[:8], b'\x89PNG\r\n\x1a\n')

    @unittest.skipUnless(Path('/usr/bin/sandbox-exec').exists(), 'macOS sandbox integration')
    def test_sandbox_denies_other_files_writes_and_child_shell(self):
        project=self.data/'generated';project.mkdir()
        protected=self.data/'outside.txt';protected.write_text('test-only-canary')
        write_target=self.data/'escaped.txt'
        (project/'project.godot').write_text(p.PROJECT.format(title='"Sandbox Boundary Test"'))
        listener=socket.socket()
        listener.bind(('127.0.0.1',0));listener.listen(1)
        self.addCleanup(listener.close)
        port=listener.getsockname()[1]
        with socket.create_connection(('127.0.0.1',port)):
            connection,_=listener.accept();connection.close()
        script='''extends SceneTree
func _initialize():
    assert(FileAccess.open(%s, FileAccess.READ) == null, "outside read allowed")
    assert(FileAccess.open(%s, FileAccess.WRITE) == null, "outside write allowed")
    assert(OS.execute("/usr/bin/touch", PackedStringArray([%s])) != 0, "child process allowed")
    var tcp = StreamPeerTCP.new()
    assert(tcp.connect_to_host("127.0.0.1", %d) != OK, "network connection allowed")
    print("BOUNDARIES_OK")
    quit()
''' % (json.dumps(str(protected)),json.dumps(str(write_target)),json.dumps(str(write_target)), port)
        (project/'boundary.gd').write_text(script)
        result=b.run_process(p.sandbox_command(b,project,self.job,['--headless','--script','boundary.gd']),self.job,15,'boundary',cwd=project,child_env=p.runtime_env())
        self.assertIn('BOUNDARIES_OK',result)
        self.assertFalse(write_target.exists())
        self.assertEqual(protected.read_text(),'test-only-canary')

if __name__=='__main__':unittest.main()
