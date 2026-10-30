// Authenticated temporary HTTPS preview. Never exposes repository files or diagnostics.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import {createGzip,gzip} from 'node:zlib';
import {promisify} from 'node:util';
import {fileURLToPath} from 'node:url';
import {randomBytes,timingSafeEqual} from 'node:crypto';
const root=fs.realpathSync(fileURLToPath(new URL('../build/web/',import.meta.url)));
const types={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.json':'application/json','.css':'text/css','.glb':'model/gltf-binary','.wav':'audio/wav','.wasm':'application/wasm','.png':'image/png','.jpg':'image/jpeg','.ico':'image/x-icon','.ttf':'font/ttf','.otf':'font/otf','.woff2':'font/woff2','.bin':'application/octet-stream'};
const port=Number(process.env.PREVIEW_PORT||5297);
const compress=promisify(gzip);
const sessionFile=fileURLToPath(new URL('../work/tunnel/session.json',import.meta.url));
const originFile=fileURLToPath(new URL('../work/tunnel/public-origin.txt',import.meta.url));
let previousSession;
try{previousSession=JSON.parse(fs.readFileSync(sessionFile,'utf8'));}catch{}
const reusableSession=/^[a-f0-9]{48}$/.test(previousSession?.token||'')&&Date.parse(previousSession.expiresAt)>Date.now();
const token=reusableSession?previousSession.token:randomBytes(24).toString('hex');
const expiresAt=reusableSession?Date.parse(previousSession.expiresAt):Date.now()+12*60*60*1000;
fs.writeFileSync(sessionFile,JSON.stringify({pid:process.pid,token,expiresAt:new Date(expiresAt).toISOString()},null,2));
function matches(value){return typeof value==='string'&&Buffer.byteLength(value)===Buffer.byteLength(token)&&timingSafeEqual(Buffer.from(value),Buffer.from(token));}
function deny(res,code=403,message='请通过完整的手机测试链接进入。'){
  res.writeHead(code,{'Content-Type':'text/plain; charset=utf-8','Cache-Control':'no-store'}).end(message);
}
const server=http.createServer(async(req,res)=>{
  res.setHeader('X-Content-Type-Options','nosniff');
  res.setHeader('Referrer-Policy','no-referrer');
  res.setHeader('X-Frame-Options','SAMEORIGIN');
  try{
    const origin=fs.existsSync(originFile)?fs.readFileSync(originFile,'utf8').trim():'';
    if(!/^https:\/\/[a-z0-9-]+\.(trycloudflare\.com|lhr\.life)$/.test(origin)||req.headers.host!==new URL(origin).host||Date.now()>=expiresAt){deny(res);return;}
    const url=new URL(req.url,origin);
    const pathname=decodeURIComponent(url.pathname);
    if(pathname==='/enter'&&req.method==='GET'&&matches(url.searchParams.get('key'))){
      res.writeHead(303,{'Set-Cookie':`__Host-glb_preview=${token}; Secure; HttpOnly; SameSite=Lax; Path=/; Max-Age=43200`,Location:'/', 'Cache-Control':'no-store'}).end();return;
    }
    const cookie=req.headers.cookie?.split(';').map(x=>x.trim()).find(x=>x.startsWith('__Host-glb_preview='))?.slice('__Host-glb_preview='.length);
    const navigation=req.method==='GET'&&req.headers['sec-fetch-mode']==='navigate';
    if(!matches(cookie)||(req.headers.origin&&req.headers.origin!==origin)||(!navigation&&req.headers['sec-fetch-site']&&!['same-origin','none'].includes(req.headers['sec-fetch-site']))){deny(res);return;}
    if(pathname.startsWith('/api/')){
      const read=req.method==='GET'&&(pathname==='/api/speech/status'||/^\/api\/speech\/audio\/[a-f0-9]{64}\.wav$/.test(pathname));
      const write=req.method==='POST'&&['/api/speech/tts','/api/speech/assess','/api/speech/recognize'].includes(pathname);
      if(!read&&!write){deny(res);return;}
      // Only same-origin POSTs may invoke paid services; backend also limits rate and size.
      if(write&&req.headers.origin!==origin){deny(res);return;}
      if(Number(req.headers['content-length']||0)>640044){deny(res,413,'录音或请求过大');return;}
      const headers={host:'127.0.0.1:5296',origin:'http://127.0.0.1:5296','sec-fetch-site':'same-origin'};
      for(const name of ['content-type','content-length','range'])if(req.headers[name])headers[name]=req.headers[name];
      const upstream=http.request({hostname:'127.0.0.1',port:5296,path:url.pathname+url.search,method:req.method,headers},incoming=>{
        res.writeHead(incoming.statusCode,{...incoming.headers,'Cache-Control':'private, no-store'});incoming.pipe(res);
      });
      upstream.setTimeout(90000,()=>upstream.destroy());
      upstream.on('error',()=>{if(!res.headersSent)deny(res,502,'电脑语音服务暂时未连接');else res.destroy();});
      req.on('aborted',()=>upstream.destroy());res.on('close',()=>{if(!res.writableEnded)upstream.destroy();});
      req.pipe(upstream);return;
    }
    if(!['GET','HEAD'].includes(req.method)){res.writeHead(405,{Allow:'GET, HEAD'}).end();return;}
    if(pathname.includes('\\')||pathname.split('/').some(part=>part.startsWith('.'))){res.writeHead(404).end();return;}
    const candidate=path.resolve(root,'.'+(pathname==='/'?'/index.html':pathname));
    if(!candidate.startsWith(root+path.sep)||!types[path.extname(candidate)]){res.writeHead(404).end();return;}
    const file=await fs.promises.realpath(candidate);
    if(!file.startsWith(root+path.sep)){res.writeHead(404).end();return;}
    const stat=await fs.promises.stat(file);
    if(!stat.isFile()){res.writeHead(404).end();return;}
    const etag=`W/"${stat.size}-${Math.trunc(stat.mtimeMs)}"`;
    const headers={'Content-Type':types[path.extname(file)],'Cache-Control':'private, no-cache','Accept-Ranges':'bytes',ETag:etag};
    if(path.extname(file)==='.glb') {
      const chunkSize=1024*1024;
      headers['X-Preview-Model-Bytes']=stat.size;
      headers['X-Preview-Chunk-Size']=chunkSize;
      if(url.searchParams.has('previewPart')) {
        const indexText=url.searchParams.get('previewPart');
        const index=Number(indexText);
        if(!/^\d+$/.test(indexText)||!Number.isSafeInteger(index)||index>=Math.ceil(stat.size/chunkSize)){deny(res,416,'模型分块不存在');return;}
        const fileHandle=await fs.promises.open(file,'r');
        const buffer=Buffer.alloc(Math.min(chunkSize,stat.size-index*chunkSize));
        try {
          let offset=0;
          while(offset<buffer.length){const {bytesRead}=await fileHandle.read(buffer,offset,buffer.length-offset,index*chunkSize+offset);if(!bytesRead)throw Error('Incomplete model');offset+=bytesRead;}
        }finally{await fileHandle.close();}
        const useGzip=/\bgzip\b/.test(req.headers['accept-encoding']||'');
        const payload=useGzip?await compress(buffer,{level:4}):buffer;
        headers['Content-Length']=payload.length;
        headers['X-Preview-Model-ETag']=etag;
        headers.ETag=`W/"${stat.size}-${Math.trunc(stat.mtimeMs)}-part${index}"`;
        headers.Vary='Accept-Encoding';
        if(useGzip)headers['Content-Encoding']='gzip';
        res.writeHead(200,headers).end(req.method==='HEAD'?undefined:payload);return;
      }
    }
    if(req.headers['if-none-match']===etag){res.writeHead(304,headers).end();return;}
    let start=0,end=stat.size-1,status=200;
    if(req.headers.range){
      const range=/^bytes=(\d+)-(\d*)$/.exec(req.headers.range);
      if(!range){res.writeHead(416,{'Content-Range':`bytes */${stat.size}`}).end();return;}
      start=Number(range[1]);end=range[2]?Math.min(Number(range[2]),end):end;
      if(!Number.isSafeInteger(start)||!Number.isSafeInteger(end)||start>end||start>=stat.size){res.writeHead(416,{'Content-Range':`bytes */${stat.size}`}).end();return;}
      status=206;headers['Content-Range']=`bytes ${start}-${end}/${stat.size}`;
    }
    const compressed=status===200&&stat.size>1024&&/\bgzip\b/.test(req.headers['accept-encoding']||'');
    headers.Vary='Accept-Encoding';
    if(compressed)headers['Content-Encoding']='gzip';
    else headers['Content-Length']=Math.max(0,end-start+1);
    res.writeHead(status,headers);
    if(req.method==='HEAD'){res.end();return;}
    const stream=fs.createReadStream(file,{start,end});stream.on('error',()=>res.destroy());
    res.on('close',()=>stream.destroy());
    if(compressed){const gzip=createGzip({level:4});gzip.on('error',()=>res.destroy());stream.pipe(gzip).pipe(res);}else stream.pipe(res);
  }catch{if(!res.headersSent)res.writeHead(404);res.end();}
}).listen(port,'127.0.0.1',()=>console.log(`Authenticated preview ready on http://127.0.0.1:${port}`));
setTimeout(()=>{server.closeAllConnections();server.close();},expiresAt-Date.now()).unref();
