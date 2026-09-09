export class GameAudio {
 constructor(){this.enabled=false;this.volume=.3;this.context=null;this.nodes=new Set();this.played=0;this.last=0;}
 async enable(){this.context??=new AudioContext();await this.context.resume();if(!this.analyser){this.analyser=this.context.createAnalyser();this.analyser.fftSize=256;this.analyser.connect(this.context.destination);}this.enabled=true;}
 mute(){this.enabled=false;for(const n of this.nodes){try{n.stop();}catch{}}this.nodes.clear();}
 tone(frequency,delay,duration,type='sine',end=frequency,gain=.13){
  const c=this.context,o=c.createOscillator(),v=c.createGain(),t=c.currentTime+delay;o.type=type;o.frequency.setValueAtTime(frequency,t);o.frequency.exponentialRampToValueAtTime(Math.max(30,end),t+duration);v.gain.setValueAtTime(.0001,t);v.gain.exponentialRampToValueAtTime(Math.max(.0002,gain*this.volume),t+.012);v.gain.exponentialRampToValueAtTime(.0001,t+duration);o.connect(v).connect(this.analyser);o.start(t);o.stop(t+duration+.03);this.nodes.add(o);o.onended=()=>{o.disconnect();v.disconnect();this.nodes.delete(o);};
 }
 energy(){if(!this.analyser)return 0;const data=new Float32Array(256);this.analyser.getFloatTimeDomainData(data);return Math.sqrt(data.reduce((sum,v)=>sum+v*v,0)/data.length);}
 play(name){
  if(!this.enabled||this.context?.state!=='running')return;
  if(this.nodes.size>24)return;this.played++;
  if(name==='fire'){this.tone(180,0,.35,'sawtooth',45,.09);this.tone(460,0,.18,'triangle',100,.12);}
  else if(name==='lightning'){for(let i=0;i<3;i++)this.tone(1000-i*160,i*.045,.1,'sawtooth',100,.055);}
  else if(name==='frost'){for(let i=0;i<3;i++)this.tone(660+i*220,i*.055,.45,'sine',600+i*200,.13);}
  else if(name==='earth'){this.tone(95,0,.42,'triangle',35,.4);this.tone(200,.04,.22,'sawtooth',40,.09);}
  else if(name==='bloom'){[440,554,659].forEach((f,i)=>this.tone(f,i*.045,.4,'sine',f*1.3,.11));}
  else if(name==='venom'){this.tone(310,0,.35,'sawtooth',80,.06);this.tone(720,.05,.3,'sine',240,.1);}
  else if(name==='astral'){this.tone(90,0,.55,'triangle',35,.3);this.tone(900,0,.4,'sine',100,.1);}
  else if(name==='ward'){[523,784,1047].forEach((f,i)=>this.tone(f,i*.035,.4,'sine',f,.09));}
  else if(name==='hit')this.tone(200,0,.09,'triangle',70,.15);
  else if(name==='hurt')this.tone(110,0,.18,'sawtooth',60,.08);
  else if(name==='win'){[523,659,784,1047].forEach((f,i)=>this.tone(f,i*.14,.55));}
  else if(name==='lose'){[220,196,147].forEach((f,i)=>this.tone(f,i*.22,.6,'triangle'));}
  else if(name==='start'){[330,440,660].forEach((f,i)=>this.tone(f,i*.12,.4));}
 }
}
