// phreaknic-ccg.net: serves the Godot web build.
// Static files come from Workers Static Assets. The engine file (index.wasm, ~40 MB) is over the
// 25 MiB per-file limit for static assets, so it lives in R2 and is streamed from here.
export default {
  async fetch(request, env) {
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

    if (url.pathname === "/index.wasm") {
      if (request.method !== "GET" && request.method !== "HEAD") {
        return new Response("Method not allowed", { status: 405 });
      }
      const object = await env.GAME_FILES.get(env.WASM_KEY);
      if (!object) return new Response("Game engine file not found", { status: 404 });
      const headers = new Headers({
        "content-type": "application/wasm",
        // The key is versioned (web/<version>/index.wasm), so browsers can cache it for a day.
        "cache-control": "public, max-age=86400",
        etag: object.httpEtag,
      });
      if (request.headers.get("if-none-match") === object.httpEtag) {
        return new Response(null, { status: 304, headers });
      }
      return new Response(request.method === "HEAD" ? null : object.body, { headers });
    }

    // Everything else (index.html, index.js, index.pck, icons) is a static asset.
    return env.ASSETS.fetch(request);
  },
};
