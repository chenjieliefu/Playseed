"""Replay the saved garden image sample with real mouse/key input, or open it."""
import argparse, json, re, shutil, subprocess, sys, uuid
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import backend as b
import producer


def run(run_name, play=False, selected_revision=None):
    base = ROOT / '.playseed/image-validation'
    folder = (base / run_name).resolve()
    if folder.parent != base.resolve():
        raise ValueError('无效的验收目录')
    report = b.read_json(folder / 'report.json')
    project = Path(report['project_directory']).resolve()
    if project.parent != folder:
        raise ValueError('验收工程不在本次目录中')
    if play:
        job = folder / 'data/jobs' / ('manual-play-' + uuid.uuid4().hex)
        job.mkdir(parents=True)
        selected = selected_revision or b.read_json(project / 'game.json')['current_revision']
        source = project / f'revisions/{selected:04d}'
        producer.check(b, source, job)
        with (job / 'play.log').open('w') as log:
            subprocess.Popen(producer.sandbox_command(b, source, job, ['--max-fps','60']),
                             cwd=source, stdout=log, stderr=log, start_new_session=True,
                             env=producer.runtime_env())
        print('已打开小芽花园：点击三块泥土地播种，R 重新开始。')
        return
    results = []
    for revision in ([selected_revision] if selected_revision else [1, 2, 3]):
        expected = report['second_image' if revision == 2 else 'first_image']
        job = folder / 'data/jobs' / ('image-replay-' + uuid.uuid4().hex)
        job.mkdir(parents=True)
        scratch = job / 'project'
        shutil.copytree(project / f'revisions/{revision:04d}', scratch, ignore=shutil.ignore_patterns('.godot'))
        driver = (ROOT / 'scripts/playthrough_checks/driver.gd').read_text()
        driver = driver.replace('and reset_ok', 'and reset_ok and image_ok and timer_ok and reset.sprouted_count == 0 and reset.planted_count == 0')
        driver += '\nconst EXPECTED = "won"\nconst CAPTURE_DIR = ' + json.dumps(str(job / 'runtime'))
        driver += '\nconst IMAGE_ID = ' + json.dumps(expected) + '''
var image_ok = false
var timer_ok = false
func exercise():
    image_ok = game.robot_sprite.texture == game.asset_texture(IMAGE_ID) and game.robot_sprite.is_visible_in_tree() and is_equal_approx(game.robot_sprite.scale.x, game.robot_sprite.scale.y)
    for x in [455, 640, 825]:
        click(Vector2(x, 350))
        await tick()
    for i in range(95):
        await tick()
    timer_ok = not game.playseed_snapshot().won and game.playseed_snapshot().planted_count == 3
    for i in range(40):
        await tick()
'''
        if revision == 4:
            generated = b.read_json(folder / 'generation-report.json')['asset_id']
            driver += '\nconst GENERATED_IMAGE = ' + json.dumps(generated) + '\n'
            driver = driver.replace('    release_all()', "    for sprite in game.sprout_sprites:\n        image_ok = image_ok and sprite.is_visible_in_tree() and sprite.texture == game.asset_texture(GENERATED_IMAGE) and is_equal_approx(sprite.scale.x, sprite.scale.y)\n    release_all()")
            driver = driver.replace('    var reset = game.playseed_snapshot()', '    for sprite in game.sprout_sprites:\n        image_ok = image_ok and not sprite.visible\n    var reset = game.playseed_snapshot()')
        (scratch / '_image_check.gd').write_text(driver)
        (job / 'driver.gd').write_text(driver)
        output = b.run_process(producer.sandbox_command(b, scratch, job, ['--fixed-fps','60','--script','_image_check.gd','--quit-after','1000']), job, 30, 'image-replay', cwd=scratch, child_env=producer.runtime_env())
        match = re.search(r'PLAYTHROUGH_REPORT:(.*)', output)
        if not match or re.search(r'(?m)(SCRIPT ERROR:|ERROR:)', output):
            raise RuntimeError('实际图片试玩检查失败：' + str(job))
        result = json.loads(match[1])
        result.update(revision=revision, job=str(job), image_id=expected)
        results.append(result)
        shutil.rmtree(scratch)
        print(json.dumps(result, ensure_ascii=False), flush=True)
    report['input_replay'] = results
    report['status'] = 'input_replay_passed_needs_visual_review'
    b.atomic_json(folder / (f'image-replay-v{selected_revision}.json' if selected_revision else 'report.json'), report)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='验证或试玩参考图片素材样本')
    parser.add_argument('run')
    parser.add_argument('--play', action='store_true')
    parser.add_argument('--revision', type=int)
    args = parser.parse_args()
    run(args.run, args.play, args.revision)
