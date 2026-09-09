// Synthetic landmarks enter the real host callback, mapping and input dispatcher.
// Camera permission, initialization and lifecycle still use the browser media path.
export function hand(x){
 const h=Array.from({length:21},()=>({x,y:.7,z:0}));h[0]={x,y:.9,z:0};
 for(let i=0;i<4;i++){const base=5+i*4,px=x+(i-1.5)*.06;for(let j=0;j<4;j++)h[base+j]={x:px,y:.7-j*.15,z:0};}
 h[1]={x:x-.10,y:.8};h[2]={x:x-.2,y:.7};h[3]={x:x-.26,y:.6};h[4]={x:x-.3,y:.48};return h;
}
export const right=hand(.74),left=hand(.35);
export const pinch=(points,slot=0)=>{const p=structuredClone(points);p[4]={...p[8+slot*4]};return p;};
export async function installHands(page){
 await page.evaluate(async()=>{
  const {HandTracker}=await import('./hand-tracker.mjs');const original=HandTracker.prototype.sample;
  HandTracker.prototype.sample=function(video,now){if(window._qaLandmarks)this.onResult?.(window._qaLandmarks,now);else return original.call(this,video,now);};
 });
}
export async function feedHands(page,r=right,l=left,ms=130){
 const pairs=[];if(r)pairs.push([r,'Left']);if(l)pairs.push([l,'Right']);
 await page.evaluate(data=>{window._qaLandmarks=data;},{landmarks:pairs.map(p=>p[0]),handedness:pairs.map(p=>[{categoryName:p[1],score:.99}])});
 await page.waitForTimeout(ms);
}
export async function selectHand(page,slot){await feedHands(page);await feedHands(page,right,pinch(left,slot));}
export async function castHand(page){await feedHands(page);await feedHands(page,pinch(right),left);}
