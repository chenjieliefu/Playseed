import assert from 'node:assert/strict';
import {createSproutMage} from '../runtime/web/components.js';
const mage=createSproutMage(),poses=[];
for(let i=0;i<8;i++){mage.resetPose();mage.cast(i);for(let j=0;j<24;j++)mage.animate(1/60,j/60);const p=mage.pose();poses.push(JSON.stringify([p.arm,p.left,p.sweep,p.lean,p.step]));assert.ok(p.step>.2,'casting should shift stance');assert.ok(mage.group.position.y<.15,'mage should stand near ground instead of hovering');const before=mage.castingArm.rotation.x;mage.cast(i);mage.animate(1/60,1);assert.ok(Math.abs(mage.castingArm.rotation.x-before)<.65,'rapid cast must blend, not snap arms');}
assert.equal(new Set(poses).size,8,'all eight spells need different full-body poses');for(let i=0;i<150;i++)mage.animate(1/60,3+i/60);assert.ok(Math.abs(mage.castingArm.rotation.x+.12)<.02);mage.resetPose();assert.equal(mage.pose().age,9);console.log('MAGE_ACTIONS_OK: 8 distinct poses, stance, grounded feet, rapid blending and idle recovery');
