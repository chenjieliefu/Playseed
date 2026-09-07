"""Bounded PCM audio library, independent of image attachments and immutable versions."""
import base64
import binascii
import hashlib
import io
import math
from pathlib import Path
import re
import struct
import wave

from creator import path_for

MAX_BYTES = 16 * 1024 * 1024
DEFAULT_LEVELS = {'music': 0.35, 'sfx': 0.7}
LICENSES = ['自有原创', 'CC0', '已获授权', '其他（见来源说明）']


def root_for(api, idea_id):
    from producer import game_root
    root = game_root(api, idea_id) / 'audio-library'
    if root.is_symlink() or (root / 'library.json').is_symlink():
        raise ValueError('声音素材目录无效。')
    return root


def library(api, idea_id):
    root = root_for(api, idea_id)
    return api.read_json(root / 'library.json') if (root / 'library.json').exists() else {
        'tracks': [], 'levels': dict(DEFAULT_LEVELS)}


def levels(value):
    if not isinstance(value, dict) or set(value) != set(DEFAULT_LEVELS):
        raise ValueError('请设置音乐和音效音量。')
    if any(type(n) not in (float, int) or not math.isfinite(n) or not 0 <= n <= 1 for n in value.values()):
        raise ValueError('音量需要在0到100%之间。')
    return dict(value)


def decode_wav(data):
    if not isinstance(data, bytes) or not 44 <= len(data) <= MAX_BYTES:
        raise ValueError('请选择16 MB以内的WAV声音。')
    if data[:4] != b'RIFF' or data[8:12] != b'WAVE' or struct.unpack('<I', data[4:8])[0] + 8 != len(data):
        raise ValueError('WAV文件不完整。')
    try:
        with wave.open(io.BytesIO(data), 'rb') as reader:
            channels, width, rate, count = reader.getnchannels(), reader.getsampwidth(), reader.getframerate(), reader.getnframes()
            if channels not in (1, 2) or width != 2 or not 8000 <= rate <= 48000 or not 0 < count <= rate * 180:
                raise ValueError('仅支持16位PCM、单/双声道、8～48 kHz、3分钟以内的WAV。')
            raw = reader.readframes(count)
            if len(raw) != count * channels * width or not any(raw):
                raise ValueError('声音数据缺失或完全静音。')
        # Canonical container removes embedded loop tags and arbitrary metadata.
        output = io.BytesIO()
        with wave.open(output, 'wb') as writer:
            writer.setnchannels(channels); writer.setsampwidth(2); writer.setframerate(rate); writer.writeframes(raw)
        canonical = output.getvalue()
        return canonical, {'duration': round(count / rate, 4), 'sample_rate': rate, 'channels': channels, 'frames': count}
    except (wave.Error, EOFError, struct.error) as exc:
        raise ValueError('请使用未压缩的16位PCM WAV声音。') from exc


def checked_track(root, track):
    ident = track.get('id', '')
    if not isinstance(ident, str) or not re.fullmatch('[a-f0-9]{32}', ident):
        raise ValueError('声音素材编号无效。')
    path = root / (ident + '.wav')
    if path.is_symlink() or not path.is_file() or path.stat().st_size > MAX_BYTES:
        raise ValueError('声音素材丢失或路径无效，请重新导入。')
    data = path.read_bytes()
    canonical, info = decode_wav(data)
    if canonical != data or hashlib.sha256(data).hexdigest()[:32] != ident:
        raise ValueError('声音素材已被修改，请重新导入。')
    if track.get('role') not in ['音效', '背景音乐']:
        raise ValueError('声音用途无效。')
    return data


def handle(request, job, api):
    ident = request.get('idea_id')
    idea_path = path_for(api, ident)
    idea = api.read_json(idea_path)
    if type(request.get('revision')) is not int or request['revision'] != idea['revision']:
        raise ValueError('方案已更新，请重新打开声音素材。')
    root = root_for(api, ident)
    manifest = library(api, ident)
    if request['action'] == 'set_audio_levels':
        manifest['levels'] = levels(request.get('levels'))
        summary = '声音默认音量已保存，将用于下一次制作或修改；当前游戏版本不变。'
        result = {}
    else:
        encoded = request.get('wav_base64')
        if not isinstance(encoded, str) or len(encoded) > (MAX_BYTES * 4 // 3 + 8):
            raise ValueError('声音文件过大或无效。')
        try:
            data, info = decode_wav(base64.b64decode(encoded, validate=True))
        except (binascii.Error, ValueError) as exc:
            raise ValueError(str(exc)) from exc
        name, role = request.get('name'), request.get('role')
        source, license_name = request.get('source'), request.get('license')
        if not isinstance(name, str) or not 0 < len(name.strip()) <= 120 or role not in ['音效', '背景音乐']:
            raise ValueError('请填写声音名称和用途。')
        if not isinstance(source, str) or not 0 < len(source.strip()) <= 1000 or license_name not in LICENSES:
            raise ValueError('请记录声音来源和授权依据。')
        asset_id = hashlib.sha256(data).hexdigest()[:32]
        existing = next((t for t in manifest['tracks'] if t['id'] == asset_id), None)
        if existing:
            checked_track(root, existing)
            return {'library_changed': True, 'audio_id': asset_id, 'summary': '该声音已在素材库中，保留原用途和来源记录。'}
        if len(manifest['tracks']) >= 24:
            raise ValueError('当前项目最多保存24个声音素材。')
        target = root / (asset_id + '.wav')
        if target.is_symlink():
            raise ValueError('声音文件路径无效。')
        manifest['tracks'].append(dict(id=asset_id, name=name.strip(), role=role, source=source.strip(),
                                       license=license_name, imported_at=api.now(), **info))
        result = {'audio_id': asset_id}
        summary = '声音已入库。试听后可添加到对话，制作或修改通过检查才会用于游戏。'
    api.cancelled(job)
    if api.read_json(idea_path)['revision'] != request['revision']:
        raise ValueError('方案已更新，本次声音设置未保存。')
    root.mkdir(parents=True, exist_ok=True)
    if request['action'] == 'import_audio':
        if target.exists() and target.read_bytes() != data:
            raise ValueError('同名声音文件不一致，请检查项目文件夹。')
        if not target.exists():
            with target.open('xb') as output: output.write(data)
    api.atomic_json(root / 'library.json', manifest)
    return {'library_changed': True, 'summary': summary, **result}


def prepare_runtime(api, idea_id, staging, restored=None):
    import shutil
    source = restored / 'audio' if restored else root_for(api, idea_id)
    manifest_path = source / ('manifest.json' if restored else 'library.json')
    if source.is_symlink() or manifest_path.is_symlink():
        raise ValueError('声音素材目录无效。')
    manifest = api.read_json(manifest_path) if manifest_path.exists() else {'tracks': [], 'levels': dict(DEFAULT_LEVELS)}
    manifest['levels'] = levels(manifest.get('levels', DEFAULT_LEVELS))
    if not isinstance(manifest.get('tracks'), list) or len(manifest['tracks']) > 24:
        raise ValueError('声音素材清单无效。')
    target = staging / 'audio'
    target.mkdir()
    for track in manifest['tracks']:
        (target / (track['id'] + '.wav')).write_bytes(checked_track(source, track))
    api.atomic_json(target / 'manifest.json', manifest)
    helper = Path(__file__).resolve().parent / 'runtime/playseed_audio.gd'
    if restored and (restored / helper.name).is_file(): helper = restored / helper.name
    shutil.copy2(helper, staging / helper.name)
    return manifest
