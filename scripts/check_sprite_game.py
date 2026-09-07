"""Replay the isolated four-frame garden sample with actual keyboard input."""
import argparse,json,re,shutil,sys,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
import backend as b,producer
b.DATA=ROOT/'.playseed/qa/visual-suite/data'
args=argparse.ArgumentParser()
args.add_argument('--revision',type=int,default=3)
args.add_argument('--fps',type=int,default=4)
args.add_argument('--aligned',action='store_true')
args.add_argument('--badge-id',default='')
args.add_argument('--cat-id',default='11de2f2c489b590e957b7abb82f635d1')
opt=args.parse_args()
if not re.fullmatch('[a-f0-9]{32}',opt.cat_id): raise SystemExit('角色素材编号无效。')
if opt.revision < 3: raise SystemExit('请选择第3版或之后的帧动画样本。')
source=producer.game_root(b,'d'*32)/'revisions'/f'{opt.revision:04d}'
job=ROOT/'.playseed/qa/sprite-frames'/('replay-'+uuid.uuid4().hex[:8]);job.mkdir(parents=True)
scratch=job/'project';shutil.copytree(source,scratch,ignore=shutil.ignore_patterns('.godot'))
driver=(ROOT/'scripts/playthrough_checks/driver.gd').read_text().replace('and reset_ok','and reset_ok and checks_ok and reset.sprout_frame == 0 and reset.sprout_playing')
driver=driver.replace('    RenderingServer.force_draw(false)','    await process_frame\n    RenderingServer.force_draw(false)\n    await process_frame\n    RenderingServer.force_draw(false)')
driver+='\nconst EXPECTED = "won"\nconst CAPTURE_DIR = '+json.dumps(str(job/'runtime'))+'''
var checks_ok = true
func verify(label: String, passed: bool):
    checkpoints.append({"check":label,"passed":passed})
    checks_ok = checks_ok and passed
func go_to(target: Vector2):
    for i in range(400):
        var diff: Vector2 = target - game.cat_sprite.position
        if diff.length() < 5 or game.won: break
        key(KEY_LEFT, diff.x < -3); key(KEY_RIGHT, diff.x > 3)
        key(KEY_UP, diff.y < -3); key(KEY_DOWN, diff.y > 3)
        await tick()
    release_all()
func exercise():
    await capture("start")
    verify("four_frames",game.sprout_sprite.sprite_frames.get_frame_count("default") == 4)
    verify("correct_speed",game.sprout_sprite.sprite_frames.get_animation_speed("default") == EXPECTED_FPS)
    if EXPECTED_ALIGNED:
        var builder = load("res://playseed_sprite_frames.gd")
        var bottoms = []
        for i in range(4):
            bottoms.append(builder.visible_bottom(game.sprout_sprite.sprite_frames.get_frame_texture("default",i).get_image()))
        verify("visible_bottoms_aligned",bottoms.min() == bottoms.max())
    if EXPECTED_BADGE != "":
        var badge = game.get("ui_badge")
        verify("interface_image_loaded",badge != null and badge.texture == game.asset_texture(EXPECTED_BADGE))
        if badge != null:
            var rect: Rect2
            if badge is Control: rect = badge.get_global_rect()
            else:
                var dimensions: Vector2 = badge.texture.get_size() * badge.scale.abs()
                rect = Rect2(badge.global_position-dimensions/2,dimensions)
            verify("interface_image_size",rect.size.x >= 24 and rect.size.x <= 32 and absf(rect.size.x-rect.size.y)<0.1)
            var overlap = false
            for label in game.find_children("*","Label",true,false):
                if label.visible and label.text != "" and rect.intersects(label.get_global_rect()): overlap = true
            verify("interface_image_clear_of_text",not overlap)
    verify("expected_cat",game.cat_sprite.texture == game.asset_texture(EXPECTED_CAT))
    var observed = {}
    for i in range(80):
        observed[game.sprout_sprite.frame] = true
        await tick()
    verify("all_frames_played",observed.size() == 4)
    tap(KEY_SPACE); await tick()
    var paused_frame = game.sprout_sprite.frame
    verify("space_pauses",not game.sprout_sprite.is_playing())
    for i in range(45): await tick()
    verify("pause_stable",game.sprout_sprite.frame == paused_frame)
    await capture("paused")
    tap(KEY_SPACE); await tick()
    verify("space_resumes",game.sprout_sprite.is_playing())
    for i in range(20):
        tap(KEY_R); await tick()
        verify("reset_frame_" + str(i),game.sprout_sprite.frame == 0)
    var actors = 0
    for child in game.get_children():
        if child is AnimatedSprite2D: actors += 1
    verify("no_duplicate_nodes",actors == 1)
    var half_size: Vector2 = game.sprout_sprite.sprite_frames.get_frame_texture("default",0).get_size() * game.sprout_sprite.scale / 2
    verify("sprout_clear_of_ui",game.sprout_sprite.position.y-half_size.y >= 88 and game.sprout_sprite.position.y+half_size.y <= 532)
    for edge in [Vector2(0,0),Vector2(960,600)]:
        await go_to(edge)
        var extent: Vector2 = game.cat_sprite.texture.get_size() * game.cat_sprite.scale.abs() / 2
        var position: Vector2 = game.cat_sprite.position
        verify("cat_edge_" + str(edge),position.x-extent.x >= -0.1 and position.x+extent.x <= 960.1 and position.y-extent.y >= 87.9 and position.y+extent.y <= 532.1)
    for point in [Vector2(238,213),Vector2(494,304),Vector2(750,405)]: await go_to(point)
    verify("original_goal",game.collected_count == 3 and game.won)
'''
driver += '\nconst EXPECTED_FPS = ' + str(opt.fps) + '\n'
driver += '\nconst EXPECTED_ALIGNED = ' + ('true' if opt.aligned else 'false') + '\n'
driver += '\nconst EXPECTED_BADGE = ' + json.dumps(opt.badge_id) + '\n'
driver += '\nconst EXPECTED_CAT = ' + json.dumps(opt.cat_id) + '\n'
(scratch/'_sprite_check.gd').write_text(driver)
try:
 output=b.run_process(producer.sandbox_command(b,scratch,job,['--fixed-fps','60','--script','_sprite_check.gd','--quit-after','2000']),job,45,'replay',cwd=scratch,child_env=producer.runtime_env())
except Exception:
 output=(job/'replay.log').read_text() if (job/'replay.log').exists() else ''
match=re.search(r'PLAYTHROUGH_REPORT:(.*)',output)
if not match: print(output);raise SystemExit('未取得试玩报告：'+str(job))
report=json.loads(match[1]);report['evidence']=str(job)
b.atomic_json(ROOT/'.playseed/qa/sprite-frames/latest-playthrough.json',report)
print(json.dumps(report,ensure_ascii=False))
raise SystemExit(0 if report['passed'] and not re.search(r'(?m)(SCRIPT ERROR:|ERROR:)',output) else 1)
