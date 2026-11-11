import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const source=(await readFile(new URL('../src/index.js',import.meta.url),'utf8')).replace("import { DurableObject } from 'cloudflare:workers';","class DurableObject {constructor(ctx,env){this.ctx=ctx;this.env=env;}} ").replace("'./lib/protocol.js'",JSON.stringify(new URL('../src/lib/protocol.js',import.meta.url).href)).replace("'./admin.js'",JSON.stringify(new URL('../src/admin.js',import.meta.url).href));
const {Room,default:worker}=await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
const binding=value=>({idFromName:x=>x,get:()=>value});
const makeRoom=()=>Object.assign(Object.create(Room.prototype),{r:{code:'AB23',created:Date.now(),lastActivity:123,started:false,over:false,host_seat:0,seats:[{token:'a'.repeat(32),bot:false},{token:'b'.repeat(32),bot:false}]},clients:new Map(),rates:new Map(),generation:0,save:async()=>{},broadcastRoom:()=>{}});
const sock=()=>({close(code,reason){this.closed={code,reason};},send(){}});
test('HTTP room listing serves cache hits without Lobby calls and rate checks only misses',async()=>{
 let lists=0,allows=0;const l={allow:async()=>{allows++;return false;},list:async()=>{lists++;return [];},bump:async()=>{}};
 // A refused miss returns 429 and caches nothing.
 assert.equal((await worker.fetch(new Request('https://server/rooms'),{GAME_VERSION:'list-miss',LOBBY:binding(l)})).status,429);assert.equal(lists,0);
 let ok=0;const m={allow:async()=>{ok++;return true;},list:async()=>{lists++;return [];},bump:async()=>{}},env={GAME_VERSION:'list-test',LOBBY:binding(m)};
 for(let i=0;i<3;i++)assert.equal((await worker.fetch(new Request('https://server/rooms'),env)).status,200);
 assert.equal(lists,1);assert.equal(ok,1);
});
test('maintenance blocks create and join before body parsing or room calls',async()=>{
 const keys=[],env={ONLINE_ENABLED:'0',LOBBY:binding({bump:async k=>keys.push(...k)})};for(const path of ['/rooms','/rooms/AB23/join']){const res=await worker.fetch(new Request('https://server'+path,{method:'POST',body:'not json'}),env);assert.equal(res.status,503);assert.deepEqual(await res.json(),{error:'maintenance'});}assert.deepEqual(keys,['refused.maintenance','refused.maintenance']);
});
test('WebSocket authentication failures have identical HTTP shape',async()=>{
 for(const patch of [{r:null},{},{r:{...makeRoom().r,started:true}}]){const r=Object.assign(makeRoom(),patch);const res=await r.fetch(new Request('https://server/ws/room/AB23?token='+ 'c'.repeat(32),{headers:{Upgrade:'websocket'}}));assert.equal(res.status,401);assert.deepEqual(await res.json(),{error:'token'});}
});
test('kick revokes token, closes socket and preserves seat position',async()=>{
 const r=makeRoom(),host=sock(),guest=sock();r.clients.set(host,{seat:0});r.clients.set(guest,{seat:1});await r.message(host,JSON.stringify({t:'lobby',action:'kick',seat:1}));assert.deepEqual(guest.closed,{code:4001,reason:'kicked'});assert.equal(r.r.seats.length,2);assert.equal(r.r.seats[1].token,'');assert(!r.clients.has(guest));
});
test('busy start never locks room or boots container',async()=>{
 const r=makeRoom(),host=sock();r.clients.set(host,{seat:0});r.env={LOBBY:binding({claim:async()=> 'busy'})};r.ensure=()=>assert.fail('boot');await assert.rejects(()=>r.message(host,JSON.stringify({t:'lobby',action:'start'})),e=>e.message==='busy'&&e.status===503);assert(!r.r.started);assert(!r.starting);
});
test('hard expiry destroys, records abandonment, closes sockets and deletes room',async()=>{
 const r=makeRoom(),events=[],ws=sock();r.r.created=Date.now()-8*3600000;r.clients.set(ws,{seat:0});r.stat=async e=>events.push(e);r.ctx={container:{destroy:async why=>events.push(why)},storage:{deleteAll:async()=>events.push('delete')}};r.env={LOBBY:binding({remove:async c=>events.push(c)})};await r.alarm();assert.deepEqual(events,['abandoned','expired','AB23','delete']);assert.equal(ws.closed.reason,'expired');assert.equal(r.r,null);assert.equal(r.clients.size,0);
});
test('idle destruction releases live slot and retains snapshot',async()=>{
 const r=makeRoom(),events=[];r.r.emptySince=Date.now()-600001;r.r.snapshot={x:1};r.ctx={container:{destroy:async()=>events.push('destroy')},storage:{put:async()=>events.push('save')}};r.env={LOBBY:binding({release:async()=>events.push('release')})};r.schedule=async()=>{};await r.alarm();assert.deepEqual(events,['save','destroy','release','save','save']);assert.deepEqual(r.r.snapshot,{x:1});
});
test('locked admin returns 429 even for the correct key',async()=>{
 const env={ADMIN_KEY:'x'.repeat(32),LOBBY:binding({locked:async()=>true,stats:()=>assert.fail('stats')})};const res=await worker.fetch(new Request('https://server/admin/api/stats',{headers:{Authorization:'Bearer '+env.ADMIN_KEY}}),env);assert.equal(res.status,429);
});
test('new seat socket replaces old socket without refreshing activity',async()=>{
 const originalResponse=globalThis.Response,originalPair=globalThis.WebSocketPair;
 class UpgradeResponse extends originalResponse {constructor(body,init){if(init?.status===101){super(null);Object.defineProperty(this,'status',{value:101});this.webSocket=init.webSocket;}else super(body,init);}}
 globalThis.Response=UpgradeResponse;globalThis.WebSocketPair=class {constructor(){this[0]=sock();this[1]=Object.assign(sock(),{accept(){},addEventListener(){}});}};
 try{const r=makeRoom(),old=sock();r.clients.set(old,{seat:1});r.save=async active=>assert(!active);const res=await r.fetch(new Request('https://server/ws/room/AB23?token='+'b'.repeat(32),{headers:{Upgrade:'websocket'}}));assert.equal(res.status,101);assert.deepEqual(old.closed,{code:4000,reason:'replaced'});assert.equal(r.clients.size,1);assert.equal(r.r.lastActivity,123);}finally{globalThis.Response=originalResponse;globalThis.WebSocketPair=originalPair;}
});

const {default:site}=await import('../../site/src/index.js');
test('site caches full WASM by version and conditional hits avoid R2',async()=>{
 const original=globalThis.caches,entries=new Map(),pending=[];globalThis.caches={default:{match:async key=>entries.get(key.url)?.clone(),put:async(key,value)=>entries.set(key.url,value)}};
 let reads=0;const env={WASM_KEY:'web/test-v1/index.wasm',GAME_FILES:{get:async()=>{reads++;return {body:'wasm',httpEtag:'"strong-v1"'};}},ASSETS:{fetch:async()=>new Response('asset')}},ctx={waitUntil:p=>pending.push(p)};
 try{let res=await site.fetch(new Request('https://site/index.wasm'),env,ctx);assert.equal(await res.text(),'wasm');assert.equal(res.headers.get('etag'),'"strong-v1"');await Promise.all(pending);
 res=await site.fetch(new Request('https://site/index.wasm',{headers:{'If-None-Match':'"strong-v1"'}}),env,ctx);assert.equal(res.status,304);assert.equal(reads,1);
 res=await site.fetch(new Request('https://site/web/test-v1/index.wasm'),env,ctx);assert.equal(await res.text(),'wasm');assert(res.headers.get('cache-control').includes('immutable'));assert.equal(reads,1);
 for(const req of [new Request('https://www.site/'),new Request('https://site/join/AB23'),new Request('https://site/index.wasm',{method:'POST'}),new Request('https://site/icon.png')]){res=await site.fetch(req,env,ctx);for(const name of ['content-security-policy','x-content-type-options','referrer-policy','strict-transport-security','permissions-policy'])assert(res.headers.has(name));}
 }finally{globalThis.caches=original;}
});
test('site serves index.pck from R2 when PCK_KEY is set, else from static assets',async()=>{
 const original=globalThis.caches;globalThis.caches={default:{match:async()=>undefined,put:async()=>{}}};const keys=[];const env={WASM_KEY:'web/v/index.wasm',PCK_KEY:'web/v/index.pck',GAME_FILES:{get:async k=>{keys.push(k);return {body:'pck',httpEtag:'"p1"'};}},ASSETS:{fetch:async()=>new Response('asset')}},ctx={waitUntil:()=>{}};
 try{let res=await site.fetch(new Request('https://site/index.pck'),env,ctx);assert.equal(await res.text(),'pck');assert.equal(res.headers.get('cache-control'),'no-cache');assert.equal(res.headers.get('content-type'),'application/octet-stream');assert.deepEqual(keys,['web/v/index.pck']);
 delete env.PCK_KEY;res=await site.fetch(new Request('https://site/index.pck'),env,ctx);assert.equal(await res.text(),'asset');}finally{globalThis.caches=original;}
});
test('site WASM HEAD metadata is reused for 304 and changes with version',async()=>{
 const original=globalThis.caches;globalThis.caches={default:{match:async()=>undefined}};let heads=0;const env={WASM_KEY:'web/head-test/index.wasm',GAME_FILES:{head:async()=>{heads++;return {httpEtag:'"head-etag"'};}}};
 try{assert.equal((await site.fetch(new Request('https://site/index.wasm',{method:'HEAD'}),env,{})).status,200);assert.equal((await site.fetch(new Request('https://site/index.wasm',{headers:{'If-None-Match':'W/"head-etag"'}}),env,{})).status,304);assert.equal(heads,1);env.WASM_KEY='web/head-next/index.wasm';await site.fetch(new Request('https://site/index.wasm',{method:'HEAD'}),env,{});assert.equal(heads,2);}finally{globalThis.caches=original;}
});
test('failed release is persisted and retried by the room alarm',async()=>{
 const r=makeRoom();let releases=0;r.schedule=async()=>{};r.ctx={container:{destroy:async()=>{}},storage:{put:async()=>{}}};r.env={LOBBY:binding({release:async()=>{if(++releases===1)throw new Error('transient');}})};
 await assert.rejects(()=>r.stop('over'));assert.equal(r.r.releasePending,'over');await r.alarm();assert.equal(releases,2);assert.equal(r.r.releasePending,undefined);
});

const fs=await import('node:fs/promises'),{tmpdir}=await import('node:os'),{join}=await import('node:path'),{spawnSync}=await import('node:child_process');
test('deploy helpers remove private Docker config on success and failure without registry access',async()=>{
 for(const helper of ['deploy_online.sh','deploy_site.sh'])for(const exit of [0,17]){
  const root=await fs.mkdtemp(join(tmpdir(),'phreaknic-deploy-test-'));
  try{
   for(const path of ['tools','bin','build/server','build/web','cloudflare/online/container','cloudflare/site','cloudflare/node_modules/.bin'])await fs.mkdir(join(root,path),{recursive:true});
   await fs.copyFile(new URL('../../../tools/'+helper,import.meta.url),join(root,'tools',helper));
   for(const [path,data]of [['project.godot','config/version="0.11"\n'],['build/server/phreaknic-server.x86_64','fake'],['build/web/index.html','fake'],['build/web/index.wasm','fake']])await fs.writeFile(join(root,path),data);
   // The scripts run `npm ci` and then the pinned wrangler from cloudflare/node_modules; fake both.
   await fs.writeFile(join(root,'bin/npm'),'#!/bin/sh\nexit 0\n',{mode:0o700});
   await fs.writeFile(join(root,'cloudflare/node_modules/.bin/wrangler'),'#!/bin/sh\n[ "$(stat -c %a "$DOCKER_CONFIG")" = 700 ] || exit 99\nprintf "%s\\n" "$DOCKER_CONFIG" > "$TASK_LOG"\nprintf "credential" > "$DOCKER_CONFIG/config.json"\nexit "$TASK_EXIT"\n',{mode:0o700});
   const result=spawnSync('bash',[join(root,'tools',helper)],{env:{...process.env,PATH:join(root,'bin')+':'+process.env.PATH,CLOUDFLARE_API_TOKEN:'test-placeholder',TASK_LOG:join(root,'config-path'),TASK_EXIT:String(exit)},encoding:'utf8'});assert.equal(result.status,exit,result.stderr);
   const config=(await fs.readFile(join(root,'config-path'),'utf8')).trim();await assert.rejects(()=>fs.stat(config),e=>e.code==='ENOENT');
   if(helper==='deploy_site.sh')await assert.rejects(()=>fs.stat(join(root,'build/web/.assetsignore')),e=>e.code==='ENOENT');
  }finally{await fs.rm(root,{recursive:true,force:true});}
 }
});

test('host leave closes guests, removes storage/listing and records once',async()=>{
 const r=makeRoom(),events=[],host=sock(),guest=sock(),messages=[];
 guest.send=v=>messages.push(JSON.parse(v));r.clients.set(host,{seat:0});r.clients.set(guest,{seat:1});
 r.ctx={container:{destroy:async why=>events.push(why)},storage:{deleteAll:async()=>events.push('delete')}};
 r.env={LOBBY:binding({bump:async keys=>events.push(...keys),remove:async c=>events.push(c)})};
 await r.message(host,JSON.stringify({t:'lobby',action:'leave'}));
 assert.deepEqual(messages,[{t:'room_closed',reason:'host_left'}]);assert.deepEqual(guest.closed,{code:4002,reason:'closed'});
 assert.deepEqual(events,['rooms.closed_by_host','host_left','AB23','delete']);assert.equal(r.r,null);
 await r.closeByHost();assert.equal(events.length,4);
 // Reuse a deleted code in the same live Durable Object.
 r.stat=async()=>{};r.save=async()=>{};r.rates.set(0,{old:true});r.starting=true;
 await r.createRoom('AB23',{seats:[{token:'new'}]});assert(!r.closing);assert(!r.starting);assert.equal(r.rates.size,0);assert.equal(r.r.code,'AB23');
});
test('host disconnect schedules grace and alarm closes only at deadline',async()=>{
 const r=makeRoom(),host=sock(),guest=sock();r.clients.set(host,{seat:0});r.clients.set(guest,{seat:1});
 await r.disconnected(host);assert(r.r.hostGoneAt<=Date.now());let closed=0;r.closeByHost=async()=>closed++;r.schedule=async()=>{};
 await r.alarm();assert.equal(closed,0);r.r.hostGoneAt=Date.now()-60000;await r.alarm();assert.equal(closed,1);
 r.r.started=true;await r.alarm();assert.equal(closed,1);
});
test('host reconnect cancels pregame grace',async()=>{
 const originalResponse=globalThis.Response,originalPair=globalThis.WebSocketPair;
 globalThis.Response=class extends originalResponse {constructor(body,init){if(init?.status===101){super(null);Object.defineProperty(this,'status',{value:101});}else super(body,init);}};
 globalThis.WebSocketPair=class {constructor(){this[0]=sock();this[1]=Object.assign(sock(),{accept(){},addEventListener(){}});}};
 try{const r=makeRoom();r.r.hostGoneAt=Date.now()-59999;await r.fetch(new Request('https://server/ws/room/AB23?token='+'a'.repeat(32),{headers:{Upgrade:'websocket'}}));assert.equal(r.r.hostGoneAt,undefined);}finally{globalThis.Response=originalResponse;globalThis.WebSocketPair=originalPair;}
});
test('settings broadcast bans and clear bans on pool change',async()=>{
 const r=makeRoom(),host=sock(),messages=[];host.send=v=>messages.push(JSON.parse(v));r.clients.set(host,{seat:0});r.broadcastRoom=Room.prototype.broadcastRoom;
 await r.message(host,JSON.stringify({t:'lobby',action:'settings',banned:['unknown']}));assert.deepEqual(r.r.banned,['unknown']);assert.deepEqual(messages.at(-1).banned,['unknown']);
 await r.message(host,JSON.stringify({t:'lobby',action:'settings',card_pool:'2025',banned:['unknown']}));assert.deepEqual(r.r.banned,[]);
});

test('alarm scheduling uses persisted host deadline until reconnect or game start',async()=>{
 const r=makeRoom(),alarms=[];r.ctx={storage:{setAlarm:async at=>alarms.push(at)}};
 r.r.hostGoneAt=Date.now();await r.schedule();assert.equal(alarms.at(-1),r.r.hostGoneAt+60000);
 r.r.started=true;await r.schedule();assert.equal(alarms.at(-1),r.r.created+8*3600000);
 r.r.started=false;delete r.r.hostGoneAt;await r.schedule();assert.equal(alarms.at(-1),r.r.created+8*3600000);
});
test('container diagnostics log bounded strings without broadcasting',async()=>{
 const r=makeRoom(),lines=[],original=console.log;r.broadcast=()=>assert.fail('diagnostics are private');console.log=(...args)=>lines.push(args);
 try {await r.linkMessage({t:'diag',text:'x'.repeat(400)});for(const text of [null,12,{},[],true])await r.linkMessage({t:'diag',text});}
 finally {console.log=original;}
 assert.deepEqual(lines,[[`room AB23: ${'x'.repeat(300)}`]]);
});
test('host retains independent bans when switching back to a pool',async()=>{
 const r=makeRoom(),host=sock();r.clients.set(host,{seat:0});r.r.card_pool='2026';r.r.banned=['Filler'];
 await r.message(host,JSON.stringify({t:'lobby',action:'settings',card_pool:'2026mog'}));assert.deepEqual(r.r.banned,[]);
 await r.message(host,JSON.stringify({t:'lobby',action:'settings',banned:['Mognet']}));
 await r.message(host,JSON.stringify({t:'lobby',action:'settings',card_pool:'2026'}));assert.deepEqual(r.r.banned,['Filler']);
 await r.message(host,JSON.stringify({t:'lobby',action:'settings',card_pool:'2026mog'}));assert.deepEqual(r.r.banned,['Mognet']);
});
