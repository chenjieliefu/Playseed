"""Validated regular-grid animation settings; source PNGs remain immutable."""
import hashlib
import re
import resources
from creator import path_for


def validate(config, width, height):
    if not isinstance(config, dict):
        raise ValueError('请设置动画的行列、帧数和速度。')
    limits = {'columns': (1, 16), 'rows': (1, 16), 'first_frame': (0, 255),
              'frame_count': (2, 128), 'fps': (1, 30)}
    result = {}
    for key, (low, high) in limits.items():
        value = config.get(key)
        if type(value) is not int or not low <= value <= high:
            raise ValueError('动画设置无效：行列各1至16、帧数2至128、速度每秒1至30帧。')
        result[key] = value
    if type(config.get('loop')) is not bool:
        raise ValueError('请选择是否循环播放。')
    result['loop'] = config['loop']
    if type(config.get('align_bottom', False)) is not bool:
        raise ValueError('请选择是否对齐底部。')
    result['align_bottom'] = config.get('align_bottom', False)
    if width % result['columns'] or height % result['rows']:
        raise ValueError('图片尺寸不能按当前行列均分，请调整行列或换用规则排列的帧图片。')
    if result['first_frame'] + result['frame_count'] > result['columns'] * result['rows']:
        raise ValueError('起始帧与帧数超出图片网格，请调整后再预览。')
    result['frame_width'] = width // result['columns']
    result['frame_height'] = height // result['rows']
    if min(result['frame_width'], result['frame_height']) < 4:
        raise ValueError('单帧尺寸太小，请检查行列设置。')
    return result


def handle(request, job, api):
    idea_id = request.get('idea_id')
    path = path_for(api, idea_id)
    idea = api.read_json(path)
    if type(request.get('revision')) is not int or request['revision'] != idea['revision'] or idea['status'] != 'confirmed':
        raise ValueError('请先确认当前方案，再设置素材动画。')
    asset_id = request.get('asset_id')
    if not isinstance(asset_id, str) or not re.fullmatch('[a-f0-9]{32}', asset_id):
        raise ValueError('请选择当前项目已入库的图片。')
    manifest = resources.library(api, idea_id)
    asset = next((a for a in manifest['assets'] if a['id'] == asset_id), None)
    if not asset:
        raise ValueError('这张图片不属于当前项目。')
    root = resources.library_root(api, idea_id)
    source = root / (asset_id + '.png')
    if source.is_symlink() or not source.is_file() or source.stat().st_size > 8 * 1024 * 1024:
        raise ValueError('原图片不可用，请重新导入。')
    data = source.read_bytes()
    width, height = resources.validate_png(data)
    if hashlib.sha256(data).hexdigest()[:32] != asset_id:
        raise ValueError('原图片已变化，请重新导入。')
    if request['action'] == 'clear_asset_animation':
        asset.pop('animation', None)
        summary = '已取消这张图片的帧动画设置，原图和已有游戏版本保留。'
    else:
        asset['animation'] = validate(request.get('animation'), width, height)
        summary = '帧动画设置已保存。可在动画区预览，或通过对话用于下一版游戏；当前游戏尚未改变。'
    api.cancelled(job)
    if api.read_json(path)['revision'] != request['revision']:
        raise ValueError('方案已变化，动画设置未保存。')
    api.atomic_json(root / 'library.json', manifest)
    return {'library_changed': True, 'asset_id': asset_id, 'summary': summary}


def from_text(request, job, api):
    text = request.get('prompt', '')
    if not isinstance(text, str):
        raise ValueError('请用中文描述动画设置。')
    pattern = r'设置动画[：:]\s*「(.+?)」[，,]\s*(\d+)列[，,]\s*(\d+)行[，,]\s*从(\d+)格开始[，,]\s*(\d+)帧[，,]\s*每秒(\d+)帧[，,]\s*(循环|不循环)(?:[，,]\s*(底部对齐|保留原位))?'
    match = re.fullmatch(pattern, text.strip())
    if not match:
        raise ValueError('请按此格式设置：设置动画：「素材名」，4列，1行，从1格开始，4帧，每秒8帧，循环')
    name, columns, rows, first, count, fps, loop, alignment = match.groups()
    candidates = [a for a in resources.library(api, request.get('idea_id'))['assets'] if a['name'] == name or a['id'] == name]
    if len(candidates) != 1:
        raise ValueError('没有找到唯一的对应素材，请使用完整素材名或素材编号。')
    return handle({**request, 'action':'configure_asset_animation', 'asset_id':candidates[0]['id'],
                   'animation':{'columns':int(columns),'rows':int(rows),'first_frame':int(first)-1,
                                'frame_count':int(count),'fps':int(fps),'loop':loop=='循环',
                                'align_bottom': alignment == '底部对齐' if alignment else candidates[0].get('animation', {}).get('align_bottom', False)}},job,api)
