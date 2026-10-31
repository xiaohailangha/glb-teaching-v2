import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {speechHttp} from './services/speech-http.mjs';
import {authHttp} from './services/auth-http.mjs';
import {assetHttp} from './services/cos-assets.mjs';
const root=path.dirname(fileURLToPath(import.meta.url));
const port=Number(process.env.PORT||5296);
const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.json':'application/json; charset=utf-8','.css':'text/css','.glb':'model/gltf-binary','.wav':'audio/wav','.wasm':'application/wasm','.png':'image/png','.jpg':'image/jpeg','.ttf':'font/ttf','.bin':'application/octet-stream'};
const server=http.createServer(async(req,res)=>{
  let pathname;
  try{pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname);}catch{res.writeHead(400).end();return;}
  if(await authHttp(req,res,new URL(req.url,'http://localhost')))return;
  if(await assetHttp(req,res,new URL(req.url,'http://localhost')))return;
  if(await speechHttp(req,res,new URL(req.url,'http://localhost')))return;
  if(pathname==='/health'){res.writeHead(200,{'Content-Type':'application/json'}).end(JSON.stringify({app:'snow_speaks',framework:'Flutter',root}));return;}
  if(pathname==='/performance-recording'&&req.method==='POST'){
    if(!['127.0.0.1','::1','::ffff:127.0.0.1'].includes(req.socket.remoteAddress)||req.headers['content-type']!=='video/webm'){
      res.writeHead(403).end();return;
    }
    const chunks=[];let size=0;
    req.on('data',chunk=>{size+=chunk.length;if(size>50000000){req.destroy();return;}chunks.push(chunk);});
    req.on('end',()=>{
      if(size<1000){res.writeHead(400).end();return;}
      const folder=path.join(root,'docs/performance-recordings');fs.mkdirSync(folder,{recursive:true});
      const name=new Date().toISOString().replace(/[:.]/g,'-')+'.webm';
      fs.writeFileSync(path.join(folder,name),Buffer.concat(chunks));
      res.writeHead(201,{'Content-Type':'application/json'}).end(JSON.stringify({saved:name}));
    });return;
  }
  if(pathname==='/benchmark'&&req.method==='POST'){
    if(!['127.0.0.1','::1','::ffff:127.0.0.1'].includes(req.socket.remoteAddress)){
      res.writeHead(403).end();return;
    }
    let body='';
    req.on('data',chunk=>{body+=chunk;if(body.length>20000)req.destroy();});
    req.on('end',()=>{
      try{
        const report=JSON.parse(body);
        if(typeof report.fps!=='number'||!Number.isFinite(report.fps)||report.durationMs<29000)throw Error('Incomplete measurement');
        const dir=path.join(root,'docs/performance-reports');fs.mkdirSync(dir,{recursive:true});
        const name=new Date().toISOString().replace(/[:.]/g,'-')+'.json';
        fs.writeFileSync(path.join(dir,name),JSON.stringify(report,null,2));
        res.writeHead(201,{'Content-Type':'application/json'}).end(JSON.stringify({saved:name}));
      }catch{res.writeHead(400).end('Invalid benchmark report');}
    });return;
  }
  let base=path.join(root,'build/web');
  if(pathname.startsWith('/avatar-dev/')){base=path.join(root,'assets/avatar');pathname=pathname.slice('/avatar-dev'.length);}
  const file=path.resolve(base,'.'+(pathname==='/'?'/index.html':pathname));
  if(!file.startsWith(path.resolve(base)+path.sep)){res.writeHead(403).end();return;}
  fs.stat(file,(err,stat)=>{
    if(err||!stat.isFile()){res.writeHead(404).end('Not found');return;}
    const headers={'Content-Type':mime[path.extname(file)]||'application/octet-stream','Cache-Control':'no-cache','Accept-Ranges':'bytes'};
    const range=req.headers.range?.match(/^bytes=(\d+)-(\d*)$/);
    if(range){
      const start=Number(range[1]),end=range[2]?Math.min(Number(range[2]),stat.size-1):stat.size-1;
      if(start>end||start>=stat.size){res.writeHead(416,{'Content-Range':`bytes */${stat.size}`}).end();return;}
      res.writeHead(206,{...headers,'Content-Range':`bytes ${start}-${end}/${stat.size}`,'Content-Length':end-start+1});
      fs.createReadStream(file,{start,end}).pipe(res);
    }else{res.writeHead(200,{...headers,'Content-Length':stat.size});fs.createReadStream(file).pipe(res);}
  });
});
server.listen(port,'127.0.0.1',()=>console.log(`Storm Flutter preview: http://localhost:${port}\nProject: ${root}`));
