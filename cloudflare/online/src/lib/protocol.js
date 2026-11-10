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
  for (const [key, valid] of Object.entries({public:x=>typeof x==='boolean',card_pool:x=>['2025','2026'].includes(x),starting_life:x=>[0,20,30,40].includes(x)})) {
    if (partial && !(key in v)) continue;
    if (!valid(v[key])) fail(key);
    out[key]=v[key];
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
  return {code:r.code,host:r.seats[0].name,seats:r.seats.map(({name,hero,bot,difficulty})=>({name,hero,bot,difficulty})),open_seats:r.seats.filter(s=>!s.bot&&!s.token).length,card_pool:r.card_pool,starting_life:r.starting_life,version:r.version,created:r.created};
}
export const isOpen = r => r.public && !r.started && !r.over && summary(r).open_seats>0;

export function checkVersion(client, required) {
  if (required && client !== required) fail('version',409,{need:required});
}
