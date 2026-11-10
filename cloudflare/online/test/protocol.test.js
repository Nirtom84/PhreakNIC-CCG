import {test} from 'node:test';
import assert from 'node:assert/strict';
import {webcrypto} from 'node:crypto';
import {ALPHABET,code,validCode,token,validToken,creation,identity,settings,difficulty,originAllowed,route,wrap,summary,isOpen} from '../src/lib/protocol.js';
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
test('public summary omits tokens, heroes, snapshots and closed rooms',()=>{const r={...creation(input()),code:'AB23',created:123,started:false,over:false,snapshot:{secret:1}};assert.deepEqual(summary(r),{code:'AB23',host:'Nirtom',seats:[{name:'Nirtom',bot:false,difficulty:0},{name:'',bot:false,difficulty:0}],open_seats:1,card_pool:'2026',starting_life:0,version:'0.09',created:123});assert(isOpen(r));for(const patch of [{public:false},{started:true},{over:true},{seats:[r.seats[0],{bot:true}]}])assert(!isOpen({...r,...patch}));});
