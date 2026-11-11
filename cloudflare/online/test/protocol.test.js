import {test} from 'node:test';
import assert from 'node:assert/strict';
import {webcrypto} from 'node:crypto';
import {ALPHABET,code,validCode,token,validToken,creation,identity,settings,difficulty,originAllowed,route,wrap,summary,isOpen,checkVersion,platform,constantTimeEqual,adminEnabled,statsDays,creationKeys} from '../src/lib/protocol.js';
if(!globalThis.crypto)globalThis.crypto=webcrypto;
const input=()=>({name:' Nirtom ',hero:'nirtom',public:true,seats:[{bot:true,difficulty:0},{bot:false,difficulty:0}],card_pool:'2026',starting_life:0,version:'0.09'});
test('codes use four unambiguous symbols and reject biased random bytes',()=>{
 assert(!/[01OIL]/.test(ALPHABET));
 let n=0;assert.equal(code({getRandomValues:a=>{a.fill(n++?0:255);return a;}}),'2222');
 for(let i=0;i<100;i++)assert(validCode(code()));
 for(const s of ['ABCDX','ABO2','abc2','A/B2',''])assert(!validCode(s));
});
test('tokens are 128-bit hex and independently generated',()=>{const values=new Set(Array.from({length:100},token));assert.equal(values.size,100);for(const v of values)assert(validToken(v));assert(!validToken('a'.repeat(31)));assert(!validToken('g'.repeat(32)));});
test('creation validates and normalizes all required fields',()=>{const r=creation(input());assert.equal(r.seats[0].name,'Nirtom');assert.equal(r.seats[0].bot,false);assert(validToken(r.seats[0].token));assert.equal(r.seats[1].token,'');assert.equal(creation({...input(),hero:''}).seats[0].hero,'');for(const [k,v]of Object.entries({name:'x'.repeat(17),hero:5,public:1,seats:[],card_pool:'2027',starting_life:10,version:'x'.repeat(33)}))assert.throws(()=>creation({...input(),[k]:v}));});
test('names, seat fields, and settings reject malformed values',()=>{for(const name of ['', '  ','a\nb','a\u0000b','a\u200bb'])assert.throws(()=>identity({...input(),name}));for(const n of [-1,3,1.5,'1',null])assert.throws(()=>difficulty(n));assert.throws(()=>creation({...input(),seats:[{bot:false,difficulty:0},{bot:'yes',difficulty:1}]}));assert.deepEqual(settings({public:false},true),{public:false});assert.throws(()=>settings({starting_life:21},true));});
test('CORS permits only listed origins and HTTP loopback',()=>{for(const o of [null,'https://phreaknic-ccg.net','https://www.phreaknic-ccg.net','https://nirtom84.github.io','http://localhost:8080','http://127.0.0.1:1234'])assert(originAllowed(o));for(const o of ['null','https://evil.test','https://phreaknic-ccg.net.evil.test','http://localhost.evil.test:80','https://localhost:1234','http://localhost:8080/path'])assert(!originAllowed(o));});
test('routes match methods and exact paths',()=>{assert.deepEqual(route('POST','/rooms/AB23/join'),{kind:'join',code:'AB23'});assert.equal(route('GET','/ws/room/AB23').kind,'ws');assert.equal(route('GET','/rooms').kind,'list');assert.equal(route('POST','/rooms').kind,'create');assert.equal(route('GET','/health').kind,'health');for(const [m,p]of [['GET','/rooms/AB23/join'],['POST','/ws/room/AB23'],['GET','/ws/room/ABO1'],['GET','/health/']])assert.equal(route(m,p),null);});
test('game payload remains opaque and unchanged',()=>{const msg={t:'answer',nested:{secret:[null,1,'x']}};const r=wrap(2,msg);assert.deepEqual(r,{t:'from',seat:2,msg});assert.equal(r.msg,msg);});
test('public summary includes avatars but omits tokens, snapshots and closed rooms',()=>{const r={...creation(input()),code:'AB23',created:123,started:false,over:false,snapshot:{secret:1}};assert.deepEqual(summary(r),{banned_count:0,code:'AB23',host:'Nirtom',seats:[{name:'Nirtom',hero:'nirtom',bot:false,difficulty:0},{name:'',hero:'',bot:false,difficulty:0}],open_seats:1,card_pool:'2026',starting_life:0,bot_pace:0.5,version:'0.09',created:123});assert(isOpen(r));for(const patch of [{public:false},{started:true},{over:true},{seats:[r.seats[0],{bot:true}]}])assert(!isOpen({...r,...patch}));});

test('release version gate accepts matching or unconfigured versions',()=>{
 for(const required of [undefined,'']) for(const client of ['0.09','0.10']) assert.doesNotThrow(()=>checkVersion(client,required));
 assert.doesNotThrow(()=>checkVersion('0.10','0.10'));
 for(const client of ['0.09','',undefined]) assert.throws(()=>checkVersion(client,'0.10'),e=>e.status===409&&e.message==='version'&&e.extra.need==='0.10');
});

test('platform normalization is bounded and keeps missing distinct',()=>{for(const p of ['windows','linux','macos','android','ios','web'])assert.equal(platform(p),p);assert.equal(platform(undefined),'unknown');for(const p of [null,'Windows','unknown','',{},42])assert.equal(platform(p),'other');});
test('hashed constant time comparison handles all lengths',async()=>{assert(await constantTimeEqual('same','same'));assert(!await constantTimeEqual('same','diff'));assert(!await constantTimeEqual('short','a longer value'));assert(await constantTimeEqual('',''));});
test('admin key must be configured with at least 32 characters',()=>{for(const key of [undefined,null,'','x'.repeat(31),32])assert(!adminEnabled(key));assert(adminEnabled('x'.repeat(32)));assert(adminEnabled('x'.repeat(64)));});
test('stats ranges accept only whole days from 1 to 400',()=>{assert.equal(statsDays(null),30);assert.equal(statsDays(undefined),30);for(const n of ['1','7','30','90','365','400'])assert.equal(statsDays(n),Number(n));for(const n of ['','0','401','-1','1.5','NaN','Infinity','30x',' 7'])assert.throws(()=>statsDays(n));});
test('creation daily keys contain only aggregate dimensions',()=>{const r=creation(input());assert.deepEqual(creationKeys(r,'linux'),['rooms.created','rooms.public','seats.2','pool.2026','life.0','version.0.09','platform.linux']);assert(creationKeys({...r,public:false},'unknown').includes('rooms.invite'));assert(!JSON.stringify(creationKeys(r,'linux')).includes('Nirtom'));assert(!('platform' in identity({...input(),platform:'web'})));assert(!('platform' in creation({...input(),platform:'web'}).seats[0]));});

const hardening=await import('../src/lib/protocol.js');
test('spending caps, counted restart, and maintenance decisions',()=>{
 const {startDecision:s}=hardening;
 assert.equal(s(undefined,false,19,299),null);assert.equal(s('1',false,20,0),'busy');assert.equal(s('1',false,0,300),'busy');assert.equal(s('1',true,20,300),null);assert.equal(s('0',false,0,0),'maintenance');assert.equal(s('0',true,20,300),'maintenance');
});
test('room hard lifetime ignores activity and connections',()=>{
 const {roomExpired:e,ROOM_LIFETIME:l}=hardening,r={created:100,lastActivity:1e12,emptySince:null};assert(!e(r,100+l-1));assert(e(r,100+l));assert(e(r,100+l+1));
});
test('rate windows reset on their boundary and failure buckets lock',()=>{
 const {rateDecision:r}=hardening;assert(r({window:0,count:59},59999,60,60000).allowed);assert(!r({window:0,count:60},59999,60,60000).allowed);assert.deepEqual(r({window:0,count:60},60000,60,60000),{allowed:true,window:60000,count:1});assert(!r({window:0,count:30},3599999,30,3600000).allowed);assert(r({window:0,count:30},3600000,30,3600000).allowed);
});
test('seat traffic is shared across sockets and sustained flooding closes',()=>{
 let state={};for(let i=0;i<30;i++){state=hardening.seatRate(state,100,1);assert(state.allowed);}state=hardening.seatRate(state,100,1);assert(!state.allowed);assert(!state.close);for(let i=0;i<10;i++)state=hardening.seatRate(state,100,1);assert(state.close);
 state={};for(let i=0;i<4;i++)state=hardening.seatRate(state,100+i*1000,65536);assert(state.allowed);state=hardening.seatRate(state,5000,1);assert(!state.allowed);assert(state.close);assert(hardening.seatRate(state,10100,1).allowed);
});
test('unknown rooms, wrong and malformed tokens use the same authentication decision',()=>{
 const t='a'.repeat(32),r={started:true,seats:[{bot:false,token:t}]};for(const [room,key]of [[null,t],[r,'b'.repeat(32)],[r,''],[r,null]])assert.equal(hardening.socketSeat(room,key),-1);assert.equal(hardening.socketSeat(r,t),0);
});
test('kick accepts only a joined nonhost human before start',()=>{
 const r={host_seat:0,started:false,seats:[{token:'host'},{token:'human',bot:false},{bot:true},{token:'',bot:false}]};assert.equal(hardening.kickSeat(r,0,1),1);for(const n of [0,-1,2,3,4,1.5,'1'])assert.throws(()=>hardening.kickSeat(r,0,n));assert.throws(()=>hardening.kickSeat(r,1,1));assert.throws(()=>hardening.kickSeat({...r,started:true},0,1));
});
test('current clients get room_version and older clients keep version/need',()=>{
 assert.doesNotThrow(()=>hardening.joinVersion('0.11','0.11','0.11'));assert.throws(()=>hardening.joinVersion('0.11','0.10','0.11'),e=>e.message==='room_version'&&e.status===409&&e.extra.room==='0.10');assert.throws(()=>hardening.joinVersion('0.10','0.10','0.11'),e=>e.message==='version'&&e.extra.need==='0.11');
});
test('admin lock is checked before key comparison, including a correct key',async()=>{
 let calls=0;const compare=()=>{calls++;return true;};assert.equal(await hardening.adminDecision(true,compare),429);assert.equal(calls,0);assert.equal(await hardening.adminDecision(false,compare),200);assert.equal(calls,1);assert.equal(await hardening.adminDecision(false,()=>false),401);
});

await import("./runtime.test.js");

test('banned shape accepts bounded unique printable IDs and rejects malformed input',()=>{
 assert.deepEqual(settings({banned:['Botnet','unknown']},true),{banned:['Botnet','unknown']});assert.deepEqual(creation({...input(),banned:['Botnet']}).banned,['Botnet']);assert.throws(()=>creation({...input(),banned:'Botnet'}));
 for(const banned of [null,{},'x',[1],['a','a'],['a\n'],['é'],['x'.repeat(65)],Array.from({length:151},(_,i)=>''+i)])assert.throws(()=>settings({banned},true));
 assert.equal(summary({...creation(input()),banned:['a','b']}).banned_count,2);
});
test('host close decisions honor grace boundary and game start',()=>{
 const r={host_seat:0,started:false,hostGoneAt:100};
 assert(hardening.hostLeave(r,0));assert(!hardening.hostLeave(r,1));assert(!hardening.hostLeave({...r,started:true},0));
 assert(!hardening.hostCloseDue(r,60099));assert(hardening.hostCloseDue(r,60100));assert(!hardening.hostCloseDue({...r,hostGoneAt:null},1e9));assert(!hardening.hostCloseDue({...r,started:true},1e9));
});
test('Mog variant is accepted for creation and host pool settings',()=>{
 assert.equal(settings({card_pool:'2026mog'},true).card_pool,'2026mog');
 assert.equal(settings({public:true,card_pool:'2026mog',starting_life:0,banned:[]}).card_pool,'2026mog');
});

test('emotes accept only the eight integer presets and enforce sliding rate limits',async()=>{
 const {validEmote,emoteRate}=await import('../src/lib/protocol.js');
 for(let id=0;id<8;id++)assert(validEmote({type:'emote',id}));
 for(const id of [-1,8,0.1,'1',null,true,{},[],NaN,Infinity,'x'.repeat(70000)])assert(!validEmote({type:'emote',id}));
 for(const m of [null,[],{type:'emote',id:0,seat:1},{type:'emote',id:0,extra:'x'.repeat(70000)}])assert(!validEmote(m));
 let stamps=[];for(let i=0;i<10;i++){const r=emoteRate(stamps,i*3000);assert(r.allowed);stamps=r.stamps;assert(!emoteRate(stamps,i*3000+2999).allowed);}
 assert(!emoteRate(stamps,30000).allowed);assert(emoteRate(stamps,60000).allowed);
});

test('bot pace validates exact numeric choices and defaults only absent creation fields',()=>{
 for(const bot_pace of [0,0.25,0.5,1,1.5,2,3,5]){assert.equal(creation({...input(),bot_pace}).bot_pace,bot_pace);assert.deepEqual(settings({bot_pace},true),{bot_pace});}
 for(const bot_pace of [-1,0.1,6,'0.5',true,null,NaN,Infinity])assert.throws(()=>settings({bot_pace},true));
 assert.equal(creation(input()).bot_pace,0.5);assert.deepEqual(settings({},true),{});
 assert.equal(summary({...creation(input()),bot_pace:undefined}).bot_pace,0.5);
});
