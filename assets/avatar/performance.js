const percentile=(values,p)=>values.length?[...values].sort((a,b)=>a-b)[Math.min(values.length-1,Math.floor(values.length*p))]:null;
const rounded=value=>value==null?null:Math.round(value*100)/100;

// Measures delivered requestAnimationFrame intervals; it never manufactures FPS
// from render duration or replaces the browser's frame scheduler.
export class FrameMeter {
  constructor(){
    this.samples=[];this.last=0;this.cpuStart=0;this.run=null;this.result=null;
    this.output=document.createElement('output');this.output.id='performance';this.output.hidden=true;
    document.body.append(this.output);
    this.enabled=new URLSearchParams(location.search).has('perf');
    if(this.enabled){
      this.output.hidden=false;
      this.output.style.cssText='position:absolute;top:12px;left:12px;max-width:calc(100% - 24px);max-height:calc(100% - 72px);overflow:auto;padding:12px;background:#171717e8;color:#fff;white-space:pre-wrap;font:12px/1.5 monospace;z-index:3';
    }
    document.addEventListener('visibilitychange',()=>{
      this.last=0;this.samples=[];
      if(this.run&&document.hidden)this.run.invalid=true;
    });
  }
  attach(gl){this.gl=gl;this.ext=this.enabled?gl.getExtension('EXT_disjoint_timer_query_webgl2'):null;this.queries=[];this.gpu=[];this.ticks=0;}
  begin(now){this.now=now;this.cpuStart=performance.now();}
  beginGpu(){
    if(!this.ext)return;
    const gl=this.gl;
    while(this.queries.length&&gl.getQueryParameter(this.queries[0],gl.QUERY_RESULT_AVAILABLE)){
      const q=this.queries.shift();
      if(!gl.getParameter(this.ext.GPU_DISJOINT_EXT))this.gpu.push(gl.getQueryParameter(q,gl.QUERY_RESULT)/1e6);
      gl.deleteQuery(q);if(this.gpu.length>120)this.gpu.shift();
    }
    if(++this.ticks%15===0&&this.queries.length<4){this.query=gl.createQuery();gl.beginQuery(this.ext.TIME_ELAPSED_EXT,this.query);}
  }
  endGpu(){if(this.query){this.gl.endQuery(this.ext.TIME_ELAPSED_EXT);this.queries.push(this.query);this.query=null;}}
  end(){
    const sample={at:this.now,dt:this.last?this.now-this.last:0,cpu:performance.now()-this.cpuStart};
    this.last=this.now;
    if(!document.hidden&&sample.dt>0){
      this.samples.push(sample);if(this.samples.length>600)this.samples.shift();
      if(this.run&&sample.at>=this.run.start){
        if(!this.run.first)this.run.first=sample.at;
        else this.run.samples.push(sample);
        if(sample.at-this.run.first>=this.run.duration){
          this.result={...this.extra,...this.summarize(this.run.samples),mode:this.run.mode,valid:!this.run.invalid,
            viewport:[innerWidth,innerHeight],pixelRatio:devicePixelRatio,visibility:document.visibilityState,recordedAt:new Date().toISOString()};
          if(this.enabled&&location.hostname==='localhost'){
            fetch('/benchmark',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(this.result)})
              .catch(()=>{/* The local report is still visible if this server has no recorder. */});
          }
          this.run=null;this.complete?.(this.result);
        }
      }
    }
  }
  summarize(samples=this.samples){
    const intervals=samples.map(s=>s.dt),duration=intervals.reduce((a,b)=>a+b,0);
    const budget=1000/(this.extra?.targetFps||60);
    return {fps:rounded(samples.length*1000/duration)||0,frames:samples.length,durationMs:rounded(duration),
      frameP50:rounded(percentile(intervals,.5)),frameP95:rounded(percentile(intervals,.95)),
      cpuP95:rounded(percentile(samples.map(s=>s.cpu),.95)),gpuP95:rounded(percentile(this.gpu,.95)),
      frameBudgetMs:rounded(budget),overBudgetFrames:samples.filter(s=>s.dt>budget*1.3).length,
      over25ms:samples.filter(s=>s.dt>25).length};
  }
  publish(extra={}){
    this.extra=extra;
    const report={live:this.summarize(),benchmark:this.result,running:this.run?this.run.mode:null,...extra};
    this.output.textContent=JSON.stringify(report,null,2);return report.live;
  }
  controls(onRun){
    if(!this.enabled)return;
    const bar=document.createElement('div');bar.style.cssText='position:absolute;left:12px;bottom:12px;z-index:4;display:flex;gap:8px';
    for(const [mode,label]of [['idle','测试待机 30 秒'],['speech','测试说话 30 秒'],['cloud','测试腾讯口型 30 秒'],['performance','测试表演 30 秒'],['acting','测试连续转身 30 秒'],['emotion','测试情绪 72 秒'],['lesson','测试融合教学 60 秒'],['course','测试课程表演 60 秒']]){
      const button=document.createElement('button');button.textContent=label;
      button.onclick=()=>{
        const duration=mode==='emotion'?72000:['lesson','course'].includes(mode)?60000:30000;
        this.result=null;this.run={mode,start:performance.now()+2000,duration,first:0,samples:[],invalid:document.hidden};
        onRun(mode,duration+2000);
      };bar.append(button);
    }
    document.body.append(bar);
  }
}
