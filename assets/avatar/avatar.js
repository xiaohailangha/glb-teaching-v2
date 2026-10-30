import * as THREE from 'three';
import { GLTFLoader } from './vendor/loaders/GLTFLoader.js';
import { FrameMeter } from './performance.js';
import { NaturalMotion, makeTimeline, visemeLabels } from './motion.js';
import {applyPerformanceFace,clearPerformanceFace,applyIdleFace} from './teaching-performance.js';
import {PerformanceRecording} from './recording.js';
import {makeEyeEnvironment,configureEyeMaterial,CornealCatchlights} from './eye-materials.js';
import {emotionIds,emotionLabels,applyEmotionFace} from './emotions.js';
import {LessonDirector,PronunciationDirector,PoseSmoother} from './lesson-director.js';
import {CourseDirector,coursePose,applyCourseFace,TeachingFaceSmoother} from './course-director.js';
import {CloudSpeech,LearnerRecorder} from './cloud-speech.js';
import {EyeAim,HairDynamics} from './secondary-motion.js';
import {ActingDirector} from './acting-director.js';
import {RenderQuality,probeCadence} from './render-quality.js';
import {downloadModel} from './model-download.js';
import {isIOSBrowser,prepareMobileModel} from './mobile-memory.js';
const memoryConstrained=isIOSBrowser();
const renderQuality=new RenderQuality({pixelRatio:devicePixelRatio||1,memoryConstrained});
const cadenceProbe=probeCadence();
const teachingFaceSmoother=new TeachingFaceSmoother();
const meter=new FrameMeter();
const motion=new NaturalMotion();

const emit = (event, data = {}) => {
  const payload = JSON.stringify({source:'snow-avatar',event,...data});
  if (window.SnowNative?.postMessage) window.SnowNative.postMessage(payload);
  if (window.parent !== window) window.parent.postMessage(payload, window.location.origin);
};
const cloudSpeech=new CloudSpeech();
const learnerRecorder=new LearnerRecorder(emit);
const message = document.querySelector('#message');
const audio = document.querySelector('#voice');
let model, renderer, bindings = [], timings, active = null, repeatTimer, closeUp=false;
let ctx, analyser, bins, audioSource, lastStats=0;
let lastFrame=performance.now(), lastProgress=0;
const scene=new THREE.Scene();
const camera=new THREE.PerspectiveCamera(30,1,.05,12);
const aim = new THREE.Vector3(0,1.39,0);
const weights=motion.weights;
const cameraTarget=new THREE.Vector3(.025,1.68,1.12);
const aimTarget=new THREE.Vector3(0,1.65,0);
let ready=false, triangles=0, morphCount=0, modelBytes=0, deviceRenderer='';
let mixer,teachingAction,performanceBlend=0,performanceTime=0,performanceFraming=false;
const faceScratch={};
const demoMode=new URLSearchParams(location.search).has('demo');
const fullLayout=new URLSearchParams(location.search).get('layout')==='full';
const recording=new PerformanceRecording(fullLayout);
let expressionPreview=null;
let emotionState=null,emotionLast={index:0,time:0},emotionBlend=0,emotionAction,previousEmotionAction;
let emotionCrossfade=1,emotionOldFace={};
let lessonAction,lessonAccentAction,poseSmoother,lessonBlend=0,lessonVisits=0;
let cornealCatchlights,eyeAim,hairDynamics,actingDirector,storyState=null;
let lastLessonPose={time:7.5,accent:0,accentTime:38},lastLessonFace={phase:'listen',progress:0,elapsed:0,variation:0};
let recordingWord='apple';
let pronunciationUnits={};

function stop(notify=true) {
  learnerRecorder.cancel();
  recording.stop();
  clearTimeout(repeatTimer); repeatTimer=null;
  audio.pause(); audio.currentTime=0;
  const previous=active||emotionState; active=null;emotionState=null;storyState=null;
  if (notify && previous) emit('stopped',{session:previous.session});
}

async function playEmotion(command){
  if(!ready)return;
  const index=emotionIds.indexOf(command.emotion||'happy');if(index<0)return;
  // Retain the outgoing pose for a brief blend when switching mid-gesture.
  emotionOldFace={...weights};emotionCrossfade=0;
  if(emotionAction){previousEmotionAction.time=emotionAction.time;previousEmotionAction.weight=emotionBlend;}
  stop(false);expressionPreview=null;closeUp=false;performanceFraming=true;
  if(command.record){await ensureAudio();recording.start(ctx,audioSource);}
  emotionState={index,start:performance.now(),all:!!command.all,session:command.session};
  emotionLast={index,time:0};
  emit('emotion',{session:command.session,emotion:emotionIds[index]});
  emit('playing',{session:command.session,iteration:1,progress:0});
}

async function ensureAudio() {
  if (!ctx) {
    ctx=new (window.AudioContext||window.webkitAudioContext)();
    analyser=ctx.createAnalyser();analyser.fftSize=128;
    bins=new Uint8Array(analyser.frequencyBinCount);
    audioSource=ctx.createMediaElementSource(audio);
    audioSource.connect(analyser);
    const output=ctx.createGain();output.gain.value=new URLSearchParams(location.search).has('quiet')?0:1;
    analyser.connect(output);output.connect(ctx.destination);
  }
  if(ctx.state!=='running') await ctx.resume();
}

async function play(command) {
  stop(false);
  if(!ready || !timings[command.word]) return;
  const token={word:command.word,session:command.session,rate:Number(command.rate)||1,
    repeat:Math.min(3,Math.max(1,Number(command.repeat)||1)),iteration:1,waiting:false,performance:command.word==='performance'};
  active=token;
  performanceFraming=token.performance;
  if(token.performance)performanceTime=0;
  try {
    await ensureAudio();
    if(active!==token)return;
    audio.src=new URL(`audio/${token.word}.wav`,location.href).href;
    audio.playbackRate=token.rate;audio.preservesPitch=true;
    if(command.record)recording.start(ctx,audioSource);
    await audio.play();
    if(active!==token)return;
    emit('playing',{session:token.session,progress:0,iteration:token.iteration});
  } catch(error) {
    if(active!==token)return;
    active=null;emit('error',{session:token.session,message:`音频未能播放：${error.message}`});
  }
}

async function enterLessonStage(token,stage){
  if(active!==token)return;
  const stageGeneration=(token.stageGeneration||0)+1;token.stageGeneration=stageGeneration;
  if(stage.phase==='finished'){
    active=null;recording.stop();emit('lesson-phase',{session:token.session,phase:'ready'});emit('ended',{session:token.session,progress:1});return;
  }
  token.phase=stage.phase;token.phaseStarted=performance.now();token.waiting=!stage.clip;
  token.iteration=stage.iteration||token.iteration||1;
  if(token.course)token.symbol=stage.symbol||'';
  emit('lesson-phase',{session:token.session,phase:stage.phase,iteration:token.iteration,symbol:token.symbol||'',course:token.course||false,step:stage.id||'',text:stage.text||'',options:stage.options||[],hideAnswer:!!stage.hideAnswer});
  if(!stage.clip){audio.pause();audio.currentTime=0;return;}
  token.word=stage.clip;
  try{
    audio.pause();
    token.waiting=true;
    const item=timings[stage.clip];
    const text=item?.text||(/^[a-z]+$/.test(stage.clip)?stage.clip:null);
    // Isolated phonemes are curated teaching assets, never passed as arbitrary TTS text.
    const isPhoneme=['phoneme','group'].includes(pronunciationUnits[stage.clip]?.kind);
    if(cloudSpeech.enabled&&text&&!isPhoneme){
      emit('speech-loading',{session:token.session});
      const cloud=await cloudSpeech.prepare(text,{language:/[\u3400-\u9fff]/.test(text)?'zh':'en'});
      if(active!==token||token.stageGeneration!==stageGeneration)return;
      token.timeline=makeTimeline(cloud.cues);token.speechSource=cloud.source;
      audio.src=cloud.audioUrl;
    }else{token.timeline=null;token.speechSource=isPhoneme?'curated-phoneme':'local';audio.src=new URL(`audio/${stage.clip}.wav`,location.href).href;}
    token.waiting=false;token.phaseStarted=performance.now();
    audio.playbackRate=stage.rate||1;audio.preservesPitch=true;
    await audio.play();
    if(active!==token)return;
    emit('playing',{session:token.session,iteration:token.iteration,progress:0});
  }catch(error){
    if(active!==token)return;
    active=null;emit('speech-error',{session:token.session,message:`示范暂时不可用：${error.message}`});
  }
}

async function playLesson(command){
  stop(false);
  if(!ready||!timings[command.word])return;
  const lesson=new LessonDirector({...command,variation:lessonVisits++});
  const token={word:command.word,session:command.session,lesson,iteration:1,waiting:true,performance:false,phase:'introduce',phaseStarted:performance.now()};
  active=token;recordingWord=command.word;expressionPreview=null;performanceFraming=true;
  try{await ensureAudio();if(active===token)await enterLessonStage(token,lesson.stage);}
  catch(error){if(active===token){active=null;emit('error',{session:token.session,message:error.message});}}
}

function learnerRespond(command){
  if(!active?.lesson||command.session!==active.session)return;
  const stage=active.lesson.respond(command);if(stage)enterLessonStage(active,stage);
}

async function playCourse(command){
  if(!ready)return;
  stop(false);expressionPreview=null;performanceFraming=true;
  const lesson=new CourseDirector({...command,variation:lessonVisits++});
  const token={word:'apple',session:command.session,lesson,course:true,iteration:1,waiting:true,performance:false,phase:'introduce',phaseStarted:performance.now()};
  active=token;recordingWord='apple';
  try{await ensureAudio();if(active===token)await enterLessonStage(token,lesson.stage);}
  catch(error){if(active===token){active=null;emit('error',{session:token.session,message:error.message});}}
}

async function playPronunciation(command){
  const clip=command.kind==='meaning'?`meaning_${command.word}`:Object.keys(pronunciationUnits).find(key=>['phoneme','group'].includes(pronunciationUnits[key].kind)&&pronunciationUnits[key].symbol===command.symbol);
  if(!ready||!clip||!timings[clip])return;
  stop(false);expressionPreview=null;performanceFraming=true;
  const lesson=new PronunciationDirector({word:command.word,clip,kind:command.kind,variation:lessonVisits++});
  const token={word:clip,session:command.session,lesson,iteration:1,waiting:true,performance:false,phase:command.kind,phaseStarted:performance.now(),symbol:command.symbol};
  active=token;recordingWord=command.word;
  try{await ensureAudio();if(active===token)await enterLessonStage(token,lesson.stage);}
  catch(error){if(active===token){active=null;emit('error',{session:token.session,message:error.message});}}
}

audio.addEventListener('ended',()=>{
  if(!active||!audio.ended)return;
  const token=active;
  if(token.lesson){enterLessonStage(token,token.lesson.advance());return;}
  if(token.iteration<token.repeat){
    token.waiting=true;
    repeatTimer=setTimeout(async()=>{
      if(active!==token)return;
      token.iteration++;token.waiting=false;
      audio.currentTime=0;
      try{ await audio.play(); }
      catch(error){if(active===token){active=null;emit('error',{message:error.message});}}
    },750);
  }else{active=null;recording.stop();emit('ended',{session:token.session,progress:1,iteration:token.iteration});}
});

window.avatarCommand=async(command)=>{
  if(command.type==='render-settings'){
    renderQuality.configure(command);meter.samples=[];meter.last=0;applyRenderQuality();
  }
  if(command.type==='capture-start'){
    if(active?.session!==command.session||!active.waiting||!['listen','recall'].includes(active.phase))return;
    learnerRecorder.start({session:command.session,mode:active.phase==='recall'?'recognize':'assess',text:active.lesson.word||'apple'});
  }
  if(command.type==='capture-stop')learnerRecorder.finish();
  if(command.type==='capture-cancel')learnerRecorder.cancel();
  if(command.type==='cloud-demo')playCloudDemo(command);
  if(command.type==='play')playLesson(command);
  if(command.type==='course')playCourse(command);
  if(command.type==='lesson-response')learnerRespond(command);
  if(command.type==='pronunciation')playPronunciation(command);
  if(command.type==='acting-story'){
    stop(false);await ensureAudio();storyState={start:performance.now(),session:command.session};
    if(command.record)recording.start(ctx,audioSource);
  }
  if(command.type==='performance')play({...command,word:'performance',rate:1,repeat:1});
  if(command.type==='emotion')playEmotion(command);
  if(command.type==='stop')stop();
  if(command.type==='focus')closeUp=!!command.closeUp;
  if(command.type==='retry')location.reload();
};
window.addEventListener('message',(event)=>{
  if(event.source!==window.parent || event.origin!==location.origin)return;
  try{const command=typeof event.data==='string'?JSON.parse(event.data):event.data;
    if(command?.source==='snow-flutter')window.avatarCommand(command);
  }catch(_){/* Ignore unrelated messages. */}
});
window.addEventListener('pagehide',()=>stop(false));

let lastViewportWidth=0,lastViewportHeight=0,lastViewportRatio=0;
function resize(){
  if(!renderer)return;
  const w=Math.max(1,innerWidth),h=Math.max(1,innerHeight);
  if(w===lastViewportWidth&&h===lastViewportHeight&&renderQuality.ratio===lastViewportRatio)return;
  lastViewportWidth=w;lastViewportHeight=h;lastViewportRatio=renderQuality.ratio;
  renderer.setSize(w,h,false);camera.aspect=w/h;camera.updateProjectionMatrix();
  if(fullLayout)camera.setViewOffset(w,h,w*(w>h?.225:.22),0,w,h);
}

function applyRenderQuality(){
  if(!renderer)return;
  if(renderer.getPixelRatio()!==renderQuality.ratio)renderer.setPixelRatio(renderQuality.ratio);
  const light=scene.children.find(o=>o.isDirectionalLight&&o.castShadow);
  const size=renderQuality.profile.shadow;
  if(light&&light.shadow.mapSize.x!==size){light.shadow.mapSize.set(size,size);light.shadow.map?.dispose();light.shadow.mapPass?.dispose();light.shadow.map=null;light.shadow.mapPass=null;}
  resize();
}
function frame(now){
  requestAnimationFrame(frame);
  if(document.hidden||renderer.getContext().isContextLost()||!renderQuality.shouldRender(now))return;
  const renderStart=performance.now(),interval=now-lastFrame;
  meter.begin(now);
  const dt=Math.min(.06,(now-lastFrame)/1000);lastFrame=now;
  let level=0;
  if(analyser&&active&&!audio.paused){analyser.getByteFrequencyData(bins);level=bins.reduce((a,b)=>a+b,0)/(bins.length*180);}
  const speaking=!!active&&!active.waiting&&!audio.paused;
  const id=motion.update(dt,{timeline:active?(active.timeline||timings[active.word]?.timeline):null,time:audio.currentTime,
    rate:audio.playbackRate,speaking,session:active?.session,progress:audio.duration?audio.currentTime/audio.duration:0,level});
  clearPerformanceFace(weights);
  for(const name in weights)if(name.startsWith('Emotion'))weights[name]=0;
  applyIdleFace(weights);
  const storyTime=storyState?Math.max(0,(now-storyState.start)/1000):null;
  if(storyTime!==null&&storyTime>=24){const session=storyState.session;recording.stop();storyState=null;emit('ended',{session,progress:1});}
  performanceBlend+=((active?.performance||storyState?1:0)-performanceBlend)*(1-Math.exp(-dt*8));
  if(active?.performance)performanceTime=audio.currentTime;
  if(storyState)performanceTime=Math.min(storyTime,18)/18*9.999;
  if(teachingAction){
    teachingAction.paused=false;teachingAction.enabled=true;
    teachingAction.weight=performanceBlend;
    teachingAction.time=Math.min(performanceTime,9.99999);
  }
  if(performanceBlend>.001){
    Object.assign(faceScratch,weights);const phase=applyPerformanceFace(faceScratch,performanceTime);
    for(const name in faceScratch)weights[name]+=(faceScratch[name]-weights[name])*performanceBlend;
    document.body.dataset.phase=phase;
  }else document.body.dataset.phase='idle';
  if(emotionState){
    // A click can run after this frame's rAF timestamp was captured.
    const elapsed=Math.max(0,(now-emotionState.start)/1000);
    const total=emotionState.all?(12-emotionState.index)*6:6;
    if(elapsed>=total){
      emotionLast={index:emotionState.all?11:emotionState.index,time:5.9999};
      const session=emotionState.session;emotionState=null;recording.stop();emit('ended',{session,progress:1});
    }else{
      const index=emotionState.index+(emotionState.all?Math.floor(elapsed/6):0);
      emotionLast={index,time:elapsed%6};
      if(emotionState.shown!==index){emotionState.shown=index;emit('emotion',{session:emotionState.session,emotion:emotionIds[index]});}
      if(now-lastProgress>100){emit('progress',{session:emotionState.session,progress:elapsed/total,iteration:1});lastProgress=now;}
    }
  }
  emotionBlend+=((emotionState?1:0)-emotionBlend)*(1-Math.exp(-dt*12));
  emotionCrossfade=Math.min(1,emotionCrossfade+dt/.35);
  if(emotionAction){
    emotionAction.paused=false;emotionAction.enabled=true;emotionAction.time=emotionLast.index*6+emotionLast.time;
    emotionAction.weight=emotionBlend*emotionCrossfade;
    previousEmotionAction.paused=false;previousEmotionAction.enabled=true;previousEmotionAction.weight=emotionBlend*(1-emotionCrossfade);
  }
  if(emotionBlend>.001){
    Object.assign(faceScratch,weights);applyEmotionFace(faceScratch,emotionIds[emotionLast.index],emotionLast.time);
    for(const name in faceScratch){
      const target=(emotionOldFace[name]||0)*(1-emotionCrossfade)+faceScratch[name]*emotionCrossfade;
      weights[name]+=(target-weights[name])*emotionBlend;
    }
    document.body.dataset.phase=emotionIds[emotionLast.index];
  }
  lessonBlend+=((active?.lesson?1:0)-lessonBlend)*(1-Math.exp(-dt*10));
  if(active?.lesson){
    const elapsed=Math.max(0,(now-active.phaseStarted)/1000);
    const progress=active.waiting?0:audio.duration?audio.currentTime/audio.duration:0;
    lastLessonPose=coursePose(active.phase,progress,elapsed,active.lesson.variation,active.lesson.style);
    lastLessonFace={phase:active.phase,progress,elapsed,variation:active.lesson.variation,style:active.lesson.style};
  }
  if(lessonAction){
    lessonAction.paused=false;lessonAction.enabled=true;lessonAction.time=lastLessonPose.time;
    lessonAction.weight=lessonBlend*(1-lastLessonPose.accent);
    lessonAccentAction.paused=false;lessonAccentAction.enabled=true;lessonAccentAction.time=lastLessonPose.accentTime;
    lessonAccentAction.weight=lessonBlend*lastLessonPose.accent;
  }
  if(lessonBlend>.001){
    Object.assign(faceScratch,weights);
    applyCourseFace(faceScratch,lastLessonFace.phase,lastLessonFace.progress,lastLessonFace.elapsed,lastLessonFace.variation,lastLessonFace.style);
    for(const name in faceScratch)weights[name]+=(faceScratch[name]-weights[name])*lessonBlend;
    document.body.dataset.phase=lastLessonFace.phase;
  }
  teachingFaceSmoother.update(weights,dt,lessonBlend>.001);
  eyeAim?.restore();hairDynamics?.restore();actingDirector?.restore();mixer?.update(0);
  poseSmoother?.update(dt,true);
  if(expressionPreview!==null){
    for(const name in weights)weights[name]=0;
    if(expressionPreview>=0)applyPerformanceFace(weights,expressionPreview);
    teachingAction.weight=0;emotionAction.weight=0;previousEmotionAction.weight=0;mixer.update(0);
  }
  if(active)active.viseme=visemeLabels[id]||'';
  if(expressionPreview===null)actingDirector?.update(dt,weights,{speaking,engaged:!!active||!!storyState,storyTime,emoting:emotionBlend>.01,phase:active?.phase||'idle'});
  eyeAim?.update(weights,model?.rotation.y||0);hairDynamics?.update(dt,weights);
  for(let i=0;i<bindings.length;i++){
    const binding=bindings[i];binding.influences[binding.index]=weights[binding.name]||0;
  }
  const actingFrame=true;
  const cameraDistance=(closeUp?.78:1.51)*Math.max(1,.72/(camera.aspect*(fullLayout?.55:1)));
  cameraTarget.y=1.64;aimTarget.y=1.62;
  cameraTarget.z=cameraDistance;
  camera.position.lerp(cameraTarget,1-Math.exp(-dt*5));
  aim.lerp(aimTarget,1-Math.exp(-dt*5));
  camera.lookAt(aim);
  cornealCatchlights?.update(camera,weights);
  meter.beginGpu();renderer.render(scene,camera);meter.endGpu();meter.end();
  const lessonCaptions={introduce:'LOOK & LISTEN',demonstrate:'LISTEN & REPEAT',invite:'YOUR TURN',listen:'YOUR TURN',encourage:'KEEP GOING'};
  recording.draw(renderer.domElement,emotionState?{title:emotionIds[emotionLast.index].toUpperCase(),subtitle:`${String(emotionLast.index+1).padStart(2,'0')} / 12 · ${emotionLabels[emotionLast.index]}`} :active?.lesson?{title:recordingWord.toUpperCase(),subtitle:recordingWord==='apple'?'/ˈæp.əl/  苹果':pronunciationUnits[`meaning_${recordingWord}`]?.symbol||'',teaching:true}:null);
  if(active&&now-lastProgress>100){
    emit('progress',{session:active.session,word:active.word,progress:audio.duration?audio.currentTime/audio.duration:0,
      time:audio.currentTime,viseme:active.viseme||'',iteration:active.iteration,level});lastProgress=now;
  }
  if(ready&&now-lastStats>3000){
    const perf=meter.publish({triangles,drawCalls:renderer.info.render.calls,deviceRenderer,modelBytes,version:'storm-v4-adaptive',...renderQuality.status,animationSeconds:10,hairBones:hairDynamics?.records.size||0,hairPeakRadians:hairDynamics?.peak||0});
    emit('stats',{...perf,...renderQuality.status,triangles,drawCalls:renderer.info.render.calls,modelBytes,deviceRenderer,sourceClock:'audio.currentTime'});
    lastStats=now;
  }
  if(renderQuality.observe(now,interval,performance.now()-renderStart))applyRenderQuality();
}
document.addEventListener('visibilitychange',()=>{lastFrame=performance.now();renderQuality.resetTiming();});

async function init(){
  try{
    renderer=new THREE.WebGLRenderer({antialias:!memoryConstrained,alpha:true,powerPreference:'high-performance'});
    renderer.transmissionResolutionScale=memoryConstrained?.5:1;
    renderer.domElement.addEventListener('webglcontextlost',event=>{
      event.preventDefault();stop(false);ready=false;
      emit('error',{message:'人物渲染被浏览器中断，请关闭其他标签页后点击重试'});
    });
    renderer.domElement.addEventListener('webglcontextrestored',()=>{
      lastFrame=performance.now();renderQuality.resetTiming();ready=true;
      emit('ready',{triangles,morphCount,modelBytes,speech:cloudSpeech.status,runtime:'Three.js · WebGL'});
    });
    const gl=renderer.getContext(),debugInfo=gl.getExtension('WEBGL_debug_renderer_info');
    meter.attach(gl);
    deviceRenderer=debugInfo?gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER);
    renderer.setPixelRatio(renderQuality.ratio);
    renderer.outputColorSpace=THREE.SRGBColorSpace;
    renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1;
    renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.VSMShadowMap;
    document.body.prepend(renderer.domElement);
    scene.add(new THREE.HemisphereLight(0xfff4e5,0x64646b,.9));
    const key=new THREE.DirectionalLight(0xffedda,2.7);key.position.set(-2,3.8,4);key.target.position.set(0,1.5,0);scene.add(key,key.target);
    key.castShadow=true;key.shadow.mapSize.set(renderQuality.profile.shadow,renderQuality.profile.shadow);
    Object.assign(key.shadow.camera,{left:-1.25,right:1.25,top:1.25,bottom:-1.25,near:.1,far:9});
    key.shadow.bias=-.00008;key.shadow.normalBias=.001;key.shadow.radius=6;key.shadow.blurSamples=8;
    const fill=new THREE.DirectionalLight(0xdde9ff,1.1);fill.position.set(2,1.7,2);scene.add(fill);
    const rim=new THREE.DirectionalLight(0xffffff,1.6);rim.position.set(0,2,-2);scene.add(rim);
    let [modelData,data,performanceAudio,prompts,units,coursePrompts]=await Promise.all([downloadModel(new URL('./models/storm-performance.glb',location.href).href,{cloudManifestUrl:'/api/assets/model-manifest'}),fetch('./audio/timings.json').then(r=>{if(!r.ok)throw Error('口型时间数据缺失');return r.json();}),fetch('./audio/performance-cues.json').then(r=>r.json()),fetch('./audio/teaching-prompts.json').then(r=>r.json()),fetch('./audio/pronunciation-units.json').then(r=>r.json()),fetch('./audio/course-prompts.json').then(r=>{if(!r.ok)throw Error('课程语音缺失');return r.json();})]);
    modelBytes=modelData.byteLength;
    const gltf=await new GLTFLoader().parseAsync(modelData,new URL('./models/',location.href).href);
    // The parser caches the binary GLB and accessor buffers. The scene/clips
    // already own everything needed for playback; do not retain both copies.
    modelData=null;gltf.parser=null;
    const mobileMemory=await prepareMobileModel(gltf.scene,{enabled:memoryConstrained});
    document.body.dataset.mobileMemory=JSON.stringify(mobileMemory);
    await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
    pronunciationUnits=units;
    model=gltf.scene;model.scale.setScalar(1.5);timings={...data,...prompts,...units,...coursePrompts,performance:performanceAudio};scene.add(model);
    const clip=gltf.animations.find(clip=>clip.name==='Teaching_Apple_10s');
    if(!clip)throw Error('教学动画缺失');
    mixer=new THREE.AnimationMixer(model);teachingAction=mixer.clipAction(clip);
    teachingAction.setLoop(THREE.LoopOnce,1);teachingAction.clampWhenFinished=true;teachingAction.play();teachingAction.weight=0;
    const emotionClip=gltf.animations.find(c=>c.name==='Emotion_Reel');
    if(!emotionClip)throw Error('情绪动画缺失');
    emotionAction=mixer.clipAction(emotionClip);previousEmotionAction=mixer.clipAction(emotionClip.clone());
    for(const action of [emotionAction,previousEmotionAction]){action.setLoop(THREE.LoopOnce,1);action.clampWhenFinished=true;action.play();action.weight=0;}
    lessonAction=mixer.clipAction(clip.clone());lessonAccentAction=mixer.clipAction(emotionClip.clone());
    for(const action of [lessonAction,lessonAccentAction]){action.setLoop(THREE.LoopOnce,1);action.clampWhenFinished=true;action.play();action.weight=0;}
    const lessonBones=[];model.traverse(o=>{if(o.isBone)lessonBones.push(o);});poseSmoother=new PoseSmoother(lessonBones);
    for(const [word,item]of Object.entries(timings))item.timeline=makeTimeline(item.cues,word);
    const rig=await fetch('./models/storm-rig.json').then(r=>{if(!r.ok)throw Error('Storm 注视与头发骨骼配置缺失');return r.json();});
    eyeAim=new EyeAim(model,rig);hairDynamics=new HairDynamics(model,rig);actingDirector=new ActingDirector(model,rig);
    const unique=new Set();
    const eyeEnvironment=makeEyeEnvironment(renderer);
    model.traverse(obj=>{
      if(!obj.isMesh)return;
      obj.frustumCulled=true;obj.updateMatrix();obj.matrixAutoUpdate=false;
      obj.castShadow=!/eye[._]|cornea/i.test(obj.name);obj.receiveShadow=true;
      if(obj.morphTargetDictionary){
        for(const [name,index]of Object.entries(obj.morphTargetDictionary)){
          // Eye spheres rotate rigidly; linear gaze morphs must not flatten or cross them.
          if(name.startsWith('Gaze')&&/^Storm_eye[._]/.test(obj.name))continue;
          if(!(name in weights))weights[name]=0;
          unique.add(name);bindings.push({name,index,influences:obj.morphTargetInfluences});
        }
      }
      triangles+=(obj.geometry.index?.count||obj.geometry.attributes.position.count)/3;
      const mats=Array.isArray(obj.material)?obj.material:[obj.material];
      for(const m of mats){
        if(!configureEyeMaterial(m,eyeEnvironment.texture)){m.envMap=eyeEnvironment.texture;m.envMapIntensity=.25;}
      }
    });
    cornealCatchlights=new CornealCatchlights(model,rig);
    morphCount=unique.size;
    resize();camera.position.set(.025,1.68,1.12*Math.max(1,.72/camera.aspect));aim.set(0,1.65,0);
    camera.lookAt(aim);
    await renderer.compileAsync(scene,camera);
    renderer.render(scene,camera);
    message.remove();ready=true;
    let testTimer,testEndTimer;
    meter.controls((mode,duration)=>{
      const emotionSession=emotionState?.session||30000;
      clearInterval(testTimer);clearTimeout(testEndTimer);stop(false);
      if(mode==='cloud'){
        let index=0;const run=()=>playCloudDemo({text:'I like apples.',language:'en',session:70000+index++});
        run();testTimer=setInterval(run,2700);
        testEndTimer=setTimeout(()=>{clearInterval(testTimer);stop(false);},duration+100);
      }else if(mode==='emotion'){
        playEmotion({emotion:'happy',all:true,session:emotionSession});
        testEndTimer=setTimeout(()=>stop(false),duration+100);
      }else if(mode==='acting'){
        storyState={start:performance.now(),session:80000};
        testTimer=setInterval(()=>{storyState={start:performance.now(),session:80001};},24000);
        testEndTimer=setTimeout(()=>{clearInterval(testTimer);stop(false);},duration+100);
      }else if(mode==='performance'){
        let index=0;const run=()=>play({word:'performance',session:20000+index++,rate:1,repeat:1});
        run();testTimer=setInterval(run,10080);
        testEndTimer=setTimeout(()=>{clearInterval(testTimer);stop(false);},duration+100);
      }else if(mode==='speech'){
        let index=0;const words=Object.keys(data);
        testTimer=setInterval(()=>play({word:words[index++%words.length],session:10000+index,rate:1,repeat:1}),2200);
        testEndTimer=setTimeout(()=>{clearInterval(testTimer);stop(false);},duration);
      }else if(mode==='course'){
        let index=0;const styles=['adult','child46','child79','child1012'];
        playCourse({style:styles[index++%styles.length],session:60000+index});
        testTimer=setInterval(()=>{
          if(active?.course&&active.lesson.stage.options&&performance.now()-active.phaseStarted>1400){
            const action=active.lesson.stage.phase==='choice'?'apple':'attempt';
            learnerRespond({session:active.session,action});
          }
          if(!active)playCourse({style:styles[index++%styles.length],session:60000+index});
        },250);
        testEndTimer=setTimeout(()=>{clearInterval(testTimer);stop(false);},duration+100);
      }else if(mode==='lesson'){
        let index=0;const words=Object.keys(data);
        playLesson({word:words[index++],session:40000+index});
        // Benchmark-only simulated button actions. Normal teaching waits for
        // the learner's real "I've finished" button, with no timeout feedback.
        testTimer=setInterval(()=>{
          if(active?.lesson?.stage?.phase==='listen'&&performance.now()-active.phaseStarted>1800)learnerRespond({session:active.session});
          if(!active)playLesson({word:words[index++%words.length],session:40000+index,reason:'next'});
        },250);
        testEndTimer=setTimeout(()=>{clearInterval(testTimer);stop(false);},duration+100);
      }
    });
    if(demoMode&&window.parent===window){
      const button=document.createElement('button');button.id='demo-play';button.textContent='播放 10 秒教学表演';
      button.style.cssText='position:absolute;bottom:20px;left:24px;z-index:2;padding:12px 20px;border:1px solid #ffffff55;border-radius:24px;background:#ffffff16;color:white;cursor:pointer;font:14px system-ui';
      button.onclick=()=>play({word:'performance',session:Date.now(),rate:1,repeat:1});document.body.append(button);
    }
    if(new URLSearchParams(location.search).has('emotions')&&window.parent===window){
      const bar=document.createElement('div');bar.style.cssText='position:absolute;right:20px;bottom:24px;z-index:5;display:flex;gap:8px';
      const select=document.createElement('select');select.setAttribute('aria-label','情绪');
      for(const id of emotionIds){const o=document.createElement('option');o.value=id;o.textContent=id;select.append(o);}
      const playButton=document.createElement('button');playButton.textContent='播放情绪';playButton.onclick=()=>playEmotion({emotion:select.value,session:Date.now()});
      const all=document.createElement('button');all.textContent='连播全部情绪';all.onclick=()=>playEmotion({emotion:'happy',all:true,session:Date.now()});
      bar.append(select,playButton,all);document.body.append(bar);
    }
    if(new URLSearchParams(location.search).has('record')){
      const button=document.createElement('button');button.id='record-status';button.textContent=new URLSearchParams(location.search).has('lesson')?'录制日常教学':new URLSearchParams(location.search).has('emotions')?'录制 72 秒情绪':'录制 10 秒表演';
      button.style.cssText='position:absolute;bottom:70px;left:24px;z-index:4;padding:12px;cursor:pointer';
      button.onclick=async()=>{
        if(new URLSearchParams(location.search).has('lesson')){
          await playLesson({word:new URLSearchParams(location.search).get('lesson')||'apple',session:50000});
          recording.start(ctx,audioSource);button.textContent='录制中…';return;
        }
        if(new URLSearchParams(location.search).has('emotions')){
          await ensureAudio();playEmotion({emotion:'happy',all:true,session:Date.now()});recording.start(ctx,audioSource);button.textContent='录制中…';return;
        }
        await play({word:'performance',session:Date.now(),rate:1,repeat:1});
        if(active?.performance){recording.start(ctx,audioSource);button.textContent='录制中…';}
      };document.body.append(button);
    }
    if(new URLSearchParams(location.search).has('lesson')&&window.parent===window){
      const done=document.createElement('button');done.textContent='我读好了';done.style.cssText='position:absolute;right:20px;bottom:20px;z-index:5;padding:12px';
      done.onclick=()=>learnerRespond({session:active?.session});document.body.append(done);
    }
    if(new URLSearchParams(location.search).has('faces')){
      const select=document.createElement('select');select.setAttribute('aria-label','表情检查');
      select.style.cssText='position:absolute;top:12px;left:12px;z-index:6;padding:12px';
      for(const [value,label]of [['live','正常播放'],['-1','中性'],['1.3','招呼微笑'],['6.8','期待跟读'],['9.45','鼓励微笑']]){
        const option=document.createElement('option');option.value=value;option.textContent=label;select.append(option);
      }
      select.onchange=()=>{stop();expressionPreview=select.value==='live'?null:Number(select.value);};document.body.append(select);
    }
    const speechStatus=await cloudSpeech.init();
    emit('ready',{triangles:Math.round(triangles),morphCount,modelBytes,voice:cloudSpeech.enabled?'腾讯超自然大模型 2.0':'本地示范音频',speech:speechStatus,runtime:'Three.js · WebGL'});
    renderQuality.cadence=await cadenceProbe;
    lastFrame=performance.now();requestAnimationFrame(frame);
  }catch(error){message.textContent='人物加载失败，请点击重试';emit('error',{message:error.message});console.error(error);}
}
window.addEventListener('resize',resize);
init();

async function playCloudDemo(command){
  if(!ready)return;stop(false);await ensureAudio();
  const token={session:command.session,word:'apple',waiting:true,phase:'demonstrate',phaseStarted:performance.now(),iteration:1,lesson:{variation:0,style:'adult'}};
  active=token;performanceFraming=true;
  try{
    const cloud=await cloudSpeech.prepare(command.text||'Apple. I like apples.',{language:command.language||'en',voice:command.voice||403007});
    if(active!==token)return;
    token.timeline=makeTimeline(cloud.cues);token.speechSource=cloud.source;
    // One-shot demo retains teaching gestures without entering the course director.
    token.lesson.advance=()=>({phase:'finished'});
    audio.src=cloud.audioUrl;audio.playbackRate=1;token.waiting=false;token.phaseStarted=performance.now();
    if(command.record)recording.start(ctx,audioSource);
    await audio.play();
    emit('cloud-result',{session:token.session,key:cloud.key,voice:cloud.voice,duration:cloud.duration,phones:cloud.phones.length,cached:cloud.cached,alignmentSource:cloud.source});
  }catch(error){if(active===token){active=null;emit('error',{session:token.session,message:error.message});}}
}
