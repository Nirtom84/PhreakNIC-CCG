export const ALPHABET = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
export function code(random = crypto) {
  let result = '';
  while (result.length < 4) {
    const bytes = random.getRandomValues(new Uint8Array(8));
    for (const b of bytes) if (b < Math.floor(256 / ALPHABET.length) * ALPHABET.length && result.length < 4) result += ALPHABET[b % ALPHABET.length];
  }
  return result;
}
export const validCode = value => typeof value === 'string' && value.length === 4 && [...value].every(c => ALPHABET.includes(c));
export const token = () => [...crypto.getRandomValues(new Uint8Array(16))].map(b => b.toString(16).padStart(2, '0')).join('');
export const validToken = value => typeof value === 'string' && /^[a-f0-9]{32}$/.test(value);
export function originAllowed(origin) {
  if (origin === null) return true;
  if (['https://phreaknic-ccg.net', 'https://www.phreaknic-ccg.net', 'https://nirtom84.github.io'].includes(origin)) return true;
  try { const u = new URL(origin); return u.origin === origin && u.protocol === 'http:' && ['localhost', '127.0.0.1'].includes(u.hostname); } catch { return false; }
}
export function route(method, path) {
  if (method === 'GET' && path === '/health') return {kind:'health'};
  if (path === '/rooms' && ['GET','POST'].includes(method)) return {kind: method === 'GET' ? 'list' : 'create'};
  const m = path.match(/^\/(rooms|ws\/room)\/([^/]+)(\/join)?$/);
  if (!m || !validCode(m[2])) return null;
  if (method === 'POST' && m[1] === 'rooms' && m[3]) return {kind:'join',code:m[2]};
  if (method === 'GET' && m[1] === 'ws/room' && !m[3]) return {kind:'ws',code:m[2]};
  return null;
}
export function fail(error, status=400, extra={}) { throw Object.assign(new Error(error), {status, extra}); }
export function text(value, field, max, printable=false) {
  if (typeof value !== 'string') fail(field);
  const v = value.trim();
  if (!v.length || [...v].length > max || /[\p{C}\p{Zl}\p{Zp}]/u.test(v) || (printable && /[^\x20-\x7e]/.test(v))) fail(field);
  return v;
}
export function identity(v) {
  if (!v || typeof v !== 'object' || Array.isArray(v)) fail('body');
  // Hero is optional: players with a typed handle have none (the game shows the FOTTR logo).
  const hero = v.hero === undefined || v.hero === null || v.hero === '' ? '' : text(v.hero,'hero',64);
  return {name:text(v.name,'name',16), hero, version:text(v.version,'version',32,true)};
}
export function settings(v, partial=false) {
  const out = {};
  for (const [key, valid] of Object.entries({public:x=>typeof x==='boolean',card_pool:x=>['2025','2026','2026mog'].includes(x),starting_life:x=>[0,20,30,40].includes(x)})) {
    if (partial && !(key in v)) continue;
    if (!valid(v[key])) fail(key);
    out[key]=v[key];
  }
  if (!partial || 'banned' in v) {
    const banned=v.banned===undefined?[]:v.banned;
    if(!Array.isArray(banned)||banned.length>150||new Set(banned).size!==banned.length||banned.some(id=>typeof id!=='string'||id.length>64||/[^\x20-\x7e]/.test(id)))fail('banned');
    out.banned=banned;
  }
  return out;
}
export function difficulty(n) { if (!Number.isInteger(n) || n<0 || n>2) fail('difficulty'); return n; }
export function creation(v) {
  const who=identity(v), config=settings(v);
  if (!Array.isArray(v.seats) || v.seats.length<2 || v.seats.length>4) fail('seats');
  const seats=v.seats.map((s,i)=> {
    if (!s || typeof s.bot!=='boolean') fail('seats');
    const d=difficulty(s.difficulty);
    return {name:i===0?who.name:s.bot?'Bot':'',hero:i===0?who.hero:'',bot:i===0?false:s.bot,difficulty:d,token:i===0?token():''};
  });
  return {...config,version:who.version,seats};
}
export const wrap = (seat,msg) => ({t:'from',seat,msg});
export function summary(r) {
  return {banned_count:(r.banned||[]).length,code:r.code,host:r.seats[0].name,seats:r.seats.map(({name,hero,bot,difficulty})=>({name,hero,bot,difficulty})),open_seats:r.seats.filter(s=>!s.bot&&!s.token).length,card_pool:r.card_pool,starting_life:r.starting_life,version:r.version,created:r.created};
}
export const isOpen = r => r.public && !r.started && !r.over && summary(r).open_seats>0;

export function checkVersion(client, required) {
  if (required && client !== required) fail('version',409,{need:required});
}

export const platform = v => v===undefined?'unknown':['windows','linux','macos','android','ios','web'].includes(v)?v:'other';
export const adminEnabled = key => typeof key==='string'&&key.length>=32;
export function statsDays(v) {if(v===null||v===undefined)return 30;if(!/^[0-9]+$/.test(v)||Number(v)<1||Number(v)>400)fail('days');return Number(v);}
export async function constantTimeEqual(a,b) {
  const hash=v=>crypto.subtle.digest('SHA-256',new TextEncoder().encode(v));
  const [x,y]=await Promise.all([hash(a),hash(b)]);const left=new Uint8Array(x),right=new Uint8Array(y);let diff=0;
  for(let i=0;i<left.length;i++)diff|=left[i]^right[i];return diff===0;
}
export function creationKeys(r,p) {return ['rooms.created',r.public?'rooms.public':'rooms.invite','seats.'+r.seats.length,'pool.'+r.card_pool,'life.'+r.starting_life,'version.'+r.version,'platform.'+p];}

export const ROOM_LIFETIME=8*3600000;
export const roomExpired=(r,now=Date.now())=>now>=r.created+ROOM_LIFETIME;
export const startDecision=(enabled,counted,live,daily)=>enabled==='0'?'maintenance':counted?null:live>=20||daily>=300?'busy':null;
export function rateDecision(row,now,limit,span,cost=1) {const window=row&&now-row.window<span?row.window:now,count=window===row?.window?row.count:0;return {allowed:count+cost<=limit,window,count:count+cost};}
export function socketSeat(r,t) {return r&&validToken(t)?r.seats.findIndex(s=>!s.bot&&s.token===t):-1;}
export function joinVersion(client,room,server) {checkVersion(client,server);if(client!==room)fail('room_version',409,{room});}
export function kickSeat(r,actor,seat) {if(r.started||actor!==r.host_seat||!Number.isInteger(seat)||seat<=0||seat>=r.seats.length||r.seats[seat].bot||!r.seats[seat].token)fail('seat');return seat;}
export async function adminDecision(locked,compare) {if(locked)return 429;return await compare()?200:401;}
export function seatRate(state,now,bytes) {
 const messages=rateDecision(state.messages,now,30,1000),traffic=rateDecision(state.traffic,now,262144,10000,bytes);
 const strikes=rateDecision(state.strikes,now,10,10000,messages.allowed&&traffic.allowed?0:1);
 return {messages,traffic,strikes,allowed:messages.allowed&&traffic.allowed,close:!traffic.allowed||!strikes.allowed};
}

export const hostCloseDue=(r,now=Date.now())=>!r.started&&r.hostGoneAt!=null&&now>=r.hostGoneAt+60000;
export const hostLeave=(r,seat)=>!r.started&&seat===r.host_seat;
