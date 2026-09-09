export const SPELLS=[
 {name:'熔星爆破',short:'烈焰',icon:'fire',color:'#ff9250'},
 {name:'连锁雷霆',short:'雷霆',icon:'bolt',color:'#bba1ff'},
 {name:'极寒绽放',short:'冰霜',icon:'snow',color:'#91eaff'},
 {name:'大地突刺',short:'岩柱',icon:'rock',color:'#ecc58b'},
 {name:'奥术花开',short:'花开',icon:'flower',color:'#b4ed91'},
 {name:'剧毒晶簇',short:'毒晶',icon:'crystal',color:'#cc87ff'},
 {name:'星界冲击',short:'星界',icon:'star',color:'#e4bdff'},
 {name:'圣光结界',short:'圣光',icon:'shield',color:'#ffdc8c'}
];
// Small vector icons, shared by skill cards and the tracked fingertips.
export function drawSpellIcon(ctx,icon,x,y,size,color){
 ctx.save();ctx.translate(x,y);ctx.scale(size/24,size/24);ctx.strokeStyle=color;ctx.fillStyle=color;ctx.lineWidth=1.6;ctx.lineJoin='round';ctx.lineCap='round';ctx.beginPath();
 if(icon==='bolt'){ctx.moveTo(2,-11);ctx.lineTo(-8,2);ctx.lineTo(-1,2);ctx.lineTo(-3,11);ctx.lineTo(8,-3);ctx.lineTo(1,-3);ctx.closePath();ctx.fill();}
 else if(icon==='fire'){ctx.moveTo(0,-11);ctx.bezierCurveTo(5,-3,12,1,7,8);ctx.bezierCurveTo(2,14,-10,9,-7,1);ctx.lineTo(-3,-4);ctx.lineTo(-2,2);ctx.quadraticCurveTo(3,-1,0,-11);ctx.fill();}
 else if(icon==='snow'){for(let i=0;i<6;i++){ctx.save();ctx.rotate(i*Math.PI/3);ctx.moveTo(0,0);ctx.lineTo(0,-10);ctx.moveTo(-3,-5);ctx.lineTo(0,-7);ctx.lineTo(3,-5);ctx.restore();}ctx.stroke();}
 else if(icon==='flower'){for(let i=0;i<6;i++){const a=i*Math.PI/3;ctx.moveTo(0,0);ctx.ellipse(Math.sin(a)*6,Math.cos(a)*6,3,5,-a,0,Math.PI*2);}ctx.stroke();ctx.beginPath();ctx.arc(0,0,3,0,7);ctx.fill();}
 else if(icon==='shield'){ctx.moveTo(0,-10);ctx.lineTo(9,-6);ctx.lineTo(7,4);ctx.quadraticCurveTo(0,14,-7,4);ctx.lineTo(-9,-6);ctx.closePath();ctx.stroke();ctx.moveTo(0,-5);ctx.lineTo(0,6);ctx.moveTo(-4,0);ctx.lineTo(4,0);ctx.stroke();}
 else if(icon==='star'){for(let i=0;i<8;i++){const a=i*Math.PI/4,r=i%2?3:11;ctx.lineTo(Math.sin(a)*r,Math.cos(a)*r);}ctx.closePath();ctx.fill();}
 else{ctx.moveTo(0,-11);ctx.lineTo(8,-3);ctx.lineTo(6,8);ctx.lineTo(0,11);ctx.lineTo(-8,5);ctx.lineTo(-7,-4);ctx.closePath();ctx.stroke();ctx.moveTo(0,-11);ctx.lineTo(-2,1);ctx.lineTo(0,11);ctx.moveTo(-2,1);ctx.lineTo(8,-3);ctx.stroke();}
 ctx.restore();
}
