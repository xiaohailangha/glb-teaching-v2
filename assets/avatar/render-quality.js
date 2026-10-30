const profiles={high:{maxFps:120,maxRatio:1.5,shadow:1024},medium:{maxFps:60,maxRatio:1.25,shadow:768},low:{maxFps:30,maxRatio:1,shadow:512}};
const percentile=(a,p)=>[...a].sort((x,y)=>x-y)[Math.floor((a.length-1)*p)]||0;

export function cadenceFromIntervals(intervals){
  const valid=intervals.filter(x=>Number.isFinite(x)&&x>=3&&x<45);
  if(valid.length<20)return 60;
  const measured=1000/percentile(valid,.25);
  return [30,60,75,90,120,144,165,240].reduce((best,hz)=>Math.abs(hz-measured)<Math.abs(best-measured)?hz:best,60);
}

// This measures the browser's available callbacks while assets load. It does
// not claim to read the physical display's advertised refresh rate.
export function probeCadence(){
  return new Promise(resolve=>{
    const intervals=[];let previous=0;
    const sample=now=>{if(previous&&!document.hidden)intervals.push(now-previous);previous=now;
      if(intervals.length>=48)resolve(cadenceFromIntervals(intervals));else requestAnimationFrame(sample);
    };requestAnimationFrame(sample);
  });
}

export class RenderQuality {
  constructor({pixelRatio=1,cadence=60,memoryConstrained=false}={}){
    this.memoryConstrained=memoryConstrained;
    this.nativeRatio=pixelRatio;this.cadence=cadence;this.next=0;this.windowStart=0;this.samples=[];this.bad=0;this.good=0;this.fallback=1;this.lastChange=0;
    this.configure({quality:'high',adaptive:true});
  }
  configure({quality='high',adaptive=true}={}){
    this.quality=profiles[quality]?quality:'high';this.adaptive=adaptive===true;this.profile={...profiles[this.quality]};
    if(this.memoryConstrained){this.profile.maxRatio=Math.min(this.profile.maxRatio,1);this.profile.shadow=Math.min(this.profile.shadow,512);}
    this.maxRatio=Math.min(this.nativeRatio,this.profile.maxRatio);this.minRatio=Math.min(this.maxRatio,Math.max(.75,Math.min(1,this.nativeRatio)));
    this.ratio=this.adaptive?Math.min(this.maxRatio,1.25):this.maxRatio;this.fallback=1;this.bad=0;this.good=0;this.samples=[];this.windowStart=0;this.next=0;this.reason='profile';
  }
  get targetFps(){return this.cadence/Math.ceil(this.cadence/this.profile.maxFps)/this.fallback;}
  shouldRender(now){
    if(this.targetFps>=this.cadence-.1)return true;
    const period=1000/this.targetFps;
    if(!this.next||now-this.next>period*2)this.next=now;
    if(now+.5<this.next)return false;
    this.next+=period;return true;
  }
  resetTiming(){this.next=0;this.windowStart=0;this.samples=[];this.bad=0;this.good=0;}
  observe(now,interval,cpu){
    if(!this.adaptive||interval<=0||interval>250)return false;
    if(!this.windowStart)this.windowStart=now;
    this.samples.push({interval,cpu});
    if(now-this.windowStart<2000)return false;
    const budget=1000/this.targetFps,p90=percentile(this.samples.map(s=>s.interval),.9),cpu90=percentile(this.samples.map(s=>s.cpu),.9);
    this.samples=[];this.windowStart=now;
    this.bad=p90>budget*1.25?this.bad+1:0;
    this.good=p90<budget*1.12&&cpu90<budget*.60?this.good+1:0;
    if(this.bad>=2&&now-this.lastChange>4000){
      if(this.ratio>this.minRatio+.01){this.ratio=Math.max(this.minRatio,Math.round((this.ratio-.1)*100)/100);this.reason='reduce-resolution';}
      else if(this.targetFps>=55&&this.bad>=3){this.fallback*=2;this.next=0;this.reason='reduce-cadence';}
      else return false;
      this.bad=0;this.good=0;this.lastChange=now;return true;
    }
    if(this.good>=6&&now-this.lastChange>12000){
      if(this.fallback>1){this.fallback/=2;this.next=0;this.reason='recover-cadence';}
      else if(this.ratio<this.maxRatio-.01){this.ratio=Math.min(this.maxRatio,Math.round((this.ratio+.1)*100)/100);this.reason='recover-resolution';}
      else return false;
      this.good=0;this.bad=0;this.lastChange=now;return true;
    }
    return false;
  }
  get status(){return {quality:this.quality,adaptive:this.adaptive,cadenceHz:this.cadence,targetFps:this.targetFps,renderPixelRatio:this.ratio,qualityReason:this.reason};}
}
