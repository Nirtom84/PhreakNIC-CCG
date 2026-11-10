// phreaknic-ccg.net: serves the Godot web build.
// Static files come from Workers Static Assets. The engine file (index.wasm, ~40 MB) is over the
// 25 MiB per-file limit for static assets, so it lives in R2 and is streamed from here.
const etags=new Map();
const security={
  'Content-Security-Policy':"default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; worker-src 'self' blob:; connect-src 'self' https://online-01.phreaknic-ccg.net wss://online-01.phreaknic-ccg.net https://api.github.com; img-src 'self' data: blob:; style-src 'self' 'unsafe-inline'; media-src 'self' blob:; frame-ancestors 'none'; base-uri 'none'; object-src 'none'",
  'X-Content-Type-Options':'nosniff','Referrer-Policy':'strict-origin-when-cross-origin','Strict-Transport-Security':'max-age=31536000; includeSubDomains','Permissions-Policy':'camera=(), microphone=(), geolocation=(), payment=(), usb=()'
};
export default {
  async fetch(request,env,ctx) {
    let response;try{response=await handlers.fetch(request,env,ctx);}catch{response=new Response('Internal error',{status:500});}
    let out=new Response(response.body,response);
    for(const [k,v]of Object.entries(security))out.headers.set(k,v);
    if(out.headers.get('content-type')?.includes('text/html')){
      const nonce=crypto.randomUUID().replaceAll('-','');out.headers.set('Content-Security-Policy',security['Content-Security-Policy'].replace("script-src 'self'","script-src 'self' 'nonce-"+nonce+"'"));
      out.headers.set('cache-control','no-store');out.headers.delete('etag');out.headers.delete('content-length');
      out=new HTMLRewriter().on('script',{element(e){e.setAttribute('nonce',nonce);}}).transform(out);
    }return out;
  }
};
const handlers={
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // One canonical address: www -> apex.
    if (url.hostname.startsWith("www.")) {
      url.hostname = url.hostname.slice(4);
      return Response.redirect(url.toString(), 301);
    }

    if (request.method === "GET" && /^\/join\/[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{4}$/i.test(url.pathname)) {
      url.searchParams.set("join", url.pathname.split("/")[2].toUpperCase());
      url.pathname = "/";
      return Response.redirect(url.toString(), 302);
    }

    if (url.pathname === "/index.wasm" || url.pathname === "/"+env.WASM_KEY) {
      if (request.method !== "GET" && request.method !== "HEAD") {
        return new Response("Method not allowed", { status: 405 });
      }
      const cache=caches.default,key=new Request(new URL('/'+env.WASM_KEY,url.origin)),cached=await cache.match(key);
      let etag=cached?.headers.get('etag')||etags.get(env.WASM_KEY);
      const matches=value=>request.headers.get('if-none-match')?.split(',').some(t=>t.trim()==='*'||t.trim().replace(/^W\//,'')===value);
      if(etag&&matches(etag))return new Response(null,{status:304,headers:{etag,'cache-control':'public, max-age=86400'}});
      if(cached){const out=new Response(request.method==='HEAD'?null:cached.body,cached);if(url.pathname==='/index.wasm')out.headers.set('cache-control','public, max-age=86400');return out;}
      const versioned=url.pathname!=='/index.wasm';
      const headers=new Headers({'content-type':'application/wasm','cache-control':versioned?'public, max-age=31536000, immutable':'public, max-age=86400'});
      if(request.method==='HEAD') {
        const object=await env.GAME_FILES.head(env.WASM_KEY);if(!object)return new Response('Game engine file not found',{status:404});
        etag=object.httpEtag;etags.set(env.WASM_KEY,etag);headers.set('etag',etag);return new Response(null,{status:matches(etag)?304:200,headers});
      }
      const object=await env.GAME_FILES.get(env.WASM_KEY);
      if(!object)return new Response('Game engine file not found',{status:404});
      etag=object.httpEtag;etags.set(env.WASM_KEY,etag);headers.set('etag',etag);
      const response=new Response(object.body,{headers}),stored=response.clone();stored.headers.set('cache-control','public, max-age=31536000, immutable');
      ctx.waitUntil(cache.put(key,stored));
      if(matches(etag))return new Response(null,{status:304,headers});return response;
    }

    // Everything else (index.html, index.js, index.pck, icons) is a static asset.
    const headers=new Headers(request.headers);if(url.pathname==='/'||url.pathname.endsWith('.html')){headers.delete('if-none-match');headers.delete('if-modified-since');}
    return env.ASSETS.fetch(new Request(request,{headers}));
  },
};
