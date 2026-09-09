import assert from 'node:assert/strict';
import {GestureMapping} from '../runtime/web/gesture-mapping.mjs';
import {dispatchGesture} from '../runtime/web/gesture-controls.mjs';
function hand(x=.4){const h=Array.from({length:21},()=>({x,y:.7,z:0}));h[0]={x,y:.9,z:0};for(let i=0;i<4;i++)for(let j=0;j<4;j++)h[5+4*i+j]={x:x+(i-1.5)*.06,y:.7-j*.15,z:0};h[4]={x:x-.3,y:.48,z:0};return h;}
const right=hand(.7),left=hand(.35);
function result(r=right,l=left,reverse=false){const pairs=[];if(r)pairs.push([r,'Left']);if(l)pairs.push([l,'Right']);if(reverse)pairs.reverse();return {landmarks:pairs.map(p=>p[0]),handedness:pairs.map(p=>[{categoryName:p[1],score:.99}])};}
function pinch(h,i=0){const p=structuredClone(h);p[4]={...p[[8,12,16,20][i]]};return p;}
const closed=structuredClone(left);for(const i of [8,12,16,20])closed[i]={x:.35,y:.79,z:0};
const m=new GestureMapping();assert.equal(m.sample(result(pinch(right)),0).cast,false,'joining pinched must not fire');
for(let i=0;i<4;i++){
 m.sample(result(),100+i*200);const selected=m.sample(result(right,pinch(left,i),true),133+i*200);
 assert.equal(selected.selectSlot,i);assert.equal(selected.cast,false,'left selects without casting');
 const cast=m.sample(result(pinch(right),pinch(left,i)),166+i*200);assert.equal(cast.cast,true);assert.equal(cast.selectSlot,null);
 assert.ok(cast.aim.x>500,'physical right hand maps independently of detector order');assert.equal(m.sample(result(pinch(right),pinch(left,i)),199+i*200).cast,false);
}
m.sample(result(),900);assert.equal(m.sample(result(right,pinch(left,0)),933).selectSlot,0);assert.equal(m.sample(result(right,pinch(left,3)),966).selectSlot,3,'direct finger change only needs to release the previous finger');
let count=0;for(let i=0;i<8;i++){m.sample(result(),1000+i*150);for(const d of [33,66])if(m.sample(result(pinch(right)),1000+i*150+d).cast)count++;m.sample(result(),1100+i*150);}assert.equal(count,8,'all eight rapid 67ms contacts fire once');
m.sample(result(),3000);assert.equal(m.sample(result(right,closed),3033).nextGroup,false);assert.equal(m.sample(result(right,closed),3280).nextGroup,true);assert.equal(m.sample(result(right,closed),3700).nextGroup,false);assert.equal(m.sample(result(pinch(right),closed),3733).cast,false,'bank change suppresses accidental cast');
m.sample(result(),4000);m.sample(result(null),4100);assert.equal(m.sample(result(pinch(right)),4200).cast,false,'lost/reacquired pinched hand must release');
m.sample(result(right,null),4300);assert.equal(m.sample(result(pinch(right),null),4333).cast,true,'right hand can fire selected skill without left visible');
const weak=result();weak.handedness[0][0].score=.3;assert.equal(m.sample(weak,4500).right,undefined);
const messages=[];dispatchGesture({aim:{x:600,y:200},motion:{x:110,y:-70},selectSlot:2,cast:true,nextGroup:false},(type,p)=>messages.push(p),{active:true,skillCount:8,relativeAim:true,sensitivity:1.8});
assert.equal(messages.filter(p=>p.name==='primary'&&p.point.pressed).length,1);assert.deepEqual(messages.slice(-2).map(p=>p.point),[{x:0,y:0,relative:true,pressed:true},{x:0,y:0,relative:true,pressed:false}]);assert.ok(messages.filter(p=>p.name==='aim').every(p=>Math.abs(p.point.x)<=110));assert.equal(messages.filter(p=>p.name==='aim').reduce((n,p)=>n+p.point.x,0),198);assert.equal(messages.at(-3).name,'spell3');
console.log('GESTURE_MAPPING_OK: rapid right casts, left selection/fist, no held repeat, loss protection, current selection and bounded sensitivity');
