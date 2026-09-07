import base64
import os
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch
import backend as b
import creator
import resources
import image_assets
from test_creator import answer
from test_resources import png


class ImageGenerationTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(); self.addCleanup(temp.cleanup)
        self.root = Path(temp.name).resolve()
        self.job = self.root / 'jobs/test'; self.job.mkdir(parents=True)
        for target in [patch.object(b, 'DATA', self.root / 'data'), patch.dict(os.environ, {'CODEX_HOME':str(self.root / 'codex')})]:
            target.start(); self.addCleanup(target.stop)
        with patch.object(b, 'request_structured', return_value=answer()):
            self.idea = creator.handle({'action':'discuss','prompt':'做一个花园'}, self.job, b)['idea']
        self.base = {'idea_id':self.idea['id'], 'revision':self.idea['revision']}
        creator.handle({'action':'confirm_brief',**self.base}, self.job,b)
        self.output = self.root / 'codex/generated_images/abcd-1234/result.png'
        self.output.parent.mkdir(parents=True); self.output.write_bytes(png())
        (self.job/'codex.log').write_text('session id: abcd-1234\n')

    def generate(self):
        with patch.object(b,'request_structured',return_value={'path':str(self.output),'error':''}):
            return b.process_request({'action':'generate_asset','prompt':'一个小嫩芽','role':'道具',**self.base},self.job)['image_draft']

    def generate_for_task(self):
        task = self.idea['plan']['asset_plan'][0]
        with patch.object(b, 'request_structured', return_value={'path': str(self.output), 'error': ''}):
            draft = b.process_request({'action': 'generate_asset', 'prompt': '小猫角色', 'task': task, **self.base}, self.job)['image_draft']
        return task, draft

    def test_task_draft_binds_only_after_acceptance(self):
        task, draft = self.generate_for_task()
        self.assertEqual(draft['task'], task)
        self.assertEqual(resources.task_assignments(b, self.idea['id']), [])
        b.process_request({'action': 'accept_asset', 'draft_id': draft['id'], **self.base}, self.job)
        assignment = resources.task_assignments(b, self.idea['id'])[0]
        self.assertEqual(assignment['task'], task)
        self.assertEqual(assignment['asset_id'], draft['sha256'][:32])
        self.assertFalse((resources.library_root(b, self.idea['id']).parent / 'game.json').exists())

    def test_discarded_task_draft_does_not_bind(self):
        task, draft = self.generate_for_task()
        b.process_request({'action': 'discard_asset', 'draft_id': draft['id'], **self.base}, self.job)
        self.assertEqual(resources.task_assignments(b, self.idea['id']), [])
        self.assertEqual(resources.library(b, self.idea['id'])['assets'], [])

    def test_invalid_task_rejected_before_model_and_before_accept(self):
        with patch.object(b, 'request_structured') as model:
            with self.assertRaises(ValueError):
                b.process_request({'action': 'generate_asset', 'prompt': '小猫', 'task': '不属于方案', **self.base}, self.job)
            model.assert_not_called()
        task, draft = self.generate_for_task()
        path = resources.library_root(b, self.idea['id']).parent / 'image-drafts' / (draft['id'] + '.json')
        draft['task'] = '错误任务'; b.atomic_json(path, draft)
        with self.assertRaises(ValueError):
            b.process_request({'action': 'accept_asset', 'draft_id': draft['id'], **self.base}, self.job)
        self.assertEqual(resources.library(b, self.idea['id'])['assets'], [])

    def test_generate_review_accept_and_provenance(self):
        draft=self.generate()
        self.assertEqual(resources.library(b,self.idea['id'])['assets'],[])
        self.assertFalse((resources.library_root(b,self.idea['id']).parent/'game.json').exists())
        b.process_request({'action':'accept_asset','draft_id':draft['id'],**self.base},self.job)
        asset=resources.library(b,self.idea['id'])['assets'][0]
        self.assertEqual(asset['generation']['prompt'],'一个小嫩芽')
        self.assertEqual(asset['role'],'道具')
        with self.assertRaisesRegex(ValueError,'已经处理'):
            b.process_request({'action':'accept_asset','draft_id':draft['id'],**self.base},self.job)

    def test_failure_cancel_and_discard_do_not_import(self):
        with patch.object(b,'request_structured',return_value={'path':'','error':'不可用'}):
            with self.assertRaisesRegex(ValueError,'没有完成'):
                self.generate_without_mock()
        draft=self.generate()
        (self.job/'cancel').touch()
        with self.assertRaises(InterruptedError):
            b.process_request({'action':'accept_asset','draft_id':draft['id'],**self.base},self.job)
        (self.job/'cancel').unlink()
        b.process_request({'action':'discard_asset','draft_id':draft['id'],**self.base},self.job)
        self.assertEqual(resources.library(b,self.idea['id'])['assets'],[])

    def generate_without_mock(self):
        return b.process_request({'action':'generate_asset','prompt':'嫩芽',**self.base},self.job)

    def test_reject_unrelated_old_symlink_and_tampered_images(self):
        good={'path':str(self.output)}
        self.assertEqual(image_assets.generated_bytes(good,time.time(),self.job),png())
        wrong=self.output.parent.parent/'ffff/result.png';wrong.parent.mkdir();wrong.write_bytes(png())
        with self.assertRaisesRegex(ValueError,'任务不一致'):
            image_assets.generated_bytes({'path':str(wrong)},time.time(),self.job)
        os.utime(self.output,(1,1))
        with self.assertRaises(ValueError): image_assets.generated_bytes(good,time.time(),self.job)
        os.utime(self.output,None)
        alias=self.output.parent/'alias.png';alias.symlink_to(self.output)
        with self.assertRaises(ValueError): image_assets.generated_bytes({'path':str(alias)},time.time(),self.job)
        draft=self.generate()
        path=resources.library_root(b,self.idea['id']).parent/'image-drafts'/(draft['id']+'.png')
        path.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError,'已被修改'):
            b.process_request({'action':'accept_asset','draft_id':draft['id'],**self.base},self.job)

    def test_stale_plan_cannot_accept_but_can_discard(self):
        draft=self.generate()
        idea= b.read_json(creator.path_for(b,self.idea['id']));idea['revision']+=1
        b.atomic_json(creator.path_for(b,self.idea['id']),idea)
        req={'draft_id':draft['id'],'idea_id':idea['id'],'revision':idea['revision']}
        with self.assertRaisesRegex(ValueError,'旧方案'):
            b.process_request({'action':'accept_asset',**req},self.job)
        b.process_request({'action':'discard_asset',**req},self.job)
        self.assertEqual(resources.library(b,self.idea['id'])['assets'],[])

    def test_changed_plan_during_generation_is_not_committed(self):
        def update(*args,**kwargs):
            path=creator.path_for(b,self.idea['id']);idea=b.read_json(path);idea['revision']+=1;b.atomic_json(path,idea)
            return {'path':str(self.output),'error':''}
        with patch.object(b,'request_structured',side_effect=update):
            with self.assertRaisesRegex(ValueError,'方案已更新'):
                self.generate_without_mock()
        root=resources.library_root(b,self.idea['id']).parent/'image-drafts'
        self.assertEqual(list(root.glob('*.json')),[])

    def test_style_reference_snapshot_and_provenance(self):
        uploaded = resources.import_asset({'idea_id': self.idea['id'], 'png_base64': base64.b64encode(png()).decode(), 'name': '花园画风', 'role': '参考图'}, self.job, b)
        asset_id = uploaded['asset_id']
        with patch.object(b, 'request_structured', return_value={'path': str(self.output), 'error': ''}) as model:
            draft = b.process_request({'action': 'generate_asset', 'prompt': '一朵花', 'style_reference_id': asset_id, **self.base}, self.job)['image_draft']
        paths = model.call_args.kwargs['images']
        self.assertEqual(len(paths), 1)
        self.assertEqual(paths[0].read_bytes(), png())
        self.assertEqual(paths[0].parent, self.job / 'model-images')
        self.assertEqual(draft['style_references'][0]['id'], asset_id)
        b.process_request({'action': 'accept_asset', 'draft_id': draft['id'], **self.base}, self.job)
        self.assertEqual(resources.library(b, self.idea['id'])['assets'][0]['generation']['style_references'], draft['style_references'])

    def test_reference_rejects_foreign_invalid_and_tampered_before_request(self):
        for bad in [None, [], '../private', 'f' * 32]:
            with patch.object(b, 'request_structured') as model:
                with self.assertRaises(ValueError):
                    b.process_request({'action': 'generate_asset', 'prompt': '花', 'style_reference_id': bad, **self.base}, self.job)
                model.assert_not_called()
        result = resources.import_asset({'idea_id': self.idea['id'], 'png_base64': base64.b64encode(png()).decode(), 'name': '参考', 'role': '参考图'}, self.job, b)
        (resources.library_root(b, self.idea['id']) / (result['asset_id'] + '.png')).write_bytes(b'bad')
        with patch.object(b, 'request_structured') as model:
            with self.assertRaises(ValueError):
                b.process_request({'action': 'generate_asset', 'prompt': '花', 'style_reference_id': result['asset_id'], **self.base}, self.job)
            model.assert_not_called()

    def test_no_reference_does_not_attach_recent_assets(self):
        resources.import_asset({'idea_id': self.idea['id'], 'png_base64': base64.b64encode(png()).decode(), 'name': '不应自动参考', 'role': '参考图'}, self.job, b)
        with patch.object(b, 'request_structured', return_value={'path': str(self.output), 'error': ''}) as model:
            result = self.generate_without_mock()
        self.assertNotIn('images', model.call_args.kwargs)
        self.assertNotIn('style_references', result['image_draft'])

    def repair(self, draft_id):
        with patch.object(b, 'request_structured', return_value={'path': str(self.output), 'error': ''}) as model:
            result = b.process_request({'action': 'repair_asset_transparency', 'draft_id': draft_id, **self.base}, self.job)
        return result['image_draft'], model.call_args

    def test_repair_preserves_original_and_rejects_opaque_adoption(self):
        original = self.generate()
        repaired, call = self.repair(original['id'])
        self.assertNotEqual(original['id'], repaired['id'])
        self.assertEqual(repaired['repairs_draft_id'], original['id'])
        self.assertTrue(repaired['requires_transparency'])
        self.assertEqual(call.kwargs['images'][0].read_bytes(), png())
        self.assertFalse(repaired['pixel_check']['has_transparent_pixels'])
        with self.assertRaisesRegex(ValueError, '仍没有真实透明'):
            b.process_request({'action': 'accept_asset', 'draft_id': repaired['id'], **self.base}, self.job)
        folder = resources.library_root(b, self.idea['id']).parent / 'image-drafts'
        self.assertEqual(b.read_json(folder / (original['id'] + '.json'))['state'], 'review')
        self.assertEqual(resources.library(b, self.idea['id'])['assets'], [])

    def test_real_pixels_and_repaired_adoption(self):
        import struct, zlib
        def transparent_image(empty=False):
            def chunk(kind, data):
                return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
            raw = (b'\0' + b'\x90\xd0\x60\0' * 16) * 16 if empty else (b'\0' + b'\x90\xd0\x60\0' * 8 + b'\x90\xd0\x60\xff' * 8) * 16
            return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB',16,16,8,6,0,0,0)) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b'')
        with self.assertRaisesRegex(ValueError, '没有可见内容'):
            image_assets.inspect_pixels(transparent_image(True), self.job, b)
        original = self.generate()
        self.output.write_bytes(transparent_image())
        repaired, _ = self.repair(original['id'])
        self.assertTrue(repaired['pixel_check']['has_transparent_pixels'])
        b.process_request({'action':'accept_asset', 'draft_id':repaired['id'], **self.base}, self.job)
        asset = resources.library(b, self.idea['id'])['assets'][0]
        self.assertEqual(asset['generation']['repairs_draft_id'], original['id'])

    def test_repair_rejects_old_processed_tampered_and_cancelled(self):
        original = self.generate()
        folder = resources.library_root(b, self.idea['id']).parent / 'image-drafts'
        path = folder / (original['id'] + '.json')
        for change in [{'source_revision': 999}, {'state': 'accepted'}, {'idea_id':'f'*32}]:
            b.atomic_json(path, {**original, **change})
            with patch.object(b, 'request_structured') as model:
                with self.assertRaises(ValueError): self.repair_unmocked(original['id'])
                model.assert_not_called()
        b.atomic_json(path, original)
        (self.job/'cancel').touch()
        with patch.object(b, 'request_structured') as model:
            with self.assertRaises(InterruptedError): self.repair_unmocked(original['id'])
            model.assert_not_called()
        (self.job/'cancel').unlink()
        (folder / (original['id'] + '.png')).write_bytes(b'bad')
        with patch.object(b, 'request_structured') as model:
            with self.assertRaises(ValueError): self.repair_unmocked(original['id'])
            model.assert_not_called()

    def repair_unmocked(self, draft_id):
        return b.process_request({'action':'repair_asset_transparency', 'draft_id':draft_id, **self.base}, self.job)

    def test_native_cutout_uses_no_model_and_preserves_source(self):
        original = self.generate()
        with patch.object(image_assets, 'native_cutout', return_value=png()) as cutout, patch.object(b, 'request_structured') as model:
            result = b.process_request({'action': 'cutout_asset', 'draft_id': original['id'], 'edge_inset': 4, **self.base}, self.job)['image_draft']
        model.assert_not_called()
        self.assertEqual(cutout.call_args.args[0].read_bytes(), png())
        self.assertEqual(cutout.call_args.args[2], 4)
        self.assertEqual(result['provider'], 'macOS本机背景分离')
        self.assertIsNone(result['request_model'])
        self.assertEqual(result['edge_inset'], 4)
        self.assertEqual(result['repairs_draft_id'], original['id'])
        self.assertEqual(resources.library(b, self.idea['id'])['assets'], [])

    def test_native_rejects_bad_edge_and_processing_failure(self):
        original = self.generate()
        req = {'action': 'cutout_asset', 'draft_id': original['id'], **self.base}
        for edge in [-2, 9, True, '4', None]:
            with patch.object(image_assets, 'native_cutout') as cutout:
                with self.assertRaises(ValueError): b.process_request({**req, 'edge_inset': edge}, self.job)
                cutout.assert_not_called()
        with patch.object(image_assets, 'native_cutout', side_effect=ValueError('组件不可用')), patch.object(b, 'request_structured') as model:
            with self.assertRaises(ValueError): b.process_request(req, self.job)
            model.assert_not_called()
        folder = resources.library_root(b, self.idea['id']).parent / 'image-drafts'
        self.assertEqual(len(list(folder.glob('*.json'))), 1)
        self.assertEqual(b.read_json(folder / (original['id'] + '.json'))['state'], 'review')

    def test_light_cleanup_is_explicit_and_recorded(self):
        original = self.generate()
        request = {'action':'cutout_asset', 'draft_id':original['id'], **self.base}
        with patch.object(image_assets, 'native_cutout', return_value=png()) as processor:
            result = b.process_request({**request, 'cleanup_light_edges':True}, self.job)['image_draft']
        self.assertTrue(processor.call_args.kwargs['cleanup_light_edges'])
        self.assertTrue(result['cleanup_light_edges'])
        with patch.object(image_assets, 'native_cutout') as processor:
            with self.assertRaises(ValueError): b.process_request({**request, 'cleanup_light_edges':'true'}, self.job)
            processor.assert_not_called()

    def test_native_detail_loss_explains_recovery_without_new_draft(self):
        original = self.generate()
        def refuse(*args, **kwargs):
            (self.job / 'native-cutout.log').write_text('PLAYSEED_CUTOUT_DETAIL_LOSS\n')
            raise RuntimeError('native process failed')
        with patch.object(b, 'run_process', side_effect=refuse), patch.object(b, 'request_structured') as model:
            with self.assertRaisesRegex(ValueError, '关闭“清理浅色残边”'):
                b.process_request({'action':'cutout_asset','draft_id':original['id'],'cleanup_light_edges':True,**self.base},self.job)
            model.assert_not_called()
        folder = resources.library_root(b, self.idea['id']).parent / 'image-drafts'
        self.assertEqual(len(list(folder.glob('*.json'))), 1)
        self.assertEqual(b.read_json(folder / (original['id'] + '.json'))['state'], 'review')

    def test_confirmed_style_reaches_generation_and_survives_plan_change(self):
        idea_path = b.DATA / 'ideas' / self.idea['id'] / 'idea.json'
        idea = b.read_json(idea_path)
        style = '圆润卡通造型、低饱和暖色、平涂，不使用写实毛发'
        idea['plan']['visual_style'] = style
        b.atomic_json(idea_path, idea)
        with patch.object(b, 'request_structured', return_value={'path':str(self.output),'error':''}) as model:
            draft = b.process_request({'action':'generate_asset','prompt':'小猫','role':'角色',**self.base},self.job)['image_draft']
        self.assertIn(style, model.call_args.args[0])
        self.assertEqual(draft['visual_style'],style)
        b.process_request({'action':'accept_asset','draft_id':draft['id'],**self.base},self.job)
        idea['plan']['visual_style'] = '写实自然材质'
        idea['revision'] += 1
        b.atomic_json(idea_path,idea)
        asset = resources.library(b,self.idea['id'])['assets'][0]
        self.assertEqual(asset['generation']['visual_style'],style)
