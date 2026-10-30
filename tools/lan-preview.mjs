// Temporary, authenticated LAN preview. Cloud credentials stay on loopback.
import http from 'node:http';
import fs from 'node:fs';
import {randomBytes, timingSafeEqual} from 'node:crypto';
import {fileURLToPath} from 'node:url';

const host = process.argv[2];
if (!/^(10\.(?:\d{1,3}\.){2}\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})$/.test(host || '')) {
  throw new Error('Pass the private IPv4 address of your LAN adapter.');
}
const port = 5298;
const authority = `${host}:${port}`;
const token = randomBytes(24).toString('hex');
const cookieName = 'glb_lan_preview';
const expiresAt = Date.now() + 12 * 60 * 60 * 1000;
const sessionFile = fileURLToPath(new URL('../work/lan-preview-session.json', import.meta.url));
function matches(value) {
  return typeof value === 'string' && Buffer.byteLength(value) === Buffer.byteLength(token) &&
    timingSafeEqual(Buffer.from(value), Buffer.from(token));
}
function fail(res, code, message) {
  res.writeHead(code, {'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store'}).end(message);
}
const server = http.createServer((req, res) => {
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  if (req.headers.host !== authority || Date.now() >= expiresAt) {
    fail(res, 403, '预览地址无效或已到期'); return;
  }
  const url = new URL(req.url, `http://${authority}`);
  if (url.pathname === '/enter' && req.method === 'GET' && matches(url.searchParams.get('key'))) {
    res.writeHead(303, {
      'Set-Cookie': `${cookieName}=${token}; HttpOnly; SameSite=Lax; Path=/; Max-Age=43200`,
      Location: '/', 'Cache-Control': 'no-store',
    }).end(); return;
  }
  const cookie = req.headers.cookie?.split(';').map(v => v.trim()).find(v => v.startsWith(`${cookieName}=`))?.slice(cookieName.length + 1);
  // A link opened from Messages/Safari may keep cross-site metadata on redirects.
  const topLevelRead = req.method === 'GET' && req.headers['sec-fetch-mode'] === 'navigate';
  if (!matches(cookie) || (req.headers.origin && req.headers.origin !== `http://${authority}`) ||
      (!topLevelRead && req.headers['sec-fetch-site'] && !['same-origin', 'none'].includes(req.headers['sec-fetch-site']))) {
    fail(res, 403, '请使用本次生成的完整手机预览链接打开'); return;
  }
  const speechRead = url.pathname === '/api/speech/status' || /^\/api\/speech\/audio\/[a-f0-9]{64}\.wav$/.test(url.pathname);
  const speechWrite = url.pathname === '/api/speech/tts' && req.method === 'POST';
  const staticRead = !/^\/(api|health|benchmark|performance-recording|avatar-dev)(\/|$)/.test(url.pathname);
  if (!((req.method === 'GET' || req.method === 'HEAD') && (speechRead || staticRead)) && !speechWrite) {
    fail(res, 403, '手机预览仅开放画面和教学配音'); return;
  }
  // Forward only necessary headers; the original backend still validates localhost.
  const headers = {host: '127.0.0.1:5296', origin: 'http://127.0.0.1:5296', 'sec-fetch-site': 'same-origin'};
  for (const name of ['content-type', 'content-length', 'range', 'if-none-match', 'accept-encoding']) {
    if (req.headers[name]) headers[name] = req.headers[name];
  }
  const upstream = http.request({hostname: '127.0.0.1', port: 5296, path: url.pathname + url.search, method: req.method, headers}, incoming => {
    res.writeHead(incoming.statusCode, {...incoming.headers, 'Referrer-Policy': 'no-referrer'});
    incoming.pipe(res);
  });
  upstream.setTimeout(90000, () => upstream.destroy());
  upstream.on('error', () => { if (!res.headersSent) fail(res, 502, '电脑上的项目预览服务未启动'); else res.destroy(); });
  req.on('aborted', () => upstream.destroy());
  res.on('close', () => { if (!res.writableEnded) upstream.destroy(); });
  req.pipe(upstream);
});
server.listen(port, host, () => {
  const session = {pid: process.pid, host, port, expiresAt: new Date(expiresAt).toISOString(), url: `http://${authority}/enter?key=${token}`};
  fs.writeFileSync(sessionFile, JSON.stringify(session, null, 2));
  console.log(`LAN preview ready on ${host}:${port}; link saved in work/lan-preview-session.json`);
});
setTimeout(() => server.close(() => process.exit(0)), expiresAt - Date.now()).unref();
