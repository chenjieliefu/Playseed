import assert from 'node:assert/strict';
import {captureConstraints,frameSize,widenTrack} from '../runtime/web/camera-framing.mjs';
assert.equal(captureConstraints({resizeMode:true,zoom:true}).video.resizeMode.ideal,'none');
assert.equal(captureConstraints({}).video.zoom,undefined);
for(const [w,h] of [[1920,1080],[1280,960],[1080,1920]]){
 const size=frameSize(w,h);assert.ok(Math.abs(size.width/size.height-w/h)<.003);assert.equal(Math.max(size.width,size.height),640);
}
let constraints=captureConstraints({resizeMode:true,zoom:true}).video,settings={resizeMode:'crop-and-scale',zoom:2};
const track={getConstraints:()=>constraints,getCapabilities:()=>({resizeMode:['none','crop-and-scale'],zoom:{min:1,max:4}}),getSettings:()=>settings,applyConstraints:async c=>{constraints=c;for(const entry of c.advanced)Object.assign(settings,entry);}};
assert.deepEqual(await widenTrack(track),{uncropped:true,zoomAtMinimum:true});
assert.equal(constraints.width.ideal,1280,'zoom must not reset capture resolution');
assert.equal(constraints.frameRate.max,30);
assert.deepEqual(await widenTrack({getSettings:()=>({}),getCapabilities:()=>({})}),{uncropped:false,zoomAtMinimum:false});
settings={resizeMode:'crop-and-scale',zoom:2};track.applyConstraints=async()=>{throw Error('unavailable');};
assert.deepEqual(await widenTrack(track),{uncropped:false,zoomAtMinimum:false},'unsupported controls keep the camera usable without claiming success');
track.applyConstraints=async()=>{};
assert.equal((await widenTrack(track)).zoomAtMinimum,false,'ignored constraints must not be reported as applied');
console.log('CAMERA_FRAMING_OK: preserve landscape/portrait, supported minimum zoom, unavailable/ignored fallback, resolution retained');
