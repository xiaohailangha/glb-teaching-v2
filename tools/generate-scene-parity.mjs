import fs from 'node:fs';
import {coursePose,applyCourseFace} from '../assets/avatar/course-director.js';
import {applyPerformanceFace} from '../assets/avatar/teaching-performance.js';
import {applyEmotionFace,emotionIds} from '../assets/avatar/emotions.js';
const fixtures=[];
for(const phase of ['introduce','demonstrate','invite','listen','phoneme','meaning','choice','recall','support','success','encourage','explain','transfer']){
 for(const style of ['adult','child46','child79','child1012'])for(const progress of [0,.17,.5,.85,1]){
  const w={AA:.22,EE:.07,FF:.03,MBP:0};
  applyCourseFace(w,phase,progress,2.7,1,style);
  fixtures.push({kind:'course',phase,style,progress,elapsed:2.7,variation:1,weights:w,pose:coursePose(phase,progress,2.7,1,style)});
 }
}
for(const time of [0,.05,.4,1.65,3.9,6.8,8.4,9.5,10]){const w={AA:.22,EE:.07,FF:.03,MBP:0};applyPerformanceFace(w,time);fixtures.push({kind:'performance',time,weights:w});}
for(const id of emotionIds)for(const time of [0,.3,1.5,2.9,4.9,6]){const w={AA:.22,EE:.07,FF:.03,MBP:0};applyEmotionFace(w,id,time);fixtures.push({kind:'emotion',id,time,weights:w});}
fs.mkdirSync('scene-preview/test/fixtures',{recursive:true});
fs.writeFileSync('scene-preview/test/fixtures/three-math-parity.json',JSON.stringify(fixtures));
console.log('Generated '+fixtures.length+' existing-renderer parity samples.');
