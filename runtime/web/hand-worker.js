// Trusted classic worker: video frames and inference remain on this computer.
let detector=null,canvas=null,ctx=null,delegate='GPU',frameSize=null;
self.onmessage=async({data})=>{
 try{
  if(data.type==='init'){
   ({frameSize}=await import('./camera-framing.mjs'));
   const {FilesetResolver,HandLandmarker}=await import('./vendor/mediapipe/vision_bundle.mjs');
   const vision=await FilesetResolver.forVisionTasks(new URL('./vendor/mediapipe/wasm',self.location.href).href);
   const options={baseOptions:{modelAssetPath:new URL('./vendor/mediapipe/hand_landmarker.task',self.location.href).href,delegate},canvas:new OffscreenCanvas(1,1),runningMode:'VIDEO',numHands:2,minHandDetectionConfidence:.6,minHandPresenceConfidence:.6,minTrackingConfidence:.6};
   canvas=new OffscreenCanvas(640,480);ctx=canvas.getContext('2d');
   try{detector=await HandLandmarker.createFromOptions(vision,options);detector.detectForVideo(canvas,0);}
   catch{try{detector?.close();}catch{}delegate='CPU';delete options.canvas;options.baseOptions.delegate=delegate;detector=await HandLandmarker.createFromOptions(vision,options);}
   self.postMessage({type:'ready',delegate});
  }else if(data.type==='frame'){
   try{const size=frameSize(data.bitmap.width,data.bitmap.height);if(canvas.width!==size.width||canvas.height!==size.height){canvas.width=size.width;canvas.height=size.height;}ctx.setTransform(-1,0,0,1,canvas.width,0);ctx.drawImage(data.bitmap,0,0,canvas.width,canvas.height);ctx.setTransform(1,0,0,1,0,0);const result=detector.detectForVideo(canvas,data.now);self.postMessage({type:'result',now:data.now,size,result:{landmarks:result.landmarks,handedness:result.handedness}});}finally{data.bitmap.close();}
  }
 }catch(error){self.postMessage({type:'error',message:String(error.message||error)});}
};
