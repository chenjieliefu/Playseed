import base64
import copy
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import threading
import unittest
from unittest.mock import patch
from urllib.request import urlopen,Request
from urllib.error import HTTPError
import zipfile

import backend as b
import model_assets as m
import producer
import spatial
import resources
from scripts.preview_3d import make_server
from tests.test_spatial import WORLD,answer


def glb():
    vertices=[(-.5,0,-.5),(.5,0,-.5),(0,1,0),(.5,0,-.5),(.5,0,.5),(0,1,0),(.5,0,.5),(-.5,0,.5),(0,1,0),(-.5,0,.5),(-.5,0,-.5),(0,1,0)]
    binary=b''.join(struct.pack('<fff',*v) for v in vertices)
    meta={'asset':{'version':'2.0'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'mesh':0}],
      'meshes':[{'primitives':[{'attributes':{'POSITION':0},'material':0}]}],
      'materials':[{'pbrMetallicRoughness':{'baseColorFactor':[.6,.3,.2,1],'roughnessFactor':.8}}],
      'accessors':[{'type':'VEC3','componentType':5126,'count':12,'bufferView':0,'min':[-.5,0,-.5],'max':[.5,1,.5]}],
      'buffers':[{'byteLength':len(binary)}],'bufferViews':[{'buffer':0,'byteLength':len(binary)}]}
    return pack(meta,binary)


def pack(meta,binary):
    encoded=json.dumps(meta).encode();encoded+=b' '*((-len(encoded))%4)
    return struct.pack('<III',0x46546c67,2,28+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary


class ModelIntegrationTests(unittest.TestCase):
    def setUp(self):
        temp=tempfile.TemporaryDirectory();self.addCleanup(temp.cleanup)
        self.root=Path(temp.name).resolve();self.ident='e'*32
        change=patch.object(b,'DATA',self.root/'data');change.start();self.addCleanup(change.stop)
        self.project=self.root/'project';self.project.mkdir()
        self.idea=dict(id=self.ident,title='温室',revision=1,status='confirmed',confirmed_revision=1,
            project_directory=str(self.project),plan={})
        b.atomic_json(b.DATA/'ideas'/self.ident/'idea.json',self.idea)
        b.atomic_json(self.project/'.playseed-project.json',dict(id=self.ident))
        b.atomic_json(b.DATA/'ideas'/self.ident/'builds/0001.json',dict(state='planned'))
        self.job=self.root/'job';self.job.mkdir()
        self.data=glb();self.model_id=hashlib.sha256(self.data).hexdigest()
        self.request=dict(action='import_model',idea_id=self.ident,revision=1,name='小花台',purpose='替换中央花台外观',source='测试程序生成原创四面网格',license='自有原创',glb_base64=base64.b64encode(self.data).decode())

    def test_import_metadata_dedupe_and_explicit_edit(self):
        b.process_request(self.request,self.job)
        b.process_request({**self.request,'source':'不会覆盖已有来源'},self.job)
        self.assertEqual(m.library(self.project,self.ident)['models'][0]['source'],self.request['source'])
        result=b.process_request({**self.request,'action':'update_model_metadata','model_id':self.model_id,'name':'已改名'},self.job)
        self.assertEqual(result['model']['name'],'已改名')
        self.assertEqual(m.read_model(self.project,self.ident,self.model_id),self.data)
        self.assertFalse((self.project/'game.json').exists())

    def test_failed_stale_cancel_and_missing_provenance_do_not_save(self):
        for changes in [dict(revision=True),dict(revision=2),dict(source=''),dict(purpose=''),dict(license='未知'),dict(glb_base64='bad')]:
            with self.subTest(changes=changes),self.assertRaises(ValueError): b.process_request({**self.request,**changes},self.job)
        (self.job/'cancel').touch()
        with self.assertRaises(InterruptedError): b.process_request(self.request,self.job)
        self.assertFalse((self.project/'model-library').exists())

    def test_static_subset_rejects_unsupported_broken_binary_and_node_cycles(self):
        meta=m.validate_static(self.data)
        binary=self.data[-144:]
        variants=[]
        for extra in [dict(animations=[{}]),dict(textures=[{}]),dict(skins=[{}]),dict(extensions={'KHR_lights_punctual':{}})]: variants.append({**meta,**extra})
        broken=copy.deepcopy(meta);broken['nodes'][0]['children']=[0];variants.append(broken)
        broken=copy.deepcopy(meta);broken['accessors'][0]['byteOffset']=200;variants.append(broken)
        for candidate in variants:
            with self.assertRaises(ValueError): m.validate_static(pack(candidate,binary))
        bad=binary[:12]+struct.pack('<f',float('nan'))+binary[16:]
        with self.assertRaises(ValueError): m.validate_static(pack(meta,bad))

    def test_reopen_only_selected_hashed_file(self):
        b.process_request(self.request,self.job)
        server,url=make_server(self.project,self.ident,self.model_id)
        worker=threading.Thread(target=server.serve_forever,daemon=True);worker.start()
        try:
            base=url.split('?')[0]
            self.assertEqual(urlopen(base+'selected.glb').read(),self.data)
            for path in ['../model-library/'+self.model_id+'.glb','library.json','other.glb']:
                with self.assertRaises(HTTPError): urlopen(base+path)
            with self.assertRaises(HTTPError): urlopen(Request(base+'selected.glb',headers={'Host':'wrong'}))
            (self.project/'.playseed-project.json').unlink()
            with self.assertRaises(HTTPError): urlopen(base+'selected.glb')
        finally:
            server.shutdown();server.server_close();worker.join()

    def test_real_model_bounds_collisions_and_source_snapshot(self):
        b.process_request(self.request,self.job)
        world=copy.deepcopy(WORLD);world['obstacles'][0]['model_id']=self.model_id
        target=self.root/'runtime';target.mkdir()
        spatial.prepare(target,world,b);m.snapshot(b,self.ident,target,world)
        producer.check(b,target,self.job)
        self.assertIn('SPATIAL_CHECK_OK:',(self.job/'generated-run.log').read_text())
        data=m.library(self.project,self.ident)['models'][0]
        self.assertEqual(b.read_json(target/'models/library.json')['models'][0],data)
        (self.project/'model-library'/(self.model_id+'.glb')).write_bytes(b'changed')
        with self.assertRaises(ValueError): m.snapshot(b,self.ident,target,world)

    def test_versions_restore_old_source_and_export_glb(self):
        b.process_request(self.request,self.job)
        world=copy.deepcopy(WORLD);world['obstacles'][0]['model_id']=self.model_id
        request=dict(action='build_game',idea_id=self.ident,revision=1,game_revision=0,format=spatial.FORMAT)
        with patch.object(b,'request_structured',return_value=answer(world)),patch.object(producer,'check'),patch.object(producer,'render_preview'):
            b.process_request(request,self.job)
        b.process_request({**self.request,'action':'update_model_metadata','model_id':self.model_id,'source':'后来补充的来源'},self.job)
        with patch.object(producer,'check'),patch.object(producer,'render_preview'):
            b.process_request({**request,'action':'restore_created','game_revision':1,'restore_revision':1},self.job)
        root=self.project/'revisions/0002'
        self.assertEqual(b.read_json(root/'models/library.json')['models'][0]['source'],self.request['source'])
        self.assertEqual(m.library(self.project,self.ident)['models'][0]['source'],'后来补充的来源')
        archive=self.root/'model.zip'
        resources.export_project(dict(idea_id=self.ident,game_revision=2,export_path=str(archive)),self.job,b)
        with zipfile.ZipFile(archive) as result: self.assertEqual(result.read('models/'+self.model_id+'.glb'),self.data)

    def test_missing_source_and_symlink_block_model_usage(self):
        m.save_model(self.project,self.ident,self.data)
        world=copy.deepcopy(WORLD);world['obstacles'][0]['model_id']=self.model_id
        target=self.root/'stage';target.mkdir()
        with self.assertRaises(ValueError): m.snapshot(b,self.ident,target,world)
        file=self.project/'model-library'/(self.model_id+'.glb');file.unlink()
        outside=self.root/'outside.glb';outside.write_bytes(self.data);file.symlink_to(outside)
        with self.assertRaises(ValueError): m.read_model(self.project,self.ident,self.model_id)


if __name__=='__main__': unittest.main()
