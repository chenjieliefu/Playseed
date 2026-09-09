import createGame from './game.js';
const canvas=document.querySelector('#game'),hud=document.querySelector('#hud'),help=document.querySelector('#help');
const embedded=parent!==window,errors=[];let spellIds=null,spellSelection=null;
const notify=(type,extra={})=>{if(embedded)parent.postMessage({playseed:true,type,...extra},'*');};
function fail(message){errors.push(String(message));const box=document.querySelector('#error');box.hidden=false;box.textContent='游戏运行出现问题，原版本保留。\n'+message;notify('error');}
addEventListener('error',e=>fail(e.message));addEventListener('unhandledrejection',e=>fail(e.reason));
try{
 const config=await(await fetch('./web.json')).json();
 const THREE=config.dimension==='3d'?await import('./vendor/three.module.js'):null;
 const components=THREE?await import('./components.js'):null;
 const assets={};
 await Promise.all(config.images.map(id=>new Promise((resolve,reject)=>{const img=new Image();img.crossOrigin='anonymous';img.onload=()=>{assets[id]=img;resolve();};img.onerror=()=>reject(new Error('图片加载失败 '+id));img.src='./assets/'+id+'.png';})));
 let paused=false,aim={x:480,y:300},keysDown=new Set();
 const game=await createGame({canvas,THREE,assets,width:960,height:600,hud:text=>hud.textContent=String(text),components,spellbook:ids=>{spellIds=ids;help.hidden=true;notify('spellbook',{ids});},spellState:(group,slot)=>{spellSelection={group,slot};notify('spell-state',spellSelection);},sound:name=>notify('sound',{name:String(name)})});
 for(const name of ['update','render','action','snapshot','reset'])if(typeof game[name]!=='function')throw new Error('缺少接口 '+name);
 help.textContent=config.controls.join(' · ');
 if(typeof game.resize==='function'){document.documentElement.classList.add('responsive-game');const resize=()=>game.resize(innerWidth,innerHeight,devicePixelRatio||1);new ResizeObserver(resize).observe(document.body);addEventListener('resize',resize);resize();}
 function action(name,p={...aim,pressed:true}){if(game.gestureOnly===true&&p.source!=='gesture')return;if(paused&&p.pressed)return;if(name==='aim'&&!p.relative)aim={x:p.x,y:p.y};game.action(name,p);}
 function release(){for(const name of keysDown)game.action(name,{...aim,pressed:false});keysDown.clear();game.action('primary',{...aim,pressed:false});}
 function pause(value){paused=value;if(paused)release();notify('pause-state',{paused});}
 function reset(){notify('reset-state');release();game.reset();pause(game.gestureOnly===true);game.render();}
 function point(e){const r=canvas.getBoundingClientRect();return {x:(e.clientX-r.left)/r.width*960,y:(e.clientY-r.top)/r.height*600,pressed:true};}
 canvas.addEventListener('pointerdown',e=>{if(game.gestureOnly===true)return;canvas.setPointerCapture(e.pointerId);action('primary',point(e));});
 canvas.addEventListener('pointermove',e=>action('aim',point(e)));
 canvas.addEventListener('pointerup',e=>action('primary',{...point(e),pressed:false}));
 canvas.addEventListener('pointercancel',release);
 const keys={Space:'primary',ArrowLeft:'left',KeyA:'left',ArrowRight:'right',KeyD:'right',ArrowUp:'up',KeyW:'up',ArrowDown:'down',KeyS:'down',Digit1:'spell1',Digit2:'spell2',Digit3:'spell3',Digit4:'spell4',KeyQ:'nextgroup'};
 addEventListener('keydown',e=>{if(game.gestureOnly===true||e.repeat)return;if(e.code==='KeyF'){notify('fullscreen-request');return;}if(e.code==='KeyR'){reset();return;}if(e.code==='Escape'){pause(!paused);return;}if(keys[e.code]){e.preventDefault();keysDown.add(keys[e.code]);action(keys[e.code]);}});
 addEventListener('keyup',e=>{if(game.gestureOnly===true)return;if(keys[e.code]){keysDown.delete(keys[e.code]);action(keys[e.code],{...aim,pressed:false});}});
 addEventListener('blur',release);
 document.querySelector('#reset').onclick=reset;
 if(embedded)document.querySelector('#reset').hidden=true;
 addEventListener('message',e=>{
  if(!embedded||e.source!==parent||!e.data?.playseed)return;const d=e.data;
  if(d.type==='hello'){notify('ready',{lifecycleChecks:true,relativeAim:game.relativeAim===true,depthAim:game.depthAim===true,gestureOnly:game.gestureOnly===true});if(spellIds)notify('spellbook',{ids:spellIds});if(spellSelection)notify('spell-state',spellSelection);}
  if(d.type==='pause'&&typeof d.paused==='boolean')pause(d.paused);
  if(d.type==='reset')reset();
  if(d.type==='recenter-aim'&&game.relativeAim===true)action('aimhome',{x:0,y:0,pressed:true,source:'gesture'});
  if(d.type==='action'&&['aim','primary','spell1','spell2','spell3','spell4','nextgroup','cast1','cast2','cast3','cast4'].includes(d.name)&&d.point&&Number.isFinite(d.point.x)&&Number.isFinite(d.point.y))action(d.name,{x:Math.max(d.point.relative===true&&game.relativeAim===true?-120:0,Math.min(d.point.relative===true&&game.relativeAim===true?120:960,d.point.x)),y:Math.max(d.point.relative===true&&game.relativeAim===true?-120:0,Math.min(d.point.relative===true&&game.relativeAim===true?120:600,d.point.y)),source:d.source==='gesture'?'gesture':'controls',relative:d.point.relative===true&&game.relativeAim===true,pressed:d.point.pressed===true});
 });
 reset();if(embedded||game.gestureOnly===true)pause(true);
 let previous=performance.now();
 function tick(now){const dt=Math.min(.04,(now-previous)/1000);previous=now;if(!paused)game.update(dt);game.render();requestAnimationFrame(tick);}
 requestAnimationFrame(tick);
 window.playseed={snapshot:()=>JSON.parse(JSON.stringify(game.snapshot())),reset,errors};notify('ready',{lifecycleChecks:true,relativeAim:game.relativeAim===true,depthAim:game.depthAim===true,gestureOnly:game.gestureOnly===true});
}catch(e){fail(e.message);}
