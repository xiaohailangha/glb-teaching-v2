// Run after flutter build web. Content-address the application shell so an old
// mobile cache cannot combine a retired player with a newly published lesson.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

export function packageSceneWeb(app,revision){
 const dir=path.join(app,'build/web');
 const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
 const main=fs.readFileSync(path.join(dir,'main.dart.js')),mainSha256=hash(main);
 const mainFile=`main.${mainSha256.slice(0,16)}.dart.js`;
 let bootstrap=fs.readFileSync(path.join(dir,'flutter_bootstrap.js'),'utf8');
 const match=bootstrap.match(/_flutter\.buildConfig = (\{[^\n]+\});/);
 if(!match)throw Error('Flutter build configuration missing');
 const config=JSON.parse(match[1]);
 for(const build of config.builds)if(build.mainJsPath)build.mainJsPath=mainFile;
 bootstrap=bootstrap.replace(match[0],`_flutter.buildConfig = ${JSON.stringify(config)};`);
 const release={schema:'snow-speaks.web-release/1',revision,mainSha256,mainFile};
 // A build can be packaged again without accumulating release stamps.
 bootstrap=bootstrap.replace(/^window\.__snowWebRelease = [^\n]+;\n/,'');
 bootstrap=`window.__snowWebRelease = ${JSON.stringify(release)};\n`+bootstrap;
 const bootstrapFile=`flutter_bootstrap.${hash(bootstrap).slice(0,16)}.js`;
 let html=fs.readFileSync(path.join(dir,'index.html'),'utf8');
 if(!html.includes('<base href="/scene/">'))throw Error('Unexpected application base');
 html=html.replace(/src="flutter_bootstrap(?:\.[a-f0-9]{16})?\.js"/,`src="${bootstrapFile}"`);
 html=html.replace(/href="main(?:\.[a-f0-9]{16})?\.dart\.js"/g,`href="${mainFile}"`);
 if(!html.includes(`src="${bootstrapFile}"`))throw Error('Bootstrap entry missing');
 const indexFile=`index.${hash(html).slice(0,16)}.html`;
 const priorEntries=fs.readdirSync(dir).filter(name=>/^index\.[a-f0-9]{16}\.html$/.test(name));
 for(const name of fs.readdirSync(dir)){
  if(/^(?:main\.[a-f0-9]{16}\.dart\.js|flutter_bootstrap\.[a-f0-9]{16}\.js|index\.[a-f0-9]{16}\.html)(?:\.gz)?$/.test(name))fs.unlinkSync(path.join(dir,name));
 }
 fs.writeFileSync(path.join(dir,mainFile),main);
 fs.writeFileSync(path.join(dir,'flutter_bootstrap.js'),bootstrap);
 fs.writeFileSync(path.join(dir,bootstrapFile),bootstrap);
 fs.writeFileSync(path.join(dir,'index.html'),html);
 fs.writeFileSync(path.join(dir,indexFile),html);
 // Previously shared recovery links must load this release on refresh too.
 for(const name of priorEntries)fs.writeFileSync(path.join(dir,name),html);
 fs.copyFileSync(path.join(app,'web/retire_service_worker.js'),path.join(dir,'flutter_service_worker.js'));
 fs.writeFileSync(path.join(dir,'scene-release.json'),JSON.stringify({...release,bootstrapFile,indexFile},null,2));
 return {...release,bootstrapFile,indexFile};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const app=process.argv[2];if(!app)throw Error('Pass the Flutter application directory');
 const revision=JSON.parse(fs.readFileSync(new URL('../data/teaching-pilot/current.json',import.meta.url))).revision;
 console.log(JSON.stringify(packageSceneWeb(path.resolve(app),revision)));
}
