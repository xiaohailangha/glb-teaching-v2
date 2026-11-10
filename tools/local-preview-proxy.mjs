import http from 'node:http';
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
// Loopback-only bridge for private COS assets. Do not change production CORS.
const allowed=url=>url.protocol==='https:'&&!url.username&&!url.password&&url.port===''&&/^glb-teaching-assets-\d+\.cos\.ap-beijing\.myqcloud\.com$/.test(url.hostname);
const inject=`<script>(()=>{const map=u=>{try{const v=new URL(String(u),location.href);return /^glb-teaching-assets-\\d+\\.cos\\.ap-beijing\\.myqcloud\\.com$/.test(v.hostname)?'/api/local-preview/asset?url='+encodeURIComponent(v.href):u;}catch{return u;}};const f=window.fetch;window.fetch=function(u,o){return f.call(this,u instanceof Request?new Request(map(u.url),u):map(u),o);};const x=XMLHttpRequest.prototype.open;XMLHttpRequest.prototype.open=function(m,u,...a){return x.call(this,m,map(u),...a);};})();</script>`;
http.createServer(async(req,res)=>{
 try{
  const url=new URL(req.url,'http://127.0.0.1:5296');
  const teaching=url.pathname.match(/^\/api\/local-preview\/teaching\/(B102-[a-f0-9]{16})\.wav$/);
  if(teaching){
   if(req.method!=='GET'||req.headers['sec-fetch-site']==='cross-site'){res.writeHead(403).end();return;}
   const manifest=JSON.parse(await fs.readFile(new URL('../data/curriculum/teaching-audio.json',import.meta.url),'utf8'));
   const asset=manifest.assets.find(a=>a.id===teaching[1]);
   if(!asset){res.writeHead(404).end();return;}
   const bytes=await fs.readFile(new URL(`../work/b101-guided-v2/${asset.id}.wav`,import.meta.url));
   if(bytes.length!==asset.size||crypto.createHash('sha256').update(bytes).digest('hex')!==asset.sha256){res.writeHead(503).end();return;}
   res.writeHead(200,{'Content-Type':'audio/wav','Cache-Control':'private, no-store'}).end(bytes);return;
  }
  if(url.pathname==='/api/local-preview/asset'){
   if(req.method!=='GET'||req.headers['sec-fetch-site']==='cross-site'){res.writeHead(403).end();return;}
   const target=new URL(url.searchParams.get('url'));
   if(!allowed(target)){res.writeHead(403).end();return;}
   const upstream=await fetch(target,{redirect:'error',signal:AbortSignal.timeout(60000)});
   const bytes=Buffer.from(await upstream.arrayBuffer());
   if(bytes.length>20000000){res.writeHead(413).end();return;}
   res.writeHead(upstream.status,{'Content-Type':upstream.headers.get('content-type')||'application/octet-stream','Cache-Control':'private, no-store'}).end(bytes);return;
  }
  const upstream=http.request({hostname:'127.0.0.1',port:5297,path:req.url,method:req.method,headers:req.headers},r=>{
   if(req.url==='/scene/'||req.url.startsWith('/scene/?')){
    const chunks=[];r.on('data',b=>chunks.push(b));r.on('end',()=>{const headers={...r.headers};delete headers['content-length'];res.writeHead(r.statusCode,headers).end(Buffer.concat(chunks).toString().replace('<head>','<head>'+inject));});
   }else{res.writeHead(r.statusCode,r.headers);r.pipe(res);}
  });upstream.on('error',()=>res.writeHead(502).end('Local preview unavailable'));req.pipe(upstream);
 }catch{res.writeHead(502).end('Local asset could not be loaded');}
}).listen(5296,'127.0.0.1',()=>console.log('Local preview: http://127.0.0.1:5296/scene/'));
