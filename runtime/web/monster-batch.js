import * as T from './vendor/three.module.js';
// Keep gameplay's individual joints; batch their visible pieces by geometry/material.
export function createMonsterBatch(scene){
 const records=new Map(),batches=new Map(),matrix=new T.Matrix4(),color=new T.Color();
 function add(group){const refs=[];group.traverse(o=>{if(!o.isMesh)return;const m=o.material,key=[o.geometry.uuid,m.type,m.emissive?.getHex()||0,m.emissiveIntensity||0,m.transparent,m.opacity].join(':');
  if(!batches.has(key)){const material=m.clone();material.color.setHex(0xffffff);const mesh=new T.InstancedMesh(o.geometry,material,1024);mesh.instanceMatrix.setUsage(T.DynamicDrawUsage);mesh.frustumCulled=false;mesh.castShadow=true;mesh.receiveShadow=true;mesh.count=0;scene.add(mesh);batches.set(key,mesh);}
  refs.push({object:o,batch:batches.get(key)});o.visible=false;
 });records.set(group,refs);}
 function remove(group){records.delete(group);}
 function update(){for(const batch of batches.values())batch.count=0;
  for(const [group,refs] of records){group.updateMatrixWorld(true);for(const {object,batch} of refs){let shown=true;for(let parent=object.parent;parent;parent=parent.parent){if(!parent.visible){shown=false;break;}if(parent===group)break;}if(!shown||batch.count>=1024)continue;
   const i=batch.count++;matrix.copy(object.matrixWorld);batch.setMatrixAt(i,matrix);color.copy(object.material.color);if(object.material.emissiveIntensity>1&&object.material.emissive?.getHex()===0xff497d)color.lerp(new T.Color(0xffe0eb),.65);batch.setColorAt(i,color);
  }}for(const batch of batches.values()){batch.instanceMatrix.needsUpdate=true;if(batch.instanceColor)batch.instanceColor.needsUpdate=true;}
 }
 return {add,remove,update,reset(){records.clear();for(const b of batches.values())b.count=0;}};
}
