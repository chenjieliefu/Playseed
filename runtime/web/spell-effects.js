import {SPELL_RULES} from './spell-rules.mjs';
import * as T from './vendor/three.module.js';
import {impactMaterial,accretionMaterial} from './impact-material.mjs';
import {createNatureSigilMaterial} from './vendor/elemental/src/materials/NatureSigilMaterial.js';
import {createCosmicRingMaterial} from './vendor/elemental/src/materials/CosmicShockMaterial.js';
import {createBloomState,createPetalMaterial,createBloomCoreMaterial} from './vendor/elemental/src/materials/ArcaneBloomMaterial.js';
import {createPetalGeometry} from './vendor/elemental/src/assets/GrowthGeometry.js';
import {createVenomCrystalMaterial} from './vendor/elemental/src/materials/VenomCrystalMaterial.js';
import {patchOnBeforeCompile} from './vendor/elemental/src/utils/shaderPatch.js';
import {frame} from './vendor/elemental/src/core/FrameUniforms.js';
const colors=[0xff7931,0xa896ff,0x82e9ff,0xcda975,0xa4ef82,0xbe77ff,0xe9b9ff,0xffdd91];
const env={registerShadowCasterWithPatch:(m,fn)=>patchOnBeforeCompile(m,fn)};
export function createSpellEffects(scene,anchor={x:0,z:0}){
 let clock=0;const active=[],dummy=new T.Object3D();
 const plane=new T.PlaneGeometry(1,1),annulus=new T.RingGeometry(.001,1,72,12),sphere=new T.SphereGeometry(1,20,12),grain=new T.IcosahedronGeometry(1,0),petals=createPetalGeometry({petals:40,along:9,across:5}),ring=new T.TorusGeometry(1,.022,5,64);
 const sigilMat=createNatureSigilMaterial(),sigil=new T.Mesh(plane,sigilMat);sigil.rotation.x=-Math.PI/2;sigil.position.set(anchor.x,.13,anchor.z);sigil.scale.setScalar(6);scene.add(sigil);sigil.visible=false;
 function remove(e){scene.remove(e.group);e.group.traverse(o=>{if(o.isInstancedMesh)o.dispose();});for(const m of e.materials){m.userData.depth?.dispose();m.dispose();}for(const g of e.geometries)g.dispose();}
 function cast(index,point,origin={x:0,y:2.5,z:0},extra={}){
  const rule=SPELL_RULES[index],limit=rule.limit;
  const siblings=active.filter(e=>e.index===index);if(siblings.length>=limit){const old=siblings[0];remove(old);active.splice(active.indexOf(old),1);}
  if(active.length>=32){const old=active.find(e=>![4,5,6,7].includes(e.index));if(old){remove(old);active.splice(active.indexOf(old),1);}}
  const life=rule.duration;
  const e={index,group:new T.Group(),age:0,life,materials:[],geometries:[],updates:[]};scene.add(e.group);active.push(e);
  const own=m=>{e.materials.push(m);return m;},basic=(c,opacity=1)=>own(new T.MeshBasicMaterial({color:c,transparent:true,opacity,depthWrite:false,blending:T.AdditiveBlending,toneMapped:false,side:T.DoubleSide}));
  const add=(g,m,x=point.x,y=.1,z=point.z)=>{const o=new T.Mesh(g,m);o.position.set(x,y,z);o.frustumCulled=false;e.group.add(o);return o;};
  function particles(color,count,animate){const mat=basic(color,.8),cloud=new T.InstancedMesh(grain,mat,count);cloud.frustumCulled=false;cloud.instanceMatrix.setUsage(T.DynamicDrawUsage);e.group.add(cloud);e.updates.push((t,f)=>{mat.opacity=Math.min(1,(1-f)*3)*.8;for(let i=0;i<count;i++){dummy.position.set(point.x,.2,point.z);dummy.rotation.set(0,0,0);dummy.scale.setScalar(.045);animate(dummy,i,t,f);dummy.updateMatrix();cloud.setMatrixAt(i,dummy.matrix);}cloud.instanceMatrix.needsUpdate=true;});}
  function plume(kind,size,delay=0,height=1.8){const m=own(impactMaterial(kind,size)),o=add(plane,m,point.x,height,point.z);e.updates.push((t,f)=>{o.visible=t>delay;m.uniforms.age.value=Math.max(0,t-delay);m.uniforms.fade.value=Math.min(1,Math.max(0,(life-t)*2.5));});}
  function shock(reach,delay=.0){const m=own(createCosmicRingMaterial()),o=add(annulus,m);o.rotation.x=-Math.PI/2;e.updates.push(t=>{const f=Math.max(0,(t-delay)/.6);o.visible=t>=delay;m.userData.sync({reach,front:Math.min(1,f)*reach,fade:Math.max(0,1-f),seed:index});m.uniforms.uColorBody.value.setHex(colors[index]);m.uniforms.uGlow.value=.8;});}
  function beam(points,color=colors[index]){const vs=points.map(p=>new T.Vector3(p.x,p.y??.9,p.z)),curve=new T.CurvePath();for(let i=1;i<vs.length;i++)curve.add(new T.LineCurve3(vs[i-1],vs[i]));const g=new T.TubeGeometry(curve,Math.max(12,vs.length*3),.10,5,false);e.geometries.push(g);const m=basic(color,1);add(g,m,0,0,0);e.updates.push((t,f)=>{m.opacity=(1-f)*(Math.sin(t*85)>.0?1:.45);});}
  if(index===0){
   // A solid, faceted blade descends point-first, then drives a molten impact outward.
   const sword=new T.Group();sword.position.set(point.x,16,point.z);sword.rotation.y=.45;e.group.add(sword);
   const shape=new T.Shape();shape.moveTo(0,0);shape.lineTo(-.65,1.4);shape.lineTo(-.48,6.1);shape.lineTo(.48,6.1);shape.lineTo(.65,1.4);shape.closePath();
   const bladeGeo=new T.ExtrudeGeometry(shape,{depth:.3,bevelEnabled:true,bevelSegments:1,steps:1,bevelSize:.08,bevelThickness:.06});e.geometries.push(bladeGeo);
   const steel=own(new T.MeshStandardMaterial({color:0x23120c,emissive:0xe63c06,emissiveIntensity:.18,metalness:.8,roughness:.28}));
   const blade=new T.Mesh(bladeGeo,steel);sword.add(blade);const aura=new T.Mesh(bladeGeo,basic(0xff7415,.22));aura.scale.set(1.15,1.015,1.2);sword.add(aura);
   const barGeo=new T.BoxGeometry(1,1,1);e.geometries.push(barGeo);
   for(const [x,y,w,h,d,c] of [[0,6.25,3.2,.42,.65,0xef8b25],[0,7.25,.35,1.7,.38,0x562016],[0,8.15,.65,.42,.55,0xffb644],[0,3.5,.065,4.5,.37,0xffd780]]){const o=new T.Mesh(barGeo,own(new T.MeshStandardMaterial({color:c,emissive:c,emissiveIntensity:c===0xffd780?1.6:.2,metalness:.65,roughness:.3})));o.position.set(x,y,.12);o.scale.set(w,h,d);sword.add(o);}
   const flameGeo=new T.PlaneGeometry(2.7,7.2);e.geometries.push(flameGeo);
   const flameMat=own(new T.ShaderMaterial({transparent:true,depthWrite:false,side:T.DoubleSide,blending:T.AdditiveBlending,uniforms:{age:{value:0},fade:{value:1}},vertexShader:'varying vec2 p;void main(){p=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}',fragmentShader:'varying vec2 p;uniform float age,fade;float h(vec2 q){return fract(sin(dot(q,vec2(127.1,311.7)))*43758.5453);}float n(vec2 q){vec2 i=floor(q),f=fract(q);f=f*f*(3.-2.*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+1.),f.x),f.y);}void main(){float noise=n(p*vec2(8.,15.)-vec2(age*.3,age*7.));float x=abs(p.x-.5),width=.12+.2*noise;float edge=(1.-smoothstep(width,width+.11,x))*smoothstep(0.,.07,p.y)*(1.-smoothstep(.85,1.,p.y));float vein=pow(1.-abs(sin((p.y+noise*.12)*48.)),16.);vec3 c=mix(vec3(1.5,.08,.002),vec3(2.4,.9,.10),noise*.7+vein*.3);gl_FragColor=vec4(c,edge*(.35+noise*.45)*fade);}'}));
   const flame=new T.Mesh(flameGeo,flameMat);flame.position.set(0,3.5,.48);sword.add(flame);e.updates.push(t=>{flameMat.uniforms.age.value=t;flameMat.uniforms.fade.value=Math.min(1,(life-t)*2);});
   e.updates.push(t=>{sword.position.y=t<rule.impact?16*Math.pow(1-t/rule.impact,2):-.35;const fade=Math.min(1,(life-t)*2);sword.scale.setScalar(Math.max(.001,fade));aura.material.opacity=(.17+Math.sin(t*21)*.07)*fade;});
   const lava=own(new T.ShaderMaterial({transparent:true,depthWrite:false,side:T.DoubleSide,uniforms:{age:{value:0},fade:{value:1}},vertexShader:'varying vec2 p;void main(){p=uv*2.-1.;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}',fragmentShader:'varying vec2 p;uniform float age,fade;void main(){float r=length(p),a=atan(p.y,p.x),flow=sin(p.x*19.+sin(p.y*15.-age*2.))*sin(p.y*23.+age);float cracks=pow(1.-abs(flow),15.);float rim=exp(-pow((r-.83)*24.,2.));vec3 c=mix(vec3(.045,.013,.008),vec3(2.1,.30,.01),cracks);c+=vec3(1.,.28,.02)*rim;gl_FragColor=vec4(c,(1.-smoothstep(.9,1.,r))*fade);}'}));
   const pool=add(plane,lava,point.x,.07,point.z);pool.rotation.x=-Math.PI/2;e.updates.push(t=>{pool.visible=t>=rule.impact;pool.scale.setScalar(rule.radius*2*Math.min(1,Math.max(0,t-rule.impact)*5));lava.uniforms.age.value=t;lava.uniforms.fade.value=Math.min(1,(life-t)*1.4);});
   plume(0,14,rule.impact,2.3);shock(rule.splashRadius,rule.impact);
   particles(0xffa536,96,(o,i,t)=>{const age=Math.max(0,t-rule.impact),a=i*2.4;const target=i%2?extra.targets?.[i%Math.max(1,extra.targets?.length||0)]:null,q=Math.min(1,age/.8);const reach=rule.radius*(.4+(i%7)/10);o.position.set(point.x+(target?(target.x-point.x)*q:Math.sin(a)*reach*q),.3+Math.sin(q*Math.PI)*(2+i%5),point.z+(target?(target.z-point.z)*q:Math.cos(a)*reach*q));o.scale.setScalar(t<rule.impact||age>.95?0:.06+(i%4)*.035);});
  }else if(index===1){
   // Lightning follows actual chain targets, with a branching silhouette.
   if(!extra.tint){for(let j=0;j<3;j++)beam([{x:point.x,y:8-j*1.8,z:point.z},{x:point.x+(j%2?1:-1)*1.5,y:7-j*1.8,z:point.z+.5},{x:point.x+(j%2?1:-1)*3.2,y:6-j*1.8,z:point.z+1}],0x796eff);beam([{x:point.x,y:12,z:point.z},{x:point.x-.7,y:8,z:point.z+.2},{x:point.x+.6,y:5,z:point.z-.2},{x:point.x-.3,y:3,z:point.z},{...point,y:.3}],0xc5d9ff);shock(rule.radius);particles(0xdedfff,32,(o,i,t,f)=>{const a=i*2.4,r=t*(4+i%5);o.position.set(point.x+Math.sin(a)*r,.4+t*3,point.z+Math.cos(a)*r);o.scale.set(.045,.22*(1-f),.045);});}
   const targets=extra.targets?.length?extra.targets:[{...point,y:.4}];const path=extra.tint?[origin,...targets]:[{...targets[0],y:14},...targets];
   for(let k=0;k<path.length-1;k++){const a=path[k],b=path[k+1],pts=[];for(let i=0;i<=9;i++){const f=i/9,j=i&&i<9?.34:0;pts.push({x:a.x+(b.x-a.x)*f+Math.sin(i*4.7+k)*j,y:(a.y??1)+((b.y??1)-(a.y??1))*f+Math.cos(i*2.4)*j,z:a.z+(b.z-a.z)*f});}beam(pts,extra.tint??(k?0xc3a8ff:0xeae4ff));}
  }else if(index===2){
   // Freeze spreads as a flat snow sigil, not the venom skill's crystal geometry.
   const mat=own(new T.ShaderMaterial({transparent:true,depthWrite:false,side:T.DoubleSide,blending:T.AdditiveBlending,uniforms:{fade:{value:1}},vertexShader:'varying vec2 p;void main(){p=uv*2.-1.;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}',fragmentShader:'varying vec2 p;uniform float fade;void main(){float r=length(p),a=atan(p.y,p.x);float arms=pow(abs(cos(a*3.)),42.)*(1.-smoothstep(.7,1.,r));float rings=exp(-pow((r-.77)*60.,2.));float branches=pow(abs(cos(a*9.+r*17.)),32.)*arms;float alpha=(arms*.6+rings*.8+branches)*fade;gl_FragColor=vec4(.35,.8,1.,alpha);}'}));const frost=add(plane,mat,point.x,.09,point.z);frost.rotation.x=-Math.PI/2;
   e.updates.push((t,f)=>{frost.scale.setScalar(rule.radius*2*Math.min(1,t*4));mat.uniforms.fade.value=1-f;});
   shock(rule.radius);const iceGeo=new T.ConeGeometry(.34,1,5);e.geometries.push(iceGeo);const ice=new T.InstancedMesh(iceGeo,own(new T.MeshStandardMaterial({color:0xb3e5ff,emissive:0x2474a3,emissiveIntensity:.8,metalness:.45,roughness:.16,transparent:true,opacity:.8})),24);ice.frustumCulled=false;e.group.add(ice);e.updates.push((t,f)=>{for(let i=0;i<24;i++){const a=i*2.4,r=2+i%4*1.6,g=Math.min(1,Math.max(0,t-r*.025)*8)*Math.min(1,(1-f)*4),height=(1+i%5*.45)*g;dummy.position.set(point.x+Math.sin(a)*r,height*.5,point.z+Math.cos(a)*r);dummy.rotation.set(Math.cos(a)*.3,0,Math.sin(a)*.3);dummy.scale.set(g,height,g);dummy.updateMatrix();ice.setMatrixAt(i,dummy.matrix);}ice.instanceMatrix.needsUpdate=true;});
   particles(0xcef5ff,40,(o,i,t,f)=>{const a=i*2.4,r=(i%5)*1.5;o.position.set(point.x+Math.sin(a)*r,.3+t*(.6+i%3*.2),point.z+Math.cos(a)*r);o.scale.setScalar(.065*(1-f));});
  }else if(index===3){
   // Earth ruptures forward as a line of heavy slabs.
   const g=new T.ConeGeometry(.65,1,5);e.geometries.push(g);const mat=own(new T.MeshStandardMaterial({color:0x605348,emissive:0x6b2712,emissiveIntensity:.15,roughness:.82,flatShading:true}));
   const length=Math.hypot(point.x-origin.x,point.z-origin.z),count=Math.max(2,Math.ceil(length/2.5));
   for(let i=0;i<count;i++){const f=(i+1)/count,x=origin.x+(point.x-origin.x)*f,z=origin.z+(point.z-origin.z)*f,o=add(g,mat,x,0,z);o.rotation.z=(i%2?1:-1)*.22;e.updates.push(t=>{const grow=Math.min(1,Math.max(0,t-i*.045)*9),fade=Math.min(1,(life-t)*3),height=(2.4+i/count*2.2)*grow*fade;o.scale.set(2.1,height,2.1);o.position.y=height*.5;});}
   // The same faceted earth spike grows larger at the end of the rupture.
   const tip=add(g,mat,point.x,0,point.z);tip.name='earth-finisher';
   tip.rotation.y=Math.atan2(point.x-origin.x,point.z-origin.z)+.35;
   e.updates.push(t=>{const rise=Math.min(1,Math.max(0,t-count*.045)*7)*Math.min(1,(life-t)*3),height=7.2*rise;tip.scale.set(3.4*rise,height,3.4*rise);tip.position.y=height*.5;});
   plume(1,10,.15,1.6);shock(rule.endRadius,.55);
   particles(0xc3b295,40,(o,i,t,f)=>{const q=(i%6+1)/6,a=i*2.4,r=t*.9;o.position.set(origin.x+(point.x-origin.x)*q+Math.sin(a)*r,.2+t*1.7-1.3*t*t,origin.z+(point.z-origin.z)*q+Math.cos(a)*r);o.scale.setScalar(.1*(1-f));});
  }else if(index===4){
   const state=createBloomState();state.uCentre.value.set(point.x,2.6,point.z);state.uFacing.value.set(0,1,0);state.uScale.value=2.6;state.uSeed.value=clock;
   add(petals,own(createPetalMaterial(env,state)),0,0,0);const core=add(sphere,own(createBloomCoreMaterial(state)),point.x,2.6,point.z);core.scale.setScalar(.7);
   const g=new T.CylinderGeometry(.25,.55,2.5,8);e.geometries.push(g);add(g,own(new T.MeshStandardMaterial({color:0x3f774f,roughness:.7})),point.x,1.25,point.z);
   particles(0xb8efaa,36,(o,i,t,f)=>{const a=i*2.4+t,r=2+Math.sin(i)*.7;o.position.set(point.x+Math.sin(a)*r,.5+(i%8)*.35,point.z+Math.cos(a)*r);o.scale.set(.05,.16,.05);});shock(3.5);
   const reach=add(ring,basic(0xa4ef82,.25));reach.rotation.x=-Math.PI/2;reach.scale.setScalar(rule.radius);
   e.updates.push((t,f)=>{state.uOpen.value=Math.min(1,t*2.8);state.uCharge.value=.5+Math.max(0,Math.sin(t*9))*.5;state.uFade.value=Math.min(1,(1-f)*5);});
  }else if(index===5){
   const g=new T.CylinderGeometry(0,.45,2,6),count=14;e.geometries.push(g);
   for(const name of ['aSeed','aBirth','aFlow'])g.setAttribute(name,new T.InstancedBufferAttribute(new Float32Array(Array.from({length:count},(_,i)=>name==='aSeed'?i*.17:1)),1));
   const m=own(createVenomCrystalMaterial(env));m.userData.uniforms.uCore.value.set(point.x,.4,point.z);m.userData.uniforms.uGlow.value=.5;m.userData.uniforms.uCoreGlow.value=.3;
   const crystals=new T.InstancedMesh(g,m,count);crystals.frustumCulled=false;e.group.add(crystals);
   e.updates.push((t,f)=>{m.userData.uniforms.uBirthGlow.value=.3*Math.exp(-8*t);for(let i=0;i<count;i++){const a=i*2.4,r=rule.radius*.82+Math.sin(i)*.45,scale=Math.min(1,t*6)*Math.min(1,(1-f)*5);dummy.position.set(point.x+Math.sin(a)*r,scale*(.18+i%3*.10),point.z+Math.cos(a)*r);dummy.rotation.set(Math.cos(a)*.4,0,Math.sin(a)*.4);dummy.scale.set(.8,scale*(.30+i%3*.15),.8);dummy.updateMatrix();crystals.setMatrixAt(i,dummy.matrix);}crystals.instanceMatrix.needsUpdate=true;});
   particles(0x9ec951,40,(o,i,t)=>{const a=i*2.4,r=1+(i%7)*.85,q=(t*.7+i*.31)%1;o.position.set(point.x+Math.sin(a)*r,.08+q*.6,point.z+Math.cos(a)*r);o.scale.setScalar(.08+Math.sin(q*Math.PI)*.14);});
   plume(2,rule.radius*2,0,.6);
   const poolMat=own(new T.ShaderMaterial({transparent:true,depthWrite:false,side:T.DoubleSide,uniforms:{time:{value:0},fade:{value:1}},vertexShader:'varying vec2 p;void main(){p=uv*2.-1.;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}',fragmentShader:'varying vec2 p;uniform float time;uniform float fade;float h(vec2 q){return fract(sin(dot(q,vec2(127.1,311.7)))*43758.5453);}float n(vec2 q){vec2 i=floor(q),f=fract(q);f=f*f*(3.-2.*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+1.),f.x),f.y);}void main(){float r=length(p);vec2 q=p*6.+vec2(time*.04,-time*.05);float f=n(q)*.58+n(q*2.03)*.28+n(q*4.1)*.14;float veins=pow(1.-abs(sin(f*17.+r*3.-time*.3)),18.);float edge=1.-smoothstep(.82+f*.08,1.,r);float rim=exp(-pow((r-.91)*32.,2.));vec3 c=mix(vec3(.015,.035,.018),vec3(.09,.18,.04),f);c+=vec3(.18,.42,.025)*veins+vec3(.11,.25,.01)*rim;gl_FragColor=vec4(c,edge*fade*.88);}'}));const pool=add(plane,poolMat);pool.rotation.x=-Math.PI/2;pool.scale.setScalar(rule.radius*2);e.updates.push((t,f)=>{poolMat.uniforms.time.value=t;poolMat.uniforms.fade.value=Math.min(1,(1-f)*4);});
  }else if(index===6){
   const black=add(sphere,own(new T.MeshBasicMaterial({color:0x010008})),point.x,1.5,point.z),rim=add(ring,basic(0xf3bc77),point.x,1.5,point.z);rim.rotation.x=1.1;
   e.updates.push(t=>{const size=t<rule.collapse-.2?Math.min(1.6,t*4):Math.max(.01,(rule.collapse-t)*5);black.scale.setScalar(size);rim.scale.setScalar(size*1.25);rim.rotation.z=t*2;});
   const diskMat=own(accretionMaterial()),disk=add(plane,diskMat,point.x,1.2,point.z);disk.rotation.x=-Math.PI/2;disk.scale.setScalar(13);e.updates.push(t=>{diskMat.uniforms.age.value=t;diskMat.uniforms.fade.value=t<rule.collapse-.2?Math.min(1,t*5):Math.max(0,(rule.duration-t)*2);});
   particles(0xcda9ff,64,(o,i,t)=>{const a=i*2.4+t*3,r=Math.max(.1,rule.radius*(1-t/rule.collapse))*(.5+i%4*.14);o.position.set(point.x+Math.sin(a)*r,1.5+Math.sin(a*.6)*.3,point.z+Math.cos(a)*r);o.scale.setScalar(t<rule.collapse?.055:0);});shock(rule.radius,rule.collapse);
  }else if(index===7){
   const centre={x:anchor.x,z:(anchor.z+(anchor.altarZ??anchor.z))/2};
   const g=new T.SphereGeometry(1,48,24,0,Math.PI*2,0,Math.PI/2);e.geometries.push(g);
   const shieldMat=own(new T.ShaderMaterial({transparent:true,depthWrite:false,side:T.DoubleSide,uniforms:{time:{value:0},fade:{value:1}},vertexShader:'varying vec3 n,v;varying vec2 u;void main(){u=uv;vec4 mv=modelViewMatrix*vec4(position,1.);n=normalize(normalMatrix*normal);v=normalize(-mv.xyz);gl_Position=projectionMatrix*mv;}',fragmentShader:'varying vec3 n,v;varying vec2 u;uniform float time,fade;void main(){float rim=pow(1.-abs(dot(normalize(n),normalize(v))),2.);vec2 q=u*vec2(36.,12.);q.x+=mod(floor(q.y),2.)*.5;vec2 f=abs(fract(q)-.5);float grid=smoothstep(.44,.49,max(f.x,f.y));float scan=pow(.5+.5*sin(u.y*32.-time*2.),12.);gl_FragColor=vec4(vec3(1.,.68,.23)*(1.+rim),(.045+rim*.55+grid*.11+scan*.07)*fade);}'}));
   const dome=add(g,shieldMat,centre.x,.05,centre.z);dome.scale.setScalar(rule.radius);
   for(const r of [rule.radius,rule.radius-.22]){const base=add(ring,basic(0xffdb8b,.65),centre.x,.1,centre.z);base.rotation.x=-Math.PI/2;base.scale.setScalar(r);}
   particles(0xffdd91,40,(o,i,t)=>{const a=i*2.4+t*.15,r=rule.radius*.9;o.position.set(centre.x+Math.sin(a)*r,.2+(t*.6+i*.15)%(rule.radius*.75),centre.z+Math.cos(a)*r);o.scale.setScalar(.045);});
   e.updates.push((t,f)=>{shieldMat.uniforms.time.value=t;shieldMat.uniforms.fade.value=Math.min(1,t*5)*Math.min(1,(life-t)*2);});
  }
  for(const fn of e.updates)fn(0,0);
 }
 function lance(from,to){cast(1,to,from,{targets:[to],tint:0xa4ef82});}
 function update(dt){clock+=dt;frame.uTime.value=clock;sigilMat.userData.sync({radius:2.7,quadSize:6,grown:3,front:.4,pulse:.65,fade:.4,seed:4});sigilMat.uniforms.uColorLine.value.setHex(0x96ca66);sigilMat.uniforms.uColorRune.value.setHex(0xe6c98a);
  for(let i=active.length-1;i>=0;i--){const e=active[i];e.age+=dt;if(e.age>=e.life){remove(e);active.splice(i,1);}else for(const fn of e.updates)fn(e.age,e.age/e.life);}}
 function reset(){active.forEach(remove);active.length=0;clock=0;update(0);}
 return {cast,lance,collapseOldest(){const e=active.find(e=>e.index===6&&e.age<SPELL_RULES[6].collapse);if(e)e.age=SPELL_RULES[6].collapse-.2;},update,reset,count:()=>active.length,snapshot:()=>active.map(e=>({index:e.index,left:e.life-e.age}))};
}
