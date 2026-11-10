import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../scene-preview/build/web/',import.meta.url));
const api=new URL(process.env.APP_API_ORIGIN||'http://127.0.0.1:5296');
const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm','.ttf':'font/ttf','.wav':'audio/wav','.svg':'image/svg+xml','.png':'image/png','.css':'text/css'};
http.createServer((req,res)=>{
 const u=new URL(req.url,'http://localhost');
 if(u.pathname==='/health'){res.writeHead(200,{'Content-Type':'application/json'}).end(JSON.stringify({app:'snow-speaks-web'}));return;}
 if(u.pathname.startsWith('/api/')||u.pathname.startsWith('/internal/')){
  if(u.pathname.startsWith('/internal/')){res.writeHead(404).end();return;}
  if(req.headers['sec-fetch-site']==='cross-site'||(req.headers.origin&&req.headers.origin!=='http://'+req.headers.host)){res.writeHead(403).end();return;}
  const proxy=http.request(new URL(req.url,api),{method:req.method,headers:{...req.headers,host:api.host,origin:api.origin}},up=>{res.writeHead(up.statusCode,up.headers);up.pipe(res);});
  proxy.on('error',()=>res.writeHead(502).end('Start the server repository on port 5296'));req.pipe(proxy);return;
 }
 if(u.pathname==='/'){res.writeHead(302,{Location:'/scene/'}).end();return;}
 let name;try{name=decodeURIComponent(u.pathname);}catch{res.writeHead(400).end();return;}
 if(!name.startsWith('/scene/')){res.writeHead(404).end();return;}
 const file=path.resolve(root,'.'+(name==='/scene/'?'/index.html':name.slice(6)));
 if(!file.startsWith(path.resolve(root)+path.sep)){res.writeHead(403).end();return;}
 fs.stat(file,(err,stat)=>{if(err||!stat.isFile()){res.writeHead(404).end();return;}res.writeHead(200,{'Content-Type':mime[path.extname(file)]||'application/octet-stream','Content-Length':stat.size,'Cache-Control':'no-cache'});fs.createReadStream(file).pipe(res);});
}).listen(Number(process.env.PORT||5295),'127.0.0.1',()=>console.log('App preview: http://127.0.0.1:5295/scene/'));
