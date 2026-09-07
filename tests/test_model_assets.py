import json
from pathlib import Path
import struct
import tempfile
import unittest
import model_assets as m

def model(uri=False):
    obj={'asset':{'version':'2.0'},'meshes':[{'primitives':[{'attributes':{'POSITION':0}}]}], 'accessors':[{'type':'VEC3','componentType':5126,'count':1,'bufferView':0}], 'buffers':[{'byteLength':12}], 'bufferViews':[{'buffer':0,'byteLength':12}]}
    if uri:obj['buffers'][0]['uri']='file:///private/file'
    data=json.dumps(obj).encode();data+=b' '*((-len(data))%4)
    return struct.pack('<III',0x46546c67,2,12+8+len(data)+20)+struct.pack('<II',len(data),0x4e4f534a)+data+struct.pack('<II',12,0x004e4942)+b'0'*12

class ModelAssetsTests(unittest.TestCase):
    def test_bound_project_save_dedupe_and_deleted_marker(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);(root/'.playseed-project.json').write_text(json.dumps({'id':'sample'}))
            first=m.save_model(root,'sample',model());second=m.save_model(root,'sample',model())
            self.assertEqual(first['id'],second['id']);self.assertEqual(len(list((root/'model-library').glob('*.glb'))),1)
            self.assertFalse((root/'game.json').exists())
            (root/'.playseed-project.json').unlink()
            with self.assertRaises(ValueError):m.save_model(root,'sample',model())
    def test_external_truncated_and_symlink_rejected(self):
        for data in [model(True), model()[:-1], b'not a model']:
            with self.assertRaises(ValueError):m.validate_glb(data)
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);(root/'.playseed-project.json').write_text(json.dumps({'id':'sample'}))
            (root/'other').mkdir();(root/'model-library').symlink_to(root/'other')
            with self.assertRaises(ValueError):m.save_model(root,'sample',model())
