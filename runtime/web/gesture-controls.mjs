// Shared by live tracking and fixture-driven integration checks.
export function dispatchGesture(sample,send,{active,skillCount,relativeAim=false,sensitivity=.6}){
 if(!active)return;
 const gain=Math.max(.2,Math.min(1.8,Number(sensitivity)||.6));
 const target=relativeAim?{x:0,y:0,relative:true}:sample.aim;
 if(sample.aim){const point=relativeAim?{x:(sample.motion?.x||0)*gain,y:(sample.motion?.y||0)*gain,relative:true}:sample.aim;
  // Respect the trusted input limit without dropping the rest of a fast movement.
  const steps=relativeAim?Math.max(1,Math.ceil(Math.max(Math.abs(point.x),Math.abs(point.y))/110)):1;
  for(let i=0;i<steps;i++)send('action',{source:'gesture',name:'aim',point:{...point,x:point.x/steps,y:point.y/steps,pressed:true}});
 }
 if(sample.nextGroup&&skillCount>4)send('action',{source:'gesture',name:'nextgroup',point:{x:480,y:300,pressed:true}});
 if(Number.isInteger(sample.selectSlot))send('action',{source:'gesture',name:'spell'+(sample.selectSlot+1),point:{x:480,y:300,pressed:true}});
 if(sample.cast&&sample.aim){send('action',{source:'gesture',name:'primary',point:{...target,pressed:true}});send('action',{source:'gesture',name:'primary',point:{...target,pressed:false}});}
}
