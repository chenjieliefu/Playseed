"""Validate the saved two-image garden sample using real keyboard input."""
import sys,json,re,shutil,subprocess,uuid,argparse
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
import backend as b,producer
base=ROOT/'.playseed/qa/visual-suite';b.DATA=base/'data'
parser=argparse.ArgumentParser(description='试玩或复查小猫花园素材样本')
parser.add_argument('--revision',type=int,default=2)
parser.add_argument('--play',action='store_true')
args=parser.parse_args()
rev=args.revision
if rev not in (1,2): raise SystemExit("仅有第1、2版验收样本")
source=base/f'data/created_games/{"d"*32}/revisions/{rev:04d}'
if args.play:
 job=base/'jobs'/('play-'+uuid.uuid4().hex);job.mkdir(parents=True)
 producer.check(b,source,job)
 with (job/'play.log').open('w') as log:
  subprocess.Popen(producer.sandbox_command(b,source,job,['--max-fps','60']),cwd=source,stdout=log,stderr=log,start_new_session=True,env=producer.runtime_env())
 print('已打开小猫花园散步：方向键移动，收集三个光点，R重新开始。')
 raise SystemExit(0)
job=base/f'jobs/replay-v{rev}';job.mkdir(exist_ok=True);scratch=job/'project'
shutil.copytree(source,scratch,ignore=shutil.ignore_patterns('.godot'),dirs_exist_ok=True)
driver=((ROOT/'scripts/playthrough_checks/driver.gd')).read_text().replace('and reset_ok','and reset_ok and checks_ok and reset.collected_count == 0')
driver = driver.replace('    RenderingServer.force_draw(false)', '    await process_frame\n    RenderingServer.force_draw(false)\n    await process_frame\n    RenderingServer.force_draw(false)')
driver+='\nconst EXPECTED = "won"\nconst CAPTURE_DIR = '+json.dumps(str(job/'runtime'))+'''
var checks_ok = true
func verify(label: String, passed: bool):
    checkpoints.append({"check":label,"passed":passed})
    checks_ok = checks_ok and passed
func go_to(target: Vector2):
    for i in range(400):
        var diff: Vector2 = target - game.cat_sprite.position
        if diff.length() < 5 or game.won:
            break
        key(KEY_LEFT, diff.x < -3)
        key(KEY_RIGHT, diff.x > 3)
        key(KEY_UP, diff.y < -3)
        key(KEY_DOWN, diff.y > 3)
        await tick()
    release_all()
func exercise():
    await capture("start")
    verify("original_cat_texture", game.cat_sprite.texture == game.asset_texture("11de2f2c489b590e957b7abb82f635d1"))
    verify("original_background_texture", game.background_sprite.texture == game.asset_texture("3036e33918cf42e04cbe3b11a0ac2621"))
    verify("uniform_scale", is_equal_approx(game.cat_sprite.scale.x, game.cat_sprite.scale.y) and is_equal_approx(game.background_sprite.scale.x, game.background_sprite.scale.y))
    var picture: Image = game.cat_sprite.texture.get_image()
    verify("actual_transparency", picture.detect_alpha() != Image.ALPHA_NONE)
    key(KEY_UP, true)
    for i in range(160): await tick()
    release_all()
    var half_height: float = game.cat_sprite.texture.get_height() * game.cat_sprite.scale.y / 2.0
    verify("reached_top", game.cat_sprite.position.y <= 134)
    verify("clear_of_top_panel", game.cat_sprite.position.y - half_height >= 87.99)
    await capture("top-boundary")
    key(KEY_DOWN, true)
    for i in range(180): await tick()
    release_all()
    verify("reached_bottom", game.cat_sprite.position.y >= 486)
    verify("clear_of_bottom_panel", game.cat_sprite.position.y + half_height <= 532.01)
    await capture("bottom-boundary")
    key(KEY_LEFT, true)
    for i in range(300): await tick()
    release_all()
    var half_width: float = game.cat_sprite.texture.get_width() * game.cat_sprite.scale.x / 2.0
    verify("left_canvas_edge", game.cat_sprite.position.x - half_width >= 3.99 and game.cat_sprite.position.x < 60)
    tap(KEY_R)
    await tick()
    verify("restart_facing", not game.cat_sprite.flip_h)
    for point in [Vector2(238,213),Vector2(494,304),Vector2(750,405)]:
        await go_to(point)
    for i in range(60): await tick()
    verify("three_collected", game.collected_count == 3)
'''
(scratch/'_visual_check.gd').write_text(driver)
try:
 output=b.run_process(producer.sandbox_command(b,scratch,job,['--fixed-fps','60','--script','_visual_check.gd','--quit-after','2000']),job,45,'replay',cwd=scratch,child_env=producer.runtime_env())
except Exception:
 output=(job/'replay.log').read_text() if (job/'replay.log').exists() else ''
match=re.search(r'PLAYTHROUGH_REPORT:(.*)',output)
if not match:
 print(output);raise SystemExit('Missing replay report: '+str(job))
result=json.loads(match[1]);b.atomic_json(base/f'replay-v{rev}.json',result);print(json.dumps(result,ensure_ascii=False))

raise SystemExit(0 if result["passed"] and not re.search(r"(?m)(SCRIPT ERROR:|ERROR:)",output) else 1)
