from pathlib import Path
import tempfile
import unittest

import producer
from scripts.validate_revisions import check_previous_probes, hashes


@unittest.skipUnless(Path('/usr/bin/sandbox-exec').exists(), 'macOS sandbox integration')
class RevisionRegressionTests(unittest.TestCase):
    def test_old_action_regression_is_detected_without_changing_saved_version(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            project = root / 'project'
            project.mkdir()
            (project / 'project.godot').write_text(producer.PROJECT.format(title='"回归检查"'))
            (project / 'main.tscn').write_text(producer.SCENE)
            script = '''extends Node2D
var count = 0
func reset_game():
    count = 0
func playseed_action(action: String, at: Vector2 = Vector2.ZERO):
    if action == "shoot": count += 2
func playseed_snapshot() -> Dictionary:
    return {"won": false, "lost": false, "progress": 0.0, "count": count}
'''
            (project / 'game.gd').write_text(script)
            (project / '_check.gd').write_text('# immutable original check\n')
            versions = [{'revision': 1, 'test': {'action': 'shoot', 'at': [0, 0],
                         'changed_field': 'count', 'wait_frames': 0}}]
            before = hashes(project)
            job = root / 'pass-job'
            job.mkdir()
            self.assertEqual(len(check_previous_probes(project, versions, job)), 1)
            self.assertEqual(hashes(project), before)
            self.assertFalse((job / 'regression-project').exists())

            # A new version can parse and start while silently dropping an old action.
            (project / 'game.gd').write_text(script.replace('if action == "shoot": count += 2', 'pass'))
            before = hashes(project)
            failure_job = root / 'failure-job'
            failure_job.mkdir()
            with self.assertRaises(RuntimeError):
                check_previous_probes(project, versions, failure_job)
            self.assertEqual(hashes(project), before)
            self.assertFalse((failure_job / 'regression-project').exists())


if __name__ == '__main__':
    unittest.main()
