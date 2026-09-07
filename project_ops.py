"""Safe project pin, rename, and permanent deletion operations."""
from pathlib import Path
import os
import re
import shutil

from creator import path_for


MARKER = '.playseed-project.json'


def load_idea(request, api):
    idea_id = request.get('idea_id')
    idea_path = path_for(api, idea_id)
    if not idea_path.is_file():
        raise ValueError('项目不存在或已被删除。')
    idea = api.read_json(idea_path)
    revision = request.get('revision')
    if type(revision) is not int or revision != idea.get('revision'):
        raise ValueError('项目已在别处更新，请重新打开后再操作。')
    return idea_path, idea


def external_folder(idea, api):
    selected = idea.get('project_directory')
    if not isinstance(selected, str) or not selected:
        return None
    folder = Path(selected)
    if not folder.is_absolute():
        raise ValueError('项目文件夹路径无效。')
    resolved = folder.resolve(strict=False)
    protected = {Path('/'), Path.home().resolve(), api.ROOT.resolve(), api.DATA.resolve(), api.ROOT.parent.resolve()}
    if resolved in protected:
        raise ValueError('为保护本机文件，不能操作这个目录。')
    marker = resolved / MARKER
    if not marker.is_file():
        raise ValueError('无法确认这是 Playseed 独立项目文件夹，已停止操作以保护你的文件。')
    marker_data = api.read_json(marker)
    if marker_data.get('id') != idea.get('id'):
        raise ValueError('项目文件夹标记不匹配，已停止操作。')
    return resolved


def validate_name(value):
    if not isinstance(value, str):
        raise ValueError('请输入新项目名称。')
    name = value.strip()
    if not name or len(name) > 80 or name in {'.', '..'} or '/' in name or '\x00' in name:
        raise ValueError('项目名称需为 1～80 个字，不能包含斜杠。')
    return name


def handle(request, job, api):
    idea_path, idea = load_idea(request, api)
    action = request.get('action')
    if action == 'pin_project':
        idea['pinned'] = bool(request.get('pinned'))
        api.atomic_json(idea_path, idea)
        return {'idea': idea, 'summary': '项目已置顶。' if idea['pinned'] else '项目已取消置顶。'}

    if action == 'rename_project':
        name = validate_name(request.get('name'))
        old_folder = external_folder(idea, api)
        new_folder = None
        renamed = False
        if old_folder is not None:
            new_folder = old_folder.parent / name
            if new_folder != old_folder and new_folder.exists():
                raise ValueError('同一位置已有同名文件夹，请换一个名称。')
        original = dict(idea)
        try:
            if old_folder is not None and new_folder != old_folder:
                os.rename(old_folder, new_folder)
                renamed = True
            active_folder = new_folder if renamed else old_folder
            idea['project_name'] = name
            if active_folder is not None:
                idea['project_directory'] = str(active_folder)
                api.atomic_json(active_folder / MARKER, {'id': idea['id'], 'title': name})
            api.atomic_json(idea_path, idea)
        except BaseException:
            if renamed and new_folder.exists() and not old_folder.exists():
                os.rename(new_folder, old_folder)
                api.atomic_json(old_folder / MARKER, {'id': original['id'], 'title': original.get('title', '')})
            raise
        return {'idea': idea, 'summary': '项目和项目文件夹已一起重命名。'}

    if action == 'delete_project':
        folder = external_folder(idea, api)
        if folder is not None:
            shutil.rmtree(folder)
        else:
            # Compatibility cleanup for projects created before independent folders.
            candidates = [api.DATA / 'created_games' / idea['id'], api.DATA / 'projects' / idea['id']]
            try:
                from storage import games_directory
                candidates.append(games_directory(api) / idea['id'])
            except (ValueError, OSError):
                pass
            for candidate in set(candidates):
                if candidate.exists():
                    shutil.rmtree(candidate)
        shutil.rmtree(idea_path.parent)
        return {'project_deleted': True, 'deleted_id': idea['id'], 'summary': '项目记录和项目文件夹已永久删除。'}

    raise ValueError('未知的项目操作。')
