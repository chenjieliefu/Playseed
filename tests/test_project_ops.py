import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import backend as b


class ProjectOperationsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.data = self.base / 'data'
        self.data.mkdir()
        self.patch = patch.object(b, 'DATA', self.data)
        self.patch.start()
        self.addCleanup(self.patch.stop)
        self.job = self.data / 'jobs' / 'test'
        self.job.mkdir(parents=True)
        self.idea_id = '1' * 32
        self.folder = self.base / '原项目'
        self.folder.mkdir()
        b.atomic_json(self.folder / '.playseed-project.json', {'id': self.idea_id, 'title': '原项目'})
        (self.folder / 'keep.txt').write_text('game data', encoding='utf-8')
        self.idea_path = self.data / 'ideas' / self.idea_id / 'idea.json'
        b.atomic_json(self.idea_path, {'id': self.idea_id, 'title': '原项目', 'revision': 3,
                                      'project_directory': str(self.folder), 'pinned': False})

    def request(self, action, **extra):
        return b.process_request({'action': action, 'idea_id': self.idea_id, 'revision': 3, **extra}, self.job)

    def test_pin_is_persisted(self):
        result = self.request('pin_project', pinned=True)
        self.assertTrue(result['idea']['pinned'])
        self.assertTrue(b.read_json(self.idea_path)['pinned'])

    def test_rename_moves_folder_and_updates_record(self):
        result = self.request('rename_project', name='新游戏')
        renamed = self.base / '新游戏'
        self.assertFalse(self.folder.exists())
        self.assertEqual((renamed / 'keep.txt').read_text(encoding='utf-8'), 'game data')
        self.assertEqual(Path(result['idea']['project_directory']), renamed.resolve())
        self.assertEqual(result['idea']['project_name'], '新游戏')
        self.assertEqual(result['idea']['title'], '原项目')
        self.assertEqual(b.read_json(renamed / '.playseed-project.json')['title'], '新游戏')

    def test_delete_removes_record_and_whole_project_folder(self):
        result = self.request('delete_project')
        self.assertTrue(result['project_deleted'])
        self.assertFalse(self.folder.exists())
        self.assertFalse(self.idea_path.parent.exists())

    def test_missing_or_wrong_marker_protects_user_folder(self):
        (self.folder / '.playseed-project.json').unlink()
        with self.assertRaises(ValueError):
            self.request('delete_project')
        self.assertTrue((self.folder / 'keep.txt').is_file())
        self.assertTrue(self.idea_path.is_file())
