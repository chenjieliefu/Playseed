import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch
import backend as b
import storage

class StorageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.data = Path(self.temp.name)
        self.patch = patch.object(b, 'DATA', self.data)
        self.patch.start(); self.addCleanup(self.patch.stop)
        self.source = self.data / 'created_games'
        self.source.mkdir()
        (self.source / 'keep.txt').write_text('original game')
        self.parent = self.data / 'chosen'; self.parent.mkdir()
        self.job = self.data / 'jobs/test'; self.job.mkdir(parents=True)
        self.request = {'action': 'set_games_directory', 'parent_directory': str(self.parent)}

    def test_copy_failure_keeps_old_location_and_cleans_partial(self):
        with patch('storage.shutil.copytree', side_effect=OSError('disk full')):
            with self.assertRaises(OSError):
                b.process_request(self.request, self.job)
        self.assertEqual(storage.games_directory(b), self.source)
        self.assertEqual(list(self.parent.iterdir()), [])

    def test_existing_destination_not_overwritten(self):
        target = self.parent / 'Playseed游戏'; target.mkdir()
        (target / 'personal.txt').write_text('mine')
        with self.assertRaises(ValueError):
            b.process_request(self.request, self.job)
        self.assertEqual((target / 'personal.txt').read_text(), 'mine')
        self.assertFalse((self.data / 'storage.json').exists())

    def test_cancel_does_not_switch_storage(self):
        (self.job / 'cancel').touch()
        with self.assertRaises(InterruptedError):
            b.process_request(self.request, self.job)
        self.assertEqual(storage.games_directory(b), self.source)
        self.assertEqual(list(self.parent.iterdir()), [])

    def test_nested_destination_and_missing_disk_rejected(self):
        with self.assertRaises(ValueError):
            b.process_request({**self.request, 'parent_directory': str(self.source)}, self.job)
        b.atomic_json(self.data / 'storage.json', {'games_directory': str(self.data / 'missing-disk')})
        with self.assertRaises(ValueError):
            storage.games_directory(b)
