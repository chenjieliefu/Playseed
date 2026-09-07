import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import backend as b
import producer
import spatial as s
import resources

WORLD = dict(title='温室寻物',goal='找到两枚种子，回到花园出口。',size=[12,10],spawn=[-4,3],speed=3,
    floor_color='d9e7cb',wall_color='789f89',obstacles=[dict(name='花台',position=[0,0],size=[2,1.5,2],color='85a88a')],
    items=[dict(name='金色种子',position=[-4,-3],color='efbc54'),dict(name='蓝色种子',position=[4,-3],color='75b9cf')],
    exit=dict(name='花园出口',position=[4,3],color='c9a4cb'))

def answer(world=None):
    return dict(supported=True,summary='制作了温室寻物。',limitations=['几何体小场景'],world=copy.deepcopy(world or WORLD))


class SpatialTests(unittest.TestCase):
    def setUp(self):
        temp=tempfile.TemporaryDirectory();self.addCleanup(temp.cleanup)
        self.root=Path(temp.name).resolve()
        change=patch.object(b,'DATA',self.root/'data');change.start();self.addCleanup(change.stop)
        self.ident='c'*32
        self.idea=dict(id=self.ident,title='温室寻物',revision=1,status='confirmed',confirmed_revision=1,
            plan=dict(title='温室寻物',first_version=['行走碰撞','收集种子后离开'],asset_plan=['几何体临时形象'],
                      core_loop=['行走','靠近收集','抵达出口'],visual_style='低多边形',player_goal=WORLD['goal'],later=[]))
        self.idea_path=b.DATA/'ideas'/self.ident/'idea.json'
        b.atomic_json(self.idea_path,self.idea)
        self.job=self.root/'job';self.job.mkdir()
        b.process_request(dict(action='prepare_build',idea_id=self.ident,revision=1),self.job)
        self.request=dict(action='build_game',idea_id=self.ident,revision=1,game_revision=0,format=s.FORMAT,
                          model='gpt-5.6-sol',reasoning_effort='medium')

    def test_rejects_invalid_or_unreachable_geometry(self):
        for changes in [dict(speed=True),dict(speed=float('nan')),dict(size=[50,10]),dict(spawn=[0,0]),
                        dict(items=[]),dict(floor_color='../file'),dict(spawn=[-4.1,3]),dict(script='OS.execute')]:
            with self.subTest(changes=changes),self.assertRaises(ValueError): s.validate_world({**WORLD,**changes})
        world=copy.deepcopy(WORLD)
        world['obstacles']=[dict(name='挡墙',position=[0,z],size=[1,1,4],color='777777') for z in [-2.5,2.5]]
        with self.assertRaisesRegex(ValueError,'无法到达'): s.validate_world(world)

    def test_real_godot_walk_interact_collision_reset(self):
        project=self.root/'project';project.mkdir()
        s.prepare(project,WORLD,b)
        producer.check(b,project,self.job)
        log=(self.job/'generated-run.log').read_text()
        self.assertIn('SPATIAL_CHECK_OK:',log)
        self.assertIn('"obstacles_tested":1',log)

    def test_missing_physical_walls_is_detected(self):
        project=self.root/'mutant';project.mkdir()
        s.prepare(project,WORLD,b)
        script=project/'spatial_world.gd'
        script.write_text(script.read_text().replace('if solid:', 'if solid and size.y < 0.6:'))
        with self.assertRaisesRegex(RuntimeError,'3D'): producer.check(b,project,self.job)
        self.assertIn('外墙碰撞', (self.job/'generated-run.log').read_text())

    def test_camera_and_navigation_in_tall_and_wide_rooms(self):
        for size,points in [([8,20],[[-2,8],[-2,-8],[2,-8],[2,8]]),([20,8],[[-8,2],[-8,-2],[8,-2],[8,2]]),([8,8],[[-3,3],[-3,-3],[3,-3],[3,3]]),([20,20],[[-8,8],[-8,-8],[8,-8],[8,8]])]:
            world=copy.deepcopy(WORLD);world['size']=size;world['spawn']=points[0]
            world['items'][0]['position']=points[1];world['items'][1]['position']=points[2];world['exit']['position']=points[3]
            project=self.root/f'room-{size[0]}-{size[1]}';project.mkdir()
            s.prepare(project,world,b)
            producer.check(b,project,self.job)

    def test_build_modify_restore_export_snapshots(self):
        with patch.object(b,'request_structured',return_value=answer()) as model,patch.object(producer,'check'),patch.object(producer,'render_preview'):
            game=b.process_request(self.request,self.job)['game']
            self.assertEqual(model.call_args.kwargs['model'],'gpt-5.6-sol')
        self.assertEqual(game['format'],s.FORMAT)
        base=producer.game_root(b,self.ident)/'revisions'
        files={p.name:p.read_bytes() for p in (base/'0001').iterdir() if p.is_file()}
        new=copy.deepcopy(WORLD);new['items'].append(dict(name='红色种子',position=[0,-3],color='be7272'))
        with patch.object(b,'request_structured',return_value=answer(new)),patch.object(producer,'check'),patch.object(producer,'render_preview'):
            b.process_request({**self.request,'action':'revise_game','game_revision':1,'prompt':'增加红色种子'},self.job)
        with patch.object(b,'request_structured') as model,patch.object(producer,'check'),patch.object(producer,'render_preview'):
            b.process_request({**self.request,'action':'restore_created','game_revision':2,'restore_revision':1},self.job)
            model.assert_not_called()
        for name,value in files.items():
            self.assertEqual((base/'0001'/name).read_bytes(),value)
            if name not in ['version.json','preview.png']: self.assertEqual((base/'0003'/name).read_bytes(),value)
        target=self.root/'3d.zip'
        resources.export_project(dict(idea_id=self.ident,game_revision=3,export_path=str(target)),self.job,b)
        with zipfile.ZipFile(target) as archive:
            self.assertEqual(archive.read('world.json'),files['world.json'])
            self.assertIn('spatial_player.gd',archive.namelist())

    def test_unsupported_cancel_stale_and_missing_preparation_do_not_publish(self):
        unsupported=dict(supported=False,summary='尚不支持',world=None,limitations=['战斗尚未接通'])
        with patch.object(b,'request_structured',return_value=unsupported) as model:
            with self.assertRaisesRegex(ValueError,'尚不能'): b.process_request(self.request,self.job)
            self.assertEqual(model.call_count,1)
        self.assertIsNone(producer.read_game(b,self.ident))
        with self.assertRaises(ValueError): b.process_request({**self.request,'revision':2},self.job)
        (self.job/'cancel').touch()
        with self.assertRaises(InterruptedError): b.process_request(self.request,self.job)
        (self.job/'cancel').unlink()
        (self.idea_path.parent/'builds/0001.json').unlink()
        with patch.object(b,'request_structured') as model:
            with self.assertRaisesRegex(ValueError,'制作清单'): b.process_request(self.request,self.job)
            model.assert_not_called()

    def test_2d_cannot_be_converted_or_weakened(self):
        b.atomic_json(producer.game_root(b,self.ident)/'game.json',dict(current_revision=1,versions=[]))
        with self.assertRaisesRegex(ValueError,'不能直接切'): b.process_request({**self.request,'game_revision':1},self.job)
        with self.assertRaises(ValueError): producer.validate_answer(dict(script='extends Node3D',summary='x',controls=[],implemented=[],limitations=[],test={}))

    def test_generation_failures_preserve_last_version(self):
        with patch.object(b,'request_structured',return_value=answer()),patch.object(producer,'check'),patch.object(producer,'render_preview'):
            b.process_request(self.request,self.job)
        initial=(producer.game_root(b,self.ident)/'game.json').read_bytes()
        modified=copy.deepcopy(WORLD);modified['speed']=4
        with patch.object(b,'request_structured',return_value=answer(modified)),patch.object(producer,'check',side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError): b.process_request({**self.request,'action':'revise_game','game_revision':1,'prompt':'快一点'},self.job)
        self.assertEqual((producer.game_root(b,self.ident)/'game.json').read_bytes(),initial)
        self.assertFalse(list((producer.game_root(b,self.ident)/'revisions').glob('.pending-*')))


if __name__=='__main__': unittest.main()
