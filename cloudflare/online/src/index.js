import { DurableObject } from 'cloudflare:workers';
import {code,token,validToken,originAllowed,route,creation,identity,settings,difficulty,fail,wrap,summary,isOpen} from './lib/protocol.js';
const HOUR=3600000, IDLE=600000, DAY=24*HOUR;
const json=(v,status=200)=>Response.json(v,{status,headers:{'Cache-Control':'no-store'}});
const error=e=>json({error:e.status?e.message:'internal',...e.extra},e.status||500);
const lobby=env=>env.LOBBY.get(env.LOBBY.idFromName('lobby'));
const room=(env,c)=>env.ROOMS.get(env.ROOMS.idFromName(c));
async function body(req) {
  if (Number(req.headers.get('Content-Length'))>65536) fail('body_size',413);
  const reader=req.body?.getReader(); let size=0, chunks=[];
  if (!reader) fail('body');
  while(true) {const {done,value}=await reader.read(); if(done) break; size+=value.length; if(size>65536){await reader.cancel();fail('body_size',413);} chunks.push(value);}
  try { const bytes=new Uint8Array(size); let pos=0; for(const c of chunks){bytes.set(c,pos);pos+=c.length;} return JSON.parse(new TextDecoder().decode(bytes)); } catch {fail('json');}
}
export default {async fetch(req,env) {
  const origin=req.headers.get('Origin');
  if (!originAllowed(origin)) return json({error:'origin'},403);
  let response;
  try {
    if(req.method==='OPTIONS') response=new Response(null,{status:204,headers:{'Access-Control-Allow-Methods':'GET, POST, OPTIONS','Access-Control-Allow-Headers':'Content-Type','Access-Control-Max-Age':'600'}});
    else {
      const r=route(req.method,new URL(req.url).pathname); if(!r) fail('not_found',404);
      const l=lobby(env);
      if(r.kind==='health') response=new Response('ok');
      if(r.kind==='list') response=json({rooms:await l.list()});
      if(r.kind==='create'||r.kind==='join') {
        const data= r.kind==='create'?creation(await body(req)):identity(await body(req));
        if(!await l.allow(req.headers.get('CF-Connecting-IP')||'unknown',r.kind)) fail('rate_limit',429);
        if(r.kind==='create') {
          const c=await l.reserve();
          try {const result=await room(env,c).create(c,data);if(result.failure)fail(result.failure.error,result.failure.status,result.failure.extra);response=json(result,201);} catch(e){await l.remove(c);throw e;}
        } else {const result=await room(env,r.code).join(data);if(result.failure)fail(result.failure.error,result.failure.status,result.failure.extra);response=json(result);}
      }
      if(r.kind==='ws') response=await room(env,r.code).fetch(req);
    }
  } catch(e) {response=error(e);}
  // A 101 response must keep its original WebSocket object and needs no CORS headers. Other responses can come
  // from a Durable Object stub, whose headers are immutable, so copy before adding headers.
  if(response.status!==101) {
    response=new Response(response.body,response);
    if(origin) response.headers.set('Access-Control-Allow-Origin',origin);
    response.headers.set('Vary','Origin');
  }
  return response;
}};
export class Lobby extends DurableObject {
  constructor(ctx,env) {
    super(ctx,env); this.sql=ctx.storage.sql;
    this.sql.exec('CREATE TABLE IF NOT EXISTS rooms (code TEXT PRIMARY KEY, summary TEXT, expires INTEGER NOT NULL)');
    this.sql.exec('CREATE TABLE IF NOT EXISTS limits (ip TEXT, kind TEXT, window INTEGER, count INTEGER, PRIMARY KEY(ip,kind))');
  }
  clean() {this.sql.exec('DELETE FROM rooms WHERE expires <= ?',Date.now());this.sql.exec('DELETE FROM limits WHERE window <= ?',Date.now()-HOUR);}
  list() {this.clean();return [...this.sql.exec('SELECT summary FROM rooms WHERE summary IS NOT NULL ORDER BY code')].map(r=>JSON.parse(r.summary));}
  reserve() {
    this.clean();for(let i=0;i<100;i++){const c=code();const rows=[...this.sql.exec('INSERT OR IGNORE INTO rooms(code,expires) VALUES(?,?) RETURNING code',c,Date.now()+DAY)];if(rows.length)return c;} fail('capacity',503);
  }
  upsert(c,s,expires) {this.sql.exec('INSERT INTO rooms(code,summary,expires) VALUES(?,?,?) ON CONFLICT(code) DO UPDATE SET summary=excluded.summary, expires=excluded.expires',c,s?JSON.stringify(s):null,expires);}
  remove(c) {this.sql.exec('DELETE FROM rooms WHERE code=?',c);}
  allow(ip,kind) {
    this.clean();const now=Date.now(), limit=kind==='create'?10:30;
    const r=[...this.sql.exec('SELECT window,count FROM limits WHERE ip=? AND kind=?',ip,kind)][0];
    if(r&&r.count>=limit)return false;
    this.sql.exec('INSERT INTO limits VALUES(?,?,?,1) ON CONFLICT(ip,kind) DO UPDATE SET count=count+1',ip,kind,now);return true;
  }
}
export class Room extends DurableObject {
  constructor(ctx,env) {
    super(ctx,env);this.clients=new Map();this.link=null;this.boot=null;this.generation=0;this.sleeping=false;
    ctx.blockConcurrencyWhile(async()=>{this.r=await ctx.storage.get('room');if(this.r){this.r.emptySince ||= Date.now();await ctx.storage.put('room',this.r);await this.schedule();if(ctx.container.running){ctx.container.setInactivityTimeout(IDLE);this.watch();}}});
  }
  async schedule() {await this.ctx.storage.setAlarm(Math.min(this.r.lastActivity+DAY,this.r.emptySince?this.r.emptySince+IDLE:Infinity));}
  async save(activity=false) {
    if(activity)this.r.lastActivity=Date.now();
    await this.ctx.storage.put('room',this.r);await this.schedule();
    await lobby(this.env).upsert(this.r.code,isOpen(this.r)?summary(this.r):null,this.r.lastActivity+DAY);
  }
  async create(c,data) {try{return await this.createRoom(c,data);}catch(e){return {failure:{error:e.status?e.message:'internal',status:e.status||500,extra:e.extra||{}}};}}
  async createRoom(c,data) {
    if(this.r) fail('exists',409);
    this.r={...data,code:c,host_seat:0,started:false,over:false,created:Date.now(),lastActivity:Date.now(),emptySince:Date.now(),snapshot:null,seed:crypto.getRandomValues(new Uint32Array(1))[0]&0x7fffffff};
    await this.save();return {code:c,seat:0,token:this.r.seats[0].token};
  }
  async join(data) {try{return await this.joinRoom(data);}catch(e){return {failure:{error:e.status?e.message:'internal',status:e.status||500,extra:e.extra||{}}};}}
  async joinRoom(data) {
    if(!this.r)fail('not_found',404);if(this.r.started)fail('started',409);
    if(data.version!==this.r.version)fail('version',409,{need:this.r.version});
    const seat=this.r.seats.findIndex(s=>!s.bot&&!s.token);if(seat<0)fail('full',409);
    this.r.seats[seat]={...this.r.seats[seat],...data,token:token()};await this.save(true);this.broadcastRoom();return {seat,token:this.r.seats[seat].token};
  }
  connected(seat) {return [...this.clients.values()].some(c=>c.seat===seat);}
  send(ws,v) {try{ws.send(JSON.stringify(v));}catch{}}
  broadcast(v) {for(const ws of this.clients.keys())this.send(ws,v);}
  broadcastRoom() {const r=this.r;this.broadcast({t:'room',code:r.code,seats:r.seats.map((s,i)=>({name:s.name,hero:s.hero,bot:s.bot,difficulty:s.difficulty,connected:this.connected(i)})),host_seat:r.host_seat,started:r.started,public:r.public,card_pool:r.card_pool,starting_life:r.starting_life});}
  linkSend(v) {if(this.link?.readyState===1)this.link.send(JSON.stringify(v));}
  async fetch(req) {
    try {
      if(!this.r)fail('not_found',404);
      if(!originAllowed(req.headers.get('Origin')))fail('origin',403);
      if(req.headers.get('Upgrade')?.toLowerCase()!=='websocket')fail('upgrade',426);
      const t=new URL(req.url).searchParams.get('token');if(!validToken(t))fail('token',401);
      const seat=this.r.seats.findIndex(s=>!s.bot&&s.token===t);if(seat<0)fail('token',401);
      const pair=new WebSocketPair(), ws=pair[1];ws.accept();this.clients.set(ws,{seat,count:0,window:Date.now()});
      this.r.emptySince=null;await this.save(true);
      ws.addEventListener('message',e=>this.ctx.waitUntil(this.message(ws,e.data).catch(e=>this.send(ws,{t:'error',reason:e.status?e.message:'server'}))));
      const close=()=>this.ctx.waitUntil(this.disconnected(ws));ws.addEventListener('close',close);ws.addEventListener('error',close);
      this.broadcastRoom();
      if(this.r.started&&!this.r.over){if(this.link)this.linkSend({t:'connect',seat,version:this.r.version});else this.ctx.waitUntil(this.ensure().catch(()=>{}));}
      return new Response(null,{status:101,webSocket:pair[0]});
    }catch(e){return error(e);}
  }
  async disconnected(ws) {
    const c=this.clients.get(ws);if(!c)return;this.clients.delete(ws);
    if(!this.connected(c.seat))this.linkSend({t:'disconnect',seat:c.seat});
    if(!this.clients.size)this.r.emptySince=Date.now();await this.save(true);this.broadcastRoom();
  }
  async message(ws,data) {
    const c=this.clients.get(ws);if(!c)return;
    if(typeof data!=='string'||new TextEncoder().encode(data).length>65536){ws.close(1009,'message size');return;}
    if(Date.now()-c.window>=1000){c.window=Date.now();c.count=0;}if(++c.count>30)return;
    let m;try{m=JSON.parse(data);}catch{fail('json');}if(!m||typeof m!=='object'||Array.isArray(m))fail('message');
    if(this.r.started){
      if(!this.r.over){
        // Game messages only refresh the activity time; persist it (and the lobby entry) at most once a minute.
        this.r.lastActivity=Date.now();
        if(Date.now()-(this.savedAt||0)>60000){this.savedAt=Date.now();await this.save();}
        this.linkSend(wrap(c.seat,m));
      }
      return;
    }
    if(m.t!=='lobby')fail('lobby');
    if(m.action==='leave'&&c.seat!==0){
      this.r.seats[c.seat]={name:'',hero:'',bot:false,difficulty:0,token:''};
      for(const [s,v]of this.clients)if(v.seat===c.seat){this.clients.delete(s);s.close(1000,'left');}
      if(!this.clients.size)this.r.emptySince=Date.now();
    }else {
      if(c.seat!==0)fail('host',403);
      if(m.action==='start') {
        if(this.r.seats.length<2||!this.r.seats.some(s=>!s.bot&&s.token)||this.r.seats.some(s=>!s.bot&&!s.token))fail('seats');
        this.r.started=true;await this.save(true);this.broadcastRoom();await this.ensure();return;
      }else if(m.action==='add_bot') {
        if(this.r.seats.length>=4)fail('seats');this.r.seats.push({name:'Bot',hero:'',bot:true,difficulty:difficulty(m.difficulty),token:''});
      }else if(m.action==='remove_seat') {
        if(!Number.isInteger(m.seat)||m.seat<=0||m.seat>=this.r.seats.length||this.r.seats.length<=2)fail('seat');
        for(const [s,v]of this.clients){if(v.seat===m.seat){this.clients.delete(s);s.close(1000,'removed');}else if(v.seat>m.seat)v.seat--;}
        this.r.seats.splice(m.seat,1);
      }else if(m.action==='settings')Object.assign(this.r,settings(m,true));else fail('action');
    }
    await this.save(true);this.broadcastRoom();
  }
  watch() {
    const gen=this.generation;
    this.ctx.waitUntil(this.ctx.container.monitor().then(()=>this.failed(gen),()=>this.failed(gen)));
  }
  async failed(gen) {
    if(gen!==this.generation||this.sleeping||this.r.over||!this.r.started)return;
    this.link=null;const boot=this.boot;if(boot)await boot.catch(()=>{});if(gen!==this.generation)return;if(this.clients.size&&!this.link)await this.ensure().catch(()=>{});
  }
  async ensure() {
    if(this.boot)return this.boot;
    this.sleeping=false;
    this.boot=this.recover().finally(()=>{this.boot=null;});return this.boot;
  }
  async recover() {
    this.broadcast({t:'server',status:'restarting'});
    for(let attempt=0;attempt<3;attempt++) {
      const gen=++this.generation;
      try {
        if(attempt){await this.ctx.container.destroy('restart');await new Promise(r=>setTimeout(r,1000*2**attempt));}
        if(!this.ctx.container.running)await this.ctx.container.start({image:this.ctx.container.images.base,instance:'lite',enableInternet:false,env:{}});
        this.ctx.container.setInactivityTimeout(IDLE);this.watch();
        const port=this.ctx.container.getTcpPort(8080), deadline=Date.now()+30000;
        let healthy=false;
        for(let delay=100;Date.now()<deadline;delay=Math.min(delay*2,2000)) {
          try {const res=await port.fetch(new Request('http://container/health',{signal:AbortSignal.timeout(2000)}));if(res.status===200){healthy=true;break;}}catch{}
          await new Promise(r=>setTimeout(r,delay));
        }
        if(!healthy)throw new Error('health timeout');
        const res=await port.fetch(new Request('http://container/link',{headers:{Upgrade:'websocket'}}));
        const ws=res.webSocket;if(!ws)throw new Error('link upgrade');this.link=ws;
        await new Promise((resolve,reject)=>{
          const timer=setTimeout(()=>reject(new Error('ready timeout')),5000);
          ws.addEventListener('message',e=>{
            let m;try{m=JSON.parse(e.data);}catch{return;}
            if(gen!==this.generation)return;
            if(m.t==='ready'){clearTimeout(timer);resolve();}else this.ctx.waitUntil(this.linkMessage(m));
          });
          ws.addEventListener('close',()=>{clearTimeout(timer);reject(new Error('link closed'));this.ctx.waitUntil(this.failed(gen));});
          ws.addEventListener('error',()=>{clearTimeout(timer);reject(new Error('link error'));this.ctx.waitUntil(this.failed(gen));});ws.accept();
        });
        if(ws.readyState!==1||this.link!==ws)throw new Error('link lost');
        if(this.r.snapshot)this.linkSend({t:'restore',room:this.r.code,snapshot:this.r.snapshot});
        else this.linkSend({t:'setup',room:this.r.code,seats:this.r.seats.map(({name,hero,bot,difficulty,token})=>({name,hero,bot,difficulty,token:bot?'':token})),card_pool:this.r.card_pool,starting_life:this.r.starting_life,seed:this.r.seed});
        for(let seat=0;seat<this.r.seats.length;seat++)if(this.connected(seat))this.linkSend({t:'connect',seat,version:this.r.version});
        this.broadcast({t:'server',status:'ok'});return;
      }catch {++this.generation;this.link?.close();this.link=null;}
    }
    ++this.generation;await this.ctx.container.destroy('retry limit');this.broadcast({t:'server',status:'unavailable'});
  }
  async linkMessage(m) {
    if(m.t==='to'){for(const [ws,c]of this.clients)if(c.seat===m.seat)this.send(ws,m.msg);}
    else if(m.t==='snapshot'){this.r.snapshot=m.data;await this.ctx.storage.put('room',this.r);}
    else if(m.t==='over'){this.r.over=true;await this.save(true);this.broadcast({t:'over',winner:m.winner});}
  }
  async alarm() {
    if(!this.r)return;
    if(Date.now()-this.r.lastActivity>=DAY){this.sleeping=true;++this.generation;this.link?.close();await this.ctx.container.destroy('expired');for(const ws of this.clients.keys())ws.close(1000,'expired');await lobby(this.env).remove(this.r.code);await this.ctx.storage.deleteAll();this.r=null;return;}
    if(this.r.emptySince&&Date.now()-this.r.emptySince>=IDLE){this.sleeping=true;++this.generation;this.link?.close();this.link=null;await this.ctx.container.destroy('idle');this.r.emptySince=null;await this.ctx.storage.put('room',this.r);}
    await this.schedule();
  }
}
