import assert from 'node:assert/strict';
import {GestureMapping} from '../runtime/web/gesture-mapping.mjs';
const hand=x=>Array.from({length:21},(_,i)=>({x:x+(i%4)*.02,y:i===0?.8:.4+(i%4)*.03,z:0}));
const physicalRight=hand(.75),physicalLeft=hand(.25);
for(const h of [physicalRight,physicalLeft]){h[0].y=.8;for(const i of [8,12,16,20])h[i].y=.1;}
// User's v7 camera feedback: selfie inference labels are the inverse of physical hands.
const result={landmarks:[physicalRight,physicalLeft],handedness:[[{categoryName:'Left',score:.99}],[{categoryName:'Right',score:.99}]]};
const map=new GestureMapping(),a=map.sample(result,0);
assert.equal(a.right.points,physicalRight,'selfie handedness must match the physical right hand');
const mean=[0,9,13,17].reduce((s,i)=>s+physicalRight[i].x,0)/4;
assert.ok(Math.abs(a.aim.x-mean*960)<.01,'palm centroid controls target');
physicalRight[8].x=.05;physicalRight[5].x=.05;const b=map.sample(result,100);assert.ok(Math.abs(a.aim.x-b.aim.x)<.01,'moving only fingertip must not move the target');
console.log('PHYSICAL_HAND_AND_PALM_OK');
