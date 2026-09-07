"""Self-contained GLB storage, separate from 2D image assets and game revisions."""
import hashlib
import json
from pathlib import Path
import struct
import math
import re
import base64
import binascii
import shutil

LIMIT = 20 * 1024 * 1024

def validate_glb(data):
    if len(data) < 20 or len(data) > LIMIT:
        raise ValueError('请选择20 MB以内的完整GLB模型。')
    magic, version, length = struct.unpack_from('<III', data)
    if magic != 0x46546C67 or version != 2 or length != len(data):
        raise ValueError('模型文件头无效。')
    pos, chunks = 12, []
    while pos < length:
        if pos + 8 > length: raise ValueError('模型文件不完整。')
        size, kind = struct.unpack_from('<II', data, pos)
        if size % 4 or pos + 8 + size > length: raise ValueError('模型数据块无效。')
        chunks.append((kind, data[pos+8:pos+8+size])); pos += 8 + size
    if not chunks or chunks[0][0] != 0x4E4F534A: raise ValueError('模型缺少说明数据。')
    try:
        meta = json.loads(chunks[0][1])
        if meta.get('asset', {}).get('version') != '2.0' or not meta.get('meshes'):
            raise ValueError('模型缺少几何体。')
        if any(x.get('uri') is not None for x in meta.get('buffers', []) + meta.get('images', [])):
            raise ValueError('请将模型和贴图打包为一个GLB，不允许外部资源。')
        if any(any(word in x.lower() for word in ['draco','meshopt','basisu']) for x in meta.get('extensionsRequired', [])):
            raise ValueError('暂不支持压缩模型。')
        binary = next((b for kind,b in chunks[1:] if kind == 0x004E4942), b'')
        if len(meta.get('buffers', [])) != 1 or not 0 < meta['buffers'][0]['byteLength'] <= len(binary):
            raise ValueError('模型二进制数据不完整。')
        positions = []
        for mesh in meta['meshes']:
            for primitive in mesh.get('primitives', []):
                index = primitive.get('attributes', {}).get('POSITION')
                if type(index) is not int or not 0 <= index < len(meta.get('accessors', [])):
                    raise ValueError('模型缺少有效的顶点位置。')
                accessor = meta['accessors'][index]
                if accessor.get('type') != 'VEC3' or accessor.get('componentType') != 5126 or type(accessor.get('count')) is not int or not 0 < accessor['count'] <= 2000000:
                    raise ValueError('模型顶点格式或数量超出预览范围。')
                positions.append(index)
        if not positions: raise ValueError('模型没有可见几何体。')
        for view in meta.get('bufferViews', []):
            if view.get('buffer') != 0 or view.get('byteOffset',0) < 0 or view['byteLength'] < 0 or view.get('byteOffset',0)+view['byteLength'] > len(binary):
                raise ValueError('模型数据范围无效。')
    except (TypeError, KeyError, AttributeError, json.JSONDecodeError, UnicodeDecodeError):
        raise ValueError('模型结构无效。')
    return meta

def project_root(folder, idea_id):
    folder = Path(folder)
    if folder.is_symlink() or not folder.is_absolute(): raise ValueError('项目文件夹无效。')
    marker = folder / '.playseed-project.json'
    if marker.is_symlink() or not marker.is_file() or json.loads(marker.read_text()).get('id') != idea_id:
        raise ValueError('项目已移动、删除或标记不匹配，请回到App重新打开。')
    target = folder / 'model-library'
    if target.is_symlink(): raise ValueError('模型目录不能使用链接。')
    return target

def save_model(folder, idea_id, data):
    validate_glb(data)
    target = project_root(folder, idea_id)
    target.mkdir(exist_ok=True)
    asset_id = hashlib.sha256(data).hexdigest()
    file = target / (asset_id + '.glb')
    if file.is_symlink(): raise ValueError('模型路径无效。')
    if not file.exists() and len(list(target.glob('*.glb'))) >= 24: raise ValueError('当前最多保存24个模型。')
    # Exclusive write: identical hashes deduplicate without rewriting existing assets.
    if file.exists():
        if file.read_bytes() != data: raise ValueError('已有模型被修改，请检查项目文件夹。')
    else:
        with file.open('xb') as stream: stream.write(data)
    return {'id':asset_id, 'name':'道具-' + asset_id[:8], 'bytes':len(data), 'summary':'已保存到当前项目的3D素材库，尚未加入游戏。'}


def validate_static(data):
    """The initial in-game GLB subset is static triangle meshes with base colors."""
    meta = validate_glb(data)
    if meta.get('animations') or meta.get('skins') or meta.get('images') or meta.get('textures'):
        raise ValueError('本轮入场仅支持静态基础色GLB，贴图、骨骼和动画尚未接通。')
    def visit(value):
        if isinstance(value, dict):
            if value.get('extensions'): raise ValueError('本轮入场不支持GLB扩展，请导出标准静态网格。')
            for item in value.values(): visit(item)
        elif isinstance(value, list):
            for item in value: visit(item)
        elif isinstance(value, float) and (not math.isfinite(value) or abs(value)>1e6):
            raise ValueError('模型含异常数值。')
    visit(meta)
    if meta.get('extensionsRequired'): raise ValueError('模型需要尚未支持的扩展。')
    try:
        nodes=meta.get('nodes',[])
        if not 1 <= len(nodes) <= 128 or not 1 <= len(meta['meshes']) <= 64:
            raise ValueError('模型需要1至128个节点、最多64个网格。')
        parents={}
        for i,node in enumerate(nodes):
            if 'skin' in node or 'camera' in node or 'weights' in node:
                raise ValueError('模型必须只包含静态网格。')
            for key,count in [('translation',3),('rotation',4),('scale',3),('matrix',16)]:
                if key in node and (not isinstance(node[key],list) or len(node[key])!=count or any(type(v) not in (float,int) or not math.isfinite(v) or abs(v)>1e5 for v in node[key])):
                    raise ValueError('模型变换无效。')
            for child in node.get('children',[]):
                if type(child) is not int or not 0<=child<len(nodes) or child in parents: raise ValueError('模型节点关系无效。')
                parents[child]=i
            if 'mesh' in node and (type(node['mesh']) is not int or not 0<=node['mesh']<len(meta['meshes'])):
                raise ValueError('模型网格索引无效。')
        for i in range(len(nodes)):
            seen=set();at=i
            while at in parents:
                if at in seen: raise ValueError('模型节点存在循环。')
                seen.add(at);at=parents[at]
        scene_index=meta.get('scene',0)
        if type(scene_index) is not int or not 0<=scene_index<len(meta.get('scenes',[])): raise ValueError('模型缺少有效场景。')
        roots=meta['scenes'][scene_index].get('nodes',[])
        if not roots or len(set(roots))!=len(roots) or any(type(i) is not int or not 0<=i<len(nodes) or i in parents for i in roots): raise ValueError('模型场景根节点无效。')
        for material in meta.get('materials',[]):
            if material.get('alphaMode','OPAQUE')!='OPAQUE': raise ValueError('本轮不支持透明材质。')
            factor=material.get('pbrMetallicRoughness',{}).get('baseColorFactor',[1,1,1,1])
            if len(factor)!=4 or any(type(v) not in (int,float) or not 0<=v<=1 for v in factor) or factor[3]!=1: raise ValueError('基础色材质无效。')
        accessors=meta.get('accessors',[]);views=meta.get('bufferViews',[])
        pos=12;binary=b''
        while pos<len(data):
            size,kind=struct.unpack_from('<II',data,pos)
            if kind==0x004e4942: binary=data[pos+8:pos+8+size]
            pos+=8+size
        def values(index, components, types):
            if type(index) is not int or not 0<=index<len(accessors): raise ValueError('模型索引无效。')
            a=accessors[index]
            if a.get('sparse') or a.get('componentType') not in types or a.get('type')!=components:
                raise ValueError('模型顶点格式不支持。')
            vi=a.get('bufferView');count=a.get('count')
            if type(vi) is not int or not 0<=vi<len(views) or type(count) is not int or not 0<count<=300000:
                raise ValueError('模型数据或数量超出范围。')
            view=views[vi];fmt={5121:'B',5123:'H',5125:'I',5126:'f'}[a['componentType']]
            width=3 if components=='VEC3' else 1;unit=struct.calcsize(fmt)*width
            stride=view.get('byteStride',unit);offset=a.get('byteOffset',0)
            if type(offset) is not int or offset<0 or type(stride) is not int or stride<unit or stride>252 or offset+(count-1)*stride+unit>view['byteLength']:
                raise ValueError('模型数据越界。')
            return [struct.unpack_from('<'+fmt*width,binary,view.get('byteOffset',0)+offset+i*stride) for i in range(count)]
        total=0
        for mesh in meta['meshes']:
            for primitive in mesh.get('primitives',[]):
                if primitive.get('mode',4)!=4 or primitive.get('targets'): raise ValueError('只支持静态三角面网格。')
                vertices=values(primitive['attributes']['POSITION'],'VEC3',[5126]);total+=len(vertices)
                if total>200000 or any(not math.isfinite(v) or abs(v)>1e5 for vertex in vertices for v in vertex): raise ValueError('模型顶点数量或坐标超出范围。')
                if 'indices' in primitive:
                    indices=values(primitive['indices'],'SCALAR',[5121,5123,5125])
                    if len(indices)%3 or any(v[0]>=len(vertices) for v in indices): raise ValueError('三角面索引越界。')
                elif len(vertices)%3: raise ValueError('三角面不完整。')
        instances=sum(sum(accessors[p['attributes']['POSITION']]['count'] for p in meta['meshes'][node['mesh']]['primitives']) for node in nodes if 'mesh' in node)
        if not 0 < instances <= 200000: raise ValueError('模型实例的顶点总量超出20万范围。')
        return meta
    except (TypeError,KeyError,IndexError,struct.error) as exc:
        raise ValueError('模型静态网格结构无效。') from exc


def library(folder, idea_id):
    target=project_root(folder,idea_id)
    path=target/'library.json'
    if path.is_symlink(): raise ValueError('模型清单不能使用链接。')
    info=json.loads(path.read_text()) if path.exists() else {'models':[]}
    records={item['id']:item for item in info['models']}
    for path in sorted(target.glob('*.glb')):
        if re.fullmatch('[0-9a-f]{64}',path.stem) and path.stem not in records:
            records[path.stem]=dict(id=path.stem,name='道具-'+path.stem[:8],purpose='',source='',license='',bytes=path.stat().st_size)
    return {'models':list(records.values())}


def read_model(folder,idea_id,asset_id):
    if not isinstance(asset_id,str) or not re.fullmatch('[0-9a-f]{64}',asset_id): raise ValueError('模型编号无效。')
    path=project_root(folder,idea_id)/(asset_id+'.glb')
    if path.is_symlink() or not path.is_file() or path.stat().st_size>LIMIT: raise ValueError('模型缺失或路径无效。')
    data=path.read_bytes()
    if hashlib.sha256(data).hexdigest()!=asset_id: raise ValueError('模型内容已改变，请重新导入。')
    validate_glb(data)
    return data


def metadata(request):
    from creator import bounded_text
    result={key:bounded_text(request.get(key,''),cap).strip() for key,cap in [('name',48),('purpose',300),('source',1000)]}
    if request.get('license') not in ['自有原创','CC0','已获授权','其他（见来源说明）']: raise ValueError('请选择授权依据。')
    return dict(result,license=request['license'])


def handle(request,job,api):
    import producer
    from creator import path_for
    ident=request['idea_id'];idea=api.read_json(path_for(api,ident))
    if type(request.get('revision')) is not int or request['revision']!=idea['revision']: raise ValueError('方案已更新，请重新打开模型入口。')
    folder=producer.game_root(api,ident);info=metadata(request)
    if request['action']=='import_model':
        raw=request.get('glb_base64','')
        if not isinstance(raw,str) or len(raw)>LIMIT*4//3+4: raise ValueError('模型超过20 MB。')
        try: data=base64.b64decode(raw,validate=True)
        except (binascii.Error,ValueError): raise ValueError('模型文件数据无效。')
        validate_static(data);asset_id=hashlib.sha256(data).hexdigest()
    else:
        asset_id=request.get('model_id');data=read_model(folder,ident,asset_id)
    current=library(folder,ident)
    api.cancelled(job)
    if api.read_json(path_for(api,ident))['revision']!=idea['revision']: raise ValueError('方案已变化，未保存模型资料。')
    if request['action']=='import_model': save_model(folder,ident,data)
    old=next((item for item in current['models'] if item['id']==asset_id),None)
    # Reimport cannot silently replace provenance; explicit editing can.
    if old and old.get('source') and request['action']=='import_model': info={key:old[key] for key in info}
    record=dict(id=asset_id,bytes=len(data),updated_at=api.now(),**info)
    current['models']=[item for item in current['models'] if item['id']!=asset_id]+[record]
    api.atomic_json(project_root(folder,ident)/'library.json',current)
    return dict(model=record,summary='模型资料已保存；添加到对话并制作新版本后才会入场。')


def snapshot(api,ident,project,world):
    import producer
    folder=producer.game_root(api,ident)
    if (project/'models').is_symlink(): raise ValueError('模型快照目录无效。')
    shutil.rmtree(project/'models',ignore_errors=True)
    ids={o.get('model_id') for o in world['obstacles'] if o.get('model_id')}
    if not ids: return
    records={item['id']:item for item in library(folder,ident)['models']}
    selected=[]
    for asset_id in sorted(ids):
        record=records.get(asset_id)
        if not record: raise ValueError('场景引用的模型尚未入库。')
        metadata(record)
        data=read_model(folder,ident,asset_id);validate_static(data)
        target=project/'models';target.mkdir(exist_ok=True)
        (target/(asset_id+'.glb')).write_bytes(data)
        selected.append(record)
    api.atomic_json(project/'models/library.json',dict(models=selected))


def for_project(api,ident):
    import producer
    folder=producer.game_root(api,ident)
    if not (folder/'model-library').exists() and not (folder/'model-library').is_symlink(): return {'models':[]}
    return library(folder,ident)
