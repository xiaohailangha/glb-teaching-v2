import {contentHttp} from './services/content-http.mjs';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {speechHttp} from './services/speech-http.mjs';
import {learningHttp} from './services/learning-http.mjs';
import {authHttp} from './services/auth-http.mjs';
import {assetHttp} from './services/cos-assets.mjs';
const root=path.dirname(fileURLToPath(import.meta.url));
const port=Number(process.env.PORT||5296);
const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.json':'application/json; charset=utf-8','.css':'text/css','.glb':'model/gltf-binary','.wav':'audio/wav','.wasm':'application/wasm','.png':'image/png','.jpg':'image/jpeg','.ttf':'font/ttf','.bin':'application/octet-stream','.svg':'image/svg+xml'};
const server=http.createServer(async(req,res)=>{
  let pathname;
  try{pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname);}catch{res.writeHead(400).end();return;}
  if(await learningHttp(req,res,new URL(req.url,'http://localhost')))return;
  if(await contentHttp(req,res,new URL(req.url,'http://localhost')))return;
  if(await authHttp(req,res,new URL(req.url,'http://localhost')))return;
  if(await assetHttp(req,res,new URL(req.url,'http://localhost')))return;
  if(await speechHttp(req,res,new URL(req.url,'http://localhost')))return;
  if(pathname==='/health'){res.writeHead(200,{'Content-Type':'application/json'}).end(JSON.stringify({app:'snow_speaks',framework:'Flutter',root}));return;}
  if(pathname==='/'){res.writeHead(302,{Location:'/scene/'}).end();return;}
  if(!pathname.startsWith('/scene/')){res.writeHead(404).end('Not found');return;}
  const base=path.join(root,'scene-preview/build/web');
  pathname=pathname.slice('/scene'.length);
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
server.listen(port,'127.0.0.1',()=>console.log(`Snow Speaks: http://127.0.0.1:${server.address().port}/scene/`));
