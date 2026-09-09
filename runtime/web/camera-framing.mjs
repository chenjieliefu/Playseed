// Preserve the whole camera frame in preview and inference; resolution is not field of view.
export function captureConstraints(supported={}){
 const video={width:{ideal:1280},height:{ideal:720},frameRate:{ideal:30,max:30},facingMode:{ideal:'user'}};
 if(supported.resizeMode)video.resizeMode={ideal:'none'};
 if(supported.zoom)video.zoom=true;
 return {video,audio:false};
}
export function frameSize(width,height){
 if(!Number.isFinite(width)||!Number.isFinite(height)||width<=0||height<=0)return {width:640,height:480};
 const scale=640/Math.max(width,height);
 return {width:Math.max(1,Math.round(width*scale)),height:Math.max(1,Math.round(height*scale))};
}
export async function widenTrack(track){
 const capabilities=track.getCapabilities?.()||{};
 const apply=constraint=>{const current=track.getConstraints?.()||{};return track.applyConstraints({...current,advanced:[...(current.advanced||[]),constraint]});};
 if(capabilities.resizeMode?.includes('none')){
  try{await apply({resizeMode:'none'});}catch{/* Keep the available camera usable. */}
 }
 const min=capabilities.zoom?.min;
 if(Number.isFinite(min)){
  try{await apply({zoom:min});}catch{/* Some browsers expose but cannot apply zoom. */}
 }
 const settings=track.getSettings?.()||{};
 return {uncropped:settings.resizeMode==='none',zoomAtMinimum:Number.isFinite(min)&&Number.isFinite(settings.zoom)&&Math.abs(settings.zoom-min)<.001};
}
