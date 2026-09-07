import base64
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
import zipfile
import zlib
import backend as b
import producer as p
import resources as r


def png():
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 16, 16, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress((b'\0' + b'\x90\xd0\x60\xff' * 16) * 16)) + chunk(b'IEND', b'')

class ResourceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.data = Path(self.temp.name).resolve()
        change = patch.object(b, 'DATA', self.data)
        change.start(); self.addCleanup(change.stop)
        self.idea_id = 'a' * 32
        self.job = self.data / 'jobs/test'; self.job.mkdir(parents=True)
        b.atomic_json(self.data / 'ideas' / self.idea_id / 'idea.json', {'id': self.idea_id, 'title': '资源验收', 'status': 'confirmed', 'revision': 1, 'confirmed_revision': 1, 'plan': {'title': '资源验收'}})
        self.request = {'action': 'import_asset', 'idea_id': self.idea_id, 'png_base64': base64.b64encode(png()).decode(), 'name': '小芽', 'role': '角色'}

    def test_image_import_validation_deduplication(self):
        b.process_request(self.request, self.job)
        b.process_request(self.request, self.job)
        assets = r.library(b, self.idea_id)['assets']
        self.assertEqual(len(assets), 1)
        self.assertEqual(assets[0]['width'], 16)
        self.assertEqual((r.library_root(b, self.idea_id) / (assets[0]['id'] + '.png')).read_bytes(), png())
        for data in [b'not an image', png()[:-4], png() + b'extra']:
            with self.assertRaises(ValueError):
                b.process_request({**self.request, 'png_base64': base64.b64encode(data).decode()}, self.job)

    def task_fixture(self):
        idea_file = b.DATA / 'ideas' / self.idea_id / 'idea.json'
        idea = b.read_json(idea_file)
        idea['plan']['asset_plan'] = ['玩家角色', '花园场景']
        b.atomic_json(idea_file, idea)
        b.process_request(self.request, self.job)
        asset = r.library(b, self.idea_id)['assets'][0]
        return {'action': 'bind_asset_task', 'idea_id': self.idea_id, 'revision': 1, 'task': '玩家角色', 'asset_id': asset['id']}

    def test_task_binding_reaches_model_and_unbind_keeps_image(self):
        request = self.task_fixture()
        result = b.process_request(request, self.job)
        self.assertTrue(result['library_changed'])
        context, paths = r.model_images(b, self.idea_id, self.job)
        self.assertEqual(context['asset_task_assignments'][0]['asset_id'], request['asset_id'])
        self.assertEqual(context['asset_task_assignments'][0]['task'], '玩家角色')
        self.assertEqual(paths[0].read_bytes(), png())
        b.process_request({**request, 'asset_id': ''}, self.job)
        self.assertEqual(r.task_assignments(b, self.idea_id), [])
        self.assertEqual((r.library_root(b, self.idea_id) / (request['asset_id'] + '.png')).read_bytes(), png())
        self.assertFalse((r.library_root(b, self.idea_id).parent / 'game.json').exists())

    def test_invalid_stale_or_cancelled_binding_never_changes_library(self):
        request = self.task_fixture()
        manifest_file = r.library_root(b, self.idea_id) / 'library.json'
        old = manifest_file.read_bytes()
        for change in [{'revision': 2}, {'revision': True}, {'task': '任意任务'}, {'asset_id': 'b' * 32}, {'asset_id': '../other'}]:
            with self.subTest(change=change), self.assertRaises(ValueError):
                b.process_request({**request, **change}, self.job)
            self.assertEqual(manifest_file.read_bytes(), old)
        (self.job / 'cancel').touch()
        with self.assertRaises(InterruptedError): b.process_request(request, self.job)
        self.assertEqual(manifest_file.read_bytes(), old)

    def test_new_plan_does_not_silently_reuse_old_task_binding(self):
        request = self.task_fixture()
        b.process_request(request, self.job)
        idea_file = b.DATA / 'ideas' / self.idea_id / 'idea.json'
        idea = b.read_json(idea_file); idea['revision'] = 2
        b.atomic_json(idea_file, idea)
        self.assertEqual(r.task_assignments(b, self.idea_id), [])
        self.assertIn('1', r.library(b, self.idea_id)['task_bindings'])

    def test_missing_or_tampered_task_image_is_rejected(self):
        request = self.task_fixture()
        file = r.library_root(b, self.idea_id) / (request['asset_id'] + '.png')
        file.write_bytes(b'broken')
        with self.assertRaises(ValueError): b.process_request(request, self.job)
        file.unlink()
        with self.assertRaises(ValueError): b.process_request(request, self.job)
        self.assertNotIn('task_bindings', r.library(b, self.idea_id))

    def test_upload_and_deduplicated_upload_bind_task_in_same_manifest(self):
        request = self.task_fixture()
        root = r.library_root(b, self.idea_id)
        result = b.process_request({**self.request, 'task': '花园场景', 'revision': 1}, self.job)
        self.assertEqual(result['asset_id'], request['asset_id'])
        manifest = r.library(b, self.idea_id)
        self.assertEqual(len(manifest['assets']), 1)
        self.assertEqual(manifest['task_bindings']['1']['花园场景'], request['asset_id'])
        self.assertFalse((root.parent / 'game.json').exists())

    def test_stale_upload_task_does_not_import_or_change_existing_binding(self):
        request = self.task_fixture()
        b.process_request(request, self.job)
        manifest = r.library_root(b, self.idea_id) / 'library.json'
        old = manifest.read_bytes()
        for patch_request in [{'task': '任意任务', 'revision': 1}, {'task': '玩家角色', 'revision': 2}]:
            with self.assertRaises(ValueError):
                b.process_request({**self.request, **patch_request}, self.job)
            self.assertEqual(manifest.read_bytes(), old)

    def test_resource_game_runs_in_sandbox_and_exports_immutable_version(self):
        b.process_request(self.request, self.job)
        asset_id = r.library(b, self.idea_id)['assets'][0]['id']
        script = '''extends "res://playseed_base.gd"
var image_width = 0
var actor: Sprite2D
func _ready():
    actor = Sprite2D.new()
    actor.texture = asset_texture("ASSET_ID")
    assert(actor.texture != null)
    image_width = actor.texture.get_width()
    add_child(actor)
    animate_pop(actor)
    animate_float(actor)
    animate_pulse(actor)
    animate_squash(actor)
    animate_spin(actor)
    animate_fade(actor)
    effect_burst(Vector2(30,30))
    effect_ring(Vector2(50,30))
    effect_trail(Vector2(70,30))
    effect_beam(Vector2(90,30))
func reset_game():
    image_width = actor.texture.get_width()
    assert(image_width == 16)
func playseed_action(action: String, at: Vector2 = Vector2.ZERO):
    if action == "probe": image_width += 1
func playseed_snapshot() -> Dictionary:
    return {"won": false, "lost": false, "progress": float(image_width)}
'''.replace('ASSET_ID', asset_id)
        answer = {'script': script, 'summary': '真实图片与动画特效', 'implemented': ['图片', '动画', '特效'], 'limitations': [], 'controls': ['probe=验证素材状态'], 'test': {'action': 'probe', 'at': [0, 0], 'changed_field': 'progress', 'wait_frames': 1}}
        request = {'action': 'build_game', 'idea_id': self.idea_id, 'revision': 1, 'game_revision': 0}
        with patch.object(b, 'request_structured', return_value=answer) as model, patch.object(p, 'render_preview'):
            game = b.process_request(request, self.job)['game']
        self.assertIn(asset_id, model.call_args.args[0])
        folder = p.game_root(b, self.idea_id) / 'revisions/0001'
        self.assertTrue((folder / 'assets' / (asset_id + '.png')).exists())
        before = (folder / 'game.gd').read_bytes()
        destination = self.data / '完整工程.zip'
        export = {'action': 'export_created', 'idea_id': self.idea_id, 'game_revision': 1, 'export_path': str(destination)}
        b.process_request(export, self.job)
        with zipfile.ZipFile(destination) as archive:
            self.assertIn('playseed_base.gd', archive.namelist())
            self.assertIn('assets/' + asset_id + '.png', archive.namelist())
            self.assertFalse(any(name.startswith('.godot/') for name in archive.namelist()))
        with self.assertRaises(ValueError): b.process_request(export, self.job)
        with patch.object(p, 'render_preview'):
            restored = b.process_request({**request, 'action': 'restore_created', 'game_revision': 1, 'restore_revision': 1}, self.job)
        self.assertEqual(restored['game']['current_revision'], 2)
        self.assertEqual((folder / 'game.gd').read_bytes(), before)
        self.assertTrue((p.game_root(b, self.idea_id) / 'revisions/0002/assets' / (asset_id + '.png')).exists())
