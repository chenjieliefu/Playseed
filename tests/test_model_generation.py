import copy
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import backend as b
import model_generation as m
import model_assets
from tests.test_model_integration import glb

RECIPE=dict(supported=True,name='木箱',summary='基础形状木箱，无贴图。',parts=[dict(name='箱体',shape='box',size=[1,1,1],position=[0,0,.5],rotation=[0,0,0],color='aa7744')])

class GenerationTests(unittest.TestCase):
    def setUp(self):
        tmp=tempfile.TemporaryDirectory();self.addCleanup(tmp.cleanup);self.root=Path(tmp.name).resolve()
        data=patch.object(b,'DATA',self.root/'data');data.start();self.addCleanup(data.stop)
        self.ident='f'*32;self.project=self.root/'project';self.project.mkdir();self.job=self.root/'job';self.job.mkdir()
        self.idea=dict(id=self.ident,revision=1,status='confirmed',project_directory=str(self.project),plan={'visual_style':'低多边形'})
        b.atomic_json(b.DATA/'ideas'/self.ident/'idea.json',self.idea);b.atomic_json(self.project/'.playseed-project.json',dict(id=self.ident))
        self.req=dict(action='generate_model',idea_id=self.ident,revision=1,prompt='做一个木箱')
    def fake_produce(self,api,recipe,job):
        work=job/'fake';work.mkdir(exist_ok=True)
        for name in ['model.glb','source.blend','recipe.json','front.png','back.png','report.json']:(work/name).write_bytes(glb() if name=='model.glb' else b'fixture')
        return work,dict(parts=1,blender_version='test')
    def generate(self):
        with patch.object(m,'blender_path'),patch.object(b,'request_structured',return_value=RECIPE),patch.object(m,'produce',side_effect=self.fake_produce),patch('producer.check'):
            return b.process_request(self.req,self.job)['model_draft']
    def test_generate_review_accept_dedupe_and_game_unchanged(self):
        draft=self.generate();self.assertFalse((self.project/'model-library').exists())
        response=b.process_request(dict(self.req,action='accept_model',draft_id=draft['id']),self.job)
        self.assertEqual(response['model_draft']['state'],'accepted')
        item=model_assets.library(self.project,self.ident)['models'][0]
        self.assertIn(draft['id'],item['source']);self.assertFalse((self.project/'revisions').exists())
        with self.assertRaises(ValueError):b.process_request(dict(self.req,action='accept_model',draft_id=draft['id']),self.job)
    def test_reject_unconfirmed_missing_blender_and_invalid_recipe_before_work(self):
        for recipe in [dict(RECIPE,supported=False),dict(RECIPE,parts=[]),dict(RECIPE,code='print(1)')]:
            with self.assertRaises(ValueError):m.validate_recipe(recipe)
        for key,val in [('size',[float('nan'),1,1]),('position',[0,0,10]),('rotation',[0,0,181]),('shape','python')]:
            v=copy.deepcopy(RECIPE);v['parts'][0][key]=val
            with self.assertRaises(ValueError):m.validate_recipe(v)
        b.atomic_json(b.DATA/'ideas'/self.ident/'idea.json',dict(self.idea,status='draft'))
        with patch.object(b,'request_structured') as ai,self.assertRaises(ValueError): b.process_request(self.req,self.job)
        ai.assert_not_called()
        b.atomic_json(b.DATA/'ideas'/self.ident/'idea.json',self.idea)
        with patch.object(m,'blender_path',side_effect=ValueError('missing')),patch.object(b,'request_structured') as ai,self.assertRaises(ValueError):b.process_request(self.req,self.job)
        ai.assert_not_called()
    def test_cancel_and_stale_generation_leave_no_draft(self):
        def update(*args,**kwargs):
            b.atomic_json(b.DATA/'ideas'/self.ident/'idea.json',dict(self.idea,revision=2));return RECIPE
        with patch.object(m,'blender_path'),patch.object(b,'request_structured',side_effect=update),patch.object(m,'produce') as produce,self.assertRaises(ValueError):b.process_request(self.req,self.job)
        produce.assert_not_called()
        b.atomic_json(b.DATA/'ideas'/self.ident/'idea.json',self.idea);(self.job/'cancel').touch()
        with self.assertRaises(InterruptedError):b.process_request(self.req,self.job)
        self.assertFalse((self.project/'model-drafts').exists())
    def test_old_draft_can_discard_but_cannot_accept(self):
        draft=self.generate();b.atomic_json(b.DATA/'ideas'/self.ident/'idea.json',dict(self.idea,revision=2))
        request=dict(self.req,revision=2,draft_id=draft['id'])
        with self.assertRaises(ValueError):b.process_request(dict(request,action='accept_model'),self.job)
        self.assertEqual(b.process_request(dict(request,action='discard_model'),self.job)['model_draft']['state'],'discarded')
        self.assertFalse((self.project/'model-library').exists())
    def test_tamper_and_symlink_rejected(self):
        draft=self.generate();folder=self.project/'model-drafts'/draft['id'];model=folder/'model.glb';model.write_bytes(b'tamper')
        with self.assertRaises(ValueError):b.process_request(dict(self.req,action='accept_model',draft_id=draft['id']),self.job)
        model.unlink();model.symlink_to(self.job/'fake/model.glb')
        with self.assertRaises(ValueError):b.process_request(dict(self.req,action='accept_model',draft_id=draft['id']),self.job)
        self.assertFalse((self.project/'model-library').exists())
    def test_blender_failure_or_cancel_does_not_commit(self):
        for failure in [RuntimeError('failed'),InterruptedError('stopped')]:
            with patch.object(m,'blender_path'),patch.object(b,'request_structured',return_value=RECIPE),patch.object(m,'produce',side_effect=failure),self.assertRaises(type(failure)):b.process_request(self.req,self.job)
            self.assertFalse((self.project/'model-drafts').exists())
    def test_real_blender_and_godot_gate(self):
        if not Path('/Applications/Blender.app').exists():self.skipTest('requires local Blender')
        with patch.object(b,'request_structured',return_value=RECIPE):draft=b.process_request(self.req,self.job)['model_draft']
        folder=self.project/'model-drafts'/draft['id']
        model_assets.validate_static((folder/'model.glb').read_bytes())
        self.assertTrue((folder/'source.blend').stat().st_size>1000)
        self.assertIn('SPATIAL_CHECK_OK',(self.job/'check.log').read_text() if (self.job/'check.log').exists() else '\n'.join(p.read_text() for p in self.job.glob('*.log')))
        self.assertFalse((self.project/'model-library').exists())

    def test_real_blender_rejects_detached_parts(self):
        if not Path('/Applications/Blender.app').exists():self.skipTest('requires local Blender')
        recipe=copy.deepcopy(RECIPE);recipe['parts'].append(dict(recipe['parts'][0],position=[3,0,.5]))
        with self.assertRaisesRegex(ValueError,'悬空'):
            m.produce(b,recipe,self.job)
        self.assertFalse((self.project/'model-drafts').exists())
