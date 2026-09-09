// Common player checks run for every newly generated/revised web game.
// Use the declared current probe: intentionally removed historical controls are
// not silently made permanent requirements.
export async function checkLifecycle({page, surface, probe, input}) {
 const read=()=>surface.evaluate(()=>window.playseed.snapshot());
 const state=()=>page.evaluate(()=>window.playseedPlayer.snapshot());
 const fields=[...new Set(['won','lost','progress',probe.changed_field])];
 const same=(a,b)=>fields.every(key=>JSON.stringify(a[key])===JSON.stringify(b[key]));
 const replays=[];
 await page.evaluate(()=>{
  window._qaResetEvents=0;
  window._qaResetListener=e=>{if(e.source===document.querySelector('#stage').contentWindow&&e.data?.playseed&&e.data.type==='reset-state')window._qaResetEvents++;};
  addEventListener('message',window._qaResetListener);
 });
 try{
 for(let cycle=0;cycle<2;cycle++){
  const resets=await page.evaluate(()=>window._qaResetEvents);
  await page.locator('#restart').click();
  await page.waitForFunction(n=>window._qaResetEvents>n,resets,{timeout:3000});
  await page.waitForFunction(()=>!window.playseedPlayer.snapshot().paused);
  // Match the initial probe's two-second warmup, so a legitimate opening
  // countdown or delayed target is not mistaken for a broken restart.
  await page.waitForTimeout(2000);
  const restarted=await read();
  if(restarted.won||restarted.lost||!Number.isFinite(restarted.progress))throw Error('重开按钮没有恢复可玩状态');
  await page.locator('#pause').click();
  await page.waitForFunction(()=>window.playseedPlayer.snapshot().paused);
  await page.waitForTimeout(100);
  const frozen=await read();
  await input();
  await page.waitForTimeout(200);
  if(!same(frozen,await read()))throw Error('暂停时核心玩法仍响应输入或继续推进');
  await page.locator('#pause').click();
  await page.waitForFunction(()=>!window.playseedPlayer.snapshot().paused);
  if(!(await state()).started)throw Error('继续游戏后丢失开始状态');
  const before=await read();
  await input();
  const after=await read();
  if(JSON.stringify(before[probe.changed_field])===JSON.stringify(after[probe.changed_field]))throw Error('重开或继续后核心操作失效，第 '+(cycle+1)+' 次重玩没有响应');
  // Also pause after gameplay has begun: projectiles/timers can be dormant
  // before the first action, so an initial-state-only pause test misses them.
  await page.locator('#pause').click();
  await page.waitForFunction(()=>window.playseedPlayer.snapshot().paused);
  await page.waitForTimeout(100);
  const activeFrozen=await read();
  await page.waitForTimeout(200);
  if(!same(activeFrozen,await read()))throw Error('暂停后已经开始的玩法仍在推进');
  await page.locator('#pause').click();
  await page.waitForFunction(()=>!window.playseedPlayer.snapshot().paused);
  replays.push({restarted,frozen,before,after,activeFrozen});
 }
 return {pause_resume:true,restart_replay:true,replays};
 }finally{
  await page.evaluate(()=>{removeEventListener('message',window._qaResetListener);delete window._qaResetListener;delete window._qaResetEvents;});
 }
}
