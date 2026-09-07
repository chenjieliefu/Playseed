"""Refresh visible validation shortcuts and version notes from saved manifests."""
import json
import shlex
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def update():
    folder = ROOT / '验收游戏'
    folder.mkdir(exist_ok=True)
    samples = {}
    for summary_path in sorted((ROOT / '.playseed/validation').glob('*/summary.json')):
        data = json.loads(summary_path.read_text())
        for item in data['results']:
            if item['build'] == 'passed':
                samples[item['slug']] = (summary_path.parent, item)
    for run, item in samples.values():
        project = Path(item['project_directory'])
        manifest = json.loads((project / 'game.json').read_text())
        name = item['genre'] + ' · ' + item['title']
        args = [sys.executable, str(ROOT / 'scripts/play_validation.py'), run.name, item['slug']]
        for suffix, extra in [('', []), (' · 最初版本', ['--revision', '1'])]:
            command = folder / (name + suffix + '.command')
            command.write_text('#!/bin/zsh\n' + shlex.join(args + extra) + '\n')
            command.chmod(0o755)
        target = project / 'revisions' / f"{manifest['current_revision']:04d}" / 'preview.png'
        link = folder / (name + ' · 预览.png')
        if link.is_symlink():
            link.unlink()
        if target.exists() and not link.exists():
            link.symlink_to(target)
        notes = [name, f"默认试玩第 {manifest['current_revision']} 版。另一个入口可试玩最初版本，方便比较。", '']
        for version in manifest['versions']:
            notes += [f"第 {version['revision']} 版", version['summary'],
                      '本版内容：' + '；'.join(version['implemented']),
                      '当前限制：' + '；'.join(version['limitations']), '']
        notes += ['以上功能描述来自生成记录；自动运行通过不等于所有玩法或难度已通过验收。',
                  '本批最新版本已完成自动输入通关及结算画面核对，尚未进行普通用户体验评估。']
        for outcome, label in [('won', '通关'), ('lost', '失败')]:
            report_path = run / 'playthrough-reports' / f"{item['slug']}-v{manifest['current_revision']}-{outcome}.json"
            if report_path.exists():
                report = json.loads(report_path.read_text())
                notes.append(label + '与重开检查：' + ('通过' if report.get('passed') else '未通过'))
                screenshot = Path(report['job']) / 'runtime' / 'end.png'
                if report.get('passed') and screenshot.exists():
                    end_link = folder / (name + ' · ' + label + '画面.png')
                    if end_link.is_symlink():
                        end_link.unlink()
                    if not end_link.exists():
                        end_link.symlink_to(screenshot)
        (folder / (name + ' · 版本说明.txt')).write_text('\n'.join(notes))
    (folder / '使用说明.txt').write_text(
        '双击中文 .command 文件即可试玩最新版本；带“最初版本”的入口用于比较，不会恢复或覆盖游戏。\n'
        '系统会打开终端，检查后显示隔离试玩窗口。方向和动作请看游戏内提示，R 键重开。\n'
        '预览图和版本说明随本次验收更新。验收样本未加入正式项目栏。\n'
        '原始工程位于 Playseed/.playseed/validation/，各版本保存在 revisions/ 内。\n'
        '验收结果与剩余问题以 docs/04-当前能力与边界.md 为准。\n')
    return folder


if __name__ == '__main__':
    print(update())
