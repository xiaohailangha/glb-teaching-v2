import fs from 'node:fs';
import crypto from 'node:crypto';

// Exact approved 555-lesson planning snapshot. It is not a playable release.
const bytes=fs.readFileSync(new URL('../data/curriculum/formal-plan.json',import.meta.url));
export const formalPlan=JSON.parse(bytes);
export const formalPlanHash=crypto.createHash('sha256').update(bytes).digest('hex');
export const formalPlanVersion='formal-555-'+formalPlanHash.slice(0,16);
export const testCourseIds=new Set(['B1.01-L01','B1.01-L02','B1.01-L03','B1.01-L04','B1.01-L05','B1.01-R']);
export const emptyFormalEvidence=()=>({completedCourses:[],unitCompleted:false,passed:[],words:[],learnedWords:0,dueWords:[]});

export function validateFormalPlan(plan=formalPlan){
 const units=new Map(plan.units.map(u=>[u.id,u])),courses=new Map(plan.courses.map(c=>[c.id,c]));
 if(plan.categories.length!==12||new Set(plan.categories).size!==12||units.size!==87||plan.units.length!==87||courses.size!==555||plan.courses.length!==555||plan.words.length!==3000||new Set(plan.words.map(w=>w.key)).size!==3000)throw Error('正式555课规划数量错误');
 const assignments=new Set(),seen=new Set();
 for(const u of plan.units){
  if(!plan.categories.includes(u.category)||!u.title||u.depends.some(id=>!units.has(id)))throw Error('正式单元归属或前置无效');
  const walk=(id,path=new Set())=>{if(path.has(id))throw Error('正式单元循环前置');if(seen.has(id))return;const next=new Set([...path,id]);for(const d of units.get(id).depends)walk(d,next);seen.add(id);};walk(u.id);
  for(const id of u.courses){if(assignments.has(id)||courses.get(id)?.unit!==u.id)throw Error('正式课程归属无效');assignments.add(id);}
 }
 if(assignments.size!==555)throw Error('正式课程未完整归属');
 for(const c of plan.courses){
  if(testCourseIds.has(c.id)||c.category!==units.get(c.unit)?.category||!c.title||c.prerequisites.some(id=>courses.has(id)?courses.get(id).order>=c.order:!units.has(id)||units.get(id).courses.some(cid=>courses.get(cid).order>=c.order)))throw Error('正式课程前置或测试隔离无效');
 }
 const taught=new Map();
 for(const c of plan.courses)for(const key of c.words){if(taught.has(key))throw Error('正式词条重复首教');taught.set(key,c.id);}
 if(taught.size!==3000)throw Error('正式首教词数量错误');
 for(const w of plan.words){
  const c=courses.get(w.course);
  if(taught.get(w.key)!==w.course||c?.unit!==w.unit)throw Error('正式首教分配错误');
  for(const key of ['review1','review2','review3'])if(!courses.has(w[key])||courses.get(w[key]).order<=c.order)throw Error('正式复现候选必须在首教之后');
 }
 return true;
}
validateFormalPlan();

export function formalCatalog(){
 return {planVersion:formalPlanVersion,planHash:formalPlanHash,status:'planned',counts:formalPlan.counts,
  categories:formalPlan.categories.map(name=>({name})),
  units:formalPlan.units.map(u=>({...u,name:u.title,status:'planned'})),
  courses:formalPlan.courses.map(c=>({...c,new:c.words,status:'planned',production:{script:'pending',audio:'pending',alignment:'pending',motion:'pending',study:'pending',release:'unpublished'}}))};
}
