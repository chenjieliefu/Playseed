// Checks the trusted browser host without starting a real camera.
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
const project=process.argv[2];assert.ok(project,'pass a prepared showcase directory');
for(const mode of ['check-showcase','check-gestures']){
 const result=spawnSync(process.execPath,['scripts/web_runner.mjs',mode,project],{encoding:'utf8',timeout:60000});
 process.stdout.write(result.stdout);process.stderr.write(result.stderr);assert.equal(result.status,0,mode);
}
