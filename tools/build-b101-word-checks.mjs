import fs from 'node:fs';
const sample=JSON.parse(fs.readFileSync('data/curriculum/sample.json','utf8'));
// Two distinct retrieval contexts per taught sense; articles remain optional.
const spec={
hello:['刚见面时的招呼','离开时告别','欢迎新来的人','新同伴来到身边，请打个招呼。',['hello','hi']],
hi:['刚见面时的招呼','离开时告别','询问来源','你遇到一位新同伴，请打个招呼。',['hi','hello']],
goodbye:['离开时告别','欢迎新来的人','询问姓名','你要结束见面离开了，请告别。',['goodbye','bye']],
bye:['离开时告别','询问近况','欢迎新来的人','同伴要回家了，请回应告别。',['bye','goodbye']],
welcome:['欢迎新来的人','自己准备离开','询问来源','新朋友来到另一个房间，听接待者的声音。'],
good:['近况挺好','明显不舒服','询问来源','你现在感觉挺好。请回应How are you?',['good','fine','ok','okay',"i'm fine",'i am fine',"i'm good",'i am good',"i'm well",'i am well','well']],
nice:['很高兴初次见面','准备离开','询问国家','换一位新同伴，听首次见面时的短句。'],
fine:['近况不错','明显不舒服','询问姓名','换一位说话人，他回答了自己的近况。'],
well:['身体状况好','身体不舒服','在说姓名','另一位同伴说起身体状况，听他的回应。'],
ok:['近况还好','明显不舒服','询问姓名','你现在感觉还好。请简短回应How are you?',['ok','okay','good','fine',"i'm ok",'i am ok',"i'm fine",'i am fine']],
i:['当前说话者自己','正在听的人','旁边未参与的人','你的角色叫Li，请介绍自己。',["i'm li",'i am li','my name is li']],
you:['正在听话的对方','说话者自己','未参与的人','这次换你向同伴说话。听这段声音，you指谁？'],
me:['确认叫到自己','称呼对方','询问国家','同伴叫出你的角色名字，你听到这个简短确认。'],
my:['说话者的名字','听话者的名字','任意国家','你的角色叫Li，请说出自己的名字。',['my name is li',"i'm li",'i am li']],
your:['听话者的名字','说话者的名字','任意国家','交换说话人后，再听这两个词。现在名字属于谁？'],
a:['任意一个未指定的名字','已经圈定的那个名字','所有名字','换一组姓名卡。听短语，判断说话人怎样选择名字。'],
the:['已经圈定的那个名字','任意未指定的名字','所有名字','另一组姓名卡。听短语，判断说话人怎样选择名字。'],
be:['介绍姓名身份','询问国家','准备离开','你的角色改为Lin，请用完整短句介绍自己。',["i'm lin",'i am lin','my name is lin']],
name:['姓名栏','国家栏','近况栏','你的角色叫Lin，请用完整短句介绍自己的名字。',['my name is lin',"i'm lin",'i am lin']],
country:['国家栏','姓名栏','近况栏','换一张人物信息卡，再听声音，选择对应的信息栏。'],
from:['说自己来自哪里','询问姓名','正在告别','你的角色来自Japan。请说出来源。',["i'm from japan",'i am from japan']],
where:['询问来源','询问姓名','询问近况','另一个人向你提问。听声音，判断他想知道什么。'],
};
const result=[];
for(const w of sample.words){const key=w.word.toLowerCase(),s=spec[key];if(!s)throw Error(key);
 const common={course:w.course,kind:'word',word:key,optional:['a','the'].includes(key),target:'词汇巩固',hint:w.sense};
 result.push({...common,id:`W-${key}-a`,variant:'a',prompt:`听声音，选择在当前交流中的意思。${['my','your','i','you'].includes(key)?'以当前说话者为准。':''}`,audio:[w.audio],options:s.slice(0,3),answers:[s[0]],mode:'choice'});
 const productive=Array.isArray(s[4]);
 result.push({...common,id:`W-${key}-b`,variant:'b',prompt:s[3],audio:productive?[]:[w.audio],...(productive?{}:{options:[s[2],s[0],s[1]]}),answers:productive?s[4]:[s[0]],mode:productive?'oral':'choice',hint:productive?s[4][0]:w.sense});
}
fs.writeFileSync('data/curriculum/word-checks.json',JSON.stringify(result,null,2));console.log(`Prepared ${result.length} sense-specific retrieval tasks.`);
