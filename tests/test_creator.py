import copy
import base64
import struct
import tempfile
import unittest
import zlib
from pathlib import Path
from unittest.mock import patch
import backend as b
import creator


def sample_png():
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    pixels = (b'\0' + b'\x90\xd0\x60\xff' * 2) * 2
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 2, 2, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(pixels)) + chunk(b'IEND', b'')


def answer(ready=True):
    return {'reply': '我们先做一条能探索的小街道。', 'ready': ready,
            'questions': [] if ready else [{'question': '小猫主要做什么？', 'choices': ['探索找主人', '经营小店']}],
            'plan': {'title': '小猫回家', 'premise': '小猫探索城市寻找主人', 'player_goal': '找到主人',
                     'core_loop': ['探索街道', '跳过障碍'], 'visual_style': '温暖手绘',
                     'first_version': ['一个街区', '找到主人的结尾'],
                     'asset_plan': ['小猫角色：Playseed自动设计', '街道场景：Playseed自动设计'], 'later': ['更多街区'],
                     'assumptions': ['暂定用方向键移动']}}


class CreatorTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.data = Path(tmp.name)
        p = patch.object(b, 'DATA', self.data)
        p.start()
        self.addCleanup(p.stop)
        self.job = self.data / 'jobs' / 'test'
        self.job.mkdir(parents=True)

    def discuss(self, previous=None, output=None):
        request = {'action': 'discuss', 'prompt': '小猫冒险'}
        if previous:
            request.update(idea_id=previous['id'], revision=previous['revision'])
        with patch.object(b, 'request_structured', return_value=output or answer()):
            return b.process_request(request, self.job)['idea']

    def test_conversation_confirmation_and_revision_history(self):
        idea = self.discuss(output=answer(False))
        with self.assertRaises(ValueError):
            b.process_request({'action': 'confirm_brief', 'idea_id': idea['id'], 'revision': 1}, self.job)
        ready = self.discuss(idea)
        self.assertEqual(len(ready['messages']), 4)
        confirmed = b.process_request({'action': 'confirm_brief', 'idea_id': ready['id'], 'revision': 2}, self.job)['idea']
        self.assertEqual(confirmed['status'], 'confirmed')
        self.assertEqual(b.read_json(creator.path_for(b, ready['id']))['confirmed_revision'], 2)
        revised = self.discuss(confirmed)
        self.assertEqual(revised['revision'], 3)
        self.assertIsNone(revised['confirmed_revision'])
        self.assertEqual(revised['history'][-1]['status'], 'confirmed')
        self.assertFalse((self.data / 'projects').exists(), 'brief confirmation must not fabricate a game')

    def test_new_idea_uses_an_empty_user_selected_folder(self):
        selected = self.data / '我的游戏'
        selected.mkdir()
        request = {'action': 'discuss', 'prompt': '小猫冒险', 'project_directory': str(selected),
                   'model': 'gpt-6-astra', 'reasoning_effort': 'high', 'attachment': {'name': '小猫参考', 'role': '参考图',
                   'png_base64': base64.b64encode(sample_png()).decode()}}
        with patch.object(b, 'request_structured', return_value=answer()) as model:
            idea = b.process_request(request, self.job)['idea']
        self.assertEqual(model.call_args.kwargs['model'], 'gpt-6-astra')
        self.assertEqual(model.call_args.kwargs['reasoning_effort'], 'high')
        self.assertEqual(Path(idea['project_directory']), selected.resolve())
        self.assertEqual(b.read_json(selected / '.playseed-project.json')['id'], idea['id'])
        self.assertEqual(len(b.read_json(selected / 'library/library.json')['assets']), 1)
        import producer
        self.assertEqual(producer.game_root(b, idea['id']), selected.resolve())

        occupied = self.data / '已有文件'
        occupied.mkdir()
        (occupied / 'notes.txt').write_text('keep', encoding='utf-8')
        with patch.object(b, 'request_structured') as model, self.assertRaises(ValueError):
            b.process_request({**request, 'project_directory': str(occupied)}, self.job)
        model.assert_not_called()

    def test_stale_confirmation_does_not_change_latest_plan(self):
        first = self.discuss()
        second = self.discuss(first)
        path = creator.path_for(b, first['id'])
        before = path.read_bytes()
        with self.assertRaises(ValueError):
            b.process_request({'action': 'confirm_brief', 'idea_id': first['id'], 'revision': first['revision']}, self.job)
        self.assertEqual(path.read_bytes(), before)

    def test_model_failure_or_invalid_reply_keeps_saved_plan(self):
        idea = self.discuss()
        path = creator.path_for(b, idea['id'])
        before = path.read_bytes()
        for output in [None, {}, {'reply': 'done'}]:
            with patch.object(b, 'request_structured', return_value=output), self.assertRaises(ValueError):
                creator.handle({'action': 'discuss', 'idea_id': idea['id'], 'revision': 1, 'prompt': '改一下'}, self.job, b)
            self.assertEqual(path.read_bytes(), before)

    def test_cancel_after_model_does_not_save_response(self):
        idea = self.discuss()
        path = creator.path_for(b, idea['id'])
        before = path.read_bytes()
        def cancelled_answer(*args, **kwargs):
            (self.job / 'cancel').touch()
            return answer()
        with patch.object(b, 'request_structured', side_effect=cancelled_answer), self.assertRaises(InterruptedError):
            creator.handle({'action': 'discuss', 'idea_id': idea['id'], 'revision': 1, 'prompt': '改一下'}, self.job, b)
        self.assertEqual(path.read_bytes(), before)

    def test_schema_readiness_and_path_validation(self):
        invalid = answer()
        invalid['questions'] = [{'question': '目标是什么？', 'choices': []}]
        with self.assertRaises(ValueError):
            creator.validate_answer(invalid)

        with self.assertRaises(ValueError):
            creator.path_for(b, '../projects')
        invalid = answer()
        invalid['plan']['core_loop'] = []
        with self.assertRaises(ValueError):
            creator.validate_answer(invalid)

    def test_build_checklist_is_bound_to_confirmed_revision_and_keeps_game_state_honest(self):
        idea = self.discuss()
        request = {'action': 'prepare_build', 'idea_id': idea['id'], 'revision': 1}
        with self.assertRaises(ValueError):
            b.process_request(request, self.job)
        confirmed = b.process_request({**request, 'action': 'confirm_brief'}, self.job)['idea']
        build = b.process_request(request, self.job)['build_plan']
        self.assertEqual(build['brief'], confirmed['plan'])
        self.assertEqual(build['source_revision'], 1)
        self.assertFalse(build['playable'])
        self.assertEqual(build['tasks'][0]['title'], confirmed['plan']['first_version'][0])
        self.assertEqual({t['state'] for t in build['tasks']}, {'planned'})
        self.assertEqual(build, b.process_request(request, self.job)['build_plan'])
        revised = self.discuss(confirmed)
        with self.assertRaises(ValueError):
            b.process_request(request, self.job)
        with self.assertRaises(ValueError):
            b.process_request({**request, 'revision': revised['revision']}, self.job)
        self.assertTrue((self.data / 'ideas' / idea['id'] / 'builds' / '0001.json').exists())
        self.assertFalse((self.data / 'projects').exists())

    def test_immediate_stop_keeps_new_project_and_first_message(self):
        folder = self.data / '愤怒的小鸟'
        folder.mkdir()
        (self.job / 'cancel').touch()
        request = {'action':'discuss','prompt':'帮我做一个愤怒的小鸟','project_directory':str(folder)}
        with patch.object(b, 'request_structured') as model, self.assertRaises(InterruptedError):
            b.process_request(request, self.job)
        model.assert_not_called()
        records = list((self.data/'ideas').glob('*/idea.json'))
        self.assertEqual(len(records), 1, '停止前应已保存项目，侧栏才能列出它')
        draft = b.read_json(records[0])
        self.assertEqual(draft['messages'][0]['text'], request['prompt'])
        self.assertFalse(draft['ready'])
        self.assertEqual(b.read_json(folder/'.playseed-project.json')['id'],draft['id'])
        (self.job/'cancel').unlink()
        with patch.object(b, 'request_structured', return_value=answer()):
            result = b.process_request({'action':'discuss','idea_id':draft['id'],'revision':0,'prompt':request['prompt']},self.job)['idea']
        self.assertEqual(len(result['messages']),2)
        self.assertEqual(result['revision'],1)
        self.assertNotIn('pending_first_prompt',result)
