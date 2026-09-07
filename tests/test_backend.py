import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import uuid
import zipfile

spec = importlib.util.spec_from_file_location('backend', Path(__file__).resolve().parents[1] / 'backend.py')
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)

class BackendTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.data = Path(self.temp.name)
        self.patch = patch.object(b, 'DATA', self.data)
        self.patch.start()
        self.addCleanup(self.patch.stop)
        self.job = self.data / 'jobs' / uuid.uuid4().hex
        self.job.mkdir(parents=True)

    def test_status_history_preserves_repair_and_cancellation_events(self):
        b.status(self.job, 'building', '编写游戏')
        b.status(self.job, 'checking', '检查启动')
        b.status(self.job, 'repairing', '修复问题')
        b.status(self.job, 'repairing', '修复问题')
        b.status(self.job, 'cancelled', '已停止')
        events=b.read_json(self.job/'events.json')['events']
        self.assertEqual([e['state'] for e in events], ['building','checking','repairing','cancelled'])
        self.assertEqual(b.read_json(self.job/'status.json')['state'], 'cancelled')

    def test_rejects_invalid_types_ranges_and_injection(self):
        for key, value in [('duration', -1), ('enemy_count', True), ('player_speed', float('nan')), ('title', 'bad\nconfig/name="x"'), ('player_color', 'red'), ('theme', 'unknown'), ('dash_enabled', 'false')]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                b.validate_config({**b.DEFAULT, key: value})
        with self.assertRaises(ValueError):
            b.project_dir('../../secret')

    def test_failed_build_keeps_previous_config_and_revision(self):
        pid = uuid.uuid4().hex
        with patch.object(b, 'check_game'):
            first = b.commit(pid, b.DEFAULT, 'demo', 'initial', 'demo', self.job)
        with patch.object(b, 'check_game', side_effect=RuntimeError('failed')), self.assertRaises(RuntimeError):
            b.commit(pid, {**b.DEFAULT, 'enemy_count': 3}, 'less', 'less', 'test', self.job)
        self.assertEqual(first, b.manifest(pid))
        self.assertEqual(len(list((b.project_dir(pid) / 'revisions').iterdir())), 1)

    def test_restore_adds_version_and_preserves_history(self):
        pid = uuid.uuid4().hex
        with patch.object(b, 'check_game'):
            b.commit(pid, b.DEFAULT, 'demo', 'initial', 'demo', self.job)
            b.commit(pid, {**b.DEFAULT, 'enemy_count': 2}, 'less', 'less', 'test', self.job)
            result = b.process_request({'action': 'restore', 'project_id': pid, 'revision': 1}, self.job)
        self.assertEqual(result['current_revision'], 3)
        self.assertEqual(len(result['versions']), 3)
        self.assertEqual(result['config']['enemy_count'], 5)
        self.assertEqual(b.read_json(b.revision_path(pid, 2) / 'game.json')['enemy_count'], 2)

    def test_cancellation_prevents_commit(self):
        (self.job / 'cancel').touch()
        with self.assertRaises(InterruptedError):
            b.process_request({'action': 'demo'}, self.job)
        self.assertFalse((self.data / 'projects').exists())

    def test_unsupported_model_request_does_not_write_project(self):
        with patch.object(b, 'ask_model', side_effect=ValueError('3D not supported')), self.assertRaises(ValueError):
            b.process_request({'action': 'create', 'prompt': '3D'}, self.job)
        self.assertFalse((self.data / 'projects').exists())

    def test_model_and_reasoning_strength_reach_codex(self):
        schema = {'type': 'object'}
        def complete(args, job, timeout, name, stdin, cwd):
            (job / 'answer.json').write_text('{}', encoding='utf-8')
            self.assertIn('gpt-6-astra', args)
            self.assertIn('model_reasoning_effort="high"', args)
        with patch.object(b, 'CODEX', Path('/bin/echo')), patch.object(b, 'run_process', side_effect=complete):
            self.assertEqual(b.request_structured('测试', schema, self.job, model='gpt-6-astra', reasoning_effort='high'), {})
        with patch.object(b, 'CODEX', Path('/bin/echo')), patch.object(b, 'run_process') as run:
            with self.assertRaises(ValueError):
                b.request_structured('测试', schema, self.job, model='gpt-6-astra', reasoning_effort='随便')
            run.assert_not_called()

    def test_catalog_models_and_supported_efforts_reach_codex(self):
        entries = b.read_json(b.ROOT / 'app/model_catalog.json')['models']
        self.assertEqual(len(entries), 6)
        for entry in entries:
            with self.subTest(model=entry['id']):
                def complete(args, job, *unused, **kwargs):
                    self.assertIn(entry['id'], args)
                    self.assertIn('model_reasoning_effort="' + entry['efforts'][-1] + '"', args)
                    (job / 'answer.json').write_text('{}', encoding='utf-8')
                with patch.object(b, 'CODEX', Path('/bin/echo')), patch.object(b, 'run_process', side_effect=complete):
                    self.assertEqual(b.request_structured('测试', {'type': 'object'}, self.job, model=entry['id'], reasoning_effort=entry['efforts'][-1]), {})
        with patch.object(b, 'CODEX', Path('/bin/echo')), patch.object(b, 'run_process') as run:
            for model in ['gpt-5.5', 'gpt-5.4-mini']:
                with self.assertRaises(ValueError):
                    b.request_structured('测试', {}, self.job, model=model, reasoning_effort='max')
            run.assert_not_called()

    def test_preview_source_matches_exported_game(self):
        self.assertEqual((b.ROOT / 'game/game.gd').read_bytes(), (b.ROOT / 'app/game_preview.gd').read_bytes())

    def test_health_limits_and_required_fields(self):
        for values in [{'initial_lives': 6, 'max_lives': 5}, {'initial_lives': 0}, {'max_lives': 11}, {'heart_count': 21}, {'heart_count': 1.5}, {'initial_lives': True}]:
            with self.subTest(values=values), self.assertRaises(ValueError):
                b.validate_config({**b.DEFAULT, **values})
        missing = dict(b.DEFAULT)
        del missing['heart_count']
        with self.assertRaises(ValueError):
            b.validate_config(missing)

    def test_legacy_project_can_be_restored_without_rewriting_old_files(self):
        pid = uuid.uuid4().hex
        with patch.object(b, 'check_game'):
            b.commit(pid, b.DEFAULT, 'demo', 'initial', 'demo', self.job)
            old_path = b.project_dir(pid) / 'project.json'
            old = b.read_json(old_path)
            for config in [old['config'], old['versions'][0]['config']]:
                for key in b.HEALTH_DEFAULTS:
                    config.pop(key)
            b.atomic_json(old_path, old)
            old_bytes = old_path.read_bytes()
            migrated = b.manifest(pid)
            self.assertEqual(migrated['config']['initial_lives'], 1)
            self.assertEqual(old_path.read_bytes(), old_bytes)
            b.commit(pid, {**b.DEFAULT, 'initial_lives': 3, 'max_lives': 5, 'heart_count': 5}, 'health', 'health', 'test', self.job)
            restored = b.process_request({'action': 'restore', 'project_id': pid, 'revision': 1}, self.job)
            self.assertEqual(restored['config']['initial_lives'], 1)
            self.assertEqual(restored['config']['heart_count'], 0)

if __name__ == '__main__':
    unittest.main()
