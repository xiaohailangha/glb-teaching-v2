import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {formalPlan,formalPlanHash,formalPlanVersion} from './formal-curriculum.mjs';

const hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
const phases=new Set(['meaning','model','listen','recall','support','success','finish']);
const surface=s=>String(s).replace(/’/g,"'").toLowerCase();
const tokens=s=>String(s).match(/[A-Za-z]+(?:['’-][A-Za-z]+)*/g)||[];
const normalize=s=>tokens(s).map(surface).join(' ');
// Reviewed grammatical variants only. This list authorizes a key-to-surface
// relationship, never an encounter or mastery claim. A new variant needs
// review before it can be authored under an existing canonical key.
const reviewedForms=new Map(Object.entries({
 a:['an'],be:['is','am','are'],apple:['apples'],column:['columns'],cup:['cups'],dollar:['dollars'],pound:['pounds'],noodle:['noodles'],chopstick:['chopsticks'],sock:['socks'],shoe:['shoes'],trainer:['trainers'],sandal:['sandals'],slipper:['slippers'],earring:['earrings'],match:['matches'],hurt:['hurts'],can:['cannot'],file:['files'],part:['parts'],choice:['choices'],do:['does'],need:['needs'],hour:['hours'],work:['worked'],acquire:['acquired'],drive:['driving'],steal:['stole'],disappear:['disappeared'],happen:['happened'],occur:['occurred'],friend:['friends'],option:['options'],event:['events'],
}).map(([key,forms])=>[key,new Set(forms)]));
const validSurface=(key,word)=>surface(word)===key||reviewedForms.get(key)?.has(surface(word))===true;

function readPackage(directory){
 const root=fs.realpathSync(directory);
 const read=relative=>{
  if(typeof relative!=='string'||path.isAbsolute(relative))throw Error('内容包路径无效');
  const resolved=fs.realpathSync(path.resolve(root,relative)),inside=path.relative(root,resolved);
  if(inside==='..'||inside.startsWith('..'+path.sep)||path.isAbsolute(inside))throw Error('内容包路径越界');
  return JSON.parse(fs.readFileSync(resolved,'utf8'));
 };
 const pkg=read('package.json');
 return {pkg,documents:(pkg.courses||[]).map(item=>({item,lesson:read(item.file)}))};
}

// Explicit companion packages supply authored surface-form evidence. Nothing
// read here is a learner encounter, an executable registration or a release.
export function auditContentPackages(directories){
 const sourceLessons=directories.flatMap(directory=>readPackage(directory).documents.map(d=>d.lesson));
 const packages=directories.map(directory=>auditContentPackage(directory,{sourceLessons}));
 return {schema:'snow-speaks.content-intakes/1',contentValid:packages.length>0&&packages.every(p=>p.contentValid),packages,playable:false,published:false};
}

// Read-only authoring intake. It never writes production data, registers a
// lesson, trusts remote asset URLs, or promotes an authoring status to release.
export function auditContentPackage(directory,{sourceLessons=[]}={}){
 const {pkg,documents}=readPackage(directory),errors=[],media=new Set(),lessons=[];
 const sources=new Map(),conflicts=new Set();
 for(const l of [...sourceLessons,...documents.map(d=>d.lesson)]){
  if(sources.has(l.courseId)&&hash(sources.get(l.courseId))!==hash(l))conflicts.add(l.courseId);
  sources.set(l.courseId,l);
 }
 const require=(valid,message)=>{if(!valid)errors.push(message);};
 require(pkg.schema==='snow-speaks.content-package/1','内容包schema不支持');
 require(pkg.baseline?.planSha256===formalPlanHash,'内容包规划哈希不符');
 const audio=new Map((pkg.audio||[]).map(a=>[a.id,a]));
 require(audio.size===(pkg.audio||[]).length,'音频ID重复');
 const seen=new Set();
 for(const {item,lesson:l} of documents){
  const expected=formalPlan.courses.find(c=>c.id===item.courseId);
  require(!!expected&&!seen.has(item.courseId),`${item.courseId}: 正式课号不存在或重复`);seen.add(item.courseId);
  if(!expected)continue;
  const prefix=l.courseId+': ',check=(valid,message)=>require(valid,prefix+message);
  check(l.schema==='snow-speaks.content/1','课程schema不支持');
  check(l.planHash===formalPlanHash&&l.planVersion===formalPlanVersion,'课程规划版本不符');
  check(l.sourceCourseHash===hash(expected),'课程原始范围哈希不符');
  check(l.courseId===expected.id&&l.title===expected.title&&item.title===expected.title&&l.unitId===expected.unit&&l.category===expected.category,'正式名称或归属被修改');
  check(same(l.newWords,expected.words)&&same(l.prerequisites,expected.prerequisites),'首教或前置范围被修改');
  check(l.status?.release==='not_published'&&item.status?.release==='not_published','草稿包不得自报发布');
  const steps=l.steps||[],checks=new Map((l.checks||[]).map(c=>[c.id,c])),ids=new Set(steps.map(s=>s.id)),requiredAudio=new Set();
  check(ids.size===steps.length&&steps.length>0,'教学步骤为空或重复');
  check(checks.size===(l.checks||[]).length,'练习ID重复');
  const stages=(l.sixStages||[]).flatMap(s=>s.steps);
  check(same((l.sixStages||[]).map(s=>s.id),[1,2,3,4,5,6])&&same(stages,steps.map(s=>s.id)),'六步顺序或步骤覆盖无效');
  const addAudio=id=>{if(id){check(audio.has(id),'音频引用不存在 '+id);requiredAudio.add(id);}};
  const allowed=new Set(expected.words),visiting=new Set();
  const dependency=id=>{
   if(visiting.has(id))return;visiting.add(id);
   const c=formalPlan.courses.find(c=>c.id===id),u=formalPlan.units.find(u=>u.id===id);
   if(c){c.words.forEach(w=>allowed.add(w));c.prerequisites.forEach(dependency);}
   else if(u)u.courses.forEach(dependency);
  };expected.prerequisites.forEach(dependency);
  const importedForms=new Map(),requiredTaughtWords=[],requiredKeys=new Set();
  check(l.requiredTaughtWords===undefined||Array.isArray(l.requiredTaughtWords),'已首教词引用必须为数组');
  for(const ref of Array.isArray(l.requiredTaughtWords)?l.requiredTaughtWords:[]){
   const word=formalPlan.words.find(w=>w.key===ref?.key),source=formalPlan.courses.find(c=>c.id===ref?.sourceCourse);
   const valid=!!word&&!!source&&word.course===source.id&&source.order<expected.order&&ref.planHash===formalPlanHash&&!requiredKeys.has(ref.key);
   check(valid,'已首教词引用无效 '+String(ref?.key));
   if(!valid)continue;
   requiredKeys.add(ref.key);
   requiredTaughtWords.push({key:ref.key,sourceCourse:ref.sourceCourse,planHash:ref.planHash});
   allowed.add(ref.key);
   const authored=sources.get(source.id);
   const validSource=validAuthoredSource(authored,source);
   check(validSource,'复用表面词缺少一致版本的源课内容 '+source.id);
   const forms=new Set(validSource?(authored.actualWords||[]).filter(w=>w.key===ref.key&&w.properName!==true&&typeof w.word==='string'&&validSurface(w.key,w.word)).map(w=>surface(w.word)):[]);
   check(forms.size>0,'源课实际接触词缺少 '+ref.key);
   importedForms.set(ref.key,forms);
  }
  const actual=l.actualWords||[];
  function validAuthoredSource(authored,source){
   return !!source&&authored?.schema==='snow-speaks.content/1'&&authored.courseId===source.id&&authored.planHash===formalPlanHash&&authored.planVersion===formalPlanVersion&&authored.sourceCourseHash===hash(source)&&authored.title===source.title&&authored.unitId===source.unit&&authored.category===source.category&&same(authored.newWords,source.words)&&same(authored.prerequisites,source.prerequisites)&&!conflicts.has(source.id);
  }
  // A canonical first teacher does not exhaust every later taught form. Only
  // the original prerequisite graph or a real local teaching sequence can
  // supply additional surface evidence; arbitrary earlier lessons cannot.
  const prerequisiteForms=new Map();
  for(const id of visiting){
   const source=formalPlan.courses.find(c=>c.id===id),authored=sources.get(id);
   if(!source||source.order>=expected.order||!validAuthoredSource(authored,source))continue;
   for(const w of authored.actualWords||[]){
    if(w.properName===true||typeof w.word!=='string'||!validSurface(w.key,w.word))continue;
    if(!prerequisiteForms.has(w.key))prerequisiteForms.set(w.key,new Set());
    prerequisiteForms.get(w.key).add(surface(w.word));
   }
  }
  const explicitForms=new Map();
  const firstTeacherForms=new Map();
  for(const key of allowed){
   const canonical=formalPlan.words.find(w=>w.key===key),source=formalPlan.courses.find(c=>c.id===canonical?.course),authored=sources.get(source?.id);
   if(!source||source.order>=expected.order||!validAuthoredSource(authored,source))continue;
   firstTeacherForms.set(key,new Set((authored.actualWords||[]).filter(w=>w.key===key&&w.properName!==true&&validSurface(key,w.word)).map(w=>surface(w.word))));
  }
  for(const entry of l.teachingScope?.introduced||[]){
   if(entry.kind!=='explicit_form_or_sense')continue;
   const canonical=formalPlan.words.find(w=>w.key===entry.key);
   const canonicalCourse=formalPlan.courses.find(c=>c.id===canonical?.course);
   const word=actual.find(w=>w.key===entry.key&&surface(w.word)===surface(entry.surface)&&w.properName!==true);
   const validMeaning=typeof entry.meaning==='string'&&entry.meaning.trim().length>0&&typeof word?.meaning==='string'&&word.meaning.trim().length>0;
   const priorForm=importedForms.get(entry.key)?.has(surface(entry.surface))||prerequisiteForms.get(entry.key)?.has(surface(entry.surface))||firstTeacherForms.get(entry.key)?.has(surface(entry.surface));
   const sequence=steps.some((meaning,i)=>{
    const model=steps[i+1],repeat=steps[i+2],c=checks.get(repeat?.check);
    const zh=audio.get(meaning.audio),en=audio.get(model?.audio);
    const premature=!priorForm&&steps.slice(0,i).some(s=>[s.display,...[s.audio,s.model].map(id=>audio.get(id)).filter(a=>a?.language==='en').map(a=>a.text)].some(text=>tokens(text).some(w=>surface(w)===surface(entry.surface))));
    return !premature&&meaning.stage===2&&meaning.phase==='释义'&&surface(meaning.display)===surface(entry.surface)&&typeof meaning.instruction==='string'&&/[\u4e00-\u9fff]/.test(meaning.instruction)&&zh?.language==='zh'&&zh.text===meaning.instruction&&
     model?.stage===2&&model.phase==='示范'&&surface(model.display)===surface(entry.surface)&&en?.language==='en'&&surface(en.text)===surface(entry.surface)&&
     repeat?.stage===2&&repeat.phase==='跟读'&&repeat.display===model.display&&repeat.model===model.audio&&repeat.supported===true&&repeat.capture==='immediate_on_same_display_after_model'&&
     c?.course===expected.id&&c.kind==='teaching'&&c.supported===true&&c.independentEligible===false&&Array.isArray(c.answers)&&c.answers.length===1&&surface(c.answers[0])===surface(entry.surface);
   });
   const valid=typeof entry.surface==='string'&&entry.surface.trim().length>0&&validSurface(entry.key,entry.surface)&&allowed.has(entry.key)&&canonicalCourse?.order<=expected.order&&!!word&&typeof word.ipa==='string'&&word.ipa.length>2&&validMeaning&&sequence;
   check(valid,'显式词形或义项缺少逐词释义、整词示范及即时跟读证据 '+String(entry.surface));
   if(valid){if(!explicitForms.has(entry.key))explicitForms.set(entry.key,new Set());explicitForms.get(entry.key).add(surface(entry.surface));}
  }
  check(actual.length>0&&new Set(actual.map(w=>w.word)).size===actual.length,'实际接触词为空或重复');
  for(const w of actual){
   check(w.properName===true||allowed.has(w.key),'实际接触词超出前置范围 '+w.key);
   check(w.properName===true||validSurface(w.key,w.word),'实际词形与规范词key不符或尚未经词形审核 '+w.word);
   if(w.properName!==true&&surface(w.word)!==w.key){
    const primaryHere=expected.words.includes(w.key)&&w.key==='be'&&surface(w.word)==='is';
    check(primaryHere||importedForms.get(w.key)?.has(surface(w.word))||prerequisiteForms.get(w.key)?.has(surface(w.word))||firstTeacherForms.get(w.key)?.has(surface(w.word))||explicitForms.get(w.key)?.has(surface(w.word)),'词形缺少首教、原前置或本课显式教学证据 '+w.word);
   }
   if(importedForms.has(w.key))check(w.properName!==true&&(importedForms.get(w.key).has(surface(w.word))||prerequisiteForms.get(w.key)?.has(surface(w.word))||explicitForms.get(w.key)?.has(surface(w.word))),'复用词形未在源课实际教过 '+w.word+'（且无原前置或本课显式教学证据）');
   check(typeof w.ipa==='string'&&w.ipa.length>2,'完整音标缺失 '+w.word);addAudio(w.audio);
   check(audio.get(w.audio)?.language==='en'&&surface(audio.get(w.audio).text)===surface(w.word),'单词卡音频与完整词不符 '+w.word);
  }
  check(l.summary?.wordSource==='actualWords'&&l.summary?.wholeWordAndIpaClickable===true,'结课词与音标契约缺失');
  const modeled=new Set(),surfaces=new Set(actual.map(w=>surface(w.word)));
  const checkSurface=text=>{for(const word of tokens(text))check(surfaces.has(surface(word)),'实际接触词漏列 '+word);};
  for(let i=0;i<steps.length;i++){
   const s=steps[i];check(s.course===expected.id&&s.id.startsWith(expected.id+'-'),'步骤未使用正式命名空间');
   check(phases.has(s.avatar?.phase),'人物意图无效');addAudio(s.audio);addAudio(s.model);
   checkSurface(s.display);
   if(s.phase==='示范')modeled.add(normalize(s.display||''));
   if(s.check){const c=checks.get(s.check);check(c?.course===expected.id,'练习跨课程或不存在');for(const answer of c?.answers||[])check(modeled.has(normalize(answer)),'练习回应尚未示范 '+answer);}
   if(s.phase==='跟读'){
    const model=steps[i-1];
    check(model?.phase==='示范'&&model.audio===s.model&&model.display===s.display&&s.capture==='immediate_on_same_display_after_model','未满足同屏示范后即时跟读');
   }
  }
  for(const c of checks.values()){
   check(c.course===expected.id&&!c.options,'练习不能跨课或使用选择题');
   check(Array.isArray(c.answers)&&c.answers.length>0,'口头回应目标为空');
   for(const answer of c.answers||[])checkSurface(answer);
   check(!(c.supported===true&&c.independentEligible===true),'提示练习不能认定独立掌握');
   for(const id of c.audio||[])addAudio(id);
   if(c.help)check((l.helpBranches||[]).some(h=>h.id===c.help),'练习帮助分支不存在');
  }
  for(const h of l.helpBranches||[]){
   check(ids.has(h.forStep)&&h.retry?.sameStep===h.forStep&&h.retry?.supported===true&&h.retry?.independentEligible===false,'帮助重试契约无效');
   check(h.onRepeatedDifficulty?.awardMastery===false,'困难继续不能授予掌握');
   addAudio(h.audio);addAudio(h.model);addAudio(h.onRepeatedDifficulty?.audio);
  }
  for(const id of requiredAudio)if(audio.get(id)?.language==='en')checkSurface(audio.get(id).text);
  for(const id of requiredAudio)media.add(id);
  lessons.push({courseId:l.courseId,title:l.title,contentHash:hash(l),steps:steps.length,checks:checks.size,requiredAudio:requiredAudio.size,requiredTaughtWords,runtimeStatus:requiredTaughtWords.length?'needs_runtime_taught_word_guard':'not_registered'});
 }
 require(lessons.length>0,'内容包没有有效课程');
 const missing=[...media].filter(id=>!audio.get(id)?.asset);
 return {schema:'snow-speaks.content-intake/1',packageId:pkg.id,packageHash:hash(pkg),planVersion:formalPlanVersion,contentValid:errors.length===0,errors,lessons,requiredAudio:media.size,missingAudio:missing.length,mediaStatus:'requires_hash_alignment_listening_gate',playable:false,published:false,blockers:[...(missing.length?[`${missing.length}条必需音频尚无资产`]:[]),...(lessons.some(l=>l.requiredTaughtWords.length)?['needs_runtime_taught_word_guard']:[]),'媒体须经运行端哈希、对齐与听审门禁','尚未注册为正式可执行课程']};
}
