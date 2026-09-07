import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from scripts import novice_playtest as kit


class NovicePlaytestTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        kit.b.atomic_json(self.folder / 'session.json', dict(stages=kit.STAGES))

    def complete_fixture(self, seconds=250):
        answers = {}
        for i in range(3):
            kit.b.atomic_json(self.folder / f'stage-{i}/attempt.json',
                              dict(status='finished', window_seconds=seconds))
            answers[str(i)] = dict(outcome='失败', goal='不知道', blocker='不知道怎么瞄准', change='没察觉')
        kit.b.atomic_json(self.folder / 'feedback.json', dict(answers=answers,
            experience='从未做过游戏', improvement='操作提示更明确', **{'continue': '不愿意'}))

    def test_time_never_proves_p2_or_engagement(self):
        self.complete_fixture()
        report = kit.summarize(self.folder)
        self.assertTrue(report['feedback_complete'])
        self.assertEqual(report['window_seconds'], 750)
        self.assertFalse(report['p2_accepted'])
        self.assertFalse(report['engagement_verified'])
        self.assertIn('不知道怎么瞄准', (self.folder / '试玩反馈.md').read_text())

    def test_unplayed_failed_and_missing_answers_are_incomplete(self):
        self.complete_fixture()
        (self.folder / 'stage-0/attempt.json').unlink()
        kit.b.atomic_json(self.folder / 'stage-1/attempt.json', dict(status='failed', window_seconds=400))
        feedback = kit.read(self.folder / 'feedback.json')
        feedback['answers']['2']['change'] = '   '
        kit.b.atomic_json(self.folder / 'feedback.json', feedback)
        report = kit.assess(self.folder)
        self.assertFalse(report['feedback_complete'])
        self.assertEqual(len(report['missing']), 3)

    def test_retries_are_not_added_to_time(self):
        self.complete_fixture(40)
        kit.b.atomic_json(self.folder / 'stage-0/attempt-old.json', dict(status='finished', window_seconds=900))
        self.assertEqual(kit.assess(self.folder)['window_seconds'], 120)

    def test_reject_outside_session_and_missing_previous(self):
        with self.assertRaises(ValueError): kit.session_path(self.folder)
        with self.assertRaisesRegex(ValueError, '上一段'): kit.run_stage(self.folder, 1)

    def test_tampering_cannot_launch_and_finished_feedback_is_locked(self):
        project = self.folder / 'stage-0/project'
        project.mkdir(parents=True)
        (project / 'game.gd').write_text('original')
        session = kit.read(self.folder / 'session.json')
        session['stages'][0]['project_hashes'] = kit.file_hashes(project)
        kit.b.atomic_json(self.folder / 'session.json', session)
        (project / 'game.gd').write_text('changed')
        with patch.object(kit.subprocess, 'Popen') as launch:
            result = kit.run_stage(self.folder, 0)
            self.assertEqual(result['status'], 'failed')
            launch.assert_not_called()
        kit.b.atomic_json(self.folder / 'feedback.json', dict(submitted=True))
        with self.assertRaisesRegex(ValueError, '已完成'): kit.run_stage(self.folder, 0)

    def test_orphan_game_blocks_a_second_window(self):
        kit.b.atomic_json(self.folder / 'stage-0/attempt.json', dict(status='running', game_pid=123))
        with patch.object(kit, 'pid_alive', return_value=True):
            with self.assertRaisesRegex(ValueError, '仍在运行'): kit.run_stage(self.folder, 0)

    def test_launch_reports_real_elapsed_and_errors(self):
        project = self.folder / 'stage-0/project'
        project.mkdir(parents=True)
        (project / 'game.gd').write_text('fixture')
        session = kit.read(self.folder / 'session.json')
        session['stages'][0]['project_hashes'] = kit.file_hashes(project)
        kit.b.atomic_json(self.folder / 'session.json', session)
        def command(api, source, job, extra):
            return [kit.sys.executable, '-c', 'print("SCRIPT ERROR: fixture")']
        with patch.object(kit.producer, 'sandbox_command', side_effect=command), patch.object(kit.time, 'monotonic', side_effect=[20, 85]):
            result = kit.run_stage(self.folder, 0)
        self.assertEqual(result['window_seconds'], 65)
        self.assertEqual(result['status'], 'failed')
        self.assertEqual(result['exit_code'], 0)


if __name__ == '__main__':
    unittest.main()
