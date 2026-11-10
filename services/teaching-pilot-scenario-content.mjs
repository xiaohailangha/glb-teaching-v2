const and='I want an apple and a banana.',or='I want an apple or a banana.';
const although='Although this is difficult, I can try.',despite='Despite the difficulty, I can try.',however='This is difficult. However, I can try.';
const expressions=[although,'Though this is difficult, I can try.',despite,however,'This is difficult. Nonetheless, I can try.'];
const fruit=(extra={})=>({kind:'fruit',bag:[],role:'customer',...extra});
const trip=(act,extra={})=>({kind:'trip',act,plan:'draft',members:['me','lin','sam','lee'],...extra});
const c=(id,part,title,body,display='',models=[],answers=[],extra={})=>({id,part,title,body,display,models,answers,supported:true,...extra});
const word=(id,act,meaning,scene)=>c(id,act===1?'第一幕 · 有困难，还试吗':act===2?'第二幕 · 帮老师改顺一句话':'第三幕 · 意见和名单',id+' · '+meaning,`这个词在本课表示${meaning}。听老师示范，再看着跟读。`,id,[id],[id],{scene,focus:[id]});
export const scenarioLessons=[
 {id:'N26-U006-L04',title:'你说，我来装',goal:'用 and / or 让对方装对水果',steps:[
  c('goal','水果柜台','你来决定，我来装','今天你来决定带什么水果，老师负责装袋。我们要说清楚：两样都要，还是任意一种都可以。','',[],[],{scene:fruit()}),
  c('and','看见意思','and：把两样连起来','这个连接词表示和。听到苹果和香蕉，老师就把两样都装进去。看清以后可以继续，也可以先跟读这个词。','and',['and','an apple and a banana'],[],{scene:fruit(),interaction:'optional-word',practiceAnswers:['and'],demoActions:{'an apple and a banana':{bag:['apple','banana'],caption:'and · 两样都装好'}},focus:['and']}),
  c('or','看见意思','or：这里任选一种','这个连接词表示或者。在这个柜台，苹果或者香蕉，任意一种都可以。这次老师选苹果。看清以后可以继续，也可以跟读这个词。','or',['or','an apple or a banana'],[],{scene:fruit({alternatives:true}),interaction:'optional-word',practiceAnswers:['or'],demoActions:{'an apple or a banana':{bag:['apple'],caption:'or · 这次选苹果，香蕉也可以'}},focus:['or']}),
  c('and-read','先成功一次','请把两样都装好','苹果和香蕉都要。请听完整句子，再跟着说。水果会装进袋子。',and,[and],[and],{scene:fruit(),focus:['and'],success:'packedBoth'}),
  c('or-read','只换一个决定','任意一种都可以','这次任选一种就可以。熟悉的句子只换中间这个词，听完以后告诉老师。',or,[or],[or],{scene:fruit({alternatives:true}),focus:['or'],success:'packedEither'}),
  c('my-order','轮到你作主','你今天想怎么选','现在由你作主。先选两样都要，或者任选一种，再看着提示告诉老师。你的选择会决定袋子里的水果。',and,[],[and,or],{scene:fruit(),interaction:'intent',success:'packedChoice',focus:['and','or']}),
  c('shopkeeper-both','交换角色','你来当店员','现在你当店员。听老师点单，点水果把它装进袋子，再交给老师。','',[and],[],{scene:fruit({role:'shopkeeper'}),interaction:'fruit-listen',task:{choice:'both'},success:'shopBoth'}),
  c('shopkeeper-either','交换角色','这次怎样装','再听一张新订单。你可以先选水果，放错了再点一次就能拿出来，最后交给老师。','',[or],[],{scene:fruit({role:'shopkeeper',alternatives:true}),interaction:'fruit-listen',task:{choice:'either'},success:'shopEither'}),
  c('closing','你的柜台成果','今天你让别人装对了','今天体验了表达需求和理解订单。练过和跳过的位置，会分别记录。','and：两样都要   or：这里任选一种',[],[],{scene:fruit({keepBag:true}),closing:true})
 ]},
 {id:'N26-U084-L01',title:'这次出游，听听你的意见',goal:'表达让步、反对意见和人员范围',steps:[
  c('goal','出游计划 · 三幕可分次完成','这份计划，你也有决定权','我们一起准备一次出游。先面对困难，再把话改顺，最后讨论意见和名单。每一幕都能单独完成，幕间可以休息。','',[],[],{scene:trip(1)}),
  word('although',1,'虽然',trip(1,{obstacle:true})),
  c('although-read','第一幕 · 有困难，还试吗','承认困难，仍愿意尝试','计划遇到困难，我们仍然愿意尝试。前半句承认困难，后半句说明想法。听完以后，看着句子告诉老师。',although,[although],[although],{scene:trip(1,{obstacle:true}),contrast:['Although this is difficult,','I can try.'],focus:['although'],success:'planTrying'}),
  word('however',1,'然而',trip(1,{obstacle:true,plan:'trying'})),
  c('however-read','第一幕 · 换一种组织方式','先说困难，再说转折','意思还是面对困难继续尝试。这次先把困难说完，再用下一句话表达转折。听完以后看着说。',however,[however],[however],{scene:trip(1,{obstacle:true,plan:'trying',bridge:'however'}),contrast:['This is difficult.','However, I can try.'],focus:['however'],success:'planConnected'}),
  c('though','第一幕 · 听懂另一种说法','though：这里也表示虽然','老师换一种说法，意思仍然是虽然有困难，也愿意尝试。你可以先跟读这个词，也可以听懂后继续。','though',['though',expressions[1]],[],{scene:trip(1,{plan:'trying',bridge:'though'}),interaction:'optional-word',practiceAnswers:['though'],focus:['though']}),
  c('nonetheless','第一幕 · 读一张正式说明','nonetheless：尽管如此','活动说明比较正式。这个词表示尽管如此，用来强调转折。可以选择单独跟读，也可以先理解意思。','nonetheless',['nonetheless',expressions[4]],[],{scene:trip(1,{plan:'trying',bridge:'nonetheless',document:true}),interaction:'optional-word',practiceAnswers:['nonetheless'],focus:['nonetheless']}),
  c('act-one','第一幕完成','已经能面对困难说想法','第一幕完成了。你已经用不同方式连接困难和想法。可以继续帮老师修改计划书，也可以在这里休息，下次接着来。','',[],[],{scene:trip(1,{plan:'trying'}),interaction:'checkpoint'}),
  word('despite',2,'尽管',trip(2,{plan:'trying'})),
  c('transform','第二幕 · 你来帮老师修改','换开头，后面也跟着换','老师想把开头换成尽管。这里我们学习后面接名词短语。请帮老师选择表示这个困难的那一块，放到开头后面。','Despite …, I can try.',[],[],{scene:trip(2,{plan:'trying',structure:'empty'}),interaction:'transform',contrast:['although this is difficult','despite the difficulty'],success:'structureFixed'}),
  c('despite-read','第二幕 · 把修改后的话说出来','把这一小段接回整句','开头已经换好了。看着修改后的计划书，把整句话说出来，后半句不用重新记。',despite,[],[despite],{scene:trip(2,{plan:'trying',structure:'noun',bridge:'despite'}),focus:['despite','difficulty'],success:'planRephrased'}),
  c('supported-use','第二幕 · 你来发表意见','选一种熟悉的说法','现在请你给计划留一句意见：有困难，但自己仍然愿意试试。可以选一种已经学过的完整提示，再告诉老师。',although,[],expressions,{scene:trip(2,{plan:'trying'}),alternatives:true,success:'opinionSaved'}),
  c('act-two','第二幕完成','计划书已经有你的意见','这一幕你完成了结构转换，也留下了自己的意见。接下来讨论反对的对象和出游名单，可以继续，也可以稍后再来。','',[],[],{scene:trip(2,{plan:'trying',opinion:true}),interaction:'checkpoint'}),
  word('against',3,'反对',trip(3,{plan:'trying',vote:'pending'})),
  c('against-read','第三幕 · 讨论对象','这次反对的是这项方案','讨论中，你暂时反对这项方案。这个短语把反对指向具体对象。先听，再看着告诉老师，方案会放到待修改的位置。','against the proposal',['against the proposal'],['against the proposal'],{scene:trip(3,{plan:'trying',vote:'pending'}),focus:['against'],success:'proposalHeld'}),
  c('friends','第三幕 · 看看同行的人','friends：多位朋友','名单里有几位朋友。先听清朋友的复数形式，注意结尾的声音。可以跟读，也可以听懂后继续。','friends',['friends'],[],{scene:trip(3,{plan:'trying',vote:'against'}),interaction:'optional-word',practiceAnswers:['friends']}),
  word('among',3,'在群体之中',trip(3,{plan:'trying',vote:'against'})),
  c('among-phrase','第三幕 · 你在这个群体里','在朋友之中','现在你也在朋友们这个群体里。先听这个短语，再看着说，画面会圈出你所在的群体。','among friends',['among friends'],['among friends'],{scene:trip(3,{plan:'trying',vote:'against',group:false}),focus:['among'],success:'groupShown'}),
  word('except',3,'除……之外',trip(3,{plan:'trying',vote:'against',group:true})),
  c('except-use','第三幕 · 把自己排除在外','这次你不能参加','其他朋友可以去，这次你不能参加。用这个短语告诉老师除我之外，老师会把你从参加名单里移出来。','except me',['except me'],['except me'],{scene:trip(3,{plan:'trying',vote:'against',group:true}),focus:['except'],success:'meExcluded'}),
  c('roster-check','第三幕 · 你来整理名单','听清以后，调整名单','这次你来整理名单。先听老师说，再点人物把该排除的人移出去。再次点击可以放回来，准备好后确认名单。','',['except me'],[],{scene:trip(3,{plan:'trying',vote:'against',group:true}),interaction:'roster',success:'rosterCorrect'}),
  c('closing','你的出游计划成果','回看自己的计划','这次体验了表达想法、修改句子结构，以及讨论意见和人员范围。练过、接受帮助和跳过的位置分别保留，下次再用小情境复习。','',[],[],{scene:{kind:'trip',act:3,keepState:true},closing:true})
 ]}
];
export const scenarioMessages={
 packedBoth:'两样都装好了，苹果和香蕉都在袋子里。',packedEither:'任选一种就可以。这次给你苹果，香蕉也可以。',
 shopBoth:'订单装对了，两样都有。你听懂了这个连接词。',shopEither:'订单装对了，任意一种就可以。',
 actionBoth:'刚才的订单两样都要。看看袋子，把缺的那一种也装进去，再交给老师。',
 actionEither:'刚才的订单任意一种就可以。袋子里留一种水果，再交给老师。',
 planTrying:'老师收到你的想法了。困难还在，我们保留继续尝试的计划。',planConnected:'两句话接起来了，困难和继续尝试的想法都表达清楚了。',
 structureFixed:'这块放对了。这里用表示这个困难的名词短语，再接后半句。',structureRetry:'你选的是完整小句。这里换成表示这个困难的名词短语，再试一次。',
 planRephrased:'计划书改顺了，开头换了，后面的结构也跟着换好了。',opinionSaved:'你的意见已经写进计划书了。',
 proposalHeld:'反对的是这项方案。老师把方案放到待修改的位置，不把它当作已经通过。',
 groupShown:'你在朋友们这个群体之中。看看画面里的圈。',meExcluded:'其他朋友仍在名单里，你已经移到名单外了。',
 rosterCorrect:'名单整理对了，其他朋友保留，只把自己排除在外。',rosterRetry:'老师说的是除我之外。保留其他朋友，只把你自己移出名单，再确认一次。',
 assisted:'这一处先借助提示完成，留到下次复习。现在带着完整提示，把刚才的意思说出来。'
};
