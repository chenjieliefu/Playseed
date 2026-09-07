"""Local, anonymous human playtest kit; never treats elapsed time as engagement."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import backend as b
import producer

SESSIONS = ROOT / '.playseed/qa/novice-playtests'
STAGES = [
    dict(title='第一段 · 熟悉游戏', revision=1, minutes='约 3 分钟',
         task='先看游戏内提示，尝试完成一局。愿意的话，再试一次不同的休整选择；不必硬凑时间。'),
    dict(title='第二段 · 再玩一个版本', revision=4, minutes='约 4 分钟',
         task='尝试完成一局，留意与上一段的不同。卡住时可以重来，也可以直接结束并记录原因。'),
    dict(title='第三段 · 最后一个版本', revision=8, minutes='约 3 分钟',
         task='再试一局，留意这次体验有什么变化。随后试着调整音乐和音效音量，再重开一次。'),
]


def read(path):
    return json.loads(path.read_text()) if path.exists() else {}


def file_hashes(folder):
    result = {}
    for path in sorted(folder.rglob('*')):
        if '.godot' in path.relative_to(folder).parts:
            continue
        if path.is_symlink():
            raise ValueError('试玩文件包含链接，不能继续。')
        if path.is_file():
            result[str(path.relative_to(folder))] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def session_path(value):
    path = Path(value).resolve()
    if path.parent != SESSIONS.resolve() or not (path / 'session.json').is_file():
        raise ValueError('找不到有效的本机试玩记录。')
    return path


def prepare():
    SESSIONS.mkdir(parents=True, exist_ok=True)
    folder = SESSIONS / (time.strftime('%Y%m%d-%H%M%S-') + uuid.uuid4().hex[:8])
    folder.mkdir()
    stages = []
    for index, stage in enumerate(STAGES):
        base = ROOT / ('.playseed/qa/audio-20260907/project' if index == 2
                       else '.playseed/validation/p2-20260907/project')
        source = base / 'revisions' / f"{stage['revision']:04d}"
        if not source.is_dir():
            raise ValueError('缺少已经验收的游戏版本，请先完成玩法和声音验收。')
        before = file_hashes(source)
        version = read(source / 'version.json')
        producer.validate_answer(dict(script=(source / 'game.gd').read_text(),
            **{key: version[key] for key in ['summary', 'controls', 'implemented', 'limitations', 'test']}))
        project = folder / f'stage-{index}/project'
        shutil.copytree(source, project, ignore=shutil.ignore_patterns('.godot'))
        job = folder / f'stage-{index}/preflight'
        job.mkdir()
        producer.check(b, project, job)
        if file_hashes(source) != before:
            raise ValueError('来源版本发生变化，本次准备停止。')
        stages.append(dict(stage, source=str(source), source_hashes=before,
                           project_hashes=file_hashes(project)))
    b.atomic_json(folder / 'session.json', dict(schema=1, kind='human_playtest_session', created_at=time.time(),
                  python=sys.executable, script=str(Path(__file__).resolve()), stages=stages,
                  scope='真人比较试玩；不是单个游戏连续10至15分钟内容验证'))
    return folder


def run_stage(folder, index):
    session = read(folder / 'session.json')
    if index not in range(len(session['stages'])):
        raise ValueError('试玩阶段无效。')
    with (folder / 'game.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError('还有试玩窗口未关闭，请先结束上一段。')
        if read(folder / 'feedback.json').get('submitted'):
            raise ValueError('这份反馈已完成，请开始新一份试玩。')
        for i in range(len(session['stages'])):
            old = read(folder / f'stage-{i}/attempt.json')
            if old.get('status') in ['starting', 'running'] and pid_alive(old.get('game_pid')):
                raise ValueError('上次的游戏窗口仍在运行，请先关闭它。')
        for previous in range(index):
            if not read(folder / f'stage-{previous}/attempt.json').get('status') == 'finished':
                raise ValueError('请先完成上一段试玩。')
        stage_dir = folder / f'stage-{index}'
        project = stage_dir / 'project'
        status_path = stage_dir / 'attempt.json'
        previous = read(status_path)
        attempt = dict(status='starting', started_at=time.time(), worker_pid=os.getpid())
        if previous:
            b.atomic_json(stage_dir / ('attempt-' + uuid.uuid4().hex + '.json'), previous)
        b.atomic_json(status_path, attempt)
        try:
            if file_hashes(project) != session['stages'][index]['project_hashes']:
                raise ValueError('试玩副本已被修改，请新建试玩记录。')
            job = stage_dir / ('run-' + uuid.uuid4().hex)
            job.mkdir()
            log_path = job / 'play.log'
            started = time.monotonic()
            with log_path.open('w') as log:
                process = subprocess.Popen(producer.sandbox_command(b, project, job, ['--max-fps', '60']),
                    cwd=project, stdout=log, stderr=log, env=producer.runtime_env())
                attempt.update(status='running', game_pid=process.pid, log=str(log_path))
                b.atomic_json(status_path, attempt)
                code = process.wait()
            elapsed = time.monotonic() - started
            errors = 'SCRIPT ERROR:' in log_path.read_text() or '\nERROR:' in log_path.read_text()
            attempt.update(status='finished' if code == 0 and not errors and elapsed >= 2 else 'failed',
                           ended_at=time.time(), window_seconds=round(elapsed, 2), exit_code=code)
            if attempt['status'] == 'failed':
                attempt['error'] = '窗口未正常结束或出现运行错误，请保留反馈并查看日志。'
        except Exception as exc:
            attempt.update(status='failed', ended_at=time.time(), error=str(exc))
        b.atomic_json(status_path, attempt)
        return attempt


def pid_alive(pid):
    if not isinstance(pid, int) or pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def assess(folder):
    feedback = read(folder / 'feedback.json')
    rows, missing = [], []
    for index, stage in enumerate(read(folder / 'session.json')['stages']):
        attempt = read(folder / f'stage-{index}/attempt.json')
        answer = feedback.get('answers', {}).get(str(index), {})
        if attempt.get('status') != 'finished':
            missing.append(f'第{index+1}段没有正常结束的试玩记录')
        for field, label in [('goal', '目标描述'), ('blocker', '卡点说明'), ('change', '变化描述')]:
            if not str(answer.get(field, '')).strip():
                missing.append(f'第{index+1}段缺少{label}')
        if answer.get('outcome') not in ['通关', '失败', '主动结束', '没看懂如何开始']:
            missing.append(f'第{index+1}段未选择结果')
        rows.append(dict(title=stage['title'], revision=stage['revision'],
                         source_hashes=stage.get('source_hashes', {}),
                         project_hashes=stage.get('project_hashes', {}), attempt=attempt, answer=answer))
    if feedback.get('experience') not in ['从未做过游戏', '尝试过制作游戏', '熟悉游戏制作']:
        missing.append('未填写游戏制作经验')
    if not feedback.get('improvement', '').strip():
        missing.append('未填写最希望改进的一点')
    if feedback.get('continue') not in ['愿意', '不愿意', '说不清']:
        missing.append('未填写继续玩的意愿')
    return dict(schema=1, kind='human_comparison_playtest',
                feedback_complete=not missing, missing=missing, stages=rows,
                window_seconds=sum(r['attempt'].get('window_seconds', 0) for r in rows),
                p2_accepted=False, engagement_verified=False,
                note='打开时长包括停留和离开时间，不能证明有效游玩、好玩或单版10–15分钟内容。',
                feedback=feedback)


def summarize(folder):
    report = assess(folder)
    b.atomic_json(folder / 'report.json', report)
    f = report['feedback']
    lines = ['# 新手比较试玩记录', '',
             '反馈完整，待人工评阅。' if report['feedback_complete'] else '反馈尚未完整，不能视为验收通过。', '',
             report['note'], '', '制作经验：' + str(f.get('experience', '未填写')),
             f"\n各段最后一次窗口打开时长合计：{report['window_seconds'] / 60:.1f} 分钟。重试记录另存，不能累计凑时长。"]
    for row in report['stages']:
        lines += ['', '## ' + row['title'], '', f"来源版本：{row['revision']}；运行状态：{row['attempt'].get('status', '未开始')}"]
        for key, label in [('outcome', '结果'), ('goal', '理解的目标'), ('blocker', '卡住或无聊的位置'), ('change', '感受到的变化')]:
            lines += ['', label + '：' + str(row['answer'].get(key, '未填写'))]
    lines += ['', '## 整体反馈', '', '愿意继续玩：' + str(f.get('continue', '未填写')),
              '', '最希望改进：' + str(f.get('improvement', '未填写')),
              '', '尚缺：' + ('；'.join(report['missing']) or '无必填缺项；仍需人工判断目标理解和版本差异是否准确。'),
              '', '此记录不验证从想法到制作的创作流程，也不自动完成P2验收。']
    (folder / '试玩反馈.md').write_text('\n'.join(lines) + '\n')
    return report


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--session')
    parser.add_argument('--run-stage', type=int)
    parser.add_argument('--summarize', action='store_true')
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--new', action='store_true')
    args = parser.parse_args()
    if args.run_stage is not None or args.summarize:
        folder = session_path(args.session)
        result = run_stage(folder, args.run_stage) if args.run_stage is not None else summarize(folder)
        print(json.dumps(result, ensure_ascii=False))
        return
    SESSIONS.mkdir(parents=True, exist_ok=True)
    with (SESSIONS / 'launcher.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError('试玩记录窗口已经打开，请回到那个窗口。')
        recent = sorted(SESSIONS.glob('*/session.json'), reverse=True)
        drafts = [recent[0].parent] if recent and not read(recent[0].parent / 'feedback.json').get('submitted') else []
        folder = session_path(args.session) if args.session else (drafts[0] if drafts and not args.new else prepare())
        if read(folder / 'feedback.json').get('submitted'):
            raise ValueError('这份反馈已经完成，可直接打开其中的试玩反馈文件查看。')
        print('试玩记录：' + str(folder), flush=True)
        if not args.prepare_only:
            subprocess.run([b.GODOT, '--path', str(ROOT / 'app'), '--script',
                            str(ROOT / 'scripts/novice_playtest_ui.gd'), '--', str(folder)], check=True)


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print('试玩暂未打开：' + str(exc), file=sys.stderr)
        raise SystemExit(1)
