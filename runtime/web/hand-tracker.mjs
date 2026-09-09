export class HandTracker{
 constructor(){this.worker=null;this.busy=false;this.frames=0;this.frameSize=null;this.delegate=null;this.onResult=null;this.onError=null;this.generation=0;this.initReject=null;this.initTimer=null;}
 async start(){
  const worker=new Worker(new URL('./hand-worker.js',import.meta.url));this.worker=worker;
  await new Promise((resolve,reject)=>{
   this.initReject=reject;const timer=this.initTimer=setTimeout(()=>{reject(new Error('手势识别准备超时'));this.close();},30000);
   const fail=e=>{clearTimeout(timer);reject(new Error(e.message||'手势识别失败'));this.onError?.();};
   worker.onerror=fail;worker.onmessage=({data})=>{if(worker!==this.worker)return;if(data.type==='ready'){this.delegate=data.delegate;clearTimeout(timer);this.initReject=null;resolve();}else if(data.type==='result'){this.frames++;this.frameSize=data.size;this.busy=false;this.onResult?.(data.result,data.now);}else if(data.type==='error')fail(data);};
   worker.postMessage({type:'init'});
  });
 }
 async sample(video,now){
  if(!this.worker||this.busy)return;this.busy=true;const worker=this.worker,ticket=this.generation;
  try{const bitmap=await createImageBitmap(video);if(ticket!==this.generation||worker!==this.worker){bitmap.close();return;}worker.postMessage({type:'frame',bitmap,now},[bitmap]);}catch{if(ticket===this.generation){this.busy=false;this.onError?.();}}
 }
 close(){this.generation++;clearTimeout(this.initTimer);this.initReject?.(new Error('手势准备已取消'));this.initReject=null;this.worker?.terminate();this.worker=null;this.busy=false;this.onResult=null;this.onError=null;}
}
