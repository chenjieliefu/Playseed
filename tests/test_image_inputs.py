import base64
import hashlib
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import backend as b
import creator
import producer
import resources
from test_resources import png
from test_creator import answer


class ImageInputTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name).resolve()
        self.job = self.root / 'jobs/check'
        self.job.mkdir(parents=True)
        change = patch.object(b, 'DATA', self.root)
        change.start()
        self.addCleanup(change.stop)
        self.attachment = {'name': '参考A', 'role': '角色', 'png_base64': base64.b64encode(png()).decode()}

    def test_home_attachment_is_seen_before_commit_and_reused_on_followup(self):
        folder = self.root / '我的游戏'
        folder.mkdir()
        def observe(*args, **kwargs):
            paths = kwargs['images']
            self.assertEqual(paths[0].read_bytes(), png())
            self.assertIn('attached_images', args[0])
            self.assertFalse((folder / '.playseed-project.json').exists())
            return answer()
        with patch.object(b, 'request_structured', side_effect=observe):
            idea = creator.handle({'action': 'discuss', 'prompt': '用这张图片做主角', 'attachment': self.attachment, 'project_directory': str(folder)}, self.job, b)['idea']
        with patch.object(b, 'request_structured', return_value=answer()) as model:
            creator.handle({'action': 'discuss', 'idea_id': idea['id'], 'revision': 1, 'prompt': '保持这个角色'}, self.job, b)
        self.assertEqual(model.call_args.kwargs['images'][0].read_bytes(), png())

    def test_failed_vision_keeps_first_folder_empty(self):
        folder = self.root / '未完成'
        folder.mkdir()
        with patch.object(b, 'request_structured', side_effect=RuntimeError('视觉请求失败')):
            with self.assertRaises(RuntimeError):
                creator.handle({'action': 'discuss', 'prompt': '看图', 'attachment': self.attachment, 'project_directory': str(folder)}, self.job, b)
        self.assertEqual(list(folder.iterdir()), [])
        self.assertFalse((self.root / 'ideas').exists())

    def test_cli_images_keep_order_and_reject_external_paths(self):
        image_dir = self.job / 'model-images'
        image_dir.mkdir()
        paths = [image_dir / '1.png', image_dir / '2.png']
        for path in paths:
            path.write_bytes(png())
        def complete(args, job, *rest, **kwargs):
            self.assertEqual([args[n+1] for n, arg in enumerate(args) if arg == '--image'], list(map(str, paths)))
            self.assertIn('--sandbox', args)
            (job / 'answer.json').write_text('{}')
        with patch.object(b, 'CODEX', '/bin/echo'), patch.object(b, 'run_process', side_effect=complete):
            b.request_structured('看图', {'type':'object'}, self.job, images=paths)
        outside = self.root / 'outside.png'
        outside.write_bytes(png())
        with patch.object(b, 'CODEX', '/bin/echo'), patch.object(b, 'run_process') as run:
            with self.assertRaises(ValueError):
                b.request_structured('看图', {}, self.job, images=[outside])
            run.assert_not_called()

    def test_referenced_image_priority_and_tamper_rejection(self):
        idea_id = 'a' * 32
        b.atomic_json(creator.path_for(b, idea_id), {'id':idea_id})
        library = resources.library_root(b, idea_id)
        library.mkdir(parents=True)
        import struct,zlib
        # Different valid images, using only fixture IHDR/IDAT generation.
        def image(n):
            def chunk(kind,data):
                return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
            return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',1,1,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(bytes([0,n,80,30,255])))+chunk(b'IEND',b'')
        assets=[]
        for n in range(8):
            data=image(n); asset_id=hashlib.sha256(data).hexdigest()[:32]
            assets.append({'id':asset_id,'name':f'图{n}','role':'角色','width':1,'height':1})
            (library/(asset_id+'.png')).write_bytes(data)
        b.atomic_json(library/'library.json',{'assets':assets})
        meta,paths=resources.model_images(b,idea_id,self.job,'请使用图0')
        self.assertEqual(meta['attached_images'][0]['id'],assets[0]['id'])
        self.assertEqual(meta['images_not_attached'],2)
        self.assertTrue(meta['attached_images'][0]['has_alpha_channel'])
        self.assertEqual(len(paths),6)
        self.assertEqual([a['attachment_number'] for a in meta['attached_images']],list(range(1,7)))
        (library/(assets[0]['id']+'.png')).write_bytes(png())
        with self.assertRaisesRegex(ValueError,'已被修改'):
            resources.model_images(b,idea_id,self.job,'请使用图0')

    def test_generation_repair_retains_image_input_and_restore_does_not_call_model(self):
        idea_id='b'*32
        b.atomic_json(creator.path_for(b,idea_id),{'id':idea_id,'title':'图片验证','revision':1,'confirmed_revision':1,'status':'confirmed','plan':{'title':'图片验证'}})
        resources.import_asset({**self.attachment,'idea_id':idea_id},self.job,b)
        asset_id=resources.library(b,idea_id)['assets'][0]['id']
        response={'summary':'角色换图','controls':['move=移动'],'implemented':['角色图片'],'limitations':[],
                  'test':{'action':'move','at':[0,0],'changed_field':'progress','wait_frames':1},
                  'script':'extends Node2D\nfunc reset_game():\n    pass\nfunc playseed_action(action: String, at: Vector2 = Vector2.ZERO):\n    pass\nfunc playseed_snapshot() -> Dictionary:\n    return {"won":false,"lost":false,"progress":0.0}\n'}
        request={'action':'build_game','idea_id':idea_id,'revision':1,'game_revision':0}
        with patch.object(b,'request_structured',return_value=response) as model, patch.object(producer,'check',side_effect=[RuntimeError('需修复'),None]),patch.object(producer,'render_preview'):
            producer.handle(request,self.job,b)
        self.assertEqual(model.call_count,2)
        for call in model.call_args_list:
            self.assertEqual(call.kwargs['images'][0].read_bytes(),png())
            self.assertIn(asset_id,call.args[0])
        with patch.object(b,'request_structured') as model, patch.object(producer,'check'),patch.object(producer,'render_preview'):
            producer.handle({**request,'action':'restore_created','game_revision':1,'restore_revision':1},self.job,b)
        model.assert_not_called()
