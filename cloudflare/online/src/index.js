import { DurableObject } from 'cloudflare:workers';
import {code,token,validToken,originAllowed,route,creation,identity,settings,difficulty,fail,wrap,summary,isOpen,checkVersion,platform,creationKeys,adminEnabled,constantTimeEqual,statsDays,ROOM_LIFETIME,roomExpired,startDecision,rateDecision,socketSeat,joinVersion,kickSeat,adminDecision,seatRate,hostCloseDue,hostLeave,validEmote,emoteRate,deckSubmission,deckRanking} from './lib/protocol.js';
import {adminHTML,adminJS,adminHeaders} from './admin.js';
const HOUR=3600000, IDLE=600000, DAY=24*HOUR;
let listingCache;
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
  const path=new URL(req.url).pathname;
  if(path==='/admin'||path.startsWith('/admin/'))return admin(req,env,path);
  const origin=req.headers.get('Origin');
  if (!originAllowed(origin)) return json({error:'origin'},403);
  let response;
  try {
    if(req.method==='OPTIONS') response=new Response(null,{status:204,headers:{'Access-Control-Allow-Methods':'GET, POST, OPTIONS','Access-Control-Allow-Headers':'Content-Type','Access-Control-Max-Age':'600'}});
    else {
      const r=route(req.method,new URL(req.url).pathname); if(!r) fail('not_found',404);
      const l=lobby(env);
      if(r.kind==='health') response=new Response('ok');
      // Serve the cached list without touching the Lobby; only cache misses are rate limited.
      if(r.kind==='list') {if(!listingCache||listingCache.version!==env.GAME_VERSION||Date.now()>=listingCache.until){if(!await l.allow(req.headers.get('CF-Connecting-IP')||'unknown','list'))fail('rate_limit',429);listingCache={version:env.GAME_VERSION,until:Date.now()+5000,rooms:await l.list(env.GAME_VERSION)};}response=json({rooms:listingCache.rooms});}
      if(r.kind==='create'||r.kind==='join') {
        if(env.ONLINE_ENABLED==='0'){await l.bump(['refused.maintenance']);fail('maintenance',503);}
        const raw=await body(req), data=r.kind==='create'?creation(raw):identity(raw);data.platform=platform(raw.platform);
        checkVersion(data.version,env.GAME_VERSION);
        if(!await l.allow(req.headers.get('CF-Connecting-IP')||'unknown',r.kind)) fail('rate_limit',429);
        if(r.kind==='create') {
          const c=await l.reserve();
          try {const result=await room(env,c).create(c,data);if(result.failure)fail(result.failure.error,result.failure.status,result.failure.extra);response=json(result,201);} catch(e){await l.remove(c);throw e;}
        } else {const result=await room(env,r.code).join(data);if(result.failure){if(result.failure.error==='not_found')await l.allow(req.headers.get('CF-Connecting-IP')||'unknown','failure');fail(result.failure.error,result.failure.status,result.failure.extra);}response=json(result);}
      }
      if(r.kind==='ws') {const ip=req.headers.get('CF-Connecting-IP')||'unknown';if(!await l.allow(ip,'ws'))fail('rate_limit',429);response=await room(env,r.code).fetch(req);}
    }
  } catch(e) {response=error(e);}
  const key=response.status===409?'refused.version':response.status===429?'refused.rate':response.status===500?'errors.internal':null;
  if(key&&(response.status!==409||(await response.clone().json().catch(()=>({}))).error==='version'))await quiet(()=>lobby(env).bump([key]));
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
    this.sql.exec('CREATE TABLE IF NOT EXISTS daily (day TEXT, key TEXT, count INTEGER, PRIMARY KEY(day,key))');
    this.sql.exec('CREATE TABLE IF NOT EXISTS games (code TEXT PRIMARY KEY, created INTEGER, started INTEGER, ended INTEGER, public INTEGER, humans INTEGER, bots INTEGER, difficulties TEXT, card_pool TEXT, starting_life INTEGER, version TEXT, platforms TEXT, result TEXT, turns INTEGER, touched INTEGER, clients INTEGER)');
    this.sql.exec('CREATE INDEX IF NOT EXISTS games_created ON games(created)');
    this.sql.exec('CREATE TABLE IF NOT EXISTS live (code TEXT PRIMARY KEY, expires INTEGER)');
    this.sql.exec('CREATE TABLE IF NOT EXISTS starts (day TEXT PRIMARY KEY, count INTEGER)');
    this.sql.exec('CREATE TABLE IF NOT EXISTS limits (ip TEXT, kind TEXT, window INTEGER, count INTEGER, PRIMARY KEY(ip,kind))');
  }
  clean() {if(Date.now()-(this.cleanedAt||0)<60000)return;this.cleanedAt=Date.now();this.sql.exec('DELETE FROM daily WHERE day < ?',new Date(Date.now()-400*DAY).toISOString().slice(0,10));this.sql.exec('DELETE FROM games WHERE created < ?',Date.now()-90*DAY);this.sql.exec('DELETE FROM rooms WHERE expires <= ?',Date.now());this.sql.exec('DELETE FROM limits WHERE window <= ?',Date.now()-HOUR);}
  // Only list rooms players on the server's current version can join; older rooms linger until they expire.
  list(version) {this.clean();return [...this.sql.exec('SELECT summary FROM rooms WHERE summary IS NOT NULL ORDER BY code')].map(r=>JSON.parse(r.summary)).filter(r=>(!version||r.version===version)&&r.created+ROOM_LIFETIME>Date.now()).slice(0,50);}
  reserve() {
    this.clean();for(let i=0;i<100;i++){const c=code();const rows=[...this.sql.exec('INSERT OR IGNORE INTO rooms(code,expires) VALUES(?,?) RETURNING code',c,Date.now()+DAY)];if(rows.length)return c;} fail('capacity',503);
  }
  upsert(c,s,expires,clients=0) {try{this.touch(c,clients);}catch(e){console.error('stats touch failed');}this.sql.exec('INSERT INTO rooms(code,summary,expires) VALUES(?,?,?) ON CONFLICT(code) DO UPDATE SET summary=excluded.summary, expires=excluded.expires',c,s?JSON.stringify(s):null,expires);}
  release(c) {this.sql.exec('DELETE FROM live WHERE code=?',c);}
  claim(c,created) {
    const now=Date.now(),day=new Date(now).toISOString().slice(0,10);this.sql.exec('DELETE FROM live WHERE expires<=?',now);
    const counted=[...this.sql.exec('SELECT code FROM live WHERE code=?',c)].length>0,live=[...this.sql.exec('SELECT COUNT(*) AS n FROM live')][0].n,daily=[...this.sql.exec('SELECT count FROM starts WHERE day=?',day)][0]?.count||0;
    const reason=startDecision(this.env.ONLINE_ENABLED,counted,live,daily);if(reason){this.bump(['refused.'+reason]);return reason;}if(now>=created+ROOM_LIFETIME)return 'busy';
    if(!counted){this.sql.exec('INSERT INTO live VALUES(?,?)',c,created+ROOM_LIFETIME);this.sql.exec('INSERT INTO starts VALUES(?,1) ON CONFLICT(day) DO UPDATE SET count=count+1',day);}return null;
  }
  remove(c) {this.release(c);this.sql.exec('DELETE FROM rooms WHERE code=?',c);}
  bump(keys) {const day=new Date().toISOString().slice(0,10);for(const key of keys)this.sql.exec('INSERT INTO daily VALUES(?,?,1) ON CONFLICT(day,key) DO UPDATE SET count=count+1',day,key);}
  record(event,r,p,extra={}) {
    const now=Date.now(), humans=r.seats.filter(s=>!s.bot).length,bots=r.seats.length-humans;
    if(event==='create') {this.bump(creationKeys(r,p));this.sql.exec('INSERT OR REPLACE INTO games(code,created,public,humans,bots,difficulties,card_pool,starting_life,version,platforms,touched,clients) VALUES(?,?,?,?,?,?,?,?,?,?,?,0)',r.code,r.created,+r.public,humans,bots,JSON.stringify(r.seats.filter(s=>s.bot).map(s=>s.difficulty)),r.card_pool,r.starting_life,r.version,JSON.stringify([p]),now);}
    if(event==='join') {this.bump(['joins','platform.'+p,'version.'+r.version]);const row=[...this.sql.exec('SELECT platforms FROM games WHERE code=?',r.code)][0];if(row){const list=JSON.parse(row.platforms);list.push(p);this.sql.exec('UPDATE games SET platforms=? WHERE code=?',JSON.stringify(list),r.code);}}
    if(event==='start') {this.bump(['games.started',humans===1?'games.vs_bots':'games.multi_human']);this.sql.exec('UPDATE games SET started=?, humans=?, bots=?, difficulties=?, card_pool=?, starting_life=? WHERE code=?',now,humans,bots,JSON.stringify(r.seats.filter(s=>s.bot).map(s=>s.difficulty)),r.card_pool,r.starting_life,r.code);}
    if(event==='over'||event==='abandoned') {const seat=r.seats[extra.winner],result=event==='abandoned'?'abandoned':!seat?(extra.reason==='restore_failed'?'failed':'none'):seat.bot?'bot':'human';this.bump(event==='abandoned'?['games.abandoned']:['games.finished','winner.'+result]);this.sql.exec('UPDATE games SET ended=?, result=?, turns=? WHERE code=? AND result IS NULL',now,result,Number.isInteger(extra.turns)&&extra.turns>=0?extra.turns:null,r.code);}
  }
  touch(c,clients) {this.sql.exec('UPDATE games SET touched=?,clients=? WHERE code=?',Date.now(),clients,c);}
  stats(days) {
    this.clean();const now=Date.now(),first=new Date(now-(days-1)*DAY).toISOString().slice(0,10),rows=[...this.sql.exec('SELECT * FROM daily WHERE day>=? ORDER BY day',first)],sums=new Map(),byDay=new Map();
    for(let i=0;i<days;i++){const day=new Date(now-(days-1-i)*DAY).toISOString().slice(0,10);byDay.set(day,{day});}
    for(const r of rows){const d=byDay.get(r.day);if(d)Object.defineProperty(d,r.key,{value:r.count,enumerable:true,writable:true,configurable:true});sums.set(r.key,(sums.get(r.key)||0)+r.count);}
    const totals=Object.fromEntries(sums);
    const durations=[...this.sql.exec("SELECT (ended-started)/60000.0 AS minutes FROM games WHERE result IN ('human','bot') AND started IS NOT NULL AND ended>=? ORDER BY minutes",Date.parse(first))].map(r=>r.minutes),n=durations.length;
    const live=[...this.sql.exec('SELECT COUNT(*) AS active_games, COALESCE(SUM(clients),0) AS players_connected FROM games WHERE started>=? AND result IS NULL AND touched>=?',now-DAY,now-15*60000)][0];
    const connected=[...this.sql.exec('SELECT COALESCE(SUM(clients),0) AS n FROM games WHERE touched>=?',now-15*60000)][0].n;
    return {now:{open_rooms:[...this.sql.exec('SELECT COUNT(*) AS n FROM rooms WHERE summary IS NOT NULL')][0].n,...live,players_connected:connected},days:[...byDay.values()],totals,durations:{median_minutes:n?(durations[Math.floor((n-1)/2)]+durations[Math.floor(n/2)])/2:null,mean_minutes:n?durations.reduce((a,b)=>a+b,0)/n:null,count:n},recent:[...this.sql.exec('SELECT * FROM games ORDER BY created DESC LIMIT 50')].map(r=>({...r})),generated:now};
  }
  locked(ip,kind) {const r=[...this.sql.exec('SELECT window,count FROM limits WHERE ip=? AND kind=?',ip,kind)][0];return !rateDecision(r,Date.now(),kind==='admin'?10:300,HOUR).allowed;}
  allow(ip,kind) {
    this.clean();const now=Date.now();
    // Only joins to unknown rooms (code guessing) count as failures, and they never block reconnects:
    // everyone at the con shares one IP, so one bad actor must not lock out everyone's sockets.
    if(kind==='join'&&this.locked(ip,'failure'))return false;
    // Sized for a whole con sharing one public IP; the global game caps bound the cost.
    const limit={admin:10,create:200,join:600,ws:600,list:1200,failure:300}[kind]||300,span=['ws','list'].includes(kind)?60000:HOUR;
    const r=[...this.sql.exec('SELECT window,count FROM limits WHERE ip=? AND kind=?',ip,kind)][0],d=rateDecision(r,now,limit,span);
    this.sql.exec('INSERT INTO limits VALUES(?,?,?,?) ON CONFLICT(ip,kind) DO UPDATE SET window=excluded.window,count=excluded.count',ip,kind,d.window,d.count);return d.allowed;
  }
}
export class Room extends DurableObject {
  constructor(ctx,env) {
    super(ctx,env);this.clients=new Map();this.rates=new Map();this.link=null;this.boot=null;this.generation=0;this.sleeping=false;
    ctx.blockConcurrencyWhile(async()=>{this.r=await ctx.storage.get('room');if(this.r){this.r.emptySince ||= Date.now();if(!this.r.started)this.r.hostGoneAt ||= Date.now();await ctx.storage.put('room',this.r);await this.schedule();if(ctx.container.running){ctx.container.setInactivityTimeout(IDLE);this.watch();}}});
  }
  async stat(event,p,extra) {await quiet(()=>lobby(this.env).record(event,{code:this.r.code,created:this.r.created,public:this.r.public,seats:this.r.seats.map(({bot,difficulty})=>({bot,difficulty})),card_pool:this.r.card_pool,starting_life:this.r.starting_life,version:this.r.version},p,extra));}
  async schedule() {await this.ctx.storage.setAlarm(Math.min(this.r.created+ROOM_LIFETIME,this.r.emptySince?this.r.emptySince+IDLE:Infinity,this.r.releasePending?Date.now()+60000:Infinity,!this.r.started&&this.r.hostGoneAt!=null?this.r.hostGoneAt+60000:Infinity));}
  async save(activity=false) {
    if(this.closing)return;
    if(activity)this.r.lastActivity=Date.now();
    await this.ctx.storage.put('room',this.r);await this.schedule();
    await lobby(this.env).upsert(this.r.code,isOpen(this.r)?summary(this.r):null,this.r.created+ROOM_LIFETIME,this.clients.size);
  }
  async stop(reason) {
    if(this.stopping)return this.stopping;
    this.stopping=(async()=>{
      this.r.releasePending=reason;await this.ctx.storage.put('room',this.r);await this.schedule();
      await this.ctx.container.destroy(reason);if(!this.r||this.closing)return;await lobby(this.env).release(this.r.code);if(!this.r||this.closing)return;delete this.r.releasePending;await this.ctx.storage.put('room',this.r);
    })().finally(()=>{this.stopping=null;});return this.stopping;
  }
  async create(c,data) {try{return await this.createRoom(c,data);}catch(e){return {failure:{error:e.status?e.message:'internal',status:e.status||500,extra:e.extra||{}}};}}
  async createRoom(c,data) {
    if(this.r) fail('exists',409);
    // A code can be reused after an expired room was deleted while this instance stayed in memory: reset its lifecycle.
    this.closing=false;this.sleeping=false;this.starting=false;this.boot=null;this.stopping=null;this.savedAt=0;++this.generation;this.clients.clear();this.rates.clear();this.emoteRates?.clear();this.link=null;
    if(this.env.ONLINE_ENABLED==='0'){await lobby(this.env).bump(['refused.maintenance']);fail('maintenance',503);}
    const {platform:p,...config}=data;
    if(config.card_pool==='custom')config.banned=[];
    this.r={...config,code:c,host_seat:0,started:false,over:false,created:Date.now(),lastActivity:Date.now(),emptySince:Date.now(),hostGoneAt:Date.now(),snapshot:null,seed:crypto.getRandomValues(new Uint32Array(1))[0]&0x7fffffff};
    await this.stat('create',p);await this.save();return {code:c,seat:0,token:this.r.seats[0].token};
  }
  async join(data) {try{return await this.joinRoom(data);}catch(e){return {failure:{error:e.status?e.message:'internal',status:e.status||500,extra:e.extra||{}}};}}
  async joinRoom(data) {
    if(!this.r||roomExpired(this.r))fail('not_found',404);if(this.env.ONLINE_ENABLED==='0'){await lobby(this.env).bump(['refused.maintenance']);fail('maintenance',503);}joinVersion(data.version,this.r.version,this.env.GAME_VERSION);if(this.r.started)fail('started',409);
    const seat=this.r.seats.findIndex(s=>!s.bot&&!s.token);if(seat<0)fail('full',409);
    const {platform:p,...who}=data;this.r.seats[seat]={...this.r.seats[seat],...who,token:token()};await this.stat('join',p);await this.save(true);this.broadcastRoom();return {seat,token:this.r.seats[seat].token};
  }
  connected(seat) {return [...this.clients.values()].some(c=>c.seat===seat);}
  send(ws,v) {try{ws.send(JSON.stringify(v));}catch{}}
  broadcast(v) {for(const ws of this.clients.keys())this.send(ws,v);}
  broadcastRoom() {const r=this.r;this.broadcast({t:'room',deck_roll:this.r.deck_roll||[],banned:r.banned||[],code:r.code,seats:r.seats.map((s,i)=>({name:s.name,hero:s.hero,bot:s.bot,difficulty:s.difficulty,connected:this.connected(i),deck:s.deck?{name:s.deck.name,count:s.deck.count}:null})),host_seat:r.host_seat,started:r.started,public:r.public,card_pool:r.card_pool,starting_life:r.starting_life,bot_pace:r.bot_pace??0.5});}
  linkSend(v) {if(this.link?.readyState===1)this.link.send(JSON.stringify(v));}
  async fetch(req) {
    try {
      if(!originAllowed(req.headers.get('Origin')))fail('origin',403);
      if(req.headers.get('Upgrade')?.toLowerCase()!=='websocket')fail('upgrade',426);
      if(this.r&&hostCloseDue(this.r))await this.closeByHost();
      if(this.closing||!this.r||roomExpired(this.r))fail('token',401);
      const t=new URL(req.url).searchParams.get('token');if(!validToken(t))fail('token',401);
      const seat=socketSeat(this.r,t);if(seat<0)fail('token',401);
      const pair=new WebSocketPair(), ws=pair[1];ws.accept();for(const [old,c]of this.clients)if(c.seat===seat){this.clients.delete(old);old.close(4000,'replaced');}this.clients.set(ws,{seat});
      this.r.emptySince=null;if(seat===this.r.host_seat)delete this.r.hostGoneAt;await this.save();if(this.closing){this.clients.delete(ws);ws.close(1000,'expired');fail('token',401);}
      ws.addEventListener('message',e=>this.ctx.waitUntil(this.message(ws,e.data).catch(e=>this.send(ws,{t:'error',reason:e.status?e.message:'server'}))));
      const close=()=>this.ctx.waitUntil(this.disconnected(ws));ws.addEventListener('close',close);ws.addEventListener('error',close);
      this.broadcastRoom();
      if(this.r.started&&!this.r.over){if(this.link)this.linkSend({t:'connect',seat,version:this.r.version});else this.ctx.waitUntil(this.ensure().catch(()=>{}));}
      return new Response(null,{status:101,webSocket:pair[0]});
    }catch(e){return error(e);}
  }
  async disconnected(ws) {
    const c=this.clients.get(ws);if(!c||!this.r)return;this.clients.delete(ws);
    if(!this.connected(c.seat)){this.linkSend({t:'disconnect',seat:c.seat});if(!this.r.started&&c.seat===this.r.host_seat)this.r.hostGoneAt=Date.now();}
    if(!this.clients.size)this.r.emptySince=Date.now();await this.save();this.broadcastRoom();
  }
  async message(ws,data) {
    const c=this.clients.get(ws);if(!c||this.closing)return;
    if(typeof data!=='string'||new TextEncoder().encode(data).length>65536){ws.close(1009,'message size');return;}
    // Every message counts against the seat's rate limit before anything is parsed, emotes included.
    const rate=seatRate(this.rates.get(c.seat)||{},Date.now(),new TextEncoder().encode(data).length);this.rates.set(c.seat,rate);if(!rate.allowed){if(rate.close)ws.close(1008,'rate_limit');return;}if(roomExpired(this.r)){await this.alarm();return;}
    let m;try{m=JSON.parse(data);}catch{fail('json');}if(!m||typeof m!=='object'||Array.isArray(m))fail('message');
    if(m.type==='emote'){
      if(!validEmote(m)||!this.r.started||this.r.over||this.link?.readyState!==1)return;
      this.emoteRates??=new Map();const quota=emoteRate(this.emoteRates.get(c.seat),Date.now());this.emoteRates.set(c.seat,quota.stamps);
      if(quota.allowed)this.linkSend(wrap(c.seat,m));return;
    }
    if(this.r.started){
      if(!this.r.over&&this.link?.readyState===1){
        // Game messages only refresh the activity time; persist it (and the lobby entry) at most once a minute.
        this.r.lastActivity=Date.now();
        if(Date.now()-(this.savedAt||0)>60000){this.savedAt=Date.now();await this.save();}
        this.linkSend(wrap(c.seat,m));
      }
      return;
    }
    if(m.t!=='lobby')fail('lobby');if(this.starting)fail('busy',503);
    if(['submit_deck','withdraw_deck'].includes(m.action)){
      if(this.r.card_pool!=='custom'||this.r.seats[c.seat].bot)fail('deck');
      const seat=this.r.seats[c.seat],credential=seat.token;const deck=m.action==='submit_deck'?await deckSubmission(m.code):null;
      if(!this.r||this.closing||this.r.started||this.starting||this.r.card_pool!=='custom'||this.r.seats[c.seat]!==seat||seat.token!==credential)fail('busy');
      seat.deck=deck;await this.save(true);this.broadcastRoom();return;
    }
    if(m.action==='leave'&&hostLeave(this.r,c.seat)){await this.closeByHost();return;}
    if(m.action==='leave'&&c.seat!==0){
      this.r.seats[c.seat]={name:'',hero:'',bot:false,difficulty:0,token:''};
      for(const [s,v]of this.clients)if(v.seat===c.seat){this.clients.delete(s);s.close(1000,'left');}
      if(!this.clients.size)this.r.emptySince=Date.now();
    }else {
      if(c.seat!==0)fail('host',403);
      if(m.action==='start') {
        if(this.r.seats.length<2||!this.r.seats.some(s=>!s.bot&&s.token)||this.r.seats.some(s=>!s.bot&&!s.token))fail('seats');
        if(this.r.card_pool==='custom'){const ranked=deckRanking(this.r.seats);if(!ranked.order.length)fail('Someone needs to submit a deck');this.r.deck_order=ranked.order;this.r.deck_groups=ranked.groups;this.r.deck_roll=ranked.lines;this.r.deck_attempt=0;}
        this.starting=true;try{
          const refusal=await lobby(this.env).claim(this.r.code,this.r.created);if(refusal)fail(refusal,503);
          if(!this.r||roomExpired(this.r)){await lobby(this.env).release(this.r?.code||'');fail('busy',503);}
          this.r.started=true;await this.stat('start');await this.save(true);this.broadcastRoom();await this.ensure();return;
        }finally{this.starting=false;}
      }else if(m.action==='kick') {
        kickSeat(this.r,c.seat,m.seat);this.r.seats[m.seat]={name:'',hero:'',bot:false,difficulty:0,token:''};for(const [s,v]of this.clients)if(v.seat===m.seat){this.clients.delete(s);s.close(4001,'kicked');}
      }else if(m.action==='add_bot') {
        if(this.r.seats.length>=4)fail('seats');this.r.seats.push({name:'Bot',hero:'',bot:true,difficulty:difficulty(m.difficulty),token:''});
      }else if(m.action==='remove_seat') {
        if(!Number.isInteger(m.seat)||m.seat<=0||m.seat>=this.r.seats.length||this.r.seats.length<=2)fail('seat');
        for(const [s,v]of this.clients){if(v.seat===m.seat){this.clients.delete(s);s.close(1000,'removed');}else if(v.seat>m.seat)v.seat--;}
        this.r.seats.splice(m.seat,1);const rates=new Map();for(const [seat,rate]of this.rates)if(seat!==m.seat)rates.set(seat>m.seat?seat-1:seat,rate);this.rates=rates;
      }else if(m.action==='settings'){const next=settings(m,true);if(next.card_pool&&next.card_pool!=='custom')for(const seat of this.r.seats)delete seat.deck;this.r.banned_by_pool||={};this.r.banned_by_pool[this.r.card_pool]=this.r.banned||[];if(next.card_pool&&next.card_pool!==this.r.card_pool)next.banned=this.r.banned_by_pool[next.card_pool]||[];Object.assign(this.r,next);if(this.r.card_pool==='custom')this.r.banned=[];this.r.banned_by_pool[this.r.card_pool]=this.r.banned||[];}else fail('action');
    }
    await this.save(true);this.broadcastRoom();
  }
  watch() {
    const gen=this.generation;
    this.ctx.waitUntil(this.ctx.container.monitor().then(()=>this.failed(gen),()=>this.failed(gen)));
  }
  async failed(gen) {
    if(!this.r||gen!==this.generation||this.sleeping||this.r.over||!this.r.started)return;
    this.link=null;const boot=this.boot;if(boot)await boot.catch(()=>{});if(gen!==this.generation)return;if(this.clients.size&&!this.link)await this.ensure().catch(()=>{});
  }
  async ensure() {
    if(this.closing||!this.r||this.r.over||roomExpired(this.r))return;
    if(this.boot)return this.boot;
    this.boot=(async()=>{
      if(this.stopping)await this.stopping;if(this.r?.releasePending)await this.stop(this.r.releasePending);
      if(this.closing||!this.r||this.r.over||roomExpired(this.r))return;this.sleeping=false;return this.recover();
    })().finally(()=>{this.boot=null;});return this.boot;
  }
  async recover() {
    const refusal=await lobby(this.env).claim(this.r.code,this.r.created);
    // Tell connected players instead of leaving them on a started room with no game; they can resume again later.
    if(refusal){this.broadcast({t:'server',status:'unavailable',reason:refusal});fail(refusal,503);}
    this.broadcast({t:'server',status:'restarting'});
    for(let attempt=0;attempt<3;attempt++) {
      if(!this.r||this.r.over||this.sleeping||roomExpired(this.r))return;
      const gen=++this.generation;
      try {
        if(attempt){await this.ctx.container.destroy('restart');await new Promise(r=>setTimeout(r,1000*2**attempt));}
        if(!this.r||gen!==this.generation||this.sleeping||roomExpired(this.r))return;
        console.log('room',this.r.code,'attempt',attempt,'container running:',this.ctx.container.running);
        if(!this.r||this.r.over||roomExpired(this.r)||this.sleeping)throw new Error('room expired');
        if(!this.ctx.container.running){const refusal=await lobby(this.env).claim(this.r.code,this.r.created);if(refusal)fail(refusal,503);await quiet(()=>lobby(this.env).bump(['server.starts']));if(!this.r||gen!==this.generation||this.sleeping||roomExpired(this.r))return;await this.ctx.container.start({image:this.ctx.container.images.base,instance:'lite',enableInternet:false,env:{}});}
        if(!this.r||gen!==this.generation||this.sleeping||roomExpired(this.r))return;
        console.log('room',this.r.code,'container started');
        this.ctx.container.setInactivityTimeout(IDLE);this.watch();
        const port=this.ctx.container.getTcpPort(8080), deadline=Date.now()+30000;
        let healthy=false;
        for(let delay=100;Date.now()<deadline;delay=Math.min(delay*2,2000)) {
          try {const res=await port.fetch(new Request('http://container/health',{signal:AbortSignal.timeout(2000)}));if(res.status===200){healthy=true;break;}}catch{}
          await new Promise(r=>setTimeout(r,delay));
        }
        if(!this.r||gen!==this.generation||this.sleeping||roomExpired(this.r))return;
        if(!healthy)throw new Error('health timeout');
        console.log('room',this.r.code,'container healthy');
        const res=await port.fetch(new Request('http://container/link',{headers:{Upgrade:'websocket'}}));
        const ws=res.webSocket;if(!ws)throw new Error('link upgrade');this.link=ws;
        await new Promise((resolve,reject)=>{
          const timer=setTimeout(()=>reject(new Error('ready timeout')),5000);
          ws.addEventListener('message',e=>{
            let m;try{m=JSON.parse(e.data);}catch{return;}
            if(gen!==this.generation||!this.r)return;
            if(m.t==='ready'){clearTimeout(timer);resolve();}else this.ctx.waitUntil(this.linkMessage(m));
          });
          ws.addEventListener('close',()=>{clearTimeout(timer);reject(new Error('link closed'));this.ctx.waitUntil(this.failed(gen));});
          ws.addEventListener('error',()=>{clearTimeout(timer);reject(new Error('link error'));this.ctx.waitUntil(this.failed(gen));});ws.accept();
        });
        if(ws.readyState!==1||this.link!==ws)throw new Error('link lost');
        if(this.r.snapshot){await quiet(()=>lobby(this.env).bump(['server.restores']));this.linkSend({t:'restore',room:this.r.code,snapshot:this.r.snapshot});}
        else {this.sendSetup();if(this.r.card_pool==='custom')return;}
        for(let seat=0;seat<this.r.seats.length;seat++)if(this.connected(seat))this.linkSend({t:'connect',seat,version:this.r.version});
        this.broadcast({t:'server',status:'ok'});return;
      }catch(e){if(!this.r||this.sleeping||this.r.over||gen!==this.generation)return;console.error('room',this.r.code,'attempt',attempt,'failed:',e&&e.stack||e);++this.generation;this.link?.close();this.link=null;}
    }
    await quiet(()=>lobby(this.env).bump(['server.unavailable']));++this.generation;await this.stop('retry limit');this.broadcast({t:'server',status:'unavailable'});
  }
  sendSetup() {
    const r=this.r,seat=r.seats[r.deck_order?.[r.deck_attempt||0]],custom=r.card_pool==='custom';
    const chosen=custom?`${seat.name}'s deck "${seat.deck.name}" will be played.`:'';
    const lines=custom?[...(r.deck_roll||[]).filter(line=>line!==chosen),chosen]:[];
    this.linkSend({t:'setup',attempt:r.deck_attempt||0,room:r.code,seats:r.seats.map(({name,hero,bot,difficulty,token})=>({name,hero,bot,difficulty,token:bot?'':token})),card_pool:r.card_pool,banned:custom?[]:r.banned||[],starting_life:r.starting_life,bot_pace:r.bot_pace??0.5,seed:r.seed,...(custom?{custom_deck_code:seat.deck.code,deck_roll:lines}:{})});
  }
  async linkMessage(m) {
    if(!this.r||roomExpired(this.r)||this.sleeping)return;
    if(m.t==='setup_error'&&this.r.started&&this.r.card_pool==='custom'&&!this.r.snapshot&&m.attempt===(this.r.deck_attempt||0)){
      const r=this.r,seat=r.seats[r.deck_order[r.deck_attempt||0]];r.deck_roll.push(seat.name+"'s deck was invalid and was dropped.");delete seat.deck;r.deck_attempt=(r.deck_attempt||0)+1;
      if(r.deck_attempt<r.deck_order.length){
        if(r.deck_groups){r.deck_groups.shift();if(r.deck_groups[0]?.length>1){const ranked=deckRanking(r.seats,undefined,r.deck_groups.shift());r.deck_groups.unshift(...ranked.groups);r.deck_roll.push(...ranked.lines);}r.deck_order=[...r.deck_order.slice(0,r.deck_attempt),...r.deck_groups.flat()];}
        await this.save();this.sendSetup();return;
      }
      r.started=false;r.deck_order=[];++this.generation;this.link?.close();this.link=null;await this.stop('invalid decks');await this.save(true);this.broadcastRoom();this.broadcast({t:'error',reason:'No valid submitted decks remain. Submit a valid deck and try again.'});return;
    }
    if(m.t==='setup_ok'&&this.r.started&&this.r.card_pool==='custom'&&!this.r.snapshot&&m.attempt===(this.r.deck_attempt||0)){
      const seat=this.r.seats[this.r.deck_order[this.r.deck_attempt||0]];const chosen=`${seat.name}'s deck "${seat.deck.name}" will be played.`;if(!this.r.deck_roll.includes(chosen))this.r.deck_roll.push(chosen);await this.save();this.broadcastRoom();
      for(let seat=0;seat<this.r.seats.length;seat++)if(this.connected(seat))this.linkSend({t:'connect',seat,version:this.r.version});this.broadcast({t:'server',status:'ok'});return;
    }
    if(m.t==='diag'){if(typeof m.text==='string')console.log(`room ${this.r.code}: ${m.text.slice(0,300)}`);}
    else if(m.t==='to'){for(const [ws,c]of this.clients)if(c.seat===m.seat)this.send(ws,m.msg);}
    else if(m.t==='snapshot'){this.r.snapshot=m.data;await this.ctx.storage.put('room',this.r);}
    else if(m.t==='over'&&!this.r.over){this.r.over=true;await this.stat('over',undefined,m);await this.stop('over');await this.save(true);this.broadcast(m.reason?{t:'over',winner:m.winner,reason:String(m.reason)}:{t:'over',winner:m.winner});}
  }
  async closeByHost() {
    if(this.closing||!this.r||this.r.started)return;
    this.closing=true;this.sleeping=true;++this.generation;
    const c=this.r.code;
    this.broadcast({t:'room_closed',reason:'host_left'});
    for(const ws of this.clients.keys())ws.close(4002,'closed');
    this.clients.clear();this.rates.clear();this.link?.close();this.link=null;
    await quiet(()=>lobby(this.env).bump(['rooms.closed_by_host']));
    await this.ctx.container.destroy('host_left');
    await lobby(this.env).remove(c);listingCache=null;
    await this.ctx.storage.deleteAll();this.r=null;
  }
  async alarm() {
    if(!this.r)return;
    if(hostCloseDue(this.r)){await this.closeByHost();return;}
    if(roomExpired(this.r)){this.closing=true;if(!this.r.over)await this.stat('abandoned');this.sleeping=true;++this.generation;this.link?.close();await this.ctx.container.destroy('expired');for(const ws of this.clients.keys())ws.close(1000,'expired');this.clients.clear();await lobby(this.env).remove(this.r.code);await this.ctx.storage.deleteAll();this.r=null;return;}
    if(this.r.releasePending)await this.stop(this.r.releasePending);
    if(this.r.emptySince&&Date.now()-this.r.emptySince>=IDLE){this.sleeping=true;++this.generation;this.link?.close();this.link=null;await this.stop('idle');this.r.emptySince=null;await this.ctx.storage.put('room',this.r);}
    await this.schedule();
  }
}

async function quiet(fn) {try{return await fn();}catch(e){console.error('stats failed',e?.message||'error');}}
async function admin(req,env,path) {
  const send=(v,status=200,type='application/json')=>new Response(type==='application/json'?JSON.stringify(v):v,{status,headers:{...adminHeaders,'Content-Type':type}});
  if(!adminEnabled(env.ADMIN_KEY))return send({error:'not_found'},404);
  if(req.method!=='GET')return send({error:'not_found'},404);
  if(path==='/admin')return send(adminHTML,200,'text/html; charset=utf-8');
  if(path==='/admin/app.js')return send(adminJS,200,'text/javascript; charset=utf-8');
  if(path!=='/admin/api/stats')return send({error:'not_found'},404);
  const origin=req.headers.get('Origin');if(origin!==null&&origin!=='https://online-01.phreaknic-ccg.net')return send({error:'origin'},403);
  try {
    const auth=req.headers.get('Authorization')||'',l=lobby(env),ip=req.headers.get('CF-Connecting-IP')||'unknown';
    const status=await adminDecision(await l.locked(ip,'admin'),()=>constantTimeEqual(auth,'Bearer '+env.ADMIN_KEY));if(status===429)return send({error:'rate_limit'},429);const valid=status===200;
    if(!valid){if(!await l.allow(req.headers.get('CF-Connecting-IP')||'unknown','admin'))return send({error:'rate_limit'},429);return send({error:'unauthorized'},401);}
    return send(await l.stats(statsDays(new URL(req.url).searchParams.get('days'))));
  }catch(e){return send({error:e.status?e.message:'internal'},e.status||500);}
}
