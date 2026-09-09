// Real window/button closure must also stop the preview runner and its HTTP listener.
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
const project=process.argv[2];assert.ok(project,'pass a prepared showcase directory');
for(const mode of ['check-close','check-exit']){
 const result=spawnSync(process.execPath,['scripts/web_runner.mjs',mode,project],{encoding:'utf8',timeout:30000});
 assert.equal(result.status,0,result.stderr||'preview runner did not exit');
 const ready=result.stdout.split('\n').find(s=>s.startsWith('{"ready":true'));assert.ok(ready,'preview never started');
 let reachable=false;try{await fetch(JSON.parse(ready).url,{signal:AbortSignal.timeout(2000)});reachable=true;}catch{}
 assert.equal(reachable,false,'preview HTTP service survived window exit');
 console.log(mode+': browser runner exited and local preview URL stopped');
}
