import assert from 'node:assert/strict';
import {GestureMapping} from '../runtime/web/gesture-mapping.mjs';
function hand(x=.7,y=.68){const h=Array.from({length:21},()=>({x,y,z:0}));h[0].y=y+.18;for(let i=0;i<4;i++)for(let j=0;j<4;j++)h[5+i*4+j]={x:x+(i-1.5)*.04,y:y-j*.1,z:0};h[4]={x:x-.22,y:y-.15,z:0};return h;}
const result=h=>({landmarks:h?[h]:[],handedness:h?[[{categoryName:'Left',score:.99}]]:[]});
const m=new GestureMapping();assert.deepEqual(m.sample(result(hand()),0).motion,{x:0,y:0});
let travel=0;for(let i=1;i<=20;i++)travel+=m.sample(result(hand(.82)),i*67).motion.x;
let drift=0;for(let i=21;i<=40;i++)drift+=m.sample(result(hand(.82)),i*67).motion.x;
assert.ok(travel>100,'moving the hand should move the cursor');assert.ok(Math.abs(drift)<1,'holding an offset hand must stop cursor, not continue driving');
let reverse=0;for(let i=41;i<=60;i++)reverse+=m.sample(result(hand()),i*67).motion.x;assert.ok(reverse< -100,'moving hand back must move cursor back');assert.ok(Math.abs(travel+reverse)<6,'return to same pose should return to same cursor position');
m.sample(result(null),4500);assert.deepEqual(m.sample(result(hand(.5)),4600).motion,{x:0,y:0},'reacquiring hand must not jump');
console.log('HAND_FOLLOW_OK: immediate movement, offset hold stops, reversible position, no reacquisition jump');
