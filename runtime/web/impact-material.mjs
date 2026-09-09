import * as T from './vendor/three.module.js';
// Camera-facing turbulent volume illusion. Local procedural shading, no image downloads.
export function impactMaterial(kind,size){
 return new T.ShaderMaterial({transparent:true,depthWrite:false,side:T.DoubleSide,uniforms:{age:{value:0},fade:{value:1},size:{value:size},kind:{value:kind}},vertexShader:`varying vec2 p;uniform float size;void main(){p=uv*2.-1.;vec4 centre=modelViewMatrix*vec4(0.,0.,0.,1.);gl_Position=projectionMatrix*(centre+vec4(position.xy*size,0.,0.));}`,fragmentShader:`
 varying vec2 p;uniform float age,fade,kind;
 float hash(vec2 q){return fract(sin(dot(q,vec2(127.1,311.7)))*43758.5453);}
 float noise(vec2 q){vec2 i=floor(q),f=fract(q);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);}
 float fbm(vec2 q){float n=0.,a=.5;for(int i=0;i<4;i++){n+=noise(q)*a;q=q*2.03+vec2(4.7,9.2);a*=.5;}return n;}
 void main(){vec2 q=p;float t=age,n=fbm(q*5.-vec2(t*.6,t*2.8)),r=length(q);vec3 c;float alpha;
 if(kind<.5){float grow=min(1.,t*5.),edge=1.-smoothstep(.38*grow,.92*grow+.03,r+(n-.5)*.29);float heat=clamp(.72-r*.45+(n-.5)*1.65-t*.24,0.,1.);c=mix(vec3(.065,.045,.042),vec3(.9,.045,.003),smoothstep(.23,.52,heat));c=mix(c,vec3(1.8,.32,.008),smoothstep(.44,.78,heat));c=mix(c,vec3(2.4,1.05,.16),smoothstep(.85,1.,heat));alpha=edge*min(1.,t*18.)*fade*(.6+n*.4);}
 else if(kind<1.5){float edge=(1.-smoothstep(.3,.95,r+(n-.5)*.4));c=mix(vec3(.09,.13,.17),vec3(.43,.35,.26),n);alpha=edge*fade*.55;}
 else{float edge=1.-smoothstep(.2,1.,r+(n-.5)*.2);c=mix(vec3(.06,.015,.1),vec3(.28,.55,.035),n);alpha=edge*fade*.36;}
 gl_FragColor=vec4(c,alpha);
 }`});
}
export function accretionMaterial(){return new T.ShaderMaterial({transparent:true,depthWrite:false,side:T.DoubleSide,blending:T.AdditiveBlending,uniforms:{age:{value:0},fade:{value:1}},vertexShader:'varying vec2 p;void main(){p=uv*2.-1.;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}',fragmentShader:`varying vec2 p;uniform float age,fade;void main(){float r=length(p),a=atan(p.y,p.x),bands=pow(.5+.5*sin(r*90.-a*4.+age*12.),3.);float ring=exp(-pow((r-.46)*12.,2.));float spiral=(1.-smoothstep(.45,.93,r))*smoothstep(.22,.4,r)*bands;vec3 c=mix(vec3(.22,.08,.65),vec3(2.4,1.3,.45),ring);gl_FragColor=vec4(c,(ring+spiral*.7)*fade);}`});}
