import * as T from './vendor/three.module.js';
import {SPELL_RULES} from './spell-rules.mjs';
export function createTargetPreview(scene){
 const group=new T.Group();group.visible=false;scene.add(group);
 const mat=new T.MeshBasicMaterial({color:0xffd88e,transparent:true,opacity:.65,depthWrite:false,side:T.DoubleSide,toneMapped:false});
 const fill=mat.clone();fill.opacity=.08;
 const ring=new T.Mesh(new T.RingGeometry(.98,1,128),mat);ring.rotation.x=-Math.PI/2;group.add(ring);
 const splashMat=mat.clone();splashMat.opacity=.24;const splash=new T.Mesh(new T.RingGeometry(.993,1,128),splashMat);splash.rotation.x=-Math.PI/2;group.add(splash);
 const disk=new T.Mesh(new T.CircleGeometry(1,96),fill);disk.rotation.x=-Math.PI/2;group.add(disk);
 const lane=new T.Mesh(new T.PlaneGeometry(1,1),fill);lane.rotation.x=-Math.PI/2;group.add(lane);
 const edges=[-1,1].map(()=>{const m=new T.Mesh(new T.BoxGeometry(.065,.04,1),mat);group.add(m);return m;});
 const marks=new T.InstancedMesh(new T.ConeGeometry(.18,.6,3),mat,24);marks.frustumCulled=false;group.add(marks);const pose=new T.Object3D();
 function update(selected,point,origin,altar,enabled){group.visible=enabled;if(!enabled)return;const rule=SPELL_RULES[selected],line=selected===3,ward=selected===7;
  mat.color.setHex([0xff8d42,0xb6b5ff,0x8be7ff,0xe3ba77,0xaeef91,0xb5df62,0xd2afff,0xffdc89][selected]);fill.color.copy(mat.color);splashMat.color.copy(mat.color);splash.visible=selected===0;splash.position.set(point.x,.08,point.z);splash.scale.setScalar(rule.splashRadius||1);
  const centre=ward?{x:(origin.x+altar.x)/2,z:(origin.z+altar.z)/2}:point;
  ring.position.set(centre.x,.08,centre.z);disk.position.set(centre.x,.075,centre.z);ring.scale.setScalar(line?rule.endRadius:rule.radius);disk.scale.copy(ring.scale);
  lane.visible=line;edges.forEach(o=>o.visible=line);marks.visible=line;
  if(line){const dx=point.x-origin.x,dz=point.z-origin.z,length=Math.hypot(dx,dz),yaw=Math.atan2(dx,dz);lane.position.set((point.x+origin.x)/2,.07,(point.z+origin.z)/2);lane.rotation.set(-Math.PI/2,0,yaw);lane.scale.set(rule.radius*2,length,1);
   edges.forEach((o,i)=>{const side=i?1:-1;o.position.set(lane.position.x+Math.cos(yaw)*rule.radius*side,.1,lane.position.z-Math.sin(yaw)*rule.radius*side);o.rotation.y=yaw;o.scale.z=length;});
   marks.count=Math.min(24,Math.floor(length/2));for(let i=0;i<marks.count;i++){const q=(i+1)/(marks.count+1);pose.position.set(origin.x+dx*q,.16,origin.z+dz*q);pose.rotation.set(Math.PI/2,yaw,0);pose.scale.setScalar(1);pose.updateMatrix();marks.setMatrixAt(i,pose.matrix);}marks.instanceMatrix.needsUpdate=true;
  }
 }
 return {update,reset(){group.visible=false;},get visible(){return group.visible;}};
}
