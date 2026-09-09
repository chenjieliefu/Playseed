// Playseed's reusable character and effects adapters. No DOM, network or assets.
import * as T from './vendor/three.module.js';
import {createNatureSigilMaterial} from './vendor/elemental/src/materials/NatureSigilMaterial.js';
import {createCosmicRingMaterial} from './vendor/elemental/src/materials/CosmicShockMaterial.js';
import {frame} from './vendor/elemental/src/core/FrameUniforms.js';

export function createSproutMage() {
 const group=new T.Group();group.name='Playseed · 嫩芽魔法师';
 const mat=(color,metalness=.15,roughness=.45,emissive=0)=>new T.MeshStandardMaterial({color,metalness,roughness,emissive,emissiveIntensity:1.4});
 const cream=mat(0xf6e8bb), green=mat(0x94b744), visor=mat(0x091b1b,.55,.18), eye=mat(0xc7ff48,.2,.25,0x9fe923), cloth=mat(0x344878), gold=mat(0xeaca74,.65,.3), wood=mat(0x635643);
 function mesh(g,m,pos,scale,host=group){const o=new T.Mesh(g,m);o.position.set(...pos);o.scale.set(...scale);o.castShadow=true;o.receiveShadow=true;host.add(o);return o;}
 const sphere=new T.SphereGeometry(1,24,16), cylinder=new T.CylinderGeometry(1,1,1,24);
 const ball=(m,p,s,h=group)=>mesh(sphere,m,p,s,h);
 // Large cream head, inset dark visor, two green oval eyes and the signature sprout.
 const head=new T.Group();head.position.y=1.45;group.add(head);
 ball(cream,[0,0,0],[.60,.48,.45],head);
 ball(green,[0,-.01,.325],[.50,.345,.16],head);
 ball(visor,[0,0,.405],[.445,.295,.13],head);
 const eyes=[-.19,.19].map(x=>ball(eye,[x,.015,.53],[.067,.115,.025],head));
 for(const x of [-.58,.58])ball(green,[x,-.07,0],[.085,.22,.22],head);
 // Tilted wizard hat leaves the face and sprout visible.
 const hat=new T.Group();hat.position.set(0,.34,-.04);hat.rotation.z=-.15;head.add(hat);
 mesh(cylinder,cloth,[0,.03,0],[.67,.06,.53],hat);
 mesh(new T.ConeGeometry(.48,.9,32),cloth,[0,.48,0],[1,1,1],hat);
 mesh(cylinder,gold,[0,.13,0],[.43,.075,.43],hat);
 ball(eye,[.14,.7,.03],[.065,.065,.035],hat);
 const sprout=new T.Group();sprout.position.set(.40,.27,.06);sprout.rotation.z=-.28;head.add(sprout);
 mesh(cylinder,green,[0,.18,0],[.027,.4,.027],sprout);
 const leaf1=ball(green,[-.13,.38,0],[.21,.085,.07],sprout);leaf1.rotation.z=-.6;
 const leaf2=ball(eye,[.12,.46,0],[.19,.075,.065],sprout);leaf2.rotation.z=.6;
 // Robe and cape keep the robot's rounded hands and boots visible.
 mesh(new T.CylinderGeometry(.29,.48,.8,24),cloth,[0,.61,0],[1,1,1]);
 mesh(cylinder,gold,[0,.50,0],[.385,.055,.385]);
 ball(gold,[0,.96,.32],[.09,.095,.05]);
 const cape=mesh(new T.ConeGeometry(.53,.95,24,1,true,0,Math.PI),cloth,[0,.67,-.16],[1,1,.6]);cape.rotation.y=Math.PI;
 const boots=[];for(const x of [-.24,.24])boots.push(ball(green,[x,.15,.15],[.19,.15,.29]));
 const leftArm=new T.Group();leftArm.position.set(-.46,.91,.02);group.add(leftArm);
 ball(cream,[0,-.17,.04],[.14,.24,.14],leftArm);ball(cream,[0,-.35,.12],[.15,.15,.14],leftArm);
 const castingArm=new T.Group();castingArm.position.set(.45,.94,.03);group.add(castingArm);
 ball(cream,[0,-.12,.08],[.145,.23,.15],castingArm);ball(cream,[.02,-.22,.29],[.16,.15,.14],castingArm);
 mesh(cylinder,wood,[.06,.05,.34],[.046,1.5,.046],castingArm);
 const cage=mesh(new T.TorusGeometry(.18,.025,8,24),gold,[.06,.84,.34],[1,1,1],castingArm);
 const staffCrystal=mesh(new T.OctahedronGeometry(.135),eye,[.06,.84,.34],[1,1.45,1],castingArm);
 group.scale.setScalar(1.35);
 const profiles=[
  {name:'举杖下劈',arm:1.65,wind:1.1,sweep:0,left:.8,lean:.15,step:.32},
  {name:'侧身指引',arm:1.8,wind:.2,sweep:-.65,left:.55,lean:.04,step:.24},
  {name:'双手推掌',arm:1.35,wind:.3,sweep:.1,left:1.55,lean:.11,step:.28},
  {name:'蓄力砸杖',arm:2.4,wind:1.5,sweep:0,left:.6,lean:.30,step:.42},
  {name:'托掌召唤',arm:1.05,wind:.2,sweep:.35,left:1.2,lean:-.08,step:.16},
  {name:'横扫布阵',arm:1.3,wind:.3,sweep:1.05,left:.8,lean:.08,step:.26},
  {name:'张臂牵引',arm:1.15,wind:.4,sweep:-.55,left:1.65,lean:-.13,step:.18},
  {name:'双臂撑盾',arm:1.5,wind:.25,sweep:.18,left:1.85,lean:-.07,step:.20}
 ];
 let age=9,kind=0;
 const blend=(from,to,k)=>from+(to-from)*k;
 function cast(index){age=0;kind=Math.max(0,Math.min(7,index));}
 function animate(dt,time){age=Math.min(9,age+dt);const p=profiles[kind],wind=Math.sin(Math.PI*Math.min(1,age/.20)),strike=Math.sin(Math.PI*Math.max(0,Math.min(1,(age-.08)/.72))),ease=1-Math.exp(-14*Math.max(0,dt)),breathe=Math.sin(time*2)*.014;
  const rightX=-.12-p.wind*wind+p.arm*strike;
  castingArm.rotation.x=blend(castingArm.rotation.x,rightX,ease);castingArm.rotation.y=blend(castingArm.rotation.y,p.sweep*strike,ease);castingArm.rotation.z=blend(castingArm.rotation.z,(kind===6?-.9:kind===5?.65:.2)*strike,ease);
  leftArm.rotation.x=blend(leftArm.rotation.x,-.14+p.left*strike,ease);leftArm.rotation.y=blend(leftArm.rotation.y,-.2*strike,ease);leftArm.rotation.z=blend(leftArm.rotation.z,-.25-(kind===6?1.05:.45)*strike,ease);
  group.rotation.x=blend(group.rotation.x,p.lean*strike,ease);group.rotation.z=blend(group.rotation.z,-p.sweep*.12*strike,ease);
  group.position.y=blend(group.position.y,.10-(kind===3?.09:.025)*strike+breathe,ease);
  head.rotation.x=blend(head.rotation.x,-p.lean*.45*strike+breathe,ease);head.rotation.z=blend(head.rotation.z,p.sweep*.08*strike,ease);
  cape.rotation.x=blend(cape.rotation.x,.05+Math.sin(time*3)*.035+strike*.32+wind*.15,ease);cape.rotation.z=blend(cape.rotation.z,Math.sin(time*2)*.02-p.sweep*.12*strike,ease);
  hat.rotation.z=blend(hat.rotation.z,-.15+wind*.08-strike*.05,ease);sprout.rotation.z=-.28+Math.sin(time*3)*.025+strike*.04;
  boots[0].position.z=blend(boots[0].position.z,.15+p.step*strike,ease);boots[1].position.z=blend(boots[1].position.z,.15-p.step*.5*strike,ease);
  boots[0].position.y=blend(boots[0].position.y,.15+wind*.07,ease);boots[0].rotation.x=blend(boots[0].rotation.x,-strike*.18,ease);boots[1].rotation.x=blend(boots[1].rotation.x,strike*.1,ease);
  const blink=time%5.7>5.5?Math.max(.1,Math.abs(Math.cos((time%5.7-5.5)/.2*Math.PI))):1;eyes.forEach(o=>o.scale.y=.115*blink);
 }
 function resetPose(){age=9;kind=0;animate(10,0);}
 return {group,leftArm,castingArm,staffCrystal,head,cape,cage,cast,animate,resetPose,pose:()=>({age:Math.round(age*100)/100,kind,name:profiles[kind].name,arm:Math.round(castingArm.rotation.x*100)/100,left:Math.round(leftArm.rotation.x*100)/100,sweep:Math.round(castingArm.rotation.y*100)/100,lean:Math.round(group.rotation.x*100)/100,step:Math.round(boots[0].position.z*100)/100})};
}

export {createSpellEffects} from './spell-effects.js';
export {createPresentation} from './presentation.js';
export {createMonsterBatch} from './monster-batch.js';

export {createBattlefield} from "./battlefield.js";
export {SPELL_RULES} from './spell-rules.mjs';
export {createTargetPreview} from './target-preview.js';
