// Trusted local host: generated modules run only in a fresh Chromium sandbox.
import {chromium} from 'playwright-core';
import {parse} from 'acorn';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import {installHands,feedHands,selectHand,castHand,right as fixtureRight,left as fixtureLeft} from './gesture-browser-fixture.mjs';
import {checkLifecycle} from './web-lifecycle-check.mjs';
const [mode, projectArg, reportArg]=process.argv.slice(2);
const project=fs.realpathSync(projectArg), report=reportArg?path.resolve(reportArg):null;
const script=fs.readFileSync(path.join(project,'game.js'),'utf8');
const ast=parse(script,{ecmaVersion:'latest',sourceType:'module'});
const forbidden=new Set(['eval','Function','fetch','XMLHttpRequest','WebSocket','Worker','SharedWorker','EventSource','navigator','location','window','document','globalThis','top','parent','opener','frames','localStorage','sessionStorage','indexedDB','caches','postMessage','setTimeout','setInterval']);
function bindings(pattern, scope) {
 if(!pattern)return;
 if(pattern.type==='Identifier')scope.add(pattern.name);
 else if(pattern.type==='RestElement')bindings(pattern.argument,scope);
 else if(pattern.type==='AssignmentPattern')bindings(pattern.left,scope);
 else if(pattern.type==='ArrayPattern')pattern.elements.forEach(p=>bindings(p,scope));
 else if(pattern.type==='ObjectPattern')pattern.properties.forEach(p=>bindings(p.type==='RestElement'?p.argument:p.value,scope));
}
function inspect(node, parent=null, key='', inherited=new Set()) {
 if(!node||typeof node!=='object')return;
 let scope=inherited;
 if(['Program','BlockStatement','FunctionDeclaration','FunctionExpression','ArrowFunctionExpression','CatchClause'].includes(node.type)){
  scope=new Set(inherited);
  if(node.params){bindings(node.id,scope);node.params.forEach(p=>bindings(p,scope));}
  if(node.type==='CatchClause')bindings(node.param,scope);
  if(Array.isArray(node.body))for(const statement of node.body){
   if(statement.type==='VariableDeclaration')statement.declarations.forEach(d=>bindings(d.id,scope));
   if(['FunctionDeclaration','ClassDeclaration'].includes(statement.type))bindings(statement.id,scope);
  }
 }
 if(['ImportDeclaration','ImportExpression','ExportAllDeclaration'].includes(node.type)||node.type==='ExportNamedDeclaration'&&node.source)throw Error('不允许模块加载');
 // Property names such as camera.top are data, not references to browser globals.
 const propertyName=parent&&!parent.computed&&((parent.type==='MemberExpression'&&key==='property')||(['Property','MethodDefinition'].includes(parent.type)&&key==='key'&&!parent.shorthand));
 if(node.type==='Identifier'&&!propertyName&&!scope.has(node.name)&&forbidden.has(node.name))throw Error('不允许网页系统接口 '+node.name);
 if(node.type==='MemberExpression'&&!node.computed&&['constructor','__proto__','prototype'].includes(node.property.name))throw Error('不允许反射接口');
 for(const [childKey,value] of Object.entries(node))if(Array.isArray(value))value.forEach(child=>inspect(child,node,childKey,scope));else if(value&&typeof value==='object')inspect(value,node,childKey,scope);
}
inspect(ast);
if(mode==='lint'){console.log('WEB_STATIC_OK');process.exit(0);}
const token=crypto.randomBytes(24).toString('hex');
const allowed=new Map();
function collect(dir){for(const entry of fs.readdirSync(dir,{withFileTypes:true})){const full=path.join(dir,entry.name);if(entry.isSymbolicLink())throw Error('网页工程不允许符号链接');if(entry.isDirectory())collect(full);else if(/\.(html|js|mjs|css|png|json|txt|wasm|task)$/.test(entry.name))allowed.set(path.relative(project,full).split(path.sep).join('/'),full);}}
collect(project);
const mime={'.html':'text/html','.js':'text/javascript','.css':'text/css','.json':'application/json','.png':'image/png','.txt':'text/plain','.mjs':'text/javascript','.wasm':'application/wasm','.task':'application/octet-stream'};
const server=http.createServer((req,res)=>{const url=new URL(req.url,'http://localhost');const rel=url.pathname.slice(token.length+2)||'index.html';if(req.method!=='GET'||!url.pathname.startsWith('/'+token+'/')||!allowed.has(rel)){res.writeHead(404);res.end();return;}
res.setHeader('Content-Type',mime[path.extname(rel)]);res.setHeader('Cache-Control','no-store');res.setHeader('Access-Control-Allow-Origin','*');res.setHeader('X-Content-Type-Options','nosniff');const shell=rel==='player.html',worker=rel==='hand-worker.js';res.setHeader('Permissions-Policy',shell?'camera=(self), microphone=(), geolocation=()':'camera=(), microphone=(), geolocation=()');
res.setHeader('Content-Security-Policy',(shell||worker)?"default-src 'none'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self'; img-src 'self' data:; connect-src 'self'; media-src blob:; frame-src 'self'; worker-src 'self'; object-src 'none'; base-uri 'none'; form-action 'none'":"default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; font-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'; frame-src 'none'; worker-src 'none'; sandbox allow-scripts");fs.createReadStream(allowed.get(rel)).pipe(res);});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const origin=`http://127.0.0.1:${server.address().port}`, url=`${origin}/${token}/${allowed.has('player.html')?'player.html':'index.html'}`;
let browser;
try{
 browser=await chromium.launch({channel:'chrome',headless:!['play','check-window','check-close','check-exit'].includes(mode),chromiumSandbox:true,args:['--disable-background-networking','--disable-component-update',...(mode!=='play'?['--use-fake-device-for-media-stream','--use-fake-ui-for-media-stream']:[])]});
 const context=await browser.newContext({viewport:['play','check-window','check-close','check-exit'].includes(mode)?null:{width:1200,height:750},acceptDownloads:false});
 await context.route('**/*',route=>{const u=new URL(route.request().url());const rel=u.pathname.slice(token.length+2);return u.origin===origin&&u.pathname.startsWith('/'+token+'/')&&allowed.has(rel)&&route.request().method()==='GET'?route.continue():route.abort();});
 const page=await context.newPage();if(['play','check-close','check-exit'].includes(mode)){page.once('close',()=>{void browser.close().catch(()=>{});});await page.exposeBinding('playseedClosePreview',({frame})=>{if(frame===page.mainFrame())void page.close();});}const errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error'&&/THREE|WebGLProgram|Shader Error/.test(m.text()))errors.push(m.text());});context.on('page',p=>{if(p!==page)p.close();});page.on('download',d=>d.cancel());page.on('dialog',d=>d.dismiss());
 await page.goto(url);
 const wrapped=allowed.has('player.html');
 if(wrapped)await page.locator('#stage').waitFor();
 const surface=wrapped?page.frame({url:new RegExp('/'+token+'/index.html$')}):page;
 if(!surface)throw Error('游戏画面没有打开');
 await surface.waitForFunction(()=>window.playseed||!document.querySelector('#error').hidden,{},{timeout:20000});
 if(!await surface.evaluate(()=>!!window.playseed))throw Error(await surface.locator('#error').textContent());
 if(wrapped)await page.waitForFunction(()=>window.playseedPlayer?.snapshot().ready);
 const gestureOnly=wrapped&&await page.evaluate(()=>window.playseedPlayer.snapshot().gestureOnly===true);
 if(gestureOnly&&mode!=='play')await installHands(page);
 if(mode==='check-gesture-only'){
  const intro=await surface.evaluate(()=>window.playseed.snapshot());await page.waitForTimeout(400);
  if(!gestureOnly||await page.evaluate(()=>window.playseedPlayer.snapshot().camera)||JSON.stringify(intro)!==JSON.stringify(await surface.evaluate(()=>window.playseed.snapshot())))throw Error('介绍页提前运行或开启摄像头');
  await page.evaluate(()=>{window._qaCapture=navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);navigator.mediaDevices.getUserMedia=async()=>{throw new DOMException('denied','NotAllowedError');};});
  await page.locator('#start').click();await page.waitForFunction(()=>document.querySelector('#notice').textContent.includes('允许摄像头'));
  const denied=await page.evaluate(()=>window.playseedPlayer.snapshot());if(denied.started||denied.camera||!denied.paused)throw Error('拒绝摄像头后仍开始游戏');
  await page.evaluate(()=>{navigator.mediaDevices.getUserMedia=async c=>{const stream=await window._qaCapture(c);window._qaLateStream=stream;return new Promise(resolve=>{window._qaResolveCapture=()=>resolve(stream);});};});
  await page.locator('#start').click();await page.waitForFunction(()=>window._qaResolveCapture);
  await page.locator('#start').click();await page.evaluate(()=>window._qaResolveCapture());await page.waitForTimeout(150);
  if(await page.evaluate(()=>window._qaLateStream.getTracks().some(t=>t.readyState==='live')||window.playseedPlayer.snapshot().started))throw Error('取消准备后迟到的摄像头流没有释放');
  await page.evaluate(()=>{navigator.mediaDevices.getUserMedia=window._qaCapture;});
  console.log('CAMERA_GATE_OK: no pre-start play, denial stays paused, cancellation releases late stream');
 }
 if(wrapped&&mode!=='play'){await page.locator('#start').click();await page.waitForFunction(()=>window.playseedPlayer.snapshot().started,{},{timeout:35000});}
 if(['play','check-close','check-exit'].includes(mode)){
  console.log(JSON.stringify({ready:true,url}));
  const disconnected=new Promise(resolve=>browser.on('disconnected',resolve));
  if(['check-close','check-exit'].includes(mode)){if(mode==='check-exit')await page.locator('#exit-preview').click();else await page.close();await Promise.race([disconnected,new Promise((_,reject)=>{const t=setTimeout(()=>reject(Error('关闭试玩窗口后浏览器仍在后台运行')),3000);t.unref();})]);console.log('PREVIEW_CLOSE_EXITS_OK');}
  else await disconnected;
 }else{
  const config=JSON.parse(fs.readFileSync(path.join(project,'web.json')));
  if(mode==='check-window'){
   const session=await context.newCDPSession(page),info=await session.send('Target.getTargetInfo'),win=await session.send('Browser.getWindowForTarget',{targetId:info.targetInfo.targetId});
   await session.send('Browser.setWindowBounds',{windowId:win.windowId,bounds:{windowState:'normal',width:1000,height:720}});await page.waitForTimeout(300);const small=await page.evaluate(()=>({w:innerWidth,h:innerHeight}));
   await session.send('Browser.setWindowBounds',{windowId:win.windowId,bounds:{width:1450,height:950}});await page.waitForTimeout(500);const large=await page.evaluate(()=>({w:innerWidth,h:innerHeight}));console.log('NATIVE_WINDOW_RESIZE',JSON.stringify({small,large}));
   if(large.w<=small.w+100||large.h<=small.h+100)throw Error('真实窗口放大没有传到游戏视口');
  }

  if(mode==='check-gestures'){
   if(!await page.evaluate(()=>window.playseedPlayer.snapshot().camera))await page.locator('#gesture').click();
   await page.waitForFunction(()=>window.playseedPlayer.snapshot().camera||document.querySelector('#notice').textContent,{},{timeout:45000});
   const camera=await page.evaluate(()=>window.playseedPlayer.snapshot());
   if(!camera.camera||camera.tracks!==1)throw Error('手势初始化失败: '+await page.locator('#notice').textContent());
   await page.waitForFunction(()=>window.playseedPlayer.snapshot().trackingFrames>=2,{},{timeout:12000});const warmed=await page.evaluate(()=>window.playseedPlayer.snapshot());await page.waitForTimeout(1500);const tracking=await page.evaluate(()=>window.playseedPlayer.snapshot());if(!tracking.camera||!tracking.trackerWorker||tracking.trackingFrames<2)throw Error('手势后台没有持续处理帧 '+JSON.stringify(tracking));if(tracking.trackingSize){
    const display=await page.evaluate(()=>{const v=document.querySelector('#camera'),c=document.querySelector('#hand-overlay'),box=v.getBoundingClientRect();return {w:c.width,h:c.height,ratio:box.width/box.height,fit:getComputedStyle(v).objectFit};});
    const ratio=tracking.cameraWidth/tracking.cameraHeight;
    if(Math.abs(tracking.trackingSize.width/tracking.trackingSize.height-ratio)>.005||Math.abs(display.w/display.h-ratio)>.005||Math.abs(display.ratio-ratio)>.01||display.fit!=='contain')throw Error('摄像头预览或识别裁切/拉伸');
    fs.writeFileSync(path.join(project,'camera-evidence.json'),JSON.stringify({tracking,display},null,2));
    console.log('CAMERA_FULL_FRAME_OK',JSON.stringify({width:tracking.cameraWidth,height:tracking.cameraHeight,inference:tracking.trackingSize,framing:tracking.cameraFraming}));
   }
   await page.locator('#gesture').click();
   if(await page.evaluate(()=>window.playseedPlayer.snapshot().tracks)!==0)throw Error('摄像头关闭后仍在运行');
   console.log('HAND_ENGINE_AND_CAMERA_LIFECYCLE_OK (synthetic camera)',JSON.stringify({frames:tracking.trackingFrames-warmed.trackingFrames,sampleMs:1500,delegate:tracking.trackingDelegate}));
   await page.locator('#restart').click();
   if(gestureOnly){await page.locator('#gesture').click();await page.waitForFunction(()=>window.playseedPlayer.snapshot().camera&&!window.playseedPlayer.snapshot().paused,{},{timeout:35000});}
  }
  const initial=await surface.evaluate(()=>window.playseed.snapshot());
  if(typeof initial.won!=='boolean'||typeof initial.lost!=='boolean'||!Number.isFinite(initial.progress)||initial.won||initial.lost)throw Error('开局状态无效');
  await page.waitForTimeout(2000);
  const before=await surface.evaluate(()=>window.playseed.snapshot());
  const input=config.test.action;
  const performInput=async()=>{
  if(gestureOnly){if(input.startsWith('spell'))await selectHand(page,Number(input.slice(5))-1);else if(input==='primary'){await selectHand(page,0);await castHand(page);}else throw Error('手势游戏需要选技或施法探针');}
  else if(input==='primary'){
   const box=await surface.locator('canvas').boundingBox();
   if(!box)throw Error('核心操作检查找不到游戏画布');
   await page.mouse.click(box.x+config.test.at[0]/960*box.width,box.y+config.test.at[1]/600*box.height);
  }
  else {const key={left:'ArrowLeft',right:'ArrowRight',up:'ArrowUp',down:'ArrowDown',spell1:'Digit1',spell2:'Digit2',spell3:'Digit3',spell4:'Digit4'}[input];if(!key)throw Error('无效真实输入探针');await page.keyboard.down(key);await page.waitForTimeout(120);await page.keyboard.up(key);}
  await page.waitForTimeout(config.test.wait_frames*1000/60);
  };
  await performInput();
  const after=await surface.evaluate(()=>window.playseed.snapshot());
  const field=config.test.changed_field;
  if(!(field in before)||!(field in after)||JSON.stringify(before[field])===JSON.stringify(after[field]))throw Error('受控输入没有改变玩法状态');
  if(mode==='check-gesture-only'){
   const read=()=>surface.evaluate(()=>window.playseed.snapshot());
   await feedHands(page,null,null);const idle=await read();
   await surface.locator('canvas').click({position:{x:300,y:300}});
   for(const key of ['Digit1','Digit4','KeyQ','Space','ArrowUp','KeyR','Escape'])await page.keyboard.press(key);
   const ignored=await read();for(const key of ['casts','selected_spell','skill_group','aim_x','aim_z'])if(ignored[key]!==idle[key])throw Error('鼠标键盘仍能控制战斗 '+key);
   if(!await page.locator('#slot-0').isDisabled()||!await page.locator('#next-group').isDisabled())throw Error('技能栏仍能点击选择');
   await selectHand(page,0);await feedHands(page,fixtureRight,fixtureLeft,350);const home=await read();
   const centre=[0,9,13,17].reduce((s,i)=>({x:s.x+fixtureRight[i].x/4,y:s.y+fixtureRight[i].y/4}),{x:0,y:0});
   const pushed=fixtureRight.map(p=>({...p,x:centre.x+(p.x-centre.x)*1.10,y:centre.y+(p.y-centre.y)*1.10}));
   await feedHands(page,pushed,fixtureLeft,450);const far=await read();
   const depth=home.target_aim_z-far.target_aim_z;if(depth<9.8||depth>10.6)throw Error('前后2倍灵敏度不符 '+depth);
   await feedHands(page,fixtureRight,fixtureLeft,450);const returned=await read();if(Math.abs(returned.target_aim_z-home.target_aim_z)>.3)throw Error('后收未返回原位');
   const moved=fixtureRight.map(p=>({...p,x:p.x+.02}));await feedHands(page,moved,fixtureLeft,350);const sideways=await read();if(Math.abs(sideways.target_aim_x-home.target_aim_x-1.98)>.3)throw Error('横向手感被改变');
   await feedHands(page,moved,fixtureLeft,250);const still=await read();if(Math.abs(still.aim_x-sideways.aim_x)>.1)throw Error('停手仍漂移');
   for(let bank=0;bank<2;bank++){
    if(bank){await feedHands(page);const fist=structuredClone(fixtureLeft);for(const i of [8,12,16,20])fist[i]={x:.35,y:.79,z:0};await feedHands(page,fixtureRight,fist,400);}
    for(let slot=0;slot<4;slot++){await selectHand(page,slot);const before=await read();await castHand(page);const cast=await read();if(cast.selected_spell!==bank*4+slot+1||cast.casts!==before.casts+1)throw Error('手势选技/释放未生效');}
   }
   await feedHands(page,null,null);await page.locator('#pause').click();const paused=await read();await castHand(page);if(JSON.stringify(paused)!==JSON.stringify(await read()))throw Error('暂停仍在响应手势');
   await page.locator('#pause').click();await page.locator('#gesture').click();await page.waitForFunction(()=>!window.playseedPlayer.snapshot().camera);
   const stopped=await read();await page.locator('#pause').click();await page.waitForTimeout(500);if(JSON.stringify(stopped)!==JSON.stringify(await read()))throw Error('没有摄像头时继续按钮恢复了战斗');
   await page.locator('#restart').click();await page.waitForTimeout(120);const clean=await read();if(clean.spawned||clean.casts||clean.selected_spell)throw Error('无摄像头重开未清空');await page.waitForTimeout(300);if(JSON.stringify(clean)!==JSON.stringify(await read()))throw Error('无摄像头重开后继续推进');
   await feedHands(page,null,null);await page.locator('#gesture').click();await page.waitForFunction(()=>window.playseedPlayer.snapshot().camera&&!window.playseedPlayer.snapshot().paused,{},{timeout:35000});
   await selectHand(page,1);await castHand(page);if((await read()).casts!==1)throw Error('恢复摄像头后不能施法');
   await page.evaluate(()=>{const track=document.querySelector('#camera').srcObject.getVideoTracks()[0];track.stop();track.dispatchEvent(new Event('ended'));});
   await page.waitForFunction(()=>!window.playseedPlayer.snapshot().camera&&window.playseedPlayer.snapshot().paused);
   fs.writeFileSync(path.join(project,'gesture-only-evidence.json'),JSON.stringify({depth,home,far,returned,sideways,final:await read()},null,2));
   console.log('GESTURE_ONLY_OK: camera startup/retry/disconnect, mouse/keyboard blocked, 2x depth only, 8 gestures, pause/restart/recovery');
  }
  if(mode==='check-resize'){
   await page.setViewportSize({width:1920,height:1080});
   const size=await surface.evaluate(()=>{const r=document.querySelector('canvas').getBoundingClientRect();return {width:r.width,height:r.height,availableW:innerWidth,availableH:innerHeight};});
   console.log('LAYOUT',JSON.stringify(size));
   if(Math.abs(size.width-size.availableW)>2||Math.abs(size.height-size.availableH)>2)throw Error('游戏没有填满可用画面');
   await page.locator('#fullscreen').click();await page.waitForFunction(()=>!!document.fullscreenElement);await surface.waitForFunction(()=>window.playseed.snapshot().viewport_width===innerWidth&&window.playseed.snapshot().viewport_height===innerHeight);await page.evaluate(()=>document.exitFullscreen());console.log('FULLSCREEN_BUTTON_AND_CAMERA_RESIZE_OK');
  }
  if(['check-performance','check-fire-performance'].includes(mode)){
   await surface.evaluate(()=>{const gl=document.querySelector('canvas').getContext('webgl2');window._qaDraws=0;for(const name of ['drawElements','drawArrays','drawElementsInstanced','drawArraysInstanced']){const original=gl[name].bind(gl);gl[name]=(...args)=>{window._qaDraws++;return original(...args);};}});
   const box=await surface.locator('canvas').boundingBox();await page.mouse.move(box.x+box.width*.6,box.y+box.height*.55);await page.keyboard.press(mode==='check-fire-performance'?'Digit1':'Digit3');await page.mouse.down();
   await page.waitForTimeout(2300);
   const stats=await surface.evaluate(()=>new Promise(resolve=>{let frames=0,previous=performance.now(),start=previous,draws=0,times=[];window._qaDraws=0;function tick(now){times.push(now-previous);previous=now;frames++;draws+=window._qaDraws;window._qaDraws=0;if(now-start<2500)requestAnimationFrame(tick);else{times.sort((a,b)=>a-b);resolve({fps:frames*1000/(now-start),p95:times[Math.floor(times.length*.95)],draws:draws/frames});}}requestAnimationFrame(tick);}));
   await page.mouse.up();console.log('CONTINUOUS_CAST_PERFORMANCE',JSON.stringify(stats));
   if(stats.draws>600)throw Error('连续施法每帧绘制次数过多');
  }
  if(mode==='check-mechanics'){
   const box=await surface.locator('canvas').boundingBox();
   for(let skill=0;skill<8;skill++){
    await page.locator('#restart').click();await surface.waitForFunction(()=>window.playseed.snapshot().casts===0&&window.playseed.snapshot().enemies===0);
    if(skill>=4)await page.keyboard.press('KeyQ');await page.keyboard.press('Digit'+(skill%4+1));
    await surface.waitForFunction(()=>window.playseed.snapshot().enemies>0,{},{timeout:10000});
    const before=await surface.evaluate(()=>window.playseed.snapshot()),e=before.enemy_positions[0];
    await page.mouse.click(box.x+e.sx/960*box.width,box.y+e.sy/600*box.height);
    const immediate=await surface.evaluate(()=>window.playseed.snapshot());
    if(skill===0&&immediate.pending_impacts===0)throw Error('火球没有飞行阶段');
    if(skill===1&&immediate.kills===0)throw Error('雷电不是即时命中');
    if(skill===2&&immediate.frozen_enemies===0)throw Error('冰霜没有冻结');
    if(skill===3&&immediate.pending_impacts===0)throw Error('大地没有连续突刺阶段');
    if([4,5,6].includes(skill)&&!immediate.zone_types.includes(skill))throw Error('持续技能没有独立实体');
    if(skill===7&&immediate.ward_seconds<=0)throw Error('护盾没有保护状态');
    await page.waitForTimeout(skill===4?950:skill===6?((before.spell_rules?.[6]?.collapse||1.55)+.25)*1000:skill===0?750:skill===3?1300:450);
    const after=await surface.evaluate(()=>window.playseed.snapshot());
    if(skill!==7&&after.kills===0&&after.enemy_positions[0]?.hp>=e.hp)throw Error('技能没有造成实际影响 '+skill);
    if(skill===7&&(after.kills||after.enemy_positions[0]?.hp!==e.hp))throw Error('护盾仍在冒充攻击技能');
    await page.screenshot({path:path.join(project,'mechanic-'+(skill+1)+'.png')});
   }
   await page.locator('#restart').click();await surface.waitForFunction(()=>window.playseed.snapshot().casts===0);
   console.log('EIGHT_MECHANICS_OK: projectile, instant chain, freeze, line eruption, autonomous flower, poison, delayed collapse, self shield');
  }
  if(mode==='check-hand-controls'){
   await page.locator('#restart').click();await surface.waitForFunction(()=>window.playseed.snapshot().casts===0);
   await page.evaluate(async()=>{
    const {GestureMapping}=await import('./gesture-mapping.mjs'),{dispatchGesture}=await import('./gesture-controls.mjs'),{drawHandOverlay}=await import('./hand-overlay.mjs'),{SPELLS}=await import('./spellbook.mjs');
    const mapping=new GestureMapping({depthAim:window.playseedPlayer.snapshot().depthAim});
    window._qaHandFrame=(r,l,now)=>{
     const pairs=[];if(l)pairs.push([l,'Left']);if(r)pairs.push([r,'Right']);
     const sample=mapping.sample({landmarks:pairs.map(p=>p[0]),handedness:pairs.map(p=>[{categoryName:p[1]==='Right'?'Left':'Right',score:.99}])},now);
     dispatchGesture(sample,(type,extra)=>document.querySelector('#stage').contentWindow.postMessage({playseed:true,type,...extra},'*'),{active:true,skillCount:8,relativeAim:true});
     document.querySelector('#camera-panel').hidden=false;document.body.classList.add('hands-on');document.querySelector('#hand-status').textContent='合成关键点检查 · 非真人摄像头画面';
     drawHandOverlay(document.querySelector('#hand-overlay').getContext('2d'),sample,SPELLS,window.playseedPlayer.snapshot().skillGroup);
     return {nextGroup:sample.nextGroup,selectSlot:sample.selectSlot,cast:sample.cast};
    };
   });
   function hand(x){const h=Array.from({length:21},()=>({x,y:.7,z:0}));h[0]={x,y:.9,z:0};for(let i=0;i<4;i++){const base=5+i*4,px=x+(i-1.5)*.06;for(let j=0;j<4;j++)h[base+j]={x:px,y:.7-j*.15,z:0};}h[1]={x:x-.10,y:.8};h[2]={x:x-.2,y:.7};h[3]={x:x-.26,y:.6};h[4]={x:x-.3,y:.48};return h;}
   const right=hand(.74),left=hand(.35),closed=structuredClone(left);for(const i of [8,12,16,20])closed[i]={x:.35,y:.79,z:0};
   let now=0,count=0;
   const feed=(r,l,delta=100)=>{now+=delta;return page.evaluate(({r,l,now})=>window._qaHandFrame(r,l,now),{r,l,now});};
   await page.keyboard.press('Digit1');const initialAim=await surface.evaluate(()=>window.playseed.snapshot());if(Math.abs(initialAim.aim_x)>0.1||Math.abs(initialAim.aim_z-(initialAim.home_aim_z??(initialAim.layout==='front-fan'?3.5:1.5)))>.1)throw Error('初始落点不在角色附近');
   await page.screenshot({path:path.join(project,'initial-aim.png')});
   await feed(right,left);await page.waitForTimeout(80);const anchored=await surface.evaluate(()=>window.playseed.snapshot());if(Math.abs(anchored.aim_x-initialAim.aim_x)>.1||Math.abs(anchored.aim_z-initialAim.aim_z)>.1)throw Error('舒适入镜导致落点跳跃');
   const shifted=right.map(p=>({...p,x:p.x+.12}));for(let i=0;i<5;i++)await feed(shifted,left);await page.waitForTimeout(220);const moved=await surface.evaluate(()=>window.playseed.snapshot());if(moved.aim_x<initialAim.aim_x+2)throw Error('右手偏移没有推动落点');
   await feed(shifted,left);await page.waitForTimeout(100);const stopped=await surface.evaluate(()=>window.playseed.snapshot());for(let i=0;i<3;i++)await feed(shifted,left);await page.waitForTimeout(100);const settled=await surface.evaluate(()=>window.playseed.snapshot());if(Math.abs(stopped.aim_x-settled.aim_x)>.1)throw Error('右手停住后仍漂移');
   console.log('RELATIVE_AIM_PATH_OK: starts near hero, first frame no jump, displacement moves, offset hold stops');
   if(await page.evaluate(()=>window.playseedPlayer.snapshot().depthAim)){
    const centre=[0,9,13,17].reduce((s,i)=>({x:s.x+shifted[i].x/4,y:s.y+shifted[i].y/4}),{x:0,y:0}),pushed=shifted.map(p=>({...p,x:centre.x+(p.x-centre.x)*1.25,y:centre.y+(p.y-centre.y)*1.25}));
    for(let i=0;i<8;i++)await feed(pushed,left,33);await page.waitForTimeout(220);const far=await surface.evaluate(()=>window.playseed.snapshot());if(far.aim_z>=settled.aim_z-3)throw Error('手向前推没有移到远处');
    for(let i=0;i<10;i++)await feed(shifted,left,33);await page.waitForTimeout(220);const near=await surface.evaluate(()=>window.playseed.snapshot());if(near.aim_z<=far.aim_z+3||Math.abs(near.aim_z-settled.aim_z)>.4)throw Error('手后收没有回到近处');
    console.log('DEPTH_AIM_PATH_OK: closer palm moves to far map, retract returns near without face-height mapping');
   }

   for(let bank=0;bank<2;bank++){
    if(bank){await feed(right,left);await feed(right,closed);await feed(right,closed,400);await surface.waitForFunction(()=>window.playseed.snapshot().skill_group===2);await feed(right,closed,500);if(await surface.evaluate(()=>window.playseed.snapshot().skill_group)!==2)throw Error('持续握拳重复换组');}
    for(let slot=0;slot<4;slot++){
     await feed(right,left);const touch=structuredClone(left);touch[4]={...left[[8,12,16,20][slot]]};
     await feed(right,touch,33);await surface.waitForFunction(n=>window.playseed.snapshot().selected_spell===n,bank*4+slot+1);
     if(await surface.evaluate(()=>window.playseed.snapshot().casts)!==count)throw Error('左手选择时误释放');
     const castHand=structuredClone(right);castHand[4]={...right[8]};await feed(castHand,touch,33);count++;
     await surface.waitForFunction(n=>window.playseed.snapshot().casts===n,count);
     const cast=await surface.evaluate(()=>window.playseed.snapshot());if(cast.selected_spell!==bank*4+slot+1)throw Error('右手释放了错误技能');
     await feed(castHand,touch,33);if(await surface.evaluate(()=>window.playseed.snapshot().casts)!==count)throw Error('合指保持时连发');

    }
   }
   for(let i=0;i<8;i++){await feed(right,left,33);const touch=structuredClone(right);touch[4]={...right[8]};await feed(touch,left,33);count++;await surface.waitForFunction(n=>window.playseed.snapshot().casts===n,count);await feed(touch,left,33);}
   console.log('RAPID_CAST_PATH_OK: 8 quick release/contact cycles, no dwell or cooldown');
   await feed(right,left);await page.screenshot({path:path.join(project,'hands-fixture.png')});
   await feed(null,left);const touch=structuredClone(left);touch[4]={...left[8]};await feed(null,touch);await feed(null,touch,200);
   if(await surface.evaluate(()=>window.playseed.snapshot().casts)!==count)throw Error('右手丢失后仍施法');
   await page.evaluate(()=>{document.querySelector('#camera-panel').hidden=true;document.body.classList.remove('hands-on');delete window._qaHandFrame;});
   await page.locator('#restart').click();await surface.waitForFunction(()=>window.playseed.snapshot().casts===0);
   console.log('HAND_CONTROLS_OK: physical right palm/cast, left 4 selections/fist bank, 16 casts, held/lost safeguards');
  }
  if(mode==='check-follow-smoothing'){
   await page.locator('#restart').click();await surface.waitForFunction(()=>window.playseed.snapshot().casts===0);
   await page.keyboard.press('Digit1');const home=await surface.evaluate(()=>window.playseed.snapshot());
   await page.evaluate(()=>document.querySelector('#stage').contentWindow.postMessage({playseed:true,type:'action',name:'aim',point:{x:110,y:0,relative:true,pressed:true}},'*'));
   const first=await surface.evaluate(()=>window.playseed.snapshot());
   if(first.target_aim_x<=home.aim_x+1||first.aim_x>=first.target_aim_x)throw Error('相对目标没有经过绘制帧平滑');
   await page.waitForTimeout(220);const settled=await surface.evaluate(()=>window.playseed.snapshot());
   if(Math.abs(settled.aim_x-settled.target_aim_x)>.04)throw Error('落点跟随拖尾过长');
   await page.waitForTimeout(150);const held=await surface.evaluate(()=>window.playseed.snapshot());if(Math.abs(held.aim_x-settled.aim_x)>.04)throw Error('停手后仍漂移');
   await page.evaluate(()=>document.querySelector('#stage').contentWindow.postMessage({playseed:true,type:'action',name:'cast1',point:{x:0,y:0,relative:true,pressed:true}},'*'));
   await surface.waitForFunction(()=>window.playseed.snapshot().casts===1);const shot=await surface.evaluate(()=>window.playseed.snapshot());if(Math.abs(shot.aim_x-held.aim_x)>.1)throw Error('合指施法导致落点跳转');
   console.log('FOLLOW_SMOOTHING_OK: separate target, rendered transition, settle, no drift and cast at visible aim');
  }
  if(mode==='check-front'){
   await page.locator('#restart').click();await surface.waitForFunction(()=>window.playseed.snapshot().casts===0);
   const layout=await surface.evaluate(()=>window.playseed.snapshot());
   if(!['front-fan','open-field'].includes(layout.layout)||layout.altar_z<=layout.mage_z||layout.spawn_positions.length!==5||layout.spawn_positions.some(p=>p[1]>=layout.mage_z))throw Error('前方扇区/身后祭坛布局不符');
   await surface.waitForFunction(()=>window.playseed.snapshot().enemies>=5,{},{timeout:20000});
   if(layout.mage_scale!==undefined&&(layout.mage_scale>1.21||layout.enemy_scale<1.7||layout.spawn_positions.some(p=>Math.hypot(p[0],p[1]-layout.mage_z)<32)))throw Error('体型或出生距离未调整');
   const first=await surface.evaluate(()=>window.playseed.snapshot());if(first.enemy_positions.some(p=>p.z>=first.mage_z))throw Error('敌人从身后进入');
   await page.waitForTimeout(1000);const next=await surface.evaluate(()=>window.playseed.snapshot());
   if(Math.hypot(next.enemy_positions[0].x,next.enemy_positions[0].z-next.altar_z)>=Math.hypot(first.enemy_positions[0].x,first.enemy_positions[0].z-first.altar_z))throw Error('敌人没有向身后祭坛前进');
   await page.screenshot({path:path.join(project,'front-attack.png')});
   await surface.waitForFunction(()=>window.playseed.snapshot().health<179,{},{timeout:65000});const attacked=await surface.evaluate(()=>window.playseed.snapshot());
   if(!attacked.enemy_positions.some(p=>Math.hypot(p.x,p.z-attacked.altar_z)<2))throw Error('尚未接近祭坛就开始受击');
   await page.locator('#restart').click();await surface.waitForFunction(()=>window.playseed.snapshot().health===180&&window.playseed.snapshot().enemies===0);
   console.log('FRONT_DEFENSE_OK: five forward entrances, approach altar behind mage, altar damage and reset');
  }
  if(mode==='check-framing'){
   await page.locator('#restart').click();await surface.waitForFunction(()=>window.playseed.snapshot().spawned===0);
   await surface.waitForFunction(()=>window.playseed.snapshot().spawned>=10,{},{timeout:30000});
   const state=await surface.evaluate(()=>window.playseed.snapshot());
   if(!state.random_spawns||state.recent_spawns.length!==10)throw Error('未接通随机出生');
   for(const p of state.recent_spawns){const r=Math.hypot(p.x,p.z-state.mage_z),a=Math.atan2(p.x,state.mage_z-p.z);if(r<41.99||r>48.01||Math.abs(a)>.641)throw Error('出生点离角色太近或出现在身后');}
   if(new Set(state.recent_spawns.map(p=>p.x.toFixed(3))).size!==10)throw Error('出生点重复固定');
   await page.screenshot({path:path.join(project,'random-attack.png')});
   await page.locator('#restart').click();await surface.waitForFunction(()=>window.playseed.snapshot().spawned===0);await surface.waitForFunction(()=>window.playseed.snapshot().spawned>=1,{},{timeout:8000});
   const restart=await surface.evaluate(()=>window.playseed.snapshot());if(JSON.stringify(restart.recent_spawns[0])===JSON.stringify(state.recent_spawns[0]))throw Error('重开仍重复同一出生点');
   fs.writeFileSync(path.join(project,'spawn-evidence.json'),JSON.stringify({first:state.recent_spawns,restart:restart.recent_spawns}));
   console.log('RANDOM_SPAWNS_OK: 10 distinct distant frontal points; fresh random layout on restart');
  }
  if(mode==='check-view-control'||mode==='check-framing'){
   await page.locator('#restart').click();await surface.waitForFunction(()=>window.playseed.snapshot().casts===0&&!window.playseed.snapshot().has_selection);await page.keyboard.press('Digit1');
   const snap=()=>surface.evaluate(()=>window.playseed.snapshot()),send=async(x,y)=>{await page.evaluate(({x,y})=>document.querySelector('#stage').contentWindow.postMessage({playseed:true,type:'action',name:'aim',point:{x,y,relative:true,pressed:true}},'*'),{x,y});await page.waitForTimeout(100);};
   const home=await snap();if(mode==='check-framing'?(home.camera_pitch<17||home.camera_pitch>20):(home.camera_pitch>15||home.camera_height>10))throw Error('镜头俯角不符');if(Number(await page.locator('#aim-speed').inputValue())!==.6)throw Error('默认灵敏度未降低');
   await send(20,-20);const near=await snap();if(Math.abs(near.target_aim_x-home.target_aim_x-1.5)>.01||Math.abs(near.target_aim_z-home.target_aim_z+2)>.01)throw Error('小幅瞄准变化过大');
   await send(0,-110);await send(0,-110);const far=await snap();await send(20,-20);const moved=await snap();if(Math.abs(moved.target_aim_x-far.target_aim_x-1.5)>.01||Math.abs(moved.target_aim_z-far.target_aim_z+2)>.01)throw Error('远处瞄准速度失控');
   await page.waitForTimeout(250);const held=await snap();await page.waitForTimeout(150);if(Math.abs((await snap()).aim_z-held.aim_z)>.02)throw Error('停手后漂移');
   await page.keyboard.press('Digit4');await send(0,-110);await send(0,-70);await page.waitForTimeout(150);await page.keyboard.press('Space');await page.waitForTimeout(1000);const finish=await snap();if(!(mode==='check-framing'?finish.spike_finish:finish.pillar_finish)||finish.last_cast.index!==3)throw Error('突刺终点不符');await page.screenshot({path:path.join(project,mode==='check-framing'?'spike-view.png':'pillar-low-view.png')});
   console.log('VIEW_CONTROL_OK: requested camera pitch, default 0.6 gain, identical near/far world displacement, stop and earth finisher');
  }
  if(mode==='check-persistent-limits'){
   for(const [slot,index,limit] of [[1,4,3],[2,5,3],[3,6,2],[4,7,1]]){
    await page.locator('#restart').click();await surface.waitForFunction(()=>window.playseed.snapshot().casts===0&&window.playseed.snapshot().skill_group===1&&!window.playseed.snapshot().has_selection);await page.keyboard.press('KeyQ');await surface.waitForFunction(()=>window.playseed.snapshot().skill_group===2);await page.keyboard.press('Digit'+slot);await surface.waitForFunction(n=>window.playseed.snapshot().selected_spell===n,index+1);
    for(let i=0;i<limit+1;i++)await page.keyboard.press('Space');
    const state=await surface.evaluate(()=>window.playseed.snapshot());const visible=state.visuals.filter(v=>v.index===index);if(visible.length!==limit)throw Error('持续特效与数量限制不符 '+JSON.stringify({index,limit,casts:state.casts,selected:state.selected_spell,visible,zones:state.zones}));
    if(index!==7&&state.zones.filter(z=>z.index===index).length!==limit)throw Error('持续区域与特效数量不同');
    if(visible.some(v=>v.left<state.spell_rules[index].duration-1))throw Error('新施法错误地提前结束其他持续特效');
   }
   console.log('PERSISTENT_LIMITS_OK: replacement keeps flower/swamp/hole/ward visuals and lifetimes aligned');
  }
  if(mode==='check-wide-chain'){
   await page.locator('#restart').click();await page.keyboard.press('Digit2');await surface.waitForFunction(()=>window.playseed.snapshot().enemies>=5,{},{timeout:15000});
   const state=await surface.evaluate(()=>window.playseed.snapshot()),e=state.enemy_positions[0],box=await surface.locator('canvas').boundingBox();await page.mouse.click(box.x+e.sx/960*box.width,box.y+e.sy/600*box.height);
   const hit=await surface.evaluate(()=>window.playseed.snapshot());if(hit.last_chain.length<3)throw Error('分散敌人未被广域连锁');let longest=0;for(let i=1;i<hit.last_chain.length;i++)longest=Math.max(longest,Math.hypot(hit.last_chain[i].x-hit.last_chain[i-1].x,hit.last_chain[i].z-hit.last_chain[i-1].z));if(longest<8)throw Error('雷电仍只在极小距离传播');
   await page.screenshot({path:path.join(project,'wide-chain.png')});console.log('WIDE_CHAIN_OK',JSON.stringify({targets:hit.last_chain.length,longestJump:longest}));
  }
  if(mode==='check-spell-design'){
   const box=await surface.locator('canvas').boundingBox();const snap=()=>surface.evaluate(()=>window.playseed.snapshot());
   const click=async(x,z)=>{await page.evaluate(({x,z})=>document.querySelector('#stage').contentWindow.postMessage({playseed:true,type:'action',name:'aim',point:{x,y:z,relative:true,pressed:true}},'*'),{x,z});};
   await page.locator('#restart').click();const empty=await snap();if(empty.has_selection||empty.range_visible||empty.selected_spell!==0)throw Error('开场不应选择技能或显示范围');
   await page.mouse.click(box.x+box.width*.5,box.y+box.height*.5);if((await snap()).casts)throw Error('未选择技能误释放');
   await page.keyboard.press('Digit1');let a=await snap();if(!a.range_visible||a.range_radius!==7||a.aim_z!==a.mage_z)throw Error('范围未从脚下出现');
   await click(0,-110);await page.waitForTimeout(220);a=await snap();if(a.aim_z>=a.mage_z-2)throw Error('前推方向错误');
   await page.screenshot({path:path.join(project,'range-circle.png')});
   await page.keyboard.press('Digit4');await click(60,-110);await page.waitForTimeout(220);a=await snap();if(a.range_shape!=='line'||a.range_radius!==3)throw Error('突刺没有直道范围');await page.screenshot({path:path.join(project,'range-line.png')});
   await page.keyboard.press('Digit3');await surface.waitForFunction(()=>window.playseed.snapshot().enemies>0,{},{timeout:10000});const enemy=(await snap()).enemy_positions[0];await page.mouse.click(box.x+enemy.sx/960*box.width,box.y+enemy.sy/600*box.height);await page.waitForTimeout(150);const frozen=(await snap()).enemy_positions[0];
   if(frozen.freeze<6||frozen.hp!==48)throw Error('冰冻应少量伤害并控制7秒');await page.waitForTimeout(2300);const held=(await snap()).enemy_positions[0];if(Math.hypot(held.x-frozen.x,held.z-frozen.z)>.01||held.freeze<3||held.animation_phase!==frozen.animation_phase)throw Error('冰冻敌人提前移动');
   await page.locator('#restart').click();await page.keyboard.press('KeyQ');await page.keyboard.press('Digit1');await page.keyboard.press('Space');await page.keyboard.press('Digit2');await page.keyboard.press('Space');await page.keyboard.press('Digit4');await page.keyboard.press('Space');
   a=await snap();if(a.ward_seconds<14||Math.abs(a.ward_centre_z-a.mage_z)>a.range_radius||Math.abs(a.ward_centre_z-a.altar_z)>a.range_radius)throw Error('护盾没有覆盖法师与祭坛');
   await page.waitForTimeout(5000);a=await snap();if(!a.zones.some(z=>z.index===4&&z.left>19)||!a.zones.some(z=>z.index===5&&z.left>14)||a.ward_seconds<9)throw Error('持续技能仍过短');
   if(!a.visuals.some(v=>v.index===4&&v.left>19)||!a.visuals.some(v=>v.index===5&&v.left>14))throw Error('持续技能效果提前消失');await page.screenshot({path:path.join(project,'persistent-defence.png')});
   await page.waitForTimeout(15500);a=await snap();if(a.ward_seconds>0||a.zones.some(z=>z.index===5)||!a.zones.some(z=>z.index===4&&z.left>3))throw Error('持续技能到期时间不符');
   await page.waitForTimeout(5000);a=await snap();if(a.zones.some(z=>[4,5].includes(z.index))||a.visuals.some(v=>[4,5,7].includes(v.index)))throw Error('到期效果或伤害实体未清理');
   await page.locator('#restart').click();a=await snap();if(a.has_selection||a.range_visible||a.visuals.length||a.zones.length||a.ward_seconds)throw Error('重开残留');
   console.log('SPELL_DESIGN_OK: no initial range, selection at feet, circle/line, freeze stops 7s, 25s flower / 20s swamp / 15s ward and lifecycle');
  }
  if(mode==='check-far-aim'){
   const box=await surface.locator('canvas').boundingBox();
   await surface.waitForFunction(()=>window.playseed.snapshot().enemies>=5,{},{timeout:20000});
   const state=await surface.evaluate(()=>window.playseed.snapshot());
   for(const enemy of state.enemy_positions){
    if(enemy.sx<15||enemy.sx>945||enemy.sy<15||enemy.sy>585)throw Error('远处敌人超出可视画面');
    await page.mouse.move(box.x+enemy.sx/960*box.width,box.y+enemy.sy/600*box.height);await page.waitForTimeout(180);
    const aimed=await surface.evaluate(()=>window.playseed.snapshot());if(Math.hypot(aimed.aim_x-enemy.x,aimed.aim_z-enemy.z)>.3)throw Error('远处落点被限制或偏移');
   }
   await page.screenshot({path:path.join(project,'far-field.png')});
   console.log('FAR_AIM_OK: all five remote lanes visible and individually targetable');
  }
  if(mode==='check-endless'||mode==='check-endless-death'){
   await page.locator('#restart').click();
   await surface.waitForFunction(()=>window.playseed.snapshot().spawned===0&&window.playseed.snapshot().selected_spell===0);
   const read=()=>surface.evaluate(()=>window.playseed.snapshot());
   const start=await read();
   if(!start.endless||start.spawn_interval!==1.35||start.enemy_stats.hp!==60||start.enemy_stats.speed!==.795||start.enemy_stats.damage_per_second!==4.8)throw Error('无尽模式初始配置异常');
   if(mode==='check-endless'){
    await page.keyboard.press('Digit2');
    await surface.waitForFunction(()=>window.playseed.snapshot().selected_spell===2);
    const box=await surface.locator('canvas').boundingBox(),deadline=Date.now()+130000;
    let state=start,observed=0;
    while(Date.now()<deadline){
     state=await read();
     if(state.won||state.lost)throw Error('无尽防守意外结束 '+JSON.stringify(state));
     if(state.enemy_positions.some(e=>e.max_hp!==60)||JSON.stringify(state.enemy_stats)!==JSON.stringify(start.enemy_stats))throw Error('敌人随进度变强');
     const expected=state.elapsed_seconds<3?0:Math.floor((state.elapsed_seconds-3)/1.35)+1;
     if(Math.abs(state.spawned-expected)>1)throw Error('出怪节奏改变或出现轮次休整');
     if(state.kills>=45)break;
     if(state.enemy_positions.length){const e=state.enemy_positions[0];observed++;await page.mouse.click(box.x+e.sx/960*box.width,box.y+e.sy/600*box.height);}
     await page.waitForTimeout(140);
    }
    if(state.kills<45||observed<45)throw Error('未验证超过原40敌人的连续实战 '+JSON.stringify(state));
    const checkpoint={kills:state.kills,spawned:state.spawned,elapsed:state.elapsed_seconds};
    await page.locator('#pause').click();
    await page.waitForFunction(()=>window.playseedPlayer.snapshot().paused);
    const paused=await read();await page.keyboard.press('Space');await page.waitForTimeout(1800);
    if(JSON.stringify(paused)!==JSON.stringify(await read()))throw Error('暂停时仍在推进或施法');
    await page.locator('#pause').click();
    await surface.waitForFunction(n=>window.playseed.snapshot().spawned>=n,checkpoint.spawned+3,{timeout:15000});
    const resumed=await read();
    if(resumed.won||resumed.lost||resumed.enemy_positions.some(e=>e.max_hp!==60))throw Error('继续防守异常');
    const hud=await surface.locator('#hud').textContent();
    if(!hud.includes('无尽防守')||!hud.includes('坚持')||/三波|\/3 波|\/40|待出现/.test(hud))throw Error('界面仍显示轮次终点');
    fs.writeFileSync(path.join(project,'endless-evidence.json'),JSON.stringify({checkpoint,resumed,hud},null,2));
    await page.screenshot({path:path.join(project,'endless.png')});
    console.log('ENDLESS_OK: 45 real kills, fixed pace/stats, pause freezes, resume spawns 3 more');
   }else{
    await surface.waitForFunction(()=>window.playseed.snapshot().lost,{},{timeout:110000});
    const dead=await read();
    if(dead.health!==0||dead.won)throw Error('守护值耗尽没有正确结束');
    await page.keyboard.press('Digit2');await page.keyboard.press('Space');await page.waitForTimeout(2000);
    const stopped=await read();
    for(const key of ['spawned','kills','casts','elapsed_seconds','health','enemies'])if(dead[key]!==stopped[key])throw Error('死亡后仍推进 '+key);
    fs.writeFileSync(path.join(project,'endless-death-evidence.json'),JSON.stringify({dead,stopped},null,2));
    console.log('ENDLESS_DEATH_OK: natural altar damage reaches zero; spawning, time and casting stop');
   }
   await page.keyboard.press('KeyR');
   await surface.waitForFunction(()=>window.playseed.snapshot().spawned===0&&window.playseed.snapshot().selected_spell===0);
   const clean=await read();
   if(clean.won||clean.lost||clean.health!==180||clean.kills||clean.enemies||clean.casts||clean.elapsed_seconds>.5)throw Error('无尽模式重开未清理');
  }
  if(mode==='check-battle'){
   await page.locator('#restart').click();await surface.waitForFunction(()=>window.playseed.snapshot().casts===0);
   await page.keyboard.press('KeyQ');await page.keyboard.press('Digit3');
   const box=await surface.locator('canvas').boundingBox(),deadline=Date.now()+110000;let state;
   while(Date.now()<deadline){
    state=await surface.evaluate(()=>window.playseed.snapshot());if(state.won||state.lost)break;
    if(state.enemy_positions.length){const e=state.enemy_positions[0];await page.mouse.click(box.x+e.sx/960*box.width,box.y+e.sy/600*box.height);}
    await page.waitForTimeout(180);
   }
   if(!state?.won||state.kills!==40)throw Error('三波实战未通关 '+JSON.stringify(state));
   await page.screenshot({path:path.join(project,'victory.png')});
   await page.keyboard.press('KeyR');await surface.waitForFunction(()=>window.playseed.snapshot().casts===0);
   const clean=await surface.evaluate(()=>window.playseed.snapshot());if(clean.won||clean.lost||clean.health!==180)throw Error('通关后重开异常');
   console.log('BATTLE_OK: 40 enemies defeated with real aiming/casting, victory and keyboard reset');
  }
  if(mode==='check-feel'){
   if(initial.arena_radius<17)throw Error('竞技场范围没有扩大');
   const box=await surface.locator('canvas').boundingBox();
   const perf=await surface.evaluate(()=>new Promise(resolve=>{let frames=0;const start=performance.now();function tick(){frames++;if(performance.now()-start>=2000)resolve({frames,ms:performance.now()-start});else requestAnimationFrame(tick);}requestAnimationFrame(tick);}));console.log('RENDER_SAMPLE',JSON.stringify(perf));
   for(let bank=0;bank<2;bank++){
    for(let slot=0;slot<4;slot++){
     await page.locator('#restart').click();await surface.waitForFunction(()=>window.playseed.snapshot().casts===0&&window.playseed.snapshot().skill_group===1);if(bank)await page.keyboard.press('KeyQ');
     await page.keyboard.press('Digit'+(slot+1));
     await page.mouse.move(box.x+box.width*.67,box.y+box.height*.55);
     const beforeCast=await surface.evaluate(()=>window.playseed.snapshot());
     await page.keyboard.press('Space');await page.keyboard.press('Space');
     const doubleCast=await surface.evaluate(()=>window.playseed.snapshot());
     if(doubleCast.casts!==beforeCast.casts+2||doubleCast.cooldowns.some(v=>v!==0))throw Error('技能仍有冷却限制');
     if(doubleCast.selected_spell!==bank*4+slot+1)throw Error('技能组与释放技能不符 '+JSON.stringify({bank,slot,doubleCast}));
     await surface.waitForFunction(()=>window.playseed.snapshot().pose.arm>.3,{},{timeout:2000});
     const animated=await surface.evaluate(()=>window.playseed.snapshot());
     if(animated.pose.arm<.3)throw Error('施法没有角色动作');
     await surface.waitForFunction(()=>window.playseed.snapshot().pose.age>=.32,{},{timeout:15000});
     await page.screenshot({path:path.join(project,'spell-'+(bank*4+slot+1)+'.png')});
    }
   }
   // Holding emits repeated attacks; releasing/pause stops them, regardless of cooldown.
   const count=await surface.evaluate(()=>window.playseed.snapshot().casts);
   await page.mouse.down();await page.waitForTimeout(900);await page.mouse.up();
   if(await surface.evaluate(()=>window.playseed.snapshot().casts)<=count+2)throw Error('按住施法没有连续释放');
   await page.locator('#pause').click();
   const frozen=await surface.evaluate(()=>window.playseed.snapshot());
   await page.keyboard.press('Space');await page.keyboard.press('KeyQ');await page.waitForTimeout(200);
   if(JSON.stringify(frozen)!==JSON.stringify(await surface.evaluate(()=>window.playseed.snapshot())))throw Error('暂停未锁住技能与动作');
   await page.locator('#restart').click();
   const clean=await surface.evaluate(()=>window.playseed.snapshot());
   if(clean.casts||clean.active_effects||clean.skill_group!==1||clean.pose.arm!==-.12)throw Error('重开没有清理技能组/动作/特效');
   console.log('FEEL_OK: eight spells, no cooldown, larger arena, casting animation, hold, pause and reset');
  }
  if(mode==='check-showcase'){
   await page.locator('#pause').click();
   const frozen=await surface.evaluate(()=>window.playseed.snapshot());
   await surface.locator('canvas').click({position:{x:850,y:400}});
   await page.waitForTimeout(150);
   if(JSON.stringify(frozen)!==JSON.stringify(await surface.evaluate(()=>window.playseed.snapshot())))throw Error('暂停时仍响应施法或时间推进');
   await page.locator('#pause').click();
   if(gestureOnly){await selectHand(page,2);await castHand(page);}else{await page.keyboard.press('Digit3');await surface.locator('canvas').click({position:{x:850,y:400}});}
   await page.waitForTimeout(170);
   const sound=await page.evaluate(()=>window.playseedPlayer.snapshot());
   if(sound.audioState!=='running'||sound.sounds<2||sound.audioEnergy<=0)throw Error('真实施法没有音频信号');
   await page.locator('#sound').click();
   if(await page.evaluate(()=>window.playseedPlayer.snapshot().audio))throw Error('声音没有关闭');
   if(gestureOnly)await page.locator('#restart').click();else await page.keyboard.press('KeyR');
   console.log('SHOWCASE_PAUSE_AUDIO_RESET_OK');
  }
  const reset=await surface.evaluate(()=>{window.playseed.reset();return window.playseed.snapshot();});
  if(reset.won||reset.lost||reset.progress!==initial.progress||JSON.stringify(reset[field])!==JSON.stringify(initial[field]))throw Error('重开未恢复初始状态');
  const lifecycle=mode==='check'&&wrapped&&await page.evaluate(()=>window.playseedPlayer.snapshot().lifecycleChecks===true)?await checkLifecycle({page,surface,probe:config.test,input:performInput}):null;
  const gameErrors=await surface.evaluate(()=>window.playseed.errors);
  if(errors.length||gameErrors.length)throw Error([...errors,...gameErrors].join('\n'));
  await page.screenshot({path:path.join(project,'preview.png')});
  if(wrapped){const state=await page.evaluate(()=>window.playseedPlayer.snapshot());if(!state.ready||!state.started||(!gestureOnly&&state.camera))throw Error('试玩宿主状态无效或摄像头自动开启');}
  if(report)fs.writeFileSync(report,JSON.stringify({ok:true,initial,before,after,reset,lifecycle,input_method:gestureOnly?'synthetic-hand-landmarks':'mouse-keyboard',validation:'Chromium sandbox, restricted network, real UI input, '+(gestureOnly?'synthetic hand landmarks, ':'')+'reset'+(lifecycle?', pause/resume and two restart replays':'')}));
  console.log('PLAYSEED_WEB_CHECK_OK');
 }
}finally{if(browser?.isConnected())await browser.close();server.close();}
