import {TIPS} from './gesture-mapping.mjs';
import {drawSpellIcon} from './spellbook.mjs';
const BONES=[[0,1,2,3,4],[0,5,6,7,8],[5,9,10,11,12],[9,13,14,15,16],[13,17,18,19,20],[0,17]];
export function drawHandOverlay(ctx,sample,book,group,selectedSlot=0){
 const w=ctx.canvas.width,h=ctx.canvas.height;ctx.clearRect(0,0,w,h);
 for(const [label,hand] of [['右手',sample?.right],['左手',sample?.left]]){if(!hand)continue;const p=hand.points,color=label==='右手'?'#7ce6ed':'#e6d595';
  ctx.strokeStyle=color;ctx.lineWidth=3;ctx.globalAlpha=.75;
  for(const chain of BONES){ctx.beginPath();chain.forEach((id,i)=>ctx[i?'lineTo':'moveTo'](p[id].x*w,p[id].y*h));ctx.stroke();}
  ctx.globalAlpha=1;for(const v of p){ctx.fillStyle=color;ctx.beginPath();ctx.arc(v.x*w,v.y*h,3,0,7);ctx.fill();}
  if(label==='右手'){const centre=[0,9,13,17].reduce((v,id)=>({x:v.x+p[id].x*w/4,y:v.y+p[id].y*h/4}),{x:0,y:0});ctx.strokeStyle=color;ctx.lineWidth=3;ctx.beginPath();ctx.arc(centre.x,centre.y,12,0,7);ctx.moveTo(centre.x-18,centre.y);ctx.lineTo(centre.x+18,centre.y);ctx.moveTo(centre.x,centre.y-18);ctx.lineTo(centre.x,centre.y+18);ctx.stroke();}
  const px=Math.max(48,Math.min(w-65,p[0].x*w)),py=Math.max(85,Math.min(h-20,p[0].y*h));
  ctx.fillStyle='#091725dc';ctx.fillRect(px-46,py-75,106,66);ctx.font='15px system-ui';ctx.fillStyle=color;ctx.fillText(label+(label==='右手'?(sample.pinched?' · 释放':' · 瞄准'):(sample.fist?' · 换组':' · 选技能')),px-40,py-55);
  hand.bars.forEach((v,i)=>{ctx.fillStyle='#425369';ctx.fillRect(px-35+i*17,py-45,9,30);ctx.fillStyle=color;ctx.fillRect(px-35+i*17,py-15-v*30,9,v*30);});
  const order=TIPS.map((id,i)=>({i,x:p[id].x})).sort((a,b)=>a.x-b.x);
  const centre=TIPS.reduce((s,id)=>s+p[id].x*w,0)/4,leftEdge=Math.max(40,Math.min(w-250,centre-105));
  const rowY=Math.max(30,Math.min(...TIPS.map(id=>p[id].y*h))-43);
  if(label==='左手')TIPS.forEach((id,i)=>{const spell=book[group*4+i];if(!spell)return;const x=leftEdge+order.findIndex(o=>o.i===i)*70,y=rowY;ctx.strokeStyle=spell.color;ctx.lineWidth=1;ctx.beginPath();ctx.moveTo(p[id].x*w,p[id].y*h);ctx.lineTo(x,y+22);ctx.stroke();
   ctx.fillStyle=selectedSlot===i?'#466753ee':'#091725ed';ctx.strokeStyle=spell.color;ctx.lineWidth=2;ctx.beginPath();ctx.arc(x,y,22,0,7);ctx.fill();ctx.stroke();drawSpellIcon(ctx,spell.icon,x,y,25,spell.color);ctx.font='bold 14px system-ui';ctx.textAlign='center';ctx.fillStyle='#fff3dc';ctx.fillText(spell.short,x,y+37);ctx.textAlign='start';
  });
 }
}
