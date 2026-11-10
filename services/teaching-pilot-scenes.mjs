const norm=s=>String(s).toLowerCase().replace(/[^a-z ]/g,' ').trim().replace(/\s+/g,' ');
export function sceneForSpeech(step,heard){
 const text=norm(heard),base=step.scene||{};
 if(base.kind==='fruit'&&['and-read','or-read','my-order'].includes(step.id)){
  if(text==='i want an apple and a banana')return {...base,bag:['apple','banana'],caption:'and · 两样都装好'};
  if(text==='i want an apple or a banana')return {...base,bag:['apple'],caption:'or · 任选一种，这次装苹果'};
 }
 if(base.kind==='trip'){
  if((step.answers||[]).some(s=>norm(s)===text)&&text.split(' ').length>1){
   if(text==='against the proposal')return {...base,vote:'against',caption:'方案待修改'};
   if(text==='among friends')return {...base,group:true,caption:'你在朋友之中'};
   if(text==='except me')return {...base,members:['lin','sam','lee'],caption:'除你之外，其他人保留'};
   return {...base,plan:'trying',opinion:step.id==='supported-use'||base.opinion,...(step.id==='supported-use'?{opinionText:heard}:{}),bridge:text.startsWith('despite')?'despite':text.includes('however')?'however':text.startsWith('though')?'though':text.includes('nonetheless')?'nonetheless':'although',caption:'困难保留 · 继续尝试'};
  }
 }
 return null;
}
export function sceneAction(step,input){
 const invalid=()=>{throw Object.assign(Error('场景操作无效'),{status:400});};
 const list=(value,allowed)=>{if(!Array.isArray(value)||value.some(v=>!allowed.includes(v))||new Set(value).size!==value.length)invalid();return value;};
 let good,scene={...step.scene},messageKey;
 if(step.interaction==='fruit-listen'){
  const bag=list(input.bag,['apple','banana']);good=step.task.choice==='both'?bag.length===2:bag.length===1;
  scene.bag=bag;scene.caption=good?'订单装好了':'再核对一下订单';messageKey=good?step.success:step.task.choice==='both'?'actionBoth':'actionEither';
 }else if(step.interaction==='transform'){
  if(!['noun','clause'].includes(input.choice))invalid();good=input.choice==='noun';scene.structure=good?'noun':'clause-error';scene.caption=good?'despite the difficulty':'这里需要名词短语';messageKey=good?step.success:'structureRetry';
 }else if(step.interaction==='roster'){
  const members=list(input.members,['me','lin','sam','lee']);good=members.length===3&&!members.includes('me');scene.members=members;scene.caption=good?'参加名单已确认':'再核对需要排除的人';messageKey=good?step.success:'rosterRetry';
 }else invalid();
 return {status:good?'passed':'repair',type:'scene-action',scene,messageKey,formalProgress:false,independentMastery:false};
}
