import {HandTracker} from './hand-tracker.mjs';
import {GameAudio} from './audio.js';
import {GestureMapping} from './gesture-mapping.mjs';
import {SPELLS,drawSpellIcon} from './spellbook.mjs';
import {dispatchGesture} from './gesture-controls.mjs';
import {drawHandOverlay} from './hand-overlay.mjs';
import {captureConstraints,frameSize,widenTrack} from './camera-framing.mjs';
const $=id=>document.getElementById(id),stage=$('stage'),audio=new GameAudio(),mapping=new GestureMapping();
let lifecycleChecks=false,gestureOnly=false,relativeAim=false,ready=false,started=false,paused=false,stream=null,landmarker=null,enabled=false,starting=false,lastFrame=-1,lastDetect=0,generation=0;
const send=(type,extra={})=>{if(type==='action'&&gestureOnly&&(!enabled||!started||paused||extra.source!=='gesture'))return;stage.contentWindow.postMessage({playseed:true,type,...extra},'*');};
let book=[],group=0,selectedSlot=-1;
let framing=null;
const overlay=$('hand-overlay').getContext('2d');
function syncCameraFrame(){
 const video=$('camera'),size=frameSize(video.videoWidth,video.videoHeight);
 overlay.canvas.width=size.width;overlay.canvas.height=size.height;
 document.querySelector('.camera-view').style.aspectRatio=size.width+'/'+size.height;
 $('camera-framing').textContent='完整画面 '+video.videoWidth+'×'+video.videoHeight+(framing?.zoomAtMinimum?' · 已调至最广变焦':' · 镜头未提供可用的广角调节');
}
$('camera').addEventListener('resize',syncCameraFrame);
function drawBook(){
 $('skillbar').hidden=!started||!book.length; $('skill-group').textContent='技能组 '+(group+1)+' / '+Math.ceil(book.length/4);
 for(let i=0;i<4;i++){const button=$('slot-'+i),spell=book[group*4+i];button.hidden=!spell;button.disabled=gestureOnly;if(!spell)continue;button.classList.toggle('selected',selectedSlot===i);const ctx=button.querySelector('canvas').getContext('2d');ctx.clearRect(0,0,40,40);drawSpellIcon(ctx,spell.icon,20,20,27,spell.color);button.querySelector('span').textContent=(i+1)+' '+spell.name;}
}
$('next-group').onclick=()=>{send('action',{name:'nextgroup',point:{x:480,y:300,pressed:true}});focusGame();};
for(let i=0;i<4;i++)$('slot-'+i).onclick=()=>{send('action',{name:'spell'+(i+1),point:{x:480,y:300,pressed:true}});focusGame();};
const notice=text=>$('notice').textContent=text;
function setPause(value){value=value||(gestureOnly&&!enabled);paused=value;$('paused').textContent=gestureOnly&&!enabled?'手势未就绪 · 请恢复摄像头':'已暂停 · 点击「继续」返回游戏';mapping.reset();send('pause',{paused});$('pause').textContent=value?'继续':'暂停';$('paused').hidden=!value||!started;}
function focusGame(){stage.contentWindow.focus();}
async function start(){
 if(starting){stopCamera();notice('已取消准备，点击开始可重试。');return;}
 if(!ready)return;
 try{await audio.enable();$('sound').textContent='关闭声音';}catch{notice('声音未能启动，可以稍后点击开启声音。');}
 if(gestureOnly&&!enabled){$('start').textContent='正在准备手势 · 点击取消';if(!await startCamera())return;}
 started=true;drawBook();$('welcome').hidden=true;setPause(false);audio.play('start');focusGame();
}
$('start').onclick=start;
$('exit-preview').onclick=()=>{stopCamera();audio.mute();if(typeof window.playseedClosePreview==='function')window.playseedClosePreview();else{setPause(true);notice('试玩已停止，可以关闭这个网页。');}};
async function fullScreen(){try{if(document.fullscreenElement)await document.exitFullscreen();else await document.documentElement.requestFullscreen();}catch{notice('可使用浏览器的全屏菜单，游戏会随窗口自动调整。');}focusGame();}
$('fullscreen').onclick=fullScreen;addEventListener('fullscreenchange',()=>{$('fullscreen').textContent=document.fullscreenElement?'退出全屏':'全屏';});
$('pause').onclick=()=>{if(started){setPause(!paused);focusGame();}};
$('restart').onclick=()=>{send('reset');if(started)setPause(false);focusGame();};
$('sound').onclick=async()=>{if(audio.enabled){audio.mute();$('sound').textContent='开启声音';}else{try{await audio.enable();$('sound').textContent='关闭声音';audio.play('start');}catch{notice('此浏览器暂时无法播放声音。');}}focusGame();};
$('aim-speed').oninput=e=>{$('aim-speed-value').textContent=Number(e.target.value).toFixed(1)+'×';};
$('volume').oninput=e=>audio.volume=Number(e.target.value)/100;
addEventListener('message',e=>{
 if(e.source!==stage.contentWindow||!e.data?.playseed)return;const d=e.data;
 if(d.type==='spellbook'&&Array.isArray(d.ids)){book=d.ids.slice(0,12).filter(i=>Number.isInteger(i)&&i>=0&&i<SPELLS.length).map(i=>SPELLS[i]);group=0;drawBook();}
 if(d.type==='spell-state'&&Number.isInteger(d.group)&&Number.isInteger(d.slot)&&d.slot>=-1&&d.slot<4&&d.group>=0&&d.group<Math.ceil(book.length/4)){group=d.group;selectedSlot=Math.max(-1,Math.min(3,d.slot));drawBook();}
 if(d.type==='fullscreen-request')fullScreen();
 if(d.type==='reset-state')mapping.reset();
 if(d.type==='ready'){lifecycleChecks=d.lifecycleChecks===true;gestureOnly=d.gestureOnly===true;document.body.classList.toggle('gesture-only',gestureOnly);$('next-group').disabled=gestureOnly;$('next-group').textContent=gestureOnly?'左手握拳换组':'换组 · Q';document.querySelector('#skillbar>p').textContent=gestureOnly?'左手四指选技能 · 右手合指释放':'1～4 选技能 · 点击 / 空格释放 · 无冷却';document.querySelector('.intro .small').textContent=gestureOnly?'点击开始后允许摄像头，手势准备好才会出怪。':'先用鼠标和键盘试玩，也可以在右上方开启手势。';$('start').textContent=gestureOnly?'开启摄像头并开始':'开始游戏';drawBook();relativeAim=d.relativeAim===true;mapping.depthAim=d.depthAim===true;if(relativeAim)$('hand-help').textContent='先选技能；右手左右移动、前推放远、后收放近，拇指碰食指释放，松开可立即再发。左手拇指碰四指选技能，握拳换组。右手移出再入镜可重新定位起点。画面仅在本机处理。';ready=true;$('start').disabled=false;}
 if(d.type==='pause-state'){if(paused!==(d.paused===true))mapping.reset();paused=d.paused===true;$('pause').textContent=paused?'继续':'暂停';$('paused').hidden=!paused||!started;}
 if(d.type==='sound'&&started&&!paused&&typeof d.name==='string')audio.play(d.name);
 if(d.type==='error')notice('游戏出现问题，请重开或回到 Playseed 查看记录。');
});
const config=await(await fetch('./web.json')).json();$('title').textContent=config.title||'Playseed 小游戏';document.title=(config.title||'Playseed')+' · 网页试玩';$('intro-controls').textContent=config.controls.join(' · ');
// A ready frame can finish before this module starts listening.
send('hello');
function stopCamera(){generation++;enabled=false;if(gestureOnly)setPause(true);starting=false;if(stream)stream.getTracks().forEach(t=>t.stop());stream=null;framing=null;$('camera').srcObject=null;landmarker?.close();landmarker=null;mapping.reset();overlay.clearRect(0,0,overlay.canvas.width,overlay.canvas.height);$('camera-panel').hidden=true;document.body.classList.remove('hands-on');$('gesture').disabled=false;$('gesture').textContent=gestureOnly?'恢复手势':'开启手势';$('start').textContent=gestureOnly?'开启摄像头并开始':'开始游戏';}
$('gesture').onclick=async()=>{if(enabled||starting){stopCamera();return;}await startCamera();};
async function startCamera(){
 if(starting)return false;starting=true;const ticket=++generation;$('gesture').textContent='取消手势准备';notice('');if(started)setPause(true);
 try{
  // This is the only camera request, directly following the user's button click.
  const acquired=await navigator.mediaDevices.getUserMedia(captureConstraints(navigator.mediaDevices.getSupportedConstraints()));
  if(ticket!==generation){acquired.getTracks().forEach(t=>t.stop());return false;}stream=acquired;acquired.getVideoTracks()[0].addEventListener('ended',()=>{if(ticket===generation){stopCamera();notice(gestureOnly?'摄像头已断开，游戏已暂停。恢复手势后继续。':'摄像头已断开，仍可用鼠标键盘试玩。');}});
  const acquiredFraming=await widenTrack(acquired.getVideoTracks()[0]);
  if(ticket!==generation){acquired.getTracks().forEach(t=>t.stop());return false;}
  framing=acquiredFraming;
  $('camera-panel').hidden=false;document.body.classList.add('hands-on');$('camera').srcObject=stream;await $('camera').play();
  if(ticket!==generation)return false;
  syncCameraFrame();$('hand-status').textContent='正在加载本机手势识别…';
  const detector=new HandTracker();landmarker=detector;await detector.start();
  if(ticket!==generation){detector.close();return false;}landmarker=detector;detector.onResult=handleHands;detector.onError=()=>{stopCamera();notice(gestureOnly?'手势识别已停止，游戏已暂停。点击恢复手势重试。':'手势识别已停止，鼠标键盘仍可使用。');};mapping.reset();enabled=true;starting=false;lastFrame=-1;$('gesture').textContent='关闭手势';$('hand-status').textContent='右手舒适入镜作为起点，移动手掌带动落点，停手即停';if(started)setPause(false);if(relativeAim)send('recenter-aim');focusGame();return true;
 }catch(e){if(ticket!==generation)return false;stopCamera();notice(gestureOnly?(e.name==='NotAllowedError'?'请允许摄像头后重试；游戏尚未开始或已暂停。':'手势暂时无法启动，游戏保持暂停。请检查摄像头后重试。'):(e.name==='NotAllowedError'?'摄像头未获允许，仍可用鼠标键盘试玩。':'手势暂时无法启动，仍可用鼠标键盘试玩。'));return false;}
};
function handleHands(result,now){
 if(!enabled)return;const sample=mapping.sample(result,now);drawHandOverlay(overlay,sample,book,group,selectedSlot);
 $('hand-status').textContent=!sample.right?'请将右手放在舒适位置入镜，自动定位起点':sample.fist?'左手握拳 · 切换技能组':sample.pinched?'右手合指 · 已释放，松开即可再发':!sample.left?'右掌瞄准 · 拇指碰食指释放当前技能':'右手前推放远、后收放近 · 合指释放';
 dispatchGesture(sample,send,{active:started&&!paused,skillCount:book.length,relativeAim,sensitivity:Number($('aim-speed').value)});
}
function tick(now){
 if(enabled&&landmarker&&stream&&!landmarker.busy&&now-lastDetect>=30&&$('camera').currentTime!==lastFrame){lastDetect=now;lastFrame=$('camera').currentTime;landmarker.sample($('camera'),now);}
 requestAnimationFrame(tick);
}
requestAnimationFrame(tick);addEventListener('pagehide',()=>{stopCamera();audio.mute();});
// State only, for browser verification; it never exposes camera frames or controls.
window.playseedPlayer={snapshot:()=>({lifecycleChecks,gestureOnly,cameraFraming:framing,trackingSize:landmarker?.frameSize||null,cameraWidth:$('camera').videoWidth,cameraHeight:$('camera').videoHeight,depthAim:mapping.depthAim,started,paused,ready,camera:enabled,cameraPreparing:starting,trackerWorker:!!landmarker?.worker,trackingDelegate:landmarker?.delegate||null,trackingFrames:landmarker?.frames||0,audio:audio.enabled,sounds:audio.played,audioState:audio.context?.state||'uninitialized',audioEnergy:audio.energy(),skillGroup:group,skillCount:book.length,tracks:stream?.getTracks().filter(t=>t.readyState==='live').length||0})};
