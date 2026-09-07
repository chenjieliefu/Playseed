import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFExporter } from 'three/addons/exporters/GLTFExporter.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
const $ = id => document.getElementById(id), status = text => $('status').textContent = text;
let model, imported = false, loading = false;
try {
const scene = new THREE.Scene(); scene.background = new THREE.Color('#eef2e7');
const camera = new THREE.PerspectiveCamera(40, 1, .01, 10000);
const renderer = new THREE.WebGLRenderer({antialias:true}); renderer.setPixelRatio(Math.min(devicePixelRatio,2));
renderer.toneMapping = THREE.ACESFilmicToneMapping;
$('stage').prepend(renderer.domElement);
const controls = new OrbitControls(camera,renderer.domElement); controls.enableDamping = true;
scene.add(new THREE.HemisphereLight(0xffffff,0x67715e,2.5));
const light = new THREE.DirectionalLight(0xfff2df,3); light.position.set(4,8,5); scene.add(light);
scene.add(new THREE.GridHelper(40,40,0xacb99c,0xd5ddcc));
function dispose(root) { root?.traverse(n=>{n.geometry?.dispose(); const materials = Array.isArray(n.material)?n.material:[n.material]; for(const m of materials){if(!m)continue; for(const v of Object.values(m))if(v?.isTexture)v.dispose(); m.dispose();}}); }
function fit(){const box=new THREE.Box3().setFromObject(model), size=box.getSize(new THREE.Vector3()), center=box.getCenter(new THREE.Vector3());const r=Math.max(size.x,size.y,size.z,.1);controls.target.copy(center); camera.position.copy(center).add(new THREE.Vector3(r*1.7,r*1.2,r*2));camera.near=r/1000;camera.far=r*100;camera.updateProjectionMatrix();controls.update(); status(`当前尺寸：${size.x.toFixed(2)} × ${size.y.toFixed(2)} × ${size.z.toFixed(2)} 米 · ${imported?'本地模型预览':'简单道具，可导出'}`);}
function replace(next){if(model){scene.remove(model);dispose(model);}model=next;scene.add(model);fit();}
function create(){if(loading)return;imported=false;const dims=['width','height','depth'].map(id=>{const v=Number($(id).value); const n=Number.isFinite(v)?Math.min(20,Math.max(.1,v)) : 1;$(id).value=n;return n;});const geometry=$('shape').value==='sphere'?new THREE.SphereGeometry(.5,48,32):$('shape').value==='cylinder'?new THREE.CylinderGeometry(.5,.5,1,48):new THREE.BoxGeometry(1,1,1);geometry.scale(...dims);const mesh=new THREE.Mesh(geometry,new THREE.MeshStandardMaterial({color:$('color').value,roughness:Number($('roughness').value),metalness:Number($('metalness').value)}));mesh.position.y=dims[1]/2;replace(mesh);}
for(const id of ['shape','width','height','depth','color','roughness','metalness'])$(id).addEventListener('change',()=>{if(imported){status('本地模型保持原始材质。点击“重新制作简单道具”后可编辑参数。');return;}create();});
$('reset').onclick=create; $('fit').onclick=()=>model&&fit();
$('import').onclick=()=>$('file').click();
$('file').onchange=async()=>{const file=$('file').files[0];if(!file||loading)return;loading=true;status('正在读取模型…');try{
if(file.size>20*1024*1024)throw Error('请选择 20 MB 以内的模型。');
const bytes=await file.arrayBuffer(), view=new DataView(bytes);
if(bytes.byteLength<20||view.getUint32(0,true)!==0x46546c67||view.getUint32(4,true)!==2||view.getUint32(8,true)!==bytes.byteLength||view.getUint32(16,true)!==0x4e4f534a)throw Error('不是有效的 GLB 模型。');
const length=view.getUint32(12,true);if(length>bytes.byteLength-20)throw Error('模型内容不完整。');
const meta=JSON.parse(new TextDecoder().decode(new Uint8Array(bytes,20,length)));
if([...(meta.buffers||[]),...(meta.images||[])].some(x=>x.uri))throw Error('请先将模型和贴图打包到同一个 GLB，不能引用外部文件。');
if((meta.extensionsRequired||[]).some(x=>/draco|meshopt|basisu/i.test(x)))throw Error('暂不支持压缩模型，请导出未压缩的 GLB。');
const manager=new THREE.LoadingManager();manager.setURLModifier(url=>{if(!url.startsWith('blob:'))throw Error('模型引用了不支持的外部资源。');return url;});
const result=await new GLTFLoader(manager).parseAsync(bytes,'');const box=new THREE.Box3().setFromObject(result.scene), size=box.getSize(new THREE.Vector3());if(box.isEmpty()||![size.x,size.y,size.z].every(Number.isFinite)){dispose(result.scene);throw Error('模型没有可预览的几何体。');} imported=true;replace(result.scene);
}catch(e){status('未导入：'+(e.message||'模型读取失败')+' 原预览保留。');}finally{loading=false;$('file').value='';}};
$('save').onclick=async()=>{if(loading||!model)return;$('save').disabled=true;try{const bytes=await new GLTFExporter().parseAsync(model,{binary:true});const response=await fetch('./save-model',{method:'POST',headers:{'Content-Type':'model/gltf-binary'},body:bytes});const result=await response.json();if(!response.ok)throw Error(result.error||'保存失败');status(result.summary+' 回到App素材区点击刷新查看。');}catch(e){status('未保存：'+e.message);}finally{$('save').disabled=false;}};
$('export').onclick=async()=>{if(loading||!model)return;try{const bytes=await new GLTFExporter().parseAsync(model,{binary:true});const url=URL.createObjectURL(new Blob([bytes],{type:'model/gltf-binary'}));const link=document.createElement('a');link.href=url;link.download='Playseed-道具.glb';link.click();setTimeout(()=>URL.revokeObjectURL(url),30000);status('已交给浏览器保存，请在下载记录中查看；游戏版本不会自动更新。');}catch{status('导出失败，请重新打开模型后再试。');}};
new ResizeObserver(()=>{const w=$('stage').clientWidth,h=$('stage').clientHeight;renderer.setSize(w,h);camera.aspect=w/h;camera.updateProjectionMatrix();}).observe($('stage'));
renderer.domElement.addEventListener('webglcontextlost',e=>{e.preventDefault();status('图形预览已中断，请重新打开此页。');});
create();
if(new URLSearchParams(location.search).get('selected')==='1'){
 loading=true;status('正在重新打开项目模型…');
 fetch('./selected.glb').then(response=>{if(!response.ok)throw Error('项目模型已移动或改变');return response.arrayBuffer();}).then(bytes=>{
 const manager=new THREE.LoadingManager();manager.setURLModifier(url=>{if(!url.startsWith('blob:'))throw Error('不允许外部资源');return url;});
 return new GLTFLoader(manager).parseAsync(bytes,'');
 }).then(result=>{const bounds=new THREE.Box3().setFromObject(result.scene), size=bounds.getSize(new THREE.Vector3());if(bounds.isEmpty()||![size.x,size.y,size.z].every(Number.isFinite)){dispose(result.scene);throw Error('模型没有有效的可见尺寸');}imported=true;replace(result.scene);}).catch(error=>status('模型未打开：'+error.message)).finally(()=>{loading=false;});
}
renderer.setAnimationLoop(()=>{controls.update();renderer.render(scene,camera);});
addEventListener('pagehide',()=>{renderer.setAnimationLoop(null);dispose(model);controls.dispose();renderer.dispose();});
}catch(e){status('无法启动三维预览，请使用支持图形加速的浏览器。'+e.message);$('export').disabled=true;}
