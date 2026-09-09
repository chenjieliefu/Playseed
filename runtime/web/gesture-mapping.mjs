// Selfie inference labels are inverted relative to physical hands; coordinates stay mirrored.
const dist=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y,a.z&&b.z?(a.z-b.z)*.35:0);
const clamp=x=>Math.max(0,Math.min(1,x));
export const TIPS=[8,12,16,20];
export function openness(h){return [[4,2],[8,6],[12,10],[16,14],[20,18]].map(([tip,joint])=>clamp((dist(h[tip],h[0])/Math.max(.025,dist(h[joint],h[0]))-.92)/.48));}
export class GestureMapping {
 constructor({depthAim=false}={}){this.depthAim=depthAim;this.reset();}
 reset(){this.depthBase=null;this.filteredPalm=null;this.lastRawPalm=null;this.sentPalm=null;this.neutral=null;this.lastTime=null;this.smooth=null;this.fistArmed=false;this.fistSince=null;this.fistLatched=false;this.selectArmed=false;this.contact=null;this.castArmed=false;this.pinched=false;}
 sample(result,now){
  const found={};for(let i=0;i<(result?.landmarks?.length||0);i++){
   const h=result.landmarks[i],label=result.handedness?.[i]?.[0];
   if(!h||h.length!==21||h.some(p=>!Number.isFinite(p.x)||!Number.isFinite(p.y)))continue;
   if((label?.score??0)<.65||!['Left','Right'].includes(label.categoryName))continue;
   const physical=label.categoryName==='Left'?'Right':'Left';
   if(!found[physical]||label.score>found[physical].score)found[physical]={points:h,score:label.score,bars:openness(h)};
  }
  const right=found.Right,left=found.Left;let nextGroup=false,selectSlot=null,cast=false,motion=null;
  const dt=this.lastTime===null?0:Math.max(0,Math.min(.12,(now-this.lastTime)/1000));this.lastTime=now;
  const fist=!!left&&left.bars.slice(1).every(v=>v<.27);
  const rightFist=!!right&&right.bars.slice(1).every(v=>v<.27);
  if(!left){this.fistArmed=false;this.fistSince=null;this.fistLatched=false;this.selectArmed=false;this.contact=null;}
  else{
   if(left.bars.slice(1).filter(v=>v>.65).length>=3&&!fist){this.fistArmed=true;this.fistLatched=false;this.fistSince=null;}
   if(fist){this.fistSince??=now;this.selectArmed=false;this.contact=null;if(this.fistArmed&&!this.fistLatched&&now-this.fistSince>=220){nextGroup=true;this.fistLatched=true;this.fistArmed=false;}}
   else{
    this.fistSince=null;const h=left.points,span=Math.max(.04,dist(h[0],h[9]));
    const ratios=TIPS.map(i=>dist(h[4],h[i])/span),closest=ratios.indexOf(Math.min(...ratios));
    if(ratios.every(v=>v>.42)||(this.contact!==null&&ratios[this.contact]>.42)){this.selectArmed=true;this.contact=null;}
    if(this.selectArmed&&ratios[closest]<.28){selectSlot=closest;this.contact=closest;this.selectArmed=false;}
   }
  }
  if(!right||rightFist){this.depthBase=null;this.filteredPalm=null;this.sentPalm=null;this.lastRawPalm=null;this.neutral=null;this.smooth=null;this.castArmed=false;this.pinched=false;}
  else{
   // Wrist and the three outer knuckles stay steadier while index/thumb close.
   const palm=[0,9,13,17].reduce((v,i)=>({x:v.x+right.points[i].x/4,y:v.y+right.points[i].y/4}),{x:0,y:0});
   if(this.depthAim){const h=right.points,d=(a,b)=>Math.hypot(h[a].x-h[b].x,h[a].y-h[b].y,(h[a].z||0)-(h[b].z||0));const span=Math.max(.025,(d(0,9)+d(9,17))*0.5);this.depthBase??=span;palm.y=-Math.log(span/this.depthBase)*.50;}
   this.neutral??={...palm};
   if(!this.filteredPalm){this.filteredPalm={...palm};this.sentPalm={...palm};motion={x:0,y:0};}
   else{
    const velocity=this.lastRawPalm?Math.hypot(palm.x-this.lastRawPalm.x,palm.y-this.lastRawPalm.y)/Math.max(.016,dt):0;
    const alpha=1-Math.exp(-2*Math.PI*(3.5+Math.min(14,velocity*8))*Math.max(.016,dt));
    this.filteredPalm.x+=(palm.x-this.filteredPalm.x)*alpha;this.filteredPalm.y+=(palm.y-this.filteredPalm.y)*alpha;
    const dx=this.filteredPalm.x-this.sentPalm.x,dy=this.filteredPalm.y-this.sentPalm.y;
    if(Math.hypot(dx,dy)<.0012)motion={x:0,y:0};else{motion={x:Math.max(-110,Math.min(110,dx*2200)),y:Math.max(-110,Math.min(110,dy*1800))};this.sentPalm.x+=motion.x/2200;this.sentPalm.y+=motion.y/1800;}
   }
   this.lastRawPalm={...palm};const x=clamp(palm.x)*960,y=clamp(palm.y)*600;this.smooth={x,y};
   const ratio=dist(right.points[4],right.points[8])/Math.max(.04,dist(right.points[0],right.points[9]));
   if(fist){this.castArmed=false;this.pinched=false;}
   else if(ratio>.42){this.castArmed=true;this.pinched=false;}
   else if(ratio<.28){this.pinched=true;if(this.castArmed){cast=true;this.castArmed=false;}}
  }
  return {right,left,fist,rightFist,motion,neutral:this.neutral,nextGroup,selectSlot,cast,pinched:this.pinched,contact:this.contact,aim:right&&!rightFist?this.smooth:null};
 }
}
