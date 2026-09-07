"""User-selected game storage, separate from application logs and account state."""
from pathlib import Path
import os
import shutil
import uuid


def games_directory(api):
    settings = api.DATA / 'storage.json'
    if not settings.exists():
        return api.DATA / 'created_games'
    path = Path(api.read_json(settings)['games_directory'])
    if not path.is_absolute() or not path.is_dir():
        raise ValueError('游戏保存文件夹暂时无法访问，请连接磁盘或检查文件夹位置。')
    return path


def change_directory(request, job, api):
    value = request.get('parent_directory')
    if not isinstance(value, str) or not Path(value).is_absolute():
        raise ValueError('请选择一个有效的文件夹。')
    parent = Path(value).resolve(strict=True)
    if not parent.is_dir():
        raise ValueError('请选择文件夹。')
    source = games_directory(api).resolve()
    target = parent / 'Playseed游戏'
    if target == source:
        return {'storage_changed': True, 'summary': '已经使用这个保存位置。'}
    if target.is_relative_to(source):
        raise ValueError('请选择当前游戏文件夹以外的位置。')
    if target.exists():
        raise ValueError('所选位置已有“Playseed游戏”文件夹，请选择其他位置，避免覆盖文件。')
    staging = parent / ('.playseed-copy-' + uuid.uuid4().hex)
    try:
        api.status(job, 'copying', '正在复制已有游戏和版本，完成后切换保存位置…')
        if source.exists():
            shutil.copytree(source, staging, symlinks=True)
        else:
            staging.mkdir()
        api.cancelled(job)
        # Existing folders are never merged or overwritten.
        if target.exists():
            raise ValueError('目标文件夹已存在，未切换保存位置。')
        os.rename(staging, target)
        api.atomic_json(api.DATA / 'storage.json', {'games_directory': str(target)})
        return {'storage_changed': True, 'summary': '保存位置已更新。已有游戏已复制过去，后续修改保存在新位置；原文件保留作备份。'}
    finally:
        shutil.rmtree(staging, ignore_errors=True)
