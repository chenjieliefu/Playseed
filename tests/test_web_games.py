import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import backend as b
import producer
import web_games
import resources

SCRIPT='''export default function createGame({canvas,hud}) {
 const ctx=canvas.getContext('2d');let shots=0;
 return {update(dt){},render(){ctx.fillStyle='#152441';ctx.fillRect(0,0,960,600);ctx.fillStyle='#82eec5';ctx.fillRect(400,250,100,100);hud('点击发射 '+shots);},action(name,p){if(name==='primary'&&p.pressed)shots++;},snapshot(){return {won:false,lost:false,progress:0,shots};},reset(){shots=0;}};
}'''
def answer(script=SCRIPT):
 return dict(script=script,summary='网页测试',controls=['点击发射'],implemented=['发射'],limitations=['验证夹具'],test=dict(action='primary',at=[480,300],changed_field='shots',wait_frames=0))
class WebGamesTests(unittest.TestCase):
 def setUp(self):
  tmp=tempfile.TemporaryDirectory();self.addCleanup(tmp.cleanup);self.data=Path(tmp.name)
  p=patch.object(b,'DATA',self.data);p.start();self.addCleanup(p.stop)
  self.ident='b'*32;self.idea=dict(id=self.ident,revision=1,status='confirmed',confirmed_revision=1,title='网页验证',delivery='web',plan={'title':'点击发射'})
  b.atomic_json(self.data/'ideas'/self.ident/'idea.json',self.idea)
  self.job=self.data/'job';self.job.mkdir()
  self.request=dict(action='build_game',idea_id=self.ident,revision=1,game_revision=0)
 def test_web_revision_cycle_and_export(self):
  with patch.object(b,'request_structured',return_value=answer()),patch.object(web_games,'check'):
   first=b.process_request(self.request,self.job)['game']
   self.assertEqual(first['format'],'web-2d-v1')
   root=producer.game_root(b,self.ident)
   original=(root/'revisions/0001/game.js').read_bytes()
   with patch.object(b,'request_structured',return_value=answer(SCRIPT.replace('shots++','shots+=2'))):
    second=b.process_request({**self.request,'action':'revise_game','game_revision':1,'prompt':'双发'},self.job)['game']
   self.assertEqual(second['current_revision'],2)
   restored=b.process_request({**self.request,'action':'restore_created','game_revision':2,'restore_revision':1},self.job)['game']
   self.assertEqual(restored['current_revision'],3)
   self.assertEqual((root/'revisions/0003/game.js').read_bytes(),original)
   self.assertEqual((root/'revisions/0001/game.js').read_bytes(),original)
   target=self.data/'game.zip'
   b.process_request(dict(action='export_created',idea_id=self.ident,game_revision=3,export_path=str(target)),self.job)
   import zipfile
   with zipfile.ZipFile(target) as z:self.assertIn('index.html',z.namelist());self.assertIn('game.js',z.namelist());self.assertIn('vendor/THREE-LICENSE.txt',z.namelist())
 def test_browser_uses_real_input_and_reset(self):
  with patch.object(b,'request_structured',return_value=answer()):
   game=b.process_request(self.request,self.job)['game']
  self.assertEqual(game['current_revision'],1)
  report=b.read_json(self.job/'web-check.json')
  self.assertEqual(report['after']['shots'],1);self.assertEqual(report['reset']['shots'],0)
  self.assertEqual(game['versions'][-1]['input_validation'],'mouse-keyboard')
  self.assertEqual(game['versions'][-1]['playability_checks'],['pause_resume','restart_replay'])
  self.assertEqual(len(report['lifecycle']['replays']),2)
  for replay in report['lifecycle']['replays']:
   self.assertEqual(replay['before']['shots'],0);self.assertEqual(replay['after']['shots'],1)
 def test_gesture_only_validation_is_recorded_without_claiming_real_hands(self):
  response=answer(SCRIPT.replace('return {update(dt)', 'return {gestureOnly:true,update(dt)'))
  response['controls']=['右手合指发射']
  with patch.object(b,'request_structured',return_value=response):
   game=b.process_request(self.request,self.job)['game']
  self.assertEqual(game['versions'][-1]['input_validation'],'synthetic-hand-landmarks')
  report=b.read_json(self.job/'web-check.json')
  self.assertEqual(report['after']['shots'],1);self.assertEqual(report['reset']['shots'],0)
  self.assertTrue(report['lifecycle']['pause_resume'])
  self.assertEqual(len(report['lifecycle']['replays']),2)
 def test_broken_replay_is_rejected_and_old_version_is_preserved(self):
  with patch.object(b,'request_structured',return_value=answer()),patch.object(web_games,'check'):
   first=b.process_request(self.request,self.job)['game']
  root=producer.game_root(b,self.ident)
  original=(root/'revisions/0001/game.js').read_bytes()
  broken=SCRIPT.replace('let shots=0','let shots=0,starts=0').replace("name==='primary'&&p.pressed", "name==='primary'&&p.pressed&&starts===1").replace('reset(){shots=0;', 'reset(){shots=0;starts++;')
  with self.assertRaises(RuntimeError):
   web_games.handle({**self.request,'action':'revise_game','game_revision':1,'prompt':'更新外观'},self.job,b,self.idea,first,prepared_answer=answer(broken))
  self.assertIn('核心操作失效',(self.job/'web-check.log').read_text())
  self.assertFalse((self.job/'web-check.json').exists())
  self.assertEqual(producer.read_game(b,self.ident)['current_revision'],1)
  self.assertEqual((root/'revisions/0001/game.js').read_bytes(),original)
  self.assertFalse(list((root/'revisions').glob('.pending-*')))
 def test_replay_failure_enters_existing_repair_flow(self):
  broken=SCRIPT.replace('let shots=0','let shots=0,starts=0').replace("name==='primary'&&p.pressed", "name==='primary'&&p.pressed&&starts===1").replace('reset(){shots=0;', 'reset(){shots=0;starts++;')
  with patch.object(b,'request_structured',side_effect=[answer(broken),answer()]) as model:
   game=b.process_request(self.request,self.job)['game']
  self.assertEqual(model.call_count,2)
  self.assertEqual(game['versions'][-1]['repair_count'],1)
  self.assertIn('核心操作失效',b.read_json(self.job/'repair-context-1.json')['error'])
  self.assertEqual(game['versions'][-1]['playability_checks'],['pause_resume','restart_replay'])
 def test_gameplay_advancing_in_render_is_rejected_when_paused(self):
  broken=SCRIPT.replace('let shots=0','let shots=0,progress=0').replace('render(){', 'render(){if(shots)progress++;').replace('progress:0,shots', 'progress,shots').replace('reset(){shots=0;', 'reset(){shots=0;progress=0;')
  with self.assertRaises(RuntimeError):
   web_games.handle(self.request,self.job,b,self.idea,None,prepared_answer=answer(broken))
  self.assertIn('暂停后已经开始的玩法仍在推进',(self.job/'web-check.log').read_text())
  self.assertIsNone(producer.read_game(b,self.ident))
 def test_broken_restart_button_is_not_hidden_by_direct_reset_check(self):
  prepare=web_games.prepare
  def broken_prepare(api,ident,staging,restored=None):
   prepare(api,ident,staging,restored)
   player=staging/'player.js'
   player.write_text(player.read_text().replace("$('restart').onclick=()=>{send('reset');", "$('restart').onclick=()=>{"))
  with patch.object(web_games,'prepare',side_effect=broken_prepare),self.assertRaises(RuntimeError):
   web_games.handle(self.request,self.job,b,self.idea,None,prepared_answer=answer())
  self.assertIsNone(producer.read_game(b,self.ident))
  self.assertFalse((self.job/'web-check.json').exists())
 def test_legacy_runtime_restore_keeps_old_checks_without_new_claim(self):
  prepare=web_games.prepare
  def legacy_prepare(api,ident,staging,restored=None):
   prepare(api,ident,staging,restored)
   boot=staging/'boot.js'
   boot.write_text(boot.read_text().replace('lifecycleChecks:true,','').replace("notify('reset-state');",''))
  with patch.object(web_games,'prepare',side_effect=legacy_prepare),patch.object(web_games,'check'):
   first=web_games.handle(self.request,self.job,b,self.idea,None,prepared_answer=answer())['game']
  old_script=(producer.game_root(b,self.ident)/'revisions/0001/boot.js').read_bytes()
  restored=b.process_request({**self.request,'action':'restore_created','game_revision':1,'restore_revision':1},self.job)['game']
  self.assertEqual(restored['current_revision'],2)
  self.assertNotIn('playability_checks',restored['versions'][-1])
  self.assertIsNone(b.read_json(self.job/'web-check.json')['lifecycle'])
  self.assertEqual((producer.game_root(b,self.ident)/'revisions/0001/boot.js').read_bytes(),old_script)
 def test_restart_probe_respects_the_same_opening_delay(self):
  delayed=SCRIPT.replace('let shots=0','let shots=0,age=0').replace('update(dt){}','update(dt){age+=dt;}').replace("name==='primary'&&p.pressed", "name==='primary'&&p.pressed&&age>=1.5").replace('reset(){shots=0;', 'reset(){shots=0;age=0;')
  result=web_games.handle(self.request,self.job,b,self.idea,None,prepared_answer=answer(delayed))
  self.assertEqual(result['game']['current_revision'],1)
  self.assertEqual(len(b.read_json(self.job/'web-check.json')['lifecycle']['replays']),2)
 def test_three_scene_in_browser(self):
  script="""export default function createGame({canvas,THREE:T,hud}) {
   const renderer=new T.WebGLRenderer({canvas,antialias:true});renderer.setSize(960,600,false);
   const scene=new T.Scene(),camera=new T.PerspectiveCamera(50,1.6,.1,100);camera.position.z=5;
   const mesh=new T.Mesh(new T.BoxGeometry(),new T.MeshNormalMaterial());scene.add(mesh);let casts=0;
   return {update(dt){},render(){renderer.render(scene,camera);},action(name,p){if(name==='primary'&&p.pressed){casts++;mesh.rotation.y+=.5;}},snapshot(){return {won:false,lost:false,progress:0,casts};},reset(){casts=0;mesh.rotation.y=0;}};
  }"""
  output=answer(script);output['test']['changed_field']='casts'
  with patch.object(b,'request_structured',return_value=output):
   game=b.process_request({**self.request,'format':'web-3d-v1'},self.job)['game']
  self.assertEqual(game['format'],'web-3d-v1')
  self.assertEqual(b.read_json(self.job/'web-check.json')['after']['casts'],1)
 def test_failure_does_not_publish(self):
  with patch.object(b,'request_structured',return_value=answer(SCRIPT.replace('shots++','shots=shots'))),patch.object(web_games,'check',side_effect=RuntimeError('动作不生效')):
   with self.assertRaises(RuntimeError):b.process_request(self.request,self.job)
  self.assertIsNone(producer.read_game(b,self.ident))
  self.assertFalse(list((producer.game_root(b,self.ident)/'revisions').glob('.pending-*')))
 def test_prepared_edit_checks_without_model_and_keeps_history(self):
  with patch.object(b,'request_structured') as model,patch.object(web_games,'check'):
   first=web_games.handle(self.request,self.job,b,self.idea,None,prepared_answer=answer())['game']
   second=web_games.handle({**self.request,'action':'revise_game','game_revision':1},self.job,b,self.idea,first,prepared_answer=answer())['game']
   model.assert_not_called();self.assertEqual(second['current_revision'],2)
   self.assertEqual(second['versions'][-1]['editor'],'workspace')
  with patch.object(web_games,'check',side_effect=RuntimeError('拒绝候选')),patch.object(b,'request_structured') as model:
   with self.assertRaises(RuntimeError):web_games.handle({**self.request,'action':'revise_game','game_revision':2},self.job,b,self.idea,second,prepared_answer=answer())
   model.assert_not_called();self.assertEqual(producer.read_game(b,self.ident)['current_revision'],2)
 def test_static_rejects_network_and_bad_syntax(self):
  project=self.data/'web';project.mkdir()
  for script in ["export default ()=>fetch('https://example.com')", "import x from 'https://example.com/x.js';", "export default function ("]:
   (project/'game.js').write_text(script)
   with self.assertRaises(RuntimeError):
    b.run_process(web_games.command(b,'lint',project),self.job,10,'web-lint')
 def test_static_allows_three_camera_properties(self):
  project=self.data/'web';project.mkdir()
  (project/'game.js').write_text("export default function createGame(){const camera={top:14};camera.top=12;function mesh(parent){return parent.add(camera);}return camera;}")
  b.run_process(web_games.command(b,'lint',project),self.job,10,'web-lint')
 def test_stale_play_and_cancel_keep_game(self):
  with patch.object(b,'request_structured',return_value=answer()),patch.object(web_games,'check'):
   b.process_request(self.request,self.job)
   with patch.object(web_games,'play') as play:
    with self.assertRaises(ValueError):b.process_request({**self.request,'action':'play_created','game_revision':0},self.job)
    play.assert_not_called()
   (self.job/'cancel').touch()
   with self.assertRaises(InterruptedError):b.process_request({**self.request,'action':'revise_game','game_revision':1,'prompt':'再修改'},self.job)
   self.assertEqual(producer.read_game(b,self.ident)['current_revision'],1)
 def test_native_old_project_not_converted_by_delivery(self):
  self.assertEqual(web_games.selected_format(self.idea,{'current_revision':1},self.request),'2d')
  self.assertEqual(web_games.selected_format(self.idea,None,{'format':'room3d-v1'}),'web-3d-v1')
 def test_unconfirmed_and_stale_rejected(self):
  self.idea['status']='ready';b.atomic_json(self.data/'ideas'/self.ident/'idea.json',self.idea)
  with patch.object(b,'request_structured') as model:
   with self.assertRaises(ValueError):b.process_request(self.request,self.job)
   model.assert_not_called()
 def test_context_uses_active_version_and_stops_at_restore(self):
  versions=[dict(revision=1,summary='第一版',source='build_game'),dict(revision=2,summary='后来放弃的自动攻击',source='revise_game'),dict(revision=3,summary='恢复第一版',source='restore_created',controls=['手动发射']),dict(revision=4,summary='双发',source='revise_game'),dict(revision=5,summary='不属于当前状态',source='revise_game')]
  context=web_games.revision_context({'current_revision':4,'versions':versions})
  self.assertEqual(context['current_version']['summary'],'双发')
  self.assertEqual([v['revision'] for v in context['recent_changes']],[3,4])
  context['current_version']['summary']='外部修改';self.assertEqual(versions[3]['summary'],'双发')
 def test_repair_keeps_current_requirements_components_and_images(self):
  with patch.object(b,'request_structured',return_value=answer()),patch.object(web_games,'check'):
   first=b.process_request(self.request,self.job)['game']
  reference=self.data/'reference.png'
  image_context={'visual_inputs':[{'id':'hero','name':'角色参考'}]}
  with patch.object(resources,'model_images',return_value=(image_context,[str(reference)])),patch.object(b,'request_structured',side_effect=[answer(SCRIPT.replace('shots++','shots+=2')),answer(SCRIPT.replace('shots++','shots+=3'))]) as model,patch.object(web_games,'check',side_effect=[RuntimeError('候选输入错误'),None]):
   second=b.process_request({**self.request,'action':'revise_game','game_revision':1,'prompt':'增加发射，保留原角色'},self.job)['game']
  contexts=[json.loads(call.args[0].split('\n')[-1]) for call in model.call_args_list]
  for context in contexts:
   self.assertEqual(context['previous_script'],SCRIPT)
   self.assertEqual(context['current_version']['revision'],1)
   self.assertEqual(context['current_version']['controls'],first['versions'][0]['controls'])
   self.assertEqual(context['request'],'增加发射，保留原角色')
   self.assertEqual(context['visual_inputs'],image_context['visual_inputs'])
   self.assertIn('runtime_capabilities',context)
  for call in model.call_args_list:self.assertEqual(call.kwargs['images'],[str(reference)])
  self.assertIn('候选输入错误',contexts[1]['error'])
  self.assertEqual(second['versions'][-1]['base_game_revision'],1)
 def test_capability_catalog_uses_actual_shared_rules(self):
  root=b.ROOT/'runtime/web'
  context=web_games.runtime_context(root,'web-3d-v1')
  self.assertEqual(context['shared_spell_rules_source'],(root/'spell-rules.mjs').read_text())
  self.assertIn('只绘制',context['components']['createSpellEffects(scene,anchor)'])
  self.assertNotIn('components',web_games.runtime_context(root,'web-2d-v1'))
 def test_platform_continuous_edits_and_restore_in_2d_and_3d(self):
  scenes=[('web-2d-v1',SCRIPT,'primary','shots'),('web-3d-v1',"""export default function createGame({canvas,THREE:T,hud}){
   const renderer=new T.WebGLRenderer({canvas});renderer.setSize(960,600,false);const scene=new T.Scene(),camera=new T.PerspectiveCamera(50,1.6,.1,100);camera.position.z=5;
   const gate=new T.Mesh(new T.BoxGeometry(2,.3,.3),new T.MeshNormalMaterial());scene.add(gate);let turns=0;
   return {update(dt){},render(){gate.rotation.z=turns*.2;renderer.render(scene,camera);hud('向右转动机关 '+turns);},action(name,p){if(name==='right'&&p.pressed)turns++;},snapshot(){return {won:turns>=12,lost:false,progress:Math.min(1,turns/12),turns};},reset(){turns=0;}};
  }""",'right','turns')]
  for index,(fmt,script,action,field) in enumerate(scenes):
   with self.subTest(format=fmt):
    ident=str(index+1)*32;idea={**self.idea,'id':ident};b.atomic_json(self.data/'ideas'/ident/'idea.json',idea)
    request={**self.request,'idea_id':ident,'format':fmt};response=answer(script);response['test'].update(action=action,changed_field=field)
    snapshots={}
    for revision in range(1,5):
     response['script']=script.replace(field+'++',field+f'+={revision}')
     with patch.object(b,'request_structured',return_value=response):
      result=b.process_request({**request,'action':'build_game' if revision==1 else 'revise_game','game_revision':revision-1,'prompt':f'操作效果提高至{revision}'},self.job)['game']
     self.assertEqual(result['current_revision'],revision)
     self.assertEqual(b.read_json(self.job/'web-check.json')['after'][field],revision)
     context=b.read_json(self.job/'generation-context.json');self.assertEqual(context['current_version']['revision'] if context['current_version'] else 0,revision-1)
     root=producer.game_root(b,ident);snapshots[revision]=(root/f'revisions/{revision:04d}/game.js').read_bytes()
    restored=b.process_request({**request,'action':'restore_created','game_revision':4,'restore_revision':1},self.job)['game']
    self.assertEqual(restored['current_revision'],5);self.assertEqual(restored['versions'][-1]['restored_from'],1)
    self.assertEqual(b.read_json(self.job/'web-check.json')['after'][field],1)
    for revision,content in snapshots.items():self.assertEqual((root/f'revisions/{revision:04d}/game.js').read_bytes(),content)

if __name__=='__main__':unittest.main()
