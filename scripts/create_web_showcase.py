"""User-authorized showcase, through the same backend actions as the UI."""
from pathlib import Path
import sys,json
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
import backend as b
import producer
RUN=ROOT/'.playseed/qa/web-showcase';RUN.mkdir(parents=True,exist_ok=True)
STATE=RUN/'state.json'
PROMPT='''制作一个可展示的网页3D元素魔法战斗小游戏，名称“元素守望”。参考用户指定Webcam Spell Caster的玩法类别，但用原创场景和程序模型。玩家是中心祭坛的兜帽法师，鼠标瞄准，点击施法，数字1/2/3/4切换火焰、电弧、冰霜、岩柱。守护祭坛抵挡三波从周边传送门出现的敌人，守护值耗尽失败，清掉三波胜利，可以R重开。第一版先鼠标键盘，摄像头手势、声音、在线分享后续；目前只要求本机浏览器试玩。画风明确：深蓝夜色的神秘遗迹、月光、雕刻感石柱、发光符文、青蓝祭坛，火焰橙红/雷电紫蓝/冰霜青白/岩柱暖金，四种法术有不同范围、命中反馈和冷却。模型全部由代码组合几何体，不用外部素材或Blender，不生独立图片，不复制原游戏人物。先场景、角色和法术表现统一，再完整战斗循环；不能只有球体。镜头有立体景深感但看得清敌人、法师与整块场地，HUD简洁中文，角色跟随瞄准转向。上述玩法、画风、素材来源已明确，直接整理第一版方案。'''
def call(action,extra=None):
 state=b.read_json(STATE) if STATE.exists() else {}
 job=RUN/(action+'-'+b.now().replace(':','-'));job.mkdir(parents=True,exist_ok=True)
 req=dict(action=action,model='gpt-6-astra',reasoning_effort='high')
 if state:
  ident=state['idea_id'];idea=b.read_json(b.DATA/'ideas'/ident/'idea.json');game=producer.read_game(b,ident)
  req.update(idea_id=ident,revision=idea['revision'],game_revision=game['current_revision'] if game else 0)
 req.update(extra or {});b.atomic_json(job/'request.json',req)
 print(action,str(job),flush=True)
 result=b.process_request(req,job);b.atomic_json(job/'result.json',result)
 if 'idea' in result:b.atomic_json(STATE,{'idea_id':result['idea']['id'],'last_action':action,'job':str(job)})
 return result
if not STATE.exists():
 folder=ROOT/'我的游戏/元素守望';folder.mkdir(parents=True,exist_ok=False)
 call('create_project',dict(project_directory=str(folder),delivery='web',prompt=PROMPT))
state=b.read_json(STATE);idea=b.read_json(b.DATA/'ideas'/state['idea_id']/'idea.json')
if idea['revision']==0:idea=call('discuss',{'prompt':PROMPT})['idea']
if idea['status']!='confirmed':
 if not idea['ready'] or idea['questions']:raise RuntimeError('方案有待回答问题，请先审阅；未自动编造回答。')
 call('confirm_brief')
call('prepare_build')
if not producer.read_game(b,state['idea_id']):call('build_game',dict(format='web-3d-v1',prompt=PROMPT))
print('SHOWCASE_READY',state['idea_id'],flush=True)
