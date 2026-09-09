import * as T from './vendor/three.module.js';
// Small HDR glow pass. Gameplay and pointer coordinates stay at 960×600.
export function createPresentation(renderer,scene,camera){
 const full=new T.WebGLRenderTarget(1200,750,{type:T.HalfFloatType,samples:0}),a=new T.WebGLRenderTarget(480,300,{type:T.HalfFloatType,depthBuffer:false}),b=a.clone();
 const quadScene=new T.Scene(),quadCamera=new T.OrthographicCamera(-1,1,1,-1,0,1),geometry=new T.PlaneGeometry(2,2);
 const vertexShader='varying vec2 v;void main(){v=uv;gl_Position=vec4(position.xy,0.,1.);}';
 const blur=new T.ShaderMaterial({depthTest:false,depthWrite:false,uniforms:{map:{value:null},axis:{value:new T.Vector2()},threshold:{value:0}},vertexShader,fragmentShader:'varying vec2 v;uniform sampler2D map;uniform vec2 axis;uniform float threshold;void main(){vec3 c=vec3(0.);float total=0.;for(int i=-5;i<=5;i++){float w=exp(-float(i*i)/10.);vec3 s=texture2D(map,v+axis*float(i)).rgb;c+=max(s-vec3(threshold),0.)*w;total+=w;}gl_FragColor=vec4(c/total,1.);}'});
 const composite=new T.ShaderMaterial({depthTest:false,depthWrite:false,uniforms:{map:{value:full.texture},glow:{value:b.texture},pixel:{value:new T.Vector2(1/1200,1/750)}},vertexShader,fragmentShader:`
 varying vec2 v;uniform sampler2D map;uniform sampler2D glow;uniform vec2 pixel;
 vec3 aces(vec3 x){return clamp((x*(2.51*x+.03))/(x*(2.43*x+.59)+.14),0.,1.);}
 vec3 sampleColor(vec2 uv){vec3 c=max(vec3(0.),texture2D(map,uv).rgb+texture2D(glow,uv).rgb*.28);return pow(aces(c*1.10),vec3(1./2.2));}
 void main(){vec3 l=vec3(.299,.587,.114),m=sampleColor(v),nw=sampleColor(v+vec2(-1.,-1.)*pixel),ne=sampleColor(v+vec2(1.,-1.)*pixel),sw=sampleColor(v+vec2(-1.,1.)*pixel),se=sampleColor(v+pixel);
 float lm=dot(m,l),lnw=dot(nw,l),lne=dot(ne,l),lsw=dot(sw,l),lse=dot(se,l),lo=min(lm,min(min(lnw,lne),min(lsw,lse))),hi=max(lm,max(max(lnw,lne),max(lsw,lse)));
 vec2 dir=vec2(-((lnw+lne)-(lsw+lse)),(lnw+lsw)-(lne+lse));float reduce=max((lnw+lne+lsw+lse)*.03125,.0078125);dir=clamp(dir/(min(abs(dir.x),abs(dir.y))+reduce),vec2(-8.),vec2(8.))*pixel;
 vec3 aa=.5*(sampleColor(v+dir*(-.166667))+sampleColor(v+dir*.166667)),bb=aa*.5+.25*(sampleColor(v-dir*.5)+sampleColor(v+dir*.5));float lb=dot(bb,l);gl_FragColor=vec4(lb<lo||lb>hi?aa:bb,1.);}`});
 const quad=new T.Mesh(geometry,blur);quad.frustumCulled=false;quadScene.add(quad);
 return {resize(width,height,dpr=1){
  const ratio=Math.min(dpr,1.25,Math.sqrt(1400000/(width*height)));
  renderer.setPixelRatio(ratio);renderer.setSize(width,height,false);
  const w=Math.max(1,Math.round(width*ratio)),h=Math.max(1,Math.round(height*ratio));full.setSize(w,h);composite.uniforms.pixel.value.set(1/w,1/h);a.setSize(Math.max(1,w>>2),Math.max(1,h>>2));b.setSize(Math.max(1,w>>2),Math.max(1,h>>2));
 },render(){const tone=renderer.toneMapping;renderer.toneMapping=T.NoToneMapping;renderer.setRenderTarget(full);renderer.render(scene,camera);quad.material=blur;blur.uniforms.map.value=full.texture;blur.uniforms.axis.value.set(1/a.width,0);blur.uniforms.threshold.value=1;renderer.setRenderTarget(a);renderer.render(quadScene,quadCamera);blur.uniforms.map.value=a.texture;blur.uniforms.axis.value.set(0,1/a.height);blur.uniforms.threshold.value=0;renderer.setRenderTarget(b);renderer.render(quadScene,quadCamera);quad.material=composite;renderer.setRenderTarget(null);renderer.render(quadScene,quadCamera);renderer.toneMapping=tone;},dispose(){full.dispose();a.dispose();b.dispose();geometry.dispose();blur.dispose();composite.dispose();}};
}
