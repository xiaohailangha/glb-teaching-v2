import json, re, hashlib
from pathlib import Path

base = Path('work/curriculum')
dictionary = {}
for line in (base/'reference/cmudict.dict').read_text(encoding='utf-8').splitlines():
    word, *phones = line.split()
    if '(' not in word:
        dictionary[word] = phones
# The course teaches these verbs, not their homographic nouns/adjectives.
dictionary.update(read=['R','IY1','D'], close=['K','L','OW1','Z'], excuse=['IH0','K','S','K','Y','UW1','Z'])
symbols = dict(AA='ɑː', AE='æ', AH='ʌ', AO='ɔː', AW='aʊ', AY='aɪ', B='b', CH='tʃ', D='d', DH='ð', EH='ɛ', ER='ɜːr', EY='eɪ', F='f', G='ɡ', HH='h', IH='ɪ', IY='iː', JH='dʒ', K='k', L='l', M='m', N='n', NG='ŋ', OW='oʊ', OY='ɔɪ', P='p', R='r', S='s', SH='ʃ', T='t', TH='θ', UH='ʊ', UW='uː', V='v', W='w', Y='j', Z='z', ZH='ʒ')
onsets = set('MJ PJ KJ P B T D K G F V TH DH S Z SH ZH CH JH M N L R W Y HH PR PL BR BL TR DR KR KL GR GL FR FL THR SHR SK SL SM SN SP ST SW TW KW SKW SPR STR SKR SPL'.split())
def ipa(phones):
    vowels = [i for i,p in enumerate(phones) if p[-1].isdigit()]
    stress = {}
    for n,i in enumerate(vowels):
        if len(vowels)==1 or phones[i][-1]=='0': continue
        previous = vowels[n-1]+1 if n else 0
        onset = 0 if n==0 else i
        for j in range(previous,i) if n else []:
            if ''.join(phones[j:i]) in onsets:
                onset = j
                break
        stress[onset] = 'ˈ' if phones[i][-1]=='1' else 'ˌ'
    result = ''
    for i,p in enumerate(phones):
        result += stress.get(i,'')
        result += 'ə' if p=='AH0' else 'ər' if p=='ER0' else symbols[re.sub(r'\d','',p)]
    return '/'+result+'/'

words = {}
plan = json.loads(Path('data/curriculum/plan.json').read_text(encoding='utf-8'))
for category in plan['categories']:
 for course in json.loads(Path('data/curriculum',category['id']+'.json').read_text(encoding='utf-8')):
  for item in course['vocabulary']:
   words.setdefault(item['text'].lower(),item['meaning'])
for item in json.loads(Path('data/curriculum/supporting-vocabulary.json').read_text(encoding='utf-8')):
    words[item['text'].lower()] = item['meaning']
legacy = json.loads(Path('data/course-catalog.json').read_text(encoding='utf-8'))['lexicon']
entries = {v['word']:v for v in legacy if not v.get('clip','').startswith('c96_')}
for word,meaning in words.items():
    if word in entries: continue
    clip = 'c96_'+hashlib.sha256(('en:'+word).encode()).hexdigest()[:20]
    # Capitalized proper nouns share their authored prompt, not a missing lowercase file.
    prompts = json.loads((base/'prompts.json').read_text(encoding='utf-8'))
    matches = [k for k,v in prompts.items() if v['language']=='en' and v['text'].lower()==word]
    if not matches: raise ValueError('No word prompt: '+word)
    entries[word] = dict(word=word,clip=matches[0],ipa=ipa(dictionary[word]),meaning=meaning,
                        pronunciationSource='CMUdict; General American; reviewed course sense',arpabet=dictionary[word])
# Common teaching forms reviewed against the intended American course sense.
reviewed = {
 'monday':'ˈmʌndeɪ','friday':'ˈfraɪdeɪ','sunday':'ˈsʌndeɪ','saturday':'ˈsætərdeɪ','tuesday':'ˈtuːzdeɪ',
 'usually':'ˈjuːʒuəli','sometimes':'ˈsʌmtaɪmz','always':'ˈɔːlweɪz','tomorrow':'təˈmɑːroʊ','tomato':'təˈmeɪtoʊ',
 'engineer':'ˌɛndʒɪˈnɪr','email':'ˈiːmeɪl','excuse':'ɪkˈskjuːz','music':'ˈmjuːzɪk','computer':'kəmˈpjuːtər',
 'bedroom':'ˈbɛdruːm','bathroom':'ˈbæθruːm','borrow':'ˈbɑːroʊ','hospital':'ˈhɑːspɪtəl',
 'dishes':'ˈdɪʃɪz','glasses':'ˈɡlæsɪz','jacket':'ˈdʒækɪt','tennis':'ˈtɛnɪs','practice':'ˈpræktɪs','ticket':'ˈtɪkɪt',
}
for word,form in reviewed.items():
 entries[word]['ipa']='/'+form+'/'
 entries[word]['pronunciationSource']='CMUdict with reviewed common American teaching form'
for entry in entries.values():
    if 'clip' not in entry:
        entry['clip'] = Path(entry['audio']['url']).stem
Path('data/curriculum/lexicon.json').write_text(json.dumps(list(entries.values()),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Lexicon entries:',len(entries))
print(' / '.join(k+' '+v['ipa'] for k,v in entries.items()))
