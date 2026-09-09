import assert from 'node:assert/strict';
import {GestureMapping} from '../runtime/web/gesture-mapping.mjs';
import {dispatchGesture} from '../runtime/web/gesture-controls.mjs';
function hand(x=.65,y=.55){const h=Array.from({length:21},()=>({x,y,z:0}));h[0].y=y+.18;for(let i=0;i<4;i++)for(let j=0;j<4;j++)h[5+i*4+j]={x:x+(i-1.5)*.04,y:y-j*.1,z:0};h[4]={x:x-.22,y:y-.15,z:0};return h;}
const result=h=>({landmarks:h?[h]:[],handedness:h?[[{categoryName:'Left',score:.99}]]:[]});
const map=new GestureMapping(),base=hand();const a=map.sample(result(base),0);assert.deepEqual(a.motion,{x:0,y:0},'comfortable first position must not move landing point');
let b=map.sample(result(base.map(p=>({...p,x:p.x+.01}))),100);assert.ok(b.motion.x>0,'small deliberate hand movement follows position');
b=map.sample(result(base.map(p=>({...p,x:p.x+.12}))),200);assert.ok(b.motion.x>20&&b.motion.y===0,'right offset pushes right');
b=map.sample(result(base.map(p=>({...p,y:p.y-.12}))),300);assert.ok(b.motion.y< -20&&b.motion.x<0,'up offset pushes up');
assert.ok(map.sample(result(base),400).motion.y>0,'returning hand moves cursor back');
const fist=structuredClone(base);for(const i of [8,12,16,20])fist[i]={...base[0]};assert.equal(map.sample(result(fist),500).motion,null);
const repositioned=base.map(p=>({...p,x:p.x-.2}));assert.deepEqual(map.sample(result(repositioned),900).motion,{x:0,y:0},'reopening reanchors without jumping');
map.sample(result(null),1000);assert.deepEqual(map.sample(result(base),5000).motion,{x:0,y:0},'reacquisition must not jump or integrate lost time');
const messages=[];dispatchGesture({...a,cast:true},(type,v)=>messages.push(v),{active:true,skillCount:8,relativeAim:true});assert.equal(messages[0].point.relative,true);assert.deepEqual(messages[1].point,{x:0,y:0,relative:true,pressed:true},'casting keeps current landing point');
console.log('RELATIVE_HAND_OK: comfortable origin, directional motion, position following, fist/reacquisition, cast without jumping');
