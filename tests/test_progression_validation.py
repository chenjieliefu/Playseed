import unittest
import hashlib
import json
import tempfile
from pathlib import Path
from unittest.mock import patch
from scripts.check_progression import parse_report, check
from scripts.validate_progression import ROOT, run, require_playthrough
from scripts.validate_revisions import hashes


class ProgressionValidationTests(unittest.TestCase):
    def setUp(self):
        import backend
        original = backend.DATA
        self.addCleanup(setattr, backend, "DATA", original)

    def test_missing_completion_and_runtime_error_cannot_pass(self):
        with self.assertRaisesRegex(RuntimeError, '完整试玩报告'):
            parse_report('Godot started')
        self.assertFalse(parse_report('SCRIPT ERROR: invalid access\nPROGRESSION_REPORT:{"passed":true}')['passed'])
        self.assertFalse(parse_report('PROGRESSION_REPORT:{"passed":false,"failures":["提前胜利"]}')['passed'])
        self.assertTrue(parse_report('PROGRESSION_REPORT:{"passed":true,"failures":[]}')['passed'])

    def test_outside_run_rejected_before_model_or_runtime(self):
        with patch('backend.process_request') as model:
            with self.assertRaises(ValueError): run(Path('/tmp/not-a-playseed-run'), 'build')
            model.assert_not_called()
        with patch('backend.run_process') as runtime:
            with self.assertRaises(ValueError): check('../../outside', 1)
            runtime.assert_not_called()

    def test_resume_rejects_failed_duplicate_and_out_of_order_steps(self):
        from scripts.validate_progression import ROOT
        state = {'idea_id': 'a'*32, 'steps': [{'step':'build','status':'failed'}]}
        with patch.object(Path, 'exists', return_value=True), patch('backend.read_json', return_value=state), patch('backend.process_request') as model:
            with self.assertRaisesRegex(ValueError, '已有记录'): run(ROOT / '.playseed/validation/mock', 'build')
            with self.assertRaisesRegex(ValueError, '先解决失败'): run(ROOT / '.playseed/validation/mock', 'revise1')
            state['steps'][0]['status'] = 'passed'
            with self.assertRaisesRegex(ValueError, '顺序'): run(ROOT / '.playseed/validation/mock', 'revise3')
            model.assert_not_called()

    def test_next_round_requires_three_paths_for_exact_source_and_checker(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'project/revisions/0001'
            source.mkdir(parents=True)
            (source / 'game.gd').write_text('original')
            reports = root / 'playthrough-reports'
            reports.mkdir()
            digest = hashlib.sha256((ROOT / 'scripts/playthrough_checks/progression.gd').read_bytes()).hexdigest()
            for number, (outcome, choice) in enumerate([('won','damage'),('won','heal'),('lost','damage')]):
                with self.assertRaises(ValueError): require_playthrough(root, 1)
                report = dict(outcome=outcome, choice=choice, passed=True, source_unchanged=True,
                              source_hashes=hashes(source), checker_sha256=digest)
                (reports / f'v1-{number}.json').write_text(json.dumps(report))
            require_playthrough(root, 1)
            (source / 'game.gd').write_text('changed')
            with self.assertRaises(ValueError): require_playthrough(root, 1)
            (source / 'game.gd').write_text('original')
            report['passed'] = False
            (reports / 'v1-2.json').write_text(json.dumps(report))
            with self.assertRaises(ValueError): require_playthrough(root, 1)
