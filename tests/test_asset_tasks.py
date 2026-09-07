import unittest
from unittest.mock import patch
import backend as b
import resources as r
import test_resources as fixtures

class AssetTaskTests(unittest.TestCase):
    def setUp(self):
        fixtures.ResourceTests.setUp(self)
        self.binding = fixtures.ResourceTests.task_fixture(self)
        path = b.DATA/'ideas'/self.idea_id/'idea.json'
        idea = b.read_json(path); idea['plan']['visual_style'] = '温暖手绘'
        b.atomic_json(path, idea)
        self.request = {'action': 'prepare_asset_split', 'idea_id': self.idea_id, 'revision': 1, 'task': '玩家角色'}
        self.answer = {'items': ['小猫角色：透明背景，用户上传', '背包道具：透明背景，平台生成'], 'explanation': '角色和背包各准备一张。'}

    def prepare(self):
        with patch.object(b, 'request_structured', return_value=self.answer):
            b.process_request(self.request, self.job)
        return r.library(b, self.idea_id)['task_splits']['1']['玩家角色']

    def test_review_then_accept_preserves_original_binding_and_enables_children(self):
        b.process_request(self.binding, self.job)
        split = self.prepare()
        self.assertEqual(split['state'], 'review')
        self.assertEqual(r.task_names(b.read_json(b.DATA/'ideas'/self.idea_id/'idea.json'), r.library(b,self.idea_id)), ['玩家角色', '花园场景'])
        b.process_request({**self.request, 'action': 'accept_asset_split', 'split_id': split['id']}, self.job)
        self.assertEqual(r.task_assignments(b,self.idea_id)[0]['asset_id'], self.binding['asset_id'])
        b.process_request({**self.binding, 'task': '素材1 · 小猫角色：透明背景，用户上传'}, self.job)
        self.assertEqual(len(r.task_assignments(b,self.idea_id)), 2)
        self.assertFalse((r.library_root(b,self.idea_id).parent/'game.json').exists())

    def test_discard_and_stale_confirmation_do_not_change_tasks(self):
        split = self.prepare()
        with self.assertRaises(ValueError):
            b.process_request({**self.request,'action':'accept_asset_split','split_id':'old'},self.job)
        b.process_request({**self.request,'action':'discard_asset_split','split_id':split['id']},self.job)
        self.assertEqual(r.library(b,self.idea_id)['task_splits']['1']['玩家角色']['state'],'discarded')
        with self.assertRaises(ValueError):
            b.process_request({**self.request,'action':'accept_asset_split','split_id':split['id']},self.job)

    def test_invalid_or_cancelled_model_result_never_saves_suggestion(self):
        for items in [[], ['重复','重复'], ['任务'] * 9]:
            with patch.object(b,'request_structured',return_value={'items':items,'explanation':'说明'}), self.assertRaises(ValueError):
                b.process_request(self.request,self.job)
            self.assertNotIn('task_splits',r.library(b,self.idea_id))
        def cancel(*args, **kwargs):
            (self.job/'cancel').touch()
            return self.answer
        with patch.object(b,'request_structured',side_effect=cancel), self.assertRaises(InterruptedError):
            b.process_request(self.request,self.job)
        self.assertNotIn('task_splits',r.library(b,self.idea_id))

    def test_single_image_and_existing_review_do_not_duplicate_requests(self):
        with patch.object(b,'request_structured',return_value={'items':['保留整张角色图片'],'explanation':'一张即可'}):
            result=b.process_request(self.request,self.job)
        self.assertIn('无需拆',result['summary'])
        self.assertNotIn('task_splits',r.library(b,self.idea_id))
        self.prepare()
        with patch.object(b,'request_structured') as model:
            b.process_request(self.request,self.job)
            model.assert_not_called()
