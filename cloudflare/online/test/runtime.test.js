import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const source=(await readFile(new URL('../src/index.js',import.meta.url),'utf8')).replace("import { DurableObject } from 'cloudflare:workers';","class DurableObject {constructor(ctx,env){this.ctx=ctx;this.env=env;}} ").replace("'./lib/protocol.js'",JSON.stringify(new URL('../src/lib/protocol.js',import.meta.url).href)).replace("'./admin.js'",JSON.stringify(new URL('../src/admin.js',import.meta.url).href));
const {Room,Lobby,default:worker}=await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
const binding=value=>({idFromName:x=>x,get:()=>value});
const makeRoom=()=>Object.assign(Object.create(Room.prototype),{r:{code:'AB23',version:'test',created:Date.now(),lastActivity:123,started:false,over:false,host_seat:0,seats:[{token:'a'.repeat(32),bot:false},{token:'b'.repeat(32),bot:false}]},clients:new Map(),rates:new Map(),generation:0,save:async()=>{},broadcastRoom:()=>{}});
const sock=()=>({close(code,reason){this.closed={code,reason};},send(){}});
test('HTTP room listing serves cache hits without Lobby calls and rate checks only misses',async()=>{
 let lists=0,allows=0;const l={allow:async()=>{allows++;return false;},list:async()=>{lists++;return [];},bump:async()=>{}};
 // A refused miss returns 429 and caches nothing.
 assert.equal((await worker.fetch(new Request('https://server/rooms',{headers:{'CF-Connecting-IP':'list-refused'}}),{GAME_VERSION:'list-miss',LOBBY:binding(l)})).status,429);assert.equal(lists,0);
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
test('seat check: a plain GET with the token tells a live seat (426) from a gone one (401)',async()=>{
 const live=await makeRoom().fetch(new Request('https://server/ws/room/AB23?token='+'a'.repeat(32)));
 assert.equal(live.status,426);assert.deepEqual(await live.json(),{error:'upgrade'});
 for(const patch of [{r:null},{}]){const gone=await Object.assign(makeRoom(),patch).fetch(new Request('https://server/ws/room/AB23?token='+'c'.repeat(32)));assert.equal(gone.status,401);assert.deepEqual(await gone.json(),{error:'token'});}
});
test('kick revokes token, closes socket and preserves seat position',async()=>{
 const r=makeRoom(),host=sock(),guest=sock();r.clients.set(host,{seat:0});r.clients.set(guest,{seat:1});await r.message(host,JSON.stringify({t:'lobby',action:'kick',seat:1}));assert.deepEqual(guest.closed,{code:4001,reason:'kicked'});assert.equal(r.r.seats.length,2);assert.equal(r.r.seats[1].token,'');assert(!r.clients.has(guest));
});
test('busy start never locks room or boots container',async()=>{
 const r=makeRoom(),host=sock();r.clients.set(host,{seat:0});r.env={GAME_VERSION:'test',LOBBY:binding({allow:async()=>true,refund:async()=>{},claim:async()=> 'busy'})};r.ensure=()=>assert.fail('boot');await assert.rejects(()=>r.message(host,JSON.stringify({t:'lobby',action:'start'})),e=>e.message==='busy'&&e.status===503);assert(!r.r.started);assert(!r.starting);
});
test('Start after a deploy is refused with the room version, before claiming a slot',async()=>{
 const originalResponse=globalThis.Response,originalPair=globalThis.WebSocketPair,listeners={},sent=[],pending=[];
 globalThis.Response=class extends originalResponse {constructor(body,init){if(init?.status===101){super(null);Object.defineProperty(this,'status',{value:101});}else super(body,init);}};
 globalThis.WebSocketPair=class {constructor(){this[0]=sock();this[1]=Object.assign(sock(),{accept(){},addEventListener:(type,fn)=>listeners[type]=fn,send:v=>sent.push(JSON.parse(v))});}};
 try{
  const r=makeRoom();r.r.version='0.26';r.ctx={waitUntil:p=>pending.push(p)};r.env={GAME_VERSION:'0.27',LOBBY:binding({allow:async()=>true,refund:async()=>{},claim:async()=>assert.fail('claim')})};r.ensure=()=>assert.fail('boot');
  assert.equal((await r.fetch(new Request('https://server/ws/room/AB23?token='+'a'.repeat(32),{headers:{Upgrade:'websocket'}}))).status,101);
  // The player is told which version the room is on (online_api.gd's room_version text).
  listeners.message({data:JSON.stringify({t:'lobby',action:'start'})});await Promise.all(pending);
  assert.deepEqual(sent,[{t:'error',reason:'room_version',room:'0.26'}]);assert(!r.r.started);assert(!r.starting);
 }finally{globalThis.Response=originalResponse;globalThis.WebSocketPair=originalPair;}
});
test('a second Start while the first is claiming its slot is ignored, not reported as busy',async()=>{
 const r=makeRoom(),host=sock();let release;r.clients.set(host,{seat:0});r.stat=async()=>{};r.ensure=async()=>{};r.env={GAME_VERSION:'test',LOBBY:binding({allow:async()=>true,refund:async()=>{},claim:()=>new Promise(resolve=>release=resolve)})};
 const start=()=>r.message(host,JSON.stringify({t:'lobby',action:'start'})),first=start();
 await start();release(null);await first;assert(r.r.started);
 // Other lobby actions in that moment are still refused.
 r.r.started=false;r.starting=true;await assert.rejects(()=>r.message(host,JSON.stringify({t:'lobby',action:'settings',public:false})),/busy/);
});
test('hard expiry destroys, records abandonment, closes sockets and deletes room',async()=>{
 const r=makeRoom(),events=[],ws=sock();r.r.created=Date.now()-8*3600000;r.clients.set(ws,{seat:0});r.stat=async e=>events.push(e);r.ctx={container:{destroy:async why=>events.push(why)},storage:{deleteAll:async()=>events.push('delete')}};r.env={GAME_VERSION:'test',LOBBY:binding({remove:async c=>events.push(c)})};await r.alarm();assert.deepEqual(events,['abandoned','expired','AB23','delete']);assert.equal(ws.closed.reason,'expired');assert.equal(r.r,null);assert.equal(r.clients.size,0);
});
test('idle destruction releases live slot and retains snapshot',async()=>{
 const r=makeRoom(),events=[];r.r.emptySince=Date.now()-600001;r.r.snapshot={x:1};r.ctx={container:{destroy:async()=>events.push('destroy')},storage:{put:async()=>events.push('save')}};r.env={GAME_VERSION:'test',LOBBY:binding({release:async()=>events.push('release')})};r.schedule=async()=>{};await r.alarm();assert.deepEqual(events,['save','destroy','release','save','save']);assert.deepEqual(r.r.snapshot,{x:1});
});
test('locked admin returns 429 even for the correct key',async()=>{
 const env={ADMIN_KEY:'x'.repeat(32),LOBBY:binding({locked:async()=>true,stats:()=>assert.fail('stats')})};const res=await worker.fetch(new Request('https://server/admin/api/stats',{headers:{Authorization:'Bearer '+env.ADMIN_KEY}}),env);assert.equal(res.status,429);
});
test('new seat socket replaces old socket without refreshing activity',async()=>{
 const originalResponse=globalThis.Response,originalPair=globalThis.WebSocketPair,originalNow=Date.now,now=Date.now();Date.now=()=>now;
 class UpgradeResponse extends originalResponse {constructor(body,init){if(init?.status===101){super(null,{headers:init.headers});Object.defineProperty(this,'status',{value:101});this.webSocket=init.webSocket;}else super(body,init);}}
 globalThis.Response=UpgradeResponse;globalThis.WebSocketPair=class {constructor(){this[0]=sock();this[1]=Object.assign(sock(),{accept(){},addEventListener(){}});}};
 try{const r=makeRoom(),old=sock();r.clients.set(old,{seat:1});r.save=async active=>assert(!active);const res=await r.fetch(new Request('https://server/ws/room/AB23?token='+'b'.repeat(32),{headers:{Upgrade:'websocket'}}));assert.equal(res.status,101);assert.equal(res.headers.get('Sec-WebSocket-Protocol'),null);assert.deepEqual(old.closed,{code:4000,reason:'replaced'});assert.equal(r.clients.size,1);assert.equal(r.r.lastActivity,123);const offered=await r.fetch(new Request('https://server/ws/room/AB23',{headers:{Upgrade:'websocket','Sec-WebSocket-Protocol':'phreaknic, t.'+'b'.repeat(32)}}));assert.equal(offered.headers.get('Sec-WebSocket-Protocol'),'phreaknic');}finally{globalThis.Response=originalResponse;globalThis.WebSocketPair=originalPair;Date.now=originalNow;}
});
test('a player who reconnects after the game ended is sent the result',async()=>{
 const originalResponse=globalThis.Response,originalPair=globalThis.WebSocketPair;let received;
 globalThis.Response=class extends originalResponse {constructor(body,init){if(init?.status===101){super(null);Object.defineProperty(this,'status',{value:101});}else super(body,init);}};
 globalThis.WebSocketPair=class {constructor(){this[0]=sock();this[1]=Object.assign(sock(),{accept(){},addEventListener(){},send:v=>received.push(JSON.parse(v))});}};
 try{
  for(const [over,result]of [[{t:'over',winner:0,turns:9},{t:'over',winner:0}],[{t:'over',winner:-1,reason:'restore_failed'},{t:'over',winner:-1,reason:'restore_failed'}]]){
   const r=makeRoom(),host=sock(),sent=[];host.send=v=>sent.push(JSON.parse(v));r.r.started=true;r.clients.set(host,{seat:0});r.stat=async()=>{};r.stop=async()=>{};
   await r.linkMessage(over);assert.deepEqual(sent,[result]);
   // The guest was offline when the game ended: reconnecting tells them, and doesn't boot the game server again.
   received=[];r.ensure=()=>assert.fail('boot');r.linkSend=()=>assert.fail('link');
   const res=await r.fetch(new Request('https://server/ws/room/AB23?token='+'b'.repeat(32),{headers:{Upgrade:'websocket'}}));
   assert.equal(res.status,101);assert.deepEqual(received,[result]);
  }
 }finally{globalThis.Response=originalResponse;globalThis.WebSocketPair=originalPair;}
});

const {default:site}=await import('../../site/src/index.js');
test('site caches full WASM by version and conditional hits avoid R2',async()=>{
 const original=globalThis.caches,entries=new Map(),pending=[];globalThis.caches={default:{match:async key=>entries.get(key.url)?.clone(),put:async(key,value)=>entries.set(key.url,value)}};
 let reads=0;const env={WASM_KEY:'web/test-v1/index.wasm',GAME_FILES:{get:async()=>{reads++;return {body:'wasm',httpEtag:'"strong-v1"'};}},ASSETS:{fetch:async()=>new Response('asset')}},ctx={waitUntil:p=>pending.push(p)};
 try{let res=await site.fetch(new Request('https://site/index.wasm'),env,ctx);assert.equal(await res.text(),'wasm');assert.equal(res.headers.get('etag'),'"strong-v1"');await Promise.all(pending);
 res=await site.fetch(new Request('https://site/index.wasm',{headers:{'If-None-Match':'"strong-v1"'}}),env,ctx);assert.equal(res.status,304);assert.equal(reads,1);
 res=await site.fetch(new Request('https://site/web/test-v1/index.wasm'),env,ctx);assert.equal(await res.text(),'wasm');assert(res.headers.get('cache-control').includes('immutable'));assert.equal(reads,1);
 for(const req of [new Request('https://www.site/'),new Request('https://site/join/AB23'),new Request('https://site/index.wasm',{method:'POST'}),new Request('https://site/icon.png')]){res=await site.fetch(req,env,ctx);for(const name of ['content-security-policy','x-content-type-options','referrer-policy','strict-transport-security','permissions-policy'])assert(res.headers.has(name));}
 // Invite links: six-character codes (v0.30+) and older four-character ones redirect; other lengths don't.
 for(const [path,code] of [['/join/AB23CD','AB23CD'],['/join/ab23','AB23'],['/join/AB23C',null]]){res=await site.fetch(new Request('https://site'+path),env,ctx);if(code){assert.equal(res.status,302);assert.equal(new URL(res.headers.get('location')).searchParams.get('join'),code);}else assert.notEqual(res.status,302);}
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
 const r=makeRoom();let releases=0;r.schedule=async()=>{};r.ctx={container:{destroy:async()=>{}},storage:{put:async()=>{}}};r.env={GAME_VERSION:'test',LOBBY:binding({release:async()=>{if(++releases===1)throw new Error('transient');}})};
 await assert.rejects(()=>r.stop('over'));assert.equal(r.r.releasePending,'over');await r.alarm();assert.equal(releases,2);assert.equal(r.r.releasePending,undefined);
});

const fs=await import('node:fs/promises'),{tmpdir}=await import('node:os'),{join}=await import('node:path'),{spawnSync}=await import('node:child_process');
test('deploy helpers remove private Docker config on success and failure without registry access',async()=>{
 for(const helper of ['deploy_online.sh','deploy_site.sh'])for(const exit of [0,17]){
  const root=await fs.mkdtemp(join(tmpdir(),'phreaknic-deploy-test-'));
  try{
   for(const path of ['tools','bin','build/server','build/web','cloudflare/online/container','cloudflare/site','cloudflare/node_modules/.bin'])await fs.mkdir(join(root,path),{recursive:true});
   await fs.copyFile(new URL('../../../tools/'+helper,import.meta.url),join(root,'tools',helper));
   for(const [path,data]of [['project.godot','config/version="0.11"\n'],['build/server/phreaknic-server.x86_64','fake'],['build/web/index.html','fake'],['build/web/index.wasm','fake'],['build/web/BUILD_COMMIT','test-head'],['build/server/BUILD_COMMIT','test-head']])await fs.writeFile(join(root,path),data);
   await fs.writeFile(join(root,'bin/git'),'#!/bin/sh\ncase \"$*\" in *rev-parse*) echo test-head;; esac\n',{mode:0o700});
   // The scripts run `npm ci` and then the pinned wrangler from cloudflare/node_modules; fake both.
   await fs.writeFile(join(root,'bin/npm'),'#!/bin/sh\nexit 0\n',{mode:0o700});
   await fs.writeFile(join(root,'cloudflare/node_modules/.bin/wrangler'),'#!/bin/sh\ncase "$*" in *"object get"*) echo "The specified key does not exist." >&2; exit 1;; esac\n[ "$(stat -c %a "$DOCKER_CONFIG")" = 700 ] || exit 99\nprintf "%s\\n" "$DOCKER_CONFIG" > "$TASK_LOG"\nprintf "credential" > "$DOCKER_CONFIG/config.json"\nexit "$TASK_EXIT"\n',{mode:0o700});
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
 r.env={GAME_VERSION:'test',LOBBY:binding({bump:async keys=>events.push(...keys),remove:async c=>events.push(c)})};
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
 const originalResponse=globalThis.Response,originalPair=globalThis.WebSocketPair,originalNow=Date.now,now=Date.now();Date.now=()=>now;
 globalThis.Response=class extends originalResponse {constructor(body,init){if(init?.status===101){super(null);Object.defineProperty(this,'status',{value:101});}else super(body,init);}};
 globalThis.WebSocketPair=class {constructor(){this[0]=sock();this[1]=Object.assign(sock(),{accept(){},addEventListener(){}});}};
 try{const r=makeRoom();r.r.hostGoneAt=Date.now()-59999;await r.fetch(new Request('https://server/ws/room/AB23?token='+'a'.repeat(32),{headers:{Upgrade:'websocket'}}));assert.equal(r.r.hostGoneAt,undefined);}finally{globalThis.Response=originalResponse;globalThis.WebSocketPair=originalPair;Date.now=originalNow;}
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

test('site permits result download blobs while still forbidding eval and foreign script hosts',async()=>{
 const res=await site.fetch(new Request('https://site/icon.png'),{ASSETS:{fetch:async()=>new Response('image')}},{});
 const csp=res.headers.get('content-security-policy');
 assert(csp.includes("script-src 'self' 'wasm-unsafe-eval';"));
 assert(!csp.includes("'unsafe-eval'"));
 assert(csp.includes("img-src 'self' data: blob:;"));
 assert(!csp.includes('sandbox'));assert(!csp.includes('navigate-to'));
 assert(!res.headers.get('permissions-policy').includes('web-share=()'));
});

test('emotes relay with the authenticated seat, silently drop flood and malformed presets, and reach room sockets',async()=>{
 const r=makeRoom(),ws=sock(),other=sock(),sent=[],received=[];r.r.started=true;r.link={readyState:1};r.linkSend=m=>sent.push(m);r.clients.set(ws,{seat:0});r.clients.set(other,{seat:1});
 const original=Date.now;let now=original();Date.now=()=>now;
 try{
  for(const id of ['0',-1,8,0.5,null,true])await r.message(ws,JSON.stringify({type:'emote',id}));
  await r.message(ws,JSON.stringify({type:'emote',id:0,seat:1}));assert.equal(sent.length,0);
  for(let i=0;i<10;i++){await r.message(ws,JSON.stringify({type:'emote',id:i%8}));for(let j=0;j<5;j++)await r.message(ws,JSON.stringify({type:'emote',id:1}));now+=3000;}
  assert.equal(sent.length,10);assert.deepEqual(sent[0],{t:'from',seat:0,msg:{type:'emote',id:0}});assert(!ws.closed);
  await r.message(ws,JSON.stringify({type:'emote',id:0}));assert.equal(sent.length,10);now+=30000;await r.message(ws,JSON.stringify({type:'emote',id:7}));assert.equal(sent.length,11);
  r.send=(socket,m)=>received.push([socket,m]);await r.linkMessage({t:'to',seat:1,msg:{type:'emote',seat:0,id:7}});assert.deepEqual(received,[[other,{type:'emote',seat:0,id:7}]]);
  const oversized=sock();r.clients.set(oversized,{seat:1});await r.message(oversized,JSON.stringify({type:'emote',id:'x'.repeat(70000)}));assert.equal(oversized.closed.code,1009);
  // Emotes count against the seat's general rate limit: a flood closes the socket like any other flood.
  const flood=sock();r.clients.set(flood,{seat:1});const before=sent.length;for(let j=0;j<400&&!flood.closed;j++)await r.message(flood,JSON.stringify({type:'emote',id:1}));assert.equal(flood.closed?.code,1008);assert(sent.length-before<=1);
 }finally{Date.now=original;}
});

test('only lobby host sets bot pace and descriptions include defaults',async()=>{
 const r=makeRoom(),host=sock(),guest=sock();r.clients.set(host,{seat:0});r.clients.set(guest,{seat:1});
 await assert.rejects(()=>r.message(guest,JSON.stringify({t:'lobby',action:'settings',bot_pace:5})),/host/);
 await r.message(host,JSON.stringify({t:'lobby',action:'settings',bot_pace:1.5}));assert.equal(r.r.bot_pace,1.5);
 await assert.rejects(()=>r.message(host,JSON.stringify({t:'lobby',action:'settings',bot_pace:'1'})),/bot_pace/);
 let sent;r.broadcast=m=>sent=m;Room.prototype.broadcastRoom.call(r);assert.equal(sent.bot_pace,1.5);
 delete r.r.bot_pace;Room.prototype.broadcastRoom.call(r);assert.equal(sent.bot_pace,0.5);
});

test('container setup includes configured pace and older rooms default to half a second',async()=>{
 for(const pace of [undefined,0,5]){
  const r=makeRoom(),sent=[];r.r.bot_pace=pace;
  const ws={readyState:1,send(){},addEventListener(kind,callback){if(kind==='message')this.ready=callback;},accept(){this.ready({data:JSON.stringify({t:'ready'})});}};
  r.ctx={waitUntil(){},container:{running:true,setInactivityTimeout(){},getTcpPort(){return {fetch:async request=>request.url.endsWith('/health')?{status:200}:{webSocket:ws}};}}};
  r.env={GAME_VERSION:'test',LOBBY:binding({allow:async()=>true,refund:async()=>{},claim:async()=>null,bump:async()=>{}})};r.watch=()=>{};r.broadcast=()=>{};r.linkSend=m=>sent.push(m);
  await r.recover();assert.equal(sent.find(m=>m.t==='setup').bot_pace,pace??0.5);
 }
});

test('custom submissions are private, human-owned, withdrawable and cleared with pool or seat',async()=>{
 const {deflateSync}=await import('node:zlib');const r=makeRoom(),host=sock(),guest=sock(),messages=[];r.r.card_pool='custom';r.r.seats.forEach((s,i)=>s.name='p'+i);r.clients.set(host,{seat:0});r.clients.set(guest,{seat:1});r.broadcastRoom=Room.prototype.broadcastRoom;host.send=v=>messages.push(JSON.parse(v));
 const code='PNDK1.'+deflateSync(JSON.stringify({name:'Shared',cards:Object.fromEntries(Array.from({length:15},(_,i)=>['c'+i,4]))})).toString('base64url');
 const send=(ws,action,fields={})=>{r.rates.clear();return r.message(ws,JSON.stringify({t:'lobby',action,...fields}));};
 await send(guest,'submit_deck',{code});assert.deepEqual(messages.at(-1).seats[1].deck,{name:'Shared',count:60});assert(!JSON.stringify(messages).includes(code));
 await send(guest,'withdraw_deck');assert.equal(r.r.seats[1].deck,null);
 r.r.seats[1].bot=true;await assert.rejects(()=>send(guest,'submit_deck',{code}));r.r.seats[1].bot=false;
 await send(guest,'submit_deck',{code});await send(host,'settings',{card_pool:'2026'});assert.equal(r.r.seats[1].deck,undefined);
 await send(host,'settings',{card_pool:'custom'});await send(guest,'submit_deck',{code});await send(guest,'leave');assert.equal(r.r.seats[1].deck,undefined);
});
test('custom start requires submissions, setup carries sole winner and invalid winners fall back',async()=>{
 const r=makeRoom(),host=sock(),sent=[];r.clients.set(host,{seat:0});r.r.card_pool='custom';r.r.seats.forEach((s,i)=>s.name='p'+i);r.linkSend=m=>sent.push(m);r.stat=async()=>{};r.ensure=async()=>r.sendSetup();r.env={GAME_VERSION:'test',LOBBY:binding({allow:async()=>true,refund:async()=>{},claim:async()=>null})};
 await assert.rejects(()=>r.message(host,JSON.stringify({t:'lobby',action:'start'})),/Someone needs to submit a deck/);
 r.r.seats[1].deck={name:'Only',count:60,code:'PNDK1.private'};await r.message(host,JSON.stringify({t:'lobby',action:'start'}));assert.equal(sent[0].custom_deck_code,'PNDK1.private');assert.deepEqual(r.r.deck_order,[1]);assert(!sent[0].deck_roll.join(' ').includes('D20'));
 r.r.deck_order=[1,0];r.r.deck_groups=[[1],[0]];r.r.seats[0].deck={name:'Next',count:60,code:'PNDK1.next'};await r.linkMessage({t:'setup_error',attempt:0,reason:'invalid'});assert.equal(sent.at(-1).custom_deck_code,'PNDK1.next');assert.equal(r.r.seats[1].deck,undefined);
 r.stop=async()=>{};r.broadcast=()=>{};await r.linkMessage({t:'setup_error',attempt:1,reason:'invalid'});assert.equal(r.r.started,false);assert.equal(r.r.over,false);
});
test('multiple submissions roll on the Worker, broadcast ties and send highest deck only',async()=>{
 const r=makeRoom(),host=sock(),messages=[],setups=[],original=crypto.getRandomValues.bind(crypto);let rolls=[14,14,3,10];
 r.r.card_pool='custom';r.r.seats.forEach((s,i)=>{s.name='p'+i;s.deck={name:'Deck'+i,count:60,code:'PNDK1.private'+i};});r.clients.set(host,{seat:0});host.send=v=>messages.push(JSON.parse(v));r.broadcastRoom=Room.prototype.broadcastRoom;r.linkSend=m=>setups.push(m);r.stat=async()=>{};r.ensure=async()=>r.sendSetup();r.env={GAME_VERSION:'test',LOBBY:binding({allow:async()=>true,refund:async()=>{},claim:async()=>null})};
 crypto.getRandomValues=a=>{a[0]=rolls.shift();return a;};
 try{await r.message(host,JSON.stringify({t:'lobby',action:'start'}));}finally{crypto.getRandomValues=original;}
 assert.equal(setups[0].custom_deck_code,'PNDK1.private1');assert.deepEqual(r.r.deck_order,[1,0]);assert(messages.at(-1).deck_roll.join(' ').includes('Tie at 15'));assert(!JSON.stringify(messages).includes('PNDK1.'));
});
test('the deck roll is kept only for a custom start that goes through',async()=>{
 const r=makeRoom(),host=sock(),original=crypto.getRandomValues.bind(crypto),rolls=[14,3,12,5];let claims=0;
 r.r.card_pool='custom';r.r.seats.forEach((s,i)=>{s.name='p'+i;s.deck={name:'Deck'+i,count:60,code:'PNDK1.private'+i};});r.clients.set(host,{seat:0});r.stat=async()=>{};r.ensure=async()=>{};r.env={GAME_VERSION:'test',LOBBY:binding({allow:async()=>true,refund:async()=>{},claim:async()=>claims++?null:'busy'})};
 const start=()=>r.message(host,JSON.stringify({t:'lobby',action:'start'}));
 crypto.getRandomValues=a=>{a[0]=rolls.shift();return a;};
 try{
  await assert.rejects(start,/busy/);assert.deepEqual(r.r.deck_roll??[],[]);
  await start();assert.equal(r.r.deck_roll.length,1);assert(r.r.deck_roll[0].startsWith('Deck roll (D20): p0 '));
 }finally{crypto.getRandomValues=original;}
 // Back in the lobby (every deck turned out invalid), a standard-set start shows no roll.
 r.r.started=false;r.r.card_pool='2026';await start();assert.deepEqual(r.r.deck_roll,[]);
});
test('a join returns the token it issued, never the next occupant\'s (kick + rejoin during the awaits)',async()=>{
 const r=makeRoom();r.env={GAME_VERSION:'0.30'};r.r.version='0.30';r.r.seats[1]={bot:false,token:''};let gate;r.stat=()=>new Promise(resolve=>gate=resolve);
 const first=r.joinRoom({name:'First',hero:'',version:'0.30'});
 await new Promise(resolve=>setImmediate(resolve));
 // While the first join waits, the host kicks seat 1 and a second player takes it.
 r.r.seats[1]={bot:false,token:''};const g=gate;r.stat=async()=>{};const second=await r.joinRoom({name:'Second',hero:'',version:'0.30'});g();
 await assert.rejects(first,e=>e.message==='full'&&e.status===409);
 assert.equal(second.token,r.r.seats[1].token);
});
test('starts are bounded per room and per IP before any slot is claimed',async()=>{
 let claims=0;const r=makeRoom(),host=sock();r.clients.set(host,{seat:0,ip:'1.2.3.4'});r.stat=async()=>{};r.ensure=async()=>{};
 r.r.starts=5;r.env={GAME_VERSION:'test',LOBBY:binding({allow:async()=>true,refund:async()=>{},claim:async()=>{claims++;return null;}})};
 await assert.rejects(()=>r.message(host,JSON.stringify({t:'lobby',action:'start'})),e=>/too many times/.test(e.message));
 let asked;r.r.starts=0;r.env={GAME_VERSION:'test',LOBBY:binding({allow:async(ip,kind)=>{asked=[ip,kind];return false;},claim:async()=>{claims++;return null;}})};
 await assert.rejects(()=>r.message(host,JSON.stringify({t:'lobby',action:'start'})),e=>e.message==='rate_limit'&&e.status===429);
 assert.deepEqual(asked,['1.2.3.4','start']);assert.equal(claims,0);assert(!r.r.started);assert(!r.starting);
 r.env={GAME_VERSION:'test',LOBBY:binding({allow:async()=>true,refund:async()=>{},claim:async(...args)=>{assert.equal(args[3],true);claims++;return null;}})};await r.message(host,JSON.stringify({t:'lobby',action:'start'}));
 assert.equal(claims,1);assert.equal(r.r.starts,1);assert(r.r.started);
});
test('a start refused for capacity refunds the start allowance',async()=>{
 const refunds=[];const r=makeRoom(),host=sock();r.clients.set(host,{seat:0,ip:'5.6.7.8'});r.ensure=()=>assert.fail('boot');
 r.env={GAME_VERSION:'test',LOBBY:binding({allow:async()=>true,refund:async()=>{},claim:async()=>'busy',refund:async(ip,kind)=>refunds.push([ip,kind])})};
 await assert.rejects(()=>r.message(host,JSON.stringify({t:'lobby',action:'start'})),e=>e.message==='busy');
 assert.deepEqual(refunds,[['5.6.7.8','start']]);assert.equal(r.r.starts||0,0);
});
test('waiting rooms are capped per client (IPv6 /64 counts as one) and globally; started rooms don\'t count',async()=>{
 const {DatabaseSync}=await import('node:sqlite');const db=new DatabaseSync(':memory:');
 const l=new Lobby({storage:{sql:{exec:(q,...p)=>db.prepare(q).all(...p)}}},{});
 const mine=[];for(let i=0;i<5;i++)mine.push(l.reserve('2001:db8:1:2::/64'));
 assert.throws(()=>l.reserve('2001:db8:1:2::/64'),e=>e.message==='rate_limit'&&e.status===429);
 assert.equal(l.reserve('198.51.100.7').length,6);
 // Once a room starts it no longer counts as waiting.
 l.upsert(mine[0],null,Date.now()+3600000,1,false);assert.equal(l.reserve('2001:db8:1:2::/64').length,6);
 for(let n=0;n<110;n++)for(let i=0;i<5;i++){try{l.reserve('203.0.'+n+'.1');}catch(e){assert.equal(e.message,'capacity');}}
 assert.throws(()=>l.reserve('192.0.2.200'),e=>e.message==='capacity'&&e.status===503);
});

const realLobby=async()=>{const {DatabaseSync}=await import('node:sqlite'),db=new DatabaseSync(':memory:');return {db,l:new Lobby({storage:{sql:{exec:(q,...p)=>db.prepare(q).all(...p)}}},{GAME_VERSION:'test'})};};
test('client running and daily caps, recovery, total rooms and UTC rollover',async()=>{
 const {l,db}=await realLobby(),ip='192.0.2.71',codes=Array.from({length:5},()=>l.reserve(ip)),now=Date.now();
 assert.equal(l.claim(codes[0],now,ip,true),null);assert.equal(l.claim(codes[1],now,ip,true),null);assert.equal(l.claim(codes[0],now,ip,true),null);assert.equal(l.claim(codes[2],now,ip),'busy');
 for(const c of codes.slice(0,2))l.upsert(c,null,now+3600000,0,false);
 l.reserve(ip);l.reserve(ip);assert.throws(()=>l.reserve(ip),/rate_limit/);
 l.release(codes[0]);l.release(codes[1]);for(let i=0;i<8;i++){assert.equal(l.claim(codes[0],now,ip,true),null);l.release(codes[0]);}assert.equal(l.claim(codes[0],now,ip,true),'busy');
 db.prepare('UPDATE client_starts SET day=?').run('2000-01-01');assert.equal(l.claim(codes[0],now,ip,true),null);
});
test('IPv6 /48 enforces aggregate rate, waiting, running and daily limits',async()=>{
 const {l,db}=await realLobby(),now=Date.now();
 for(let i=0;i<4;i++)for(let n=0;n<30;n++)assert(l.allow(`2001:db8:a:${i}::/64`,'create'));
 assert(!l.allow('2001:db8:a:5::/64','create'));assert(l.allow('2001:db8:b:5::/64','create'));
 const codes=[];for(let i=0;i<4;i++)for(let n=0;n<5;n++)codes.push(l.reserve(`2001:db8:c:${i}::/64`));assert.throws(()=>l.reserve('2001:db8:c:5::/64'),/rate_limit/);
 for(let i=0;i<8;i++)assert.equal(l.claim(codes[i],now,`2001:db8:d:${i}::/64`),null);assert.equal(l.claim(codes[8],now,'2001:db8:d:9::/64'),'busy');
 db.prepare('DELETE FROM live').run();db.prepare('INSERT INTO client_starts VALUES(?,?,?)').run(new Date(now).toISOString().slice(0,10),'2001:db8:e::/48',40);assert.equal(l.claim(codes[8],now,'2001:db8:e:9::/64',true),'busy');
});
test('over-limit Lobby refusals perform no SQL writes; isolate refusals skip rate RPCs',async()=>{
 const {l}=await realLobby();for(let i=0;i<30;i++)assert(l.allow('192.0.2.72','create'));const exec=l.sql.exec;let writes=0;l.sql.exec=(q,...p)=>{if(!q.startsWith('SELECT'))writes++;return exec(q,...p);};assert(!l.allow('192.0.2.72','create'));assert.equal(writes,0);
 let calls=0;const env={GAME_VERSION:'blocked-test',LOBBY:binding({allow:async()=>{calls++;return false;},bump:async()=>{calls++;}})},req=()=>new Request('https://server/rooms',{headers:{'CF-Connecting-IP':'192.0.2.73'}});
 assert.equal((await worker.fetch(req(),env)).status,429);const first=calls;assert.equal((await worker.fetch(req(),env)).status,429);assert.equal(calls,first+1); // refusal metric still recorded; rate RPC is skipped
});
test('edge binding refuses before Lobby and health bypasses it; absent binding is optional',async()=>{
 let edges=0;const env={EDGE_LIMIT:{limit:async({key})=>{edges++;assert.equal(key,'192.0.2.74');return {success:false};}},LOBBY:binding({})};
 const limited=await worker.fetch(new Request('https://server/rooms',{headers:{'CF-Connecting-IP':'192.0.2.74',Origin:'https://phreaknic-ccg.net'}}),env);assert.equal(limited.status,429);assert.equal(limited.headers.get('Access-Control-Allow-Origin'),'https://phreaknic-ccg.net');
 assert.equal((await worker.fetch(new Request('https://server/health'),env)).status,200);assert.equal(edges,1);delete env.EDGE_LIMIT;assert.equal((await worker.fetch(new Request('https://server/health'),env)).status,200);
});
test('missing deployment version blocks HTTP create/join and socket start',async()=>{
 const env={LOBBY:binding({bump:async()=>{}})};for(const path of ['/rooms','/rooms/AB23/join']){const res=await worker.fetch(new Request('https://server'+path,{method:'POST',body:'bad'}),env);assert.equal(res.status,503);assert.deepEqual(await res.json(),{error:'maintenance'});}
 const r=makeRoom(),ws=sock();r.env=env;r.clients.set(ws,{seat:0});await assert.rejects(()=>r.message(ws,JSON.stringify({t:'lobby',action:'start'})),/maintenance/);
});
test('duplicate human handles are rejected before seat mutation',async()=>{
 const r=makeRoom();r.env={GAME_VERSION:'test'};r.r.seats[0].name=' Host ';r.r.seats[1].token='';await assert.rejects(()=>r.joinRoom({name:'host',version:'test'}),e=>e.message==='name_taken'&&e.status===409);assert.equal(r.r.seats[1].token,'');
});
test('stats platform storage is bounded by seat across repeated joins',async()=>{
 const {l,db}=await realLobby(),r={...makeRoom().r,version:'test',card_pool:'2026',starting_life:0};l.record('create',r,'web');for(let i=0;i<100;i++)l.record('join',r,'linux',{seat:1});assert.deepEqual(JSON.parse(db.prepare('SELECT platforms FROM games').get().platforms),['web','linux']);
});
test('lobby saves coalesce, summary and alarm writes deduplicate, immediate save drains dirty state',async()=>{
 const r=makeRoom(),puts=[],alarms=[],upserts=[];r.save=Room.prototype.save;r.ctx={storage:{put:async(k,v)=>puts.push(structuredClone(v)),setAlarm:async t=>alarms.push(t)}};r.env={LOBBY:binding({upsert:async(...args)=>upserts.push(args)})};
 await r.save();await r.save();assert.equal(upserts.length,1);assert.equal(alarms.length,1);puts.length=0;
 for(let i=0;i<5;i++){r.r.bot_pace=i;await r.save(true,true);}assert.equal(puts.length,0);assert.equal(alarms.length,2);
 r.flushAt=Date.now()-1;await r.alarm();assert.equal(puts.length,1);assert.equal(puts[0].bot_pace,4);assert(!r.flushAt);assert.equal(upserts.length,1);
 await r.save(true,true);r.r.started=true;await r.save(true);assert(!r.flushAt);assert.equal(upserts.length,2);assert.equal(puts.at(-1).started,true);
 r.clients.set(sock(),{seat:0});await r.save();assert.equal(upserts.length,3);
});
test('lobby messages have independent burst and minute rates; game size abuse strikes',async()=>{
 const r=makeRoom(),ws=sock();r.clients.set(ws,{seat:0});for(let i=0;i<6;i++)await r.message(ws,JSON.stringify({t:'lobby',action:'settings',bot_pace:0}));assert.equal(r.rates.get('lobby:0').messages.count,6);assert.equal(r.rates.get('lobby:0').strikes.count,1);
 r.r.started=true;r.link={readyState:1};let sent=0;r.linkSend=()=>sent++;r.savedAt=Date.now();await r.message(ws,JSON.stringify({action:'tiny'}));assert.equal(sent,1);
 for(let i=0;i<11;i++)await r.message(ws,JSON.stringify({action:'x'.repeat(4096)}));assert.equal(sent,1);assert.equal(ws.closed.code,1008);
});
test('header token has precedence for seat checks and upgrade returns only phreaknic protocol',async()=>{
 const r=makeRoom();r.env={};const headers={'Sec-WebSocket-Protocol':'phreaknic, t.'+'a'.repeat(32)};
 assert.equal((await r.fetch(new Request('https://server/ws/room/AB23?token='+'b'.repeat(32),{headers}))).status,426);
 assert.equal((await r.fetch(new Request('https://server/ws/room/AB23?token='+'a'.repeat(32),{headers:{'Sec-WebSocket-Protocol':'phreaknic, t.bad'}}))).status,401);
 const Original=globalThis.Response,Pair=globalThis.WebSocketPair;globalThis.Response=class extends Original{constructor(b,i){if(i?.status===101){super(null,{headers:i.headers});Object.defineProperty(this,'status',{value:101});}else super(b,i);}};globalThis.WebSocketPair=class{constructor(){this[0]=sock();this[1]=Object.assign(sock(),{accept(){},addEventListener(){}});}};
 try{const res=await r.fetch(new Request('https://server/ws/room/AB23',{headers:{...headers,Upgrade:'websocket'}}));assert.equal(res.status,101);assert.equal(res.headers.get('Sec-WebSocket-Protocol'),'phreaknic');}finally{globalThis.Response=Original;globalThis.WebSocketPair=Pair;}
});
test('container setup has host seat and placeholder secrets; restore scrubs legacy tokens',async()=>{
 const r=makeRoom(),sent=[];r.linkSend=m=>sent.push(m);r.sendSetup();assert.equal(sent[0].host_seat,0);for(let i=0;i<2;i++){assert.match(sent[0].seats[i].token,/^[a-f0-9]{32}$/);assert.notEqual(sent[0].seats[i].token,r.r.seats[i].token);}
 r.r.snapshot={tokens:r.r.seats.map(s=>s.token),players:r.r.seats.map(s=>({token:s.token})),state:{turn:3}};const restored=r.containerSnapshot();assert.equal(restored.state.turn,3);assert(restored.tokens.every(t=>/^[a-f0-9]{32}$/.test(t)));assert.notDeepEqual(restored.tokens,r.r.snapshot.tokens);assert.notEqual(restored.players[0].token,r.r.seats[0].token);assert.equal(r.r.snapshot.players[0].token,r.r.seats[0].token);
});
test('container start injects LINK_KEY and link upgrade uses matching persisted secret after recovery',async()=>{
 const r=makeRoom(),starts=[],keys=[],sent=[];let running=false;const ws={readyState:1,send(){},addEventListener(k,fn){if(k==='message')this.ready=fn;},accept(){this.ready({data:'{"t":"ready"}'});}};
 r.ctx={storage:{put:async()=>{}},waitUntil(){},container:{get running(){return running;},images:{base:'image'},start:async o=>{starts.push(o);running=true;},setInactivityTimeout(){},getTcpPort(){return {fetch:async req=>{if(req.url.endsWith('/health'))return {status:200};keys.push(req.headers.get('X-Link-Key'));return {webSocket:ws};}};}}};r.watch=()=>{};r.env={LOBBY:binding({claim:async()=>null,bump:async()=>{}})};r.broadcast=()=>{};r.linkSend=m=>sent.push(m);
 await r.recover();assert.match(starts[0].env.LINK_KEY,/^[a-f0-9]{32}$/);assert.equal(keys[0],starts[0].env.LINK_KEY);await r.recover();assert.equal(starts.length,1);assert.equal(keys[1],keys[0]);
});

test('deploy scripts require tracked cleanliness and matching build commit, override warns; install precedes credentials',async()=>{
 for(const helper of ['deploy_online.sh','deploy_site.sh','deploy_pages.sh']){
  const root=await fs.mkdtemp(join(tmpdir(),'deploy-guard-'));
  try{
   for(const path of ['tools','bin','build/server','build/web'])await fs.mkdir(join(root,path),{recursive:true});await fs.copyFile(new URL('../../../tools/'+helper,import.meta.url),join(root,'tools',helper));
   await fs.writeFile(join(root,'bin/git'),'#!/bin/sh\ncase "$*" in *status*) printf "%s" "$TASK_DIRTY";; *rev-parse*) echo head;; esac\n',{mode:0o700});
   const run=vars=>spawnSync('bash',[join(root,'tools',helper)],{encoding:'utf8',env:{...process.env,FORCE_DIRTY:'',PATH:join(root,'bin')+':'+process.env.PATH,...vars}});
   let res=run({TASK_DIRTY:' M tracked'});assert.equal(res.status,1);assert.match(res.stderr,/uncommitted changes/);
   const target=helper==='deploy_online.sh'?'server':'web';await fs.writeFile(join(root,'build',target,'BUILD_COMMIT'),'old');res=run({TASK_DIRTY:''});assert.equal(res.status,1);assert.match(res.stderr,/Build commit differs/);
   res=run({TASK_DIRTY:' M tracked',FORCE_DIRTY:'1'});assert.equal(res.status,1);assert.match(res.stderr,/WARNING: FORCE_DIRTY/);assert.match(res.stderr,/Build commit differs/);
   await fs.writeFile(join(root,'build',target,'BUILD_COMMIT'),'head\ndirty\n');res=run({TASK_DIRTY:''});assert.equal(res.status,1);assert.match(res.stderr,/refusing dirty build/);await fs.writeFile(join(root,'build',target,'BUILD_COMMIT'),'old\ndirty\n');res=run({TASK_DIRTY:'',FORCE_DIRTY:'1'});assert.match(res.stderr,/Build commit differs/);assert.doesNotMatch(res.stderr,/refusing dirty build/);
   const source=await fs.readFile(join(root,'tools',helper),'utf8');if(helper!=='deploy_pages.sh')assert(source.indexOf('npm ci')<source.indexOf('source "$HOME/')||helper==='deploy_site.sh'&&source.indexOf('npm ci')<source.indexOf('. "$HOME/'));
  }finally{await fs.rm(root,{recursive:true,force:true});}
 }
});
test('build validates versions, cleans web output and writes commit markers',async()=>{
 const root=await fs.mkdtemp(join(tmpdir(),'build-provenance-'));
 try{
  for(const path of ['tools/web','bin','assets/music','build/web'])await fs.mkdir(join(root,path),{recursive:true});await fs.copyFile(new URL('../../../tools/build_all.sh',import.meta.url),join(root,'tools/build_all.sh'));
  await fs.writeFile(join(root,'tools/web/share.js'),'helper');await fs.writeFile(join(root,'assets/music/song.ogg'),'music');await fs.writeFile(join(root,'build/web/stale'),'old');
  await fs.writeFile(join(root,'bin/git'),'#!/bin/sh\necho build-head\n',{mode:0o700});await fs.writeFile(join(root,'bin/godot'),'#!/bin/sh\ncase "$*" in *--export-release*) for last; do :; done; touch "$last";; esac\n',{mode:0o700});
  const run=()=>spawnSync('bash',[join(root,'tools/build_all.sh'),'web','server'],{encoding:'utf8',env:{...process.env,PATH:join(root,'bin')+':'+process.env.PATH,GODOT:join(root,'bin/godot')}});
  await fs.writeFile(join(root,'project.godot'),'config/version="../bad"\n');let res=run();assert.equal(res.status,1);assert.match(res.stderr,/Invalid project version/);assert.equal(await fs.readFile(join(root,'build/web/stale'),'utf8'),'old');
  await fs.writeFile(join(root,'project.godot'),'config/version="0.31"\n');res=run();assert.equal(res.status,0,res.stderr);await assert.rejects(()=>fs.stat(join(root,'build/web/stale')));for(const target of ['web','server'])assert.equal((await fs.readFile(join(root,'build',target,'BUILD_COMMIT'),'utf8')).trim(),'build-head\ndirty');
 }finally{await fs.rm(root,{recursive:true,force:true});}
});

test('routine lobby commands defer persistence while start and kick flush immediately',async()=>{
 const r=makeRoom(),ws=sock(),calls=[];r.clients.set(ws,{seat:0});r.save=async(...args)=>calls.push(args);r.env={GAME_VERSION:'test',LOBBY:binding({allow:async()=>true,claim:async()=>null})};r.stat=async()=>{};r.ensure=async()=>{};
 await r.message(ws,'{"t":"lobby","action":"settings","bot_pace":1}');assert.deepEqual(calls.pop(),[true,true]);
 await r.message(ws,'{"t":"lobby","action":"start"}');assert.deepEqual(calls.pop(),[true]);r.r.started=false;
 await r.message(ws,'{"t":"lobby","action":"kick","seat":1}');assert.deepEqual(calls.pop(),[true,false]);
});
test('expiry and host closure consume pending flush without resurrecting deleted state',async()=>{
 for(const expired of [true,false]){
  const r=makeRoom(),events=[];r.flushAt=Date.now()-1;r.save=Room.prototype.save;r.r.public=false;if(expired)r.r.created=Date.now()-8*3600000;else r.r.hostGoneAt=Date.now()-60000;
  r.stat=async()=>{};r.ctx={storage:{put:async()=>events.push('put'),setAlarm:async()=>{},deleteAll:async()=>events.push('delete')},container:{destroy:async()=>{}}};r.env={LOBBY:binding({upsert:async()=>events.push('upsert'),remove:async()=>events.push('remove'),bump:async()=>{}})};
  await r.alarm();assert.equal(r.r,null);assert(!r.flushAt);assert.equal(events.at(-1),'delete');await r.alarm();assert.equal(events.at(-1),'delete');
 }
});
test('dev and production have edge bindings and only dev opts into loopback origins',async()=>{
 const config=JSON.parse(await readFile(new URL('../wrangler.jsonc',import.meta.url),'utf8'));for(const env of [config,config.env.dev]){const edge=env.ratelimits.find(x=>x.name==='EDGE_LIMIT');assert.match(edge.namespace_id,/^[0-9]+$/);assert.deepEqual(edge.simple,{limit:120,period:60});}assert.equal(config.env.dev.vars.ALLOW_LOCAL_ORIGINS,'1');assert.notEqual(config.vars.ALLOW_LOCAL_ORIGINS,'1');
});

test('existing live rows inherit their creating client when the new column is added',async()=>{
 const {DatabaseSync}=await import('node:sqlite'),db=new DatabaseSync(':memory:');db.exec('CREATE TABLE rooms(code TEXT PRIMARY KEY,summary TEXT,expires INTEGER NOT NULL,ip TEXT,pending INTEGER); CREATE TABLE live(code TEXT PRIMARY KEY,expires INTEGER)');
 for(const c of ['OLD234','OLD235']){db.prepare('INSERT INTO rooms VALUES(?,NULL,?,?,0)').run(c,Date.now()+3600000,'192.0.2.90');db.prepare('INSERT INTO live VALUES(?,?)').run(c,Date.now()+3600000);}
 const l=new Lobby({storage:{sql:{exec:(q,...p)=>db.prepare(q).all(...p)}}},{});assert.equal(l.claim('NEW234',Date.now(),'192.0.2.90'),'busy');
});

test('finished rooms do not consume total room slots; recovery does not consume daily starts',async()=>{
 const {l,db}=await realLobby(),ip='192.0.2.191',now=Date.now();
 for(let i=0;i<12;i++){const c=l.reserve(ip);assert.equal(l.claim(c,now,ip,i===0),null);l.upsert(c,null,now+3600000,0,false);l.release(c);}
 assert.equal(db.prepare('SELECT count FROM client_starts WHERE ip=?').get(ip).count,1);
});
test('seat check CORS preflight and Authorization status',async()=>{
 const origin='https://phreaknic-ccg.net',r=makeRoom(),env={LOBBY:binding({allow:async()=>true}),ROOMS:binding(r)};
 const pre=await worker.fetch(new Request('https://server/ws/room/AB23',{method:'OPTIONS',headers:{Origin:origin,'Access-Control-Request-Headers':'authorization'}}),env);
 assert.equal(pre.status,204);assert.match(pre.headers.get('Access-Control-Allow-Headers'),/Authorization/i);assert.match(pre.headers.get('Access-Control-Allow-Methods'),/GET/);
 for(const [token,status]of [['a'.repeat(32),426],['c'.repeat(32),401]]){const res=await worker.fetch(new Request('https://server/ws/room/AB23',{headers:{Origin:origin,Authorization:'Bearer '+token}}),env);assert.equal(res.status,status);assert.equal(res.headers.get('Access-Control-Allow-Origin'),origin);}
});
test('route blocks preserve reconnects and CORS; edge exceptions fail open',async()=>{
 const origin='https://phreaknic-ccg.net',ip='192.0.2.192',r=makeRoom();let creates=0;
 const env={GAME_VERSION:'test',LOBBY:binding({allow:async(_,kind)=>kind==='create'?(creates++,false):true,bump:async()=>{}}),ROOMS:binding(r)};
 for(let i=0;i<2;i++){const res=await worker.fetch(new Request('https://server/rooms',{method:'POST',headers:{Origin:origin,'CF-Connecting-IP':ip},body:JSON.stringify({name:'Alice',version:'test',public:false,seats:[{bot:false,difficulty:0},{bot:true,difficulty:0}],card_pool:'2026',starting_life:0})}),env);assert.equal(res.status,429);assert.equal(res.headers.get('Access-Control-Allow-Origin'),origin);}
 assert.equal(creates,1);
 const res=await worker.fetch(new Request('https://server/ws/room/AB23',{headers:{Origin:origin,'CF-Connecting-IP':ip,Authorization:'Bearer '+'a'.repeat(32)}}),env);assert.equal(res.status,426);
 env.EDGE_LIMIT={limit:async()=>{throw Error('unavailable');}};assert.equal((await worker.fetch(new Request('https://server/ws/room/AB23',{headers:{Authorization:'Bearer '+'a'.repeat(32)}}),env)).status,426);
});
test('unchanged rooms refresh Lobby once per ten-minute bucket',async()=>{
 const r=makeRoom(),now=Date.now,base=1800000000000,calls=[];r.r.started=true;let time=base;r.save=Room.prototype.save;r.schedule=async()=>{};r.ctx={storage:{put:async()=>{}}};r.env={LOBBY:binding({upsert:async(...args)=>calls.push(args)})};Date.now=()=>time;
 try{await r.save();await r.save();assert.equal(calls.length,1);time+=600000;await r.save();assert.equal(calls.length,2);}finally{Date.now=now;}
});

test('edge limit still protects admin routes with CORS',async()=>{
 const res=await worker.fetch(new Request('https://server/admin',{headers:{Origin:'https://online-01.phreaknic-ccg.net'}}),{EDGE_LIMIT:{limit:async()=>({success:false})}});
 assert.equal(res.status,429);assert.equal(res.headers.get('Access-Control-Allow-Origin'),'https://online-01.phreaknic-ccg.net');
});
