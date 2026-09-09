import * as T from './vendor/three.module.js';
// Original continuous terrain. Attack direction is expressed by enemy positions, not a fence.
export function createBattlefield(scene){
 const group=new T.Group();scene.add(group);
 const groundMat=new T.MeshStandardMaterial({color:0x28394d,roughness:.92,metalness:.08});
 groundMat.onBeforeCompile=shader=>{
  shader.vertexShader='varying vec2 fieldXZ;\n'+shader.vertexShader.replace('#include <begin_vertex>','#include <begin_vertex>\nfieldXZ=(modelMatrix*vec4(transformed,1.)).xz;');
  shader.fragmentShader=`varying vec2 fieldXZ;
  float fieldHash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
  float fieldNoise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(fieldHash(i),fieldHash(i+vec2(1,0)),f.x),mix(fieldHash(i+vec2(0,1)),fieldHash(i+1.),f.x),f.y);}
  `+shader.fragmentShader.replace('#include <color_fragment>',`#include <color_fragment>
   float grain=fieldNoise(fieldXZ*28.),broad=fieldNoise(fieldXZ*.19),detail=fieldNoise(fieldXZ*1.4);
   float path=1.-smoothstep(1.8,5.,abs(fieldXZ.x+sin(fieldXZ.y*.19)*1.2));
   diffuseColor.rgb*=.52+broad*.40+detail*.16+grain*.10+path*.12;`);
 };
 const ground=new T.Mesh(new T.PlaneGeometry(180,180),groundMat);ground.rotation.x=-Math.PI/2;ground.receiveShadow=true;ground.position.y=-.04;group.add(ground);
 const rockGeo=new T.DodecahedronGeometry(1,0),stone=new T.MeshStandardMaterial({color:0x182431,roughness:1});
 const rocks=new T.InstancedMesh(rockGeo,stone,48),dummy=new T.Object3D();
 for(let i=0;i<48;i++){const side=i%2?1:-1;dummy.position.set(side*(22+(i%7)*2.7),-.1,-34+(i%19)*2.8);dummy.rotation.set(i*.61,i*.73,i*.33);dummy.scale.set(1+i%4*.5,.5+i%3*.65,1+i%5*.3);dummy.updateMatrix();rocks.setMatrixAt(i,dummy.matrix);}rocks.castShadow=true;rocks.receiveShadow=true;group.add(rocks);
 const pillars=new T.InstancedMesh(new T.BoxGeometry(1,1,1),stone,18);
 for(let i=0;i<18;i++){const side=i%2?1:-1,h=3+i%5;dummy.position.set(side*(25+i%4*3),h/2,-35+i%9*4);dummy.rotation.set(0,i*.5,(i%3-1)*.13);dummy.scale.set(.7,h,.8);dummy.updateMatrix();pillars.setMatrixAt(i,dummy.matrix);}pillars.castShadow=true;group.add(pillars);
 // Distant broken steps and silhouettes fade naturally into the same scene fog.
 return {group,dispose(){scene.remove(group);ground.geometry.dispose();groundMat.dispose();rocks.dispose();pillars.dispose();rockGeo.dispose();pillars.geometry.dispose();stone.dispose();}};
}
