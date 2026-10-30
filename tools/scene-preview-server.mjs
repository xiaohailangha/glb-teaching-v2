import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../scene-preview/build/web/',import.meta.url));
const types={'.js':'text/javascript','.html':'text/html','.json':'application/json','.wasm':'application/wasm','.wav':'audio/wav','.png':'image/png','.bin':'application/octet-stream','.fsceneb':'application/octet-stream','.ttf':'font/ttf'};
http.createServer((req,res)=>{
 const url=new URL(req.url,'http://localhost');
 if(url.pathname.startsWith('/api/speech/')||url.pathname.startsWith('/api/assets/')){
  const proxy=http.request({host:'127.0.0.1',port:5296,path:url.pathname+url.search,method:req.method,headers:{...req.headers,host:'127.0.0.1:5296',origin:'http://127.0.0.1:5296','sec-fetch-site':'same-origin'}},r=>{res.writeHead(r.statusCode,r.headers);r.pipe(res);});
  proxy.on('error',()=>res.writeHead(502).end());req.pipe(proxy);return;
 }
 if(url.pathname==='/'){res.writeHead(302,{Location:'/scene/'}).end();return;}
 if(!url.pathname.startsWith('/scene/')){res.writeHead(404).end();return;}
 const relative=decodeURIComponent(url.pathname.slice('/scene/'.length))||'index.html',file=path.resolve(root,relative);
 if(!file.startsWith(root)||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404).end();return;}
 const size=fs.statSync(file).size,range=req.headers.range?.match(/^bytes=(\d+)-(\d*)$/);
 const headers={'Content-Type':types[path.extname(file)]||'application/octet-stream','Cache-Control':'no-cache','Accept-Ranges':'bytes'};
 if(range){const start=Number(range[1]),end=range[2]?Math.min(Number(range[2]),size-1):size-1;if(start>end||start>=size){res.writeHead(416).end();return;}res.writeHead(206,{...headers,'Content-Range':`bytes ${start}-${end}/${size}`,'Content-Length':end-start+1});fs.createReadStream(file,{start,end}).pipe(res);}
 else{res.writeHead(200,{...headers,'Content-Length':size});fs.createReadStream(file).pipe(res);}
}).listen(5303,'127.0.0.1',()=>console.log('Flutter Scene validation: http://localhost:5303/scene/'));
