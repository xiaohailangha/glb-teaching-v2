// User-requested delivery correction, 2026-11-04. Keep the immutable archive,
// release identity and existing learning records; omit only the rejected a drill.
export const deliveryRevision='article-a-only-20261104-v2';
export function correctDelivery(teacher,student){
 const lesson=structuredClone(teacher),document=structuredClone(student);
 // The retired listen-and-continue UI has no prompt playback in the app.
 document.lesson.helpBranches=[];
 const retiredPrompts=new Set(['N26A-b7c9af52467c9d3fd6ff','N26A-f5b30feeb893901ffb37']);
 if(lesson.courseId==='N26-U001-L02'){
  const removed=new Set(lesson.steps.slice(1,4).map(s=>s.id));
  if([...removed].join(',')!==[2,3,4].map(n=>'N26-U001-L02-S'+String(n).padStart(3,'0')).join(','))throw Error('Article correction source differs');
  const checks=new Set(lesson.steps.filter(s=>removed.has(s.id)).map(s=>s.check).filter(Boolean));
  for(const target of [lesson,document.lesson]){
   target.steps=target.steps.filter(s=>!removed.has(s.id));
   target.checks=target.checks.filter(c=>!checks.has(c.id));
   target.helpBranches=target.helpBranches.filter(h=>!removed.has(h.forStep));
   for(const w of target.actualWords)if(w.word==='a'){
    w.standalonePreview=false;
    w.audio='N26A-2d49534a6cc2459ded00';
   }
  }
  retiredPrompts.add('N26A-2112c00aabb1042badb5');
 }
 // Do not remove a resource if another real teaching step still uses it.
 const teachingAudio=new Set(document.lesson.steps.flatMap(s=>[s.audio,s.model]).filter(Boolean));
 document.audio=document.audio.filter(a=>!retiredPrompts.has(a.id)||teachingAudio.has(a.id));
 return {lesson,student:document,deliveryRevision};
}
