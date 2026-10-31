import fs from 'node:fs';
import path from 'node:path';
import {teachingAudio, cacheDir} from '../services/tencent-speech.mjs';

// Original adult unit 2: vocabulary -> noun phrase -> complete request -> recall.
const dir = 'scene-preview/assets/avatar';
const prompts = {};
const clip = (id, text) => (prompts[id] = text, id);
const actions = [{id: 'next', label: '继续'}, {id: 'help', label: '再听示范'}];
const segment = (label, clip) => ({label, clip});
function course(id, title, opening) {
  return {id, title, stages: [{id: 'intro', phase: 'introduce', chapter: title,
    display: title, text: opening, clip: clip(id.replace('-v1', '') + '_intro', opening)}]};
}
function practice(c, id, text, meaning, sound, picture = '', segments = []) {
  const row = {chapter: c.title, word: 'apple', display: text, text: meaning, picture};
  c.stages.push({...row, id: id + '_model', phase: 'demonstrate', clip: sound});
  c.stages.push({...row, id, phase: 'listen', practiceClip: sound, speechText: text, segments, options: actions});
}
function recall(c, id, text, meaning, sound, picture, segments = []) {
  c.stages.push({id: 'recall_' + id, phase: 'recall', chapter: c.title, word: 'apple',
    display: text, text: meaning, picture, hide: true, practiceClip: sound,
    speechText: text, segments, options: actions});
}
function finish(c) {
  c.stages.push({id: 'summary', phase: 'finish', chapter: '本节小结',
    display: '本节学习记录', text: '本节课我们就学到这里。', options: []});
}
const phraseClip = (key, text) => clip('u2_' + key, text);
function request(c, key, phrase, meaning, picture, {polite = false} = {}) {
  const p = phraseClip(key, phrase);
  practice(c, key, phrase, meaning, p, picture);
  const text = 'I want ' + phrase + (polite ? ', please.' : '.');
  const s = phraseClip('want_' + key, text);
  const parts = [segment('I want', 'chunk_want'), segment(phrase, p)];
  if (polite) parts.push(segment('please', 'unit_please'));
  practice(c, 'want_' + key, text, '我想要' + meaning.replace(/。.*$/, '') + (polite ? '，谢谢。' : '。'), s, picture, parts);
  return {text, sound: s, parts};
}

const colors = course('adult-colors-v1', '05 · 颜色', '这节课学颜色。先读单词，再读短语，最后说出完整句子。');
for (const [en, zh] of [['red', '红色'], ['green', '绿色'], ['yellow', '黄色'], ['blue', '蓝色']]) {
  practice(colors, 'word_' + en, en, zh, en === 'red' ? 'part_red' : phraseClip(en, en), 'color_' + en);
}
let red, green;
for (const [key, phrase, zh, picture] of [
  ['red_apple', 'a red apple', '一个红苹果。颜色放在水果前，前面用一个的说法。', 'red_apple'],
  ['green_apple', 'a green apple', '一个青苹果。先说颜色，再说苹果。', 'green_apple'],
  ['yellow_banana', 'a yellow banana', '一根黄香蕉。先说颜色，再说香蕉。', 'yellow_banana'],
]) {
  const r = request(colors, key, phrase, zh, picture);
  if (key === 'red_apple') red = r;
  if (key === 'green_apple') green = r;
}
recall(colors, 'green', green.text, '看青苹果，不看英文，试着说：我想要一个青苹果。', green.sound, 'green_apple', green.parts);
recall(colors, 'red', red.text, '换成红苹果，试着完整说出你的需求。', red.sound, 'red_apple', red.parts);
finish(colors);

const sizes = course('adult-sizes-v1', '06 · 大小', '这节课学大和小。先读单词，再读短语和句子。');
for (const [en, zh] of [['big', '大的；看图中较大的苹果'], ['small', '小的；看图中较小的苹果']]) {
  practice(sizes, 'word_' + en, en, zh, phraseClip(en, en), 'size_' + en);
}
let small, big;
for (const [key, phrase, zh, picture] of [
  ['big_apple', 'a big apple', '一个大苹果。大小也放在水果前。', 'big_apple'],
  ['small_apple', 'a small apple', '一个小苹果。', 'small_apple'],
  ['big_banana', 'a big banana', '一根大香蕉。', 'big_banana'],
  ['small_banana', 'a small banana', '一根小香蕉。', 'small_banana'],
  ['small_red_apple', 'a small red apple', '一个小红苹果。一起描述时，先说大小，再说颜色。', 'small_red_apple'],
]) {
  const r = request(sizes, key, phrase, zh, picture);
  if (key === 'small_apple') small = r;
  if (key === 'big_banana') big = r;
}
recall(sizes, 'small', small.text, '看小苹果，试着说：我想要一个小苹果。', small.sound, 'small_apple', small.parts);
recall(sizes, 'big', big.text, '换成大香蕉，试着完整表达需求。', big.sound, 'big_banana', big.parts);
finish(sizes);

const numbers = course('adult-numbers-v1', '07 · 数量', '这节课学一到五。先读数字，再练一个和多个，最后说出需求。');
const numerals = ['one', 'two', 'three', 'four', 'five'];
const zhNumbers = ['一', '两', '三', '四', '五'];
for (const [i, en] of numerals.entries()) {
  practice(numbers, 'word_' + en, en, ['一', '二', '三', '四', '五'][i], phraseClip(en, en), 'count_' + en);
}
practice(numbers, 'apples', 'apples', '多个苹果。结尾的复数音是 /z/，不要额外加一个音节。', phraseClip('apples', 'apples'), 'two_apples');
practice(numbers, 'bananas', 'bananas', '多根香蕉。结尾也读 /z/，和单数作对比。', phraseClip('bananas', 'bananas'), 'two_bananas');
let two, five;
for (let i = 0; i < numerals.length; i++) {
  const n = numerals[i], fruit = i % 2 === 0 ? 'apple' : 'banana';
  const plural = i === 0 ? fruit : fruit + 's';
  const phrase = n + ' ' + plural;
  const meaning = zhNumbers[i] + (fruit === 'apple' ? '个苹果' : '根香蕉') +
    (i === 0 ? '。说具体数量一，后面仍用单数。' : '。两个及以上用复数，不再加一个的说法。');
  const key = n + '_' + plural;
  const r = request(numbers, key, phrase, meaning, key);
  if (n === 'two') two = r;
  if (n === 'five') five = r;
}
// Explicit one/two contrast with the same noun; not just alternating fruit.
const twoApples = request(numbers, 'two_apples', 'two apples', '两个苹果。和一个苹果作对比，听清结尾的复数音。', 'two_apples');
recall(numbers, 'two', twoApples.text, '看图数一数：我想要两个苹果。试着自己说。', twoApples.sound, 'two_apples', twoApples.parts);
recall(numbers, 'bananas', two.text, '看两根香蕉，试着完整说出数量和需求。', two.sound, 'two_bananas', two.parts);
recall(numbers, 'five', five.text, '看五个苹果，不看英文，试着表达需求。', five.sound, 'five_apples', five.parts);
finish(numbers);

const review = course('adult-describe-review-v1', '08 · 按要求拿东西', '这节课复习颜色、大小和数量。先跟读，再看图自己说。');
const tasks = [
  ['review_small_red', 'a small red apple', '一个小红苹果。先说大小，再说颜色。', 'small_red_apple'],
  ['review_two_green', 'two green apples', '两个青苹果。数量在前，苹果用复数。', 'two_green_apples'],
  ['review_three_big', 'three big bananas', '三根大香蕉。先说数量，再说大小。', 'three_big_bananas'],
];
const learned = [];
for (const [key, phrase, zh, picture] of tasks) learned.push([picture, request(review, key, phrase, zh, picture, {polite: true})]);
practice(review, 'thanks', 'Thank you.', '拿到水果后，自然地说声谢谢。', 'unit_thank_you');
for (const [picture, r] of learned) recall(review, picture, r.text, {
  small_red_apple: '你想要一个小红苹果。看图，把完整需求礼貌地说出来。',
  two_green_apples: '换成两个青苹果。看清颜色和数量，试着礼貌地说出来。',
  three_big_bananas: '这次是三根大香蕉。看清大小和数量，完整表达需求。',
}[picture], r.sound, picture, r.parts);
recall(review, 'thanks', 'Thank you.', '拿到水果后，自己说声谢谢。', 'unit_thank_you', '');
finish(review);

for (const c of [colors, sizes, numbers, review]) {
  const filename = c.id.replace('-v1', '');
  fs.writeFileSync(`${dir}/courses/${filename}.json`, JSON.stringify(c, null, 2) + '\n');
}
if (process.argv.includes('--course-only')) process.exit(0);
const file = `${dir}/audio/unit-two-prompts.json`;
const manifest = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file)) : {};
for (const [key, text] of Object.entries(prompts)) {
  if (manifest[key]?.text === text && fs.existsSync(`${dir}/audio/${key}.wav`)) continue;
  const source = await teachingAudio(text, {voice: 403008, language: /[\u3400-\u9fff]/.test(text) ? 'zh' : 'en'});
  const alignment = JSON.parse(fs.readFileSync(path.join(cacheDir, source.key + '.alignment.json')));
  const expected = text.toLowerCase().match(/[a-z]+(?:'[a-z]+)?/g) || [];
  const words = alignment.Words || [];
  if (expected.length && (words.length !== expected.length || words.some((w, i) => w.Word.toLowerCase() !== expected[i]))) throw Error('Word alignment mismatch: ' + key);
  fs.copyFileSync(path.join(cacheDir, source.key + '.wav'), `${dir}/audio/${key}.wav`);
  manifest[key] = {text, voice: 403008, bundled: true, duration: source.duration, cues: source.cues, sourceKey: source.key,
    wordTimings: expected.length ? words.map(w => ({word: w.Word.toLowerCase(), start: w.MemBeginTime / 1000, end: w.MemEndTime / 1000})) : []};
  fs.writeFileSync(file, JSON.stringify(manifest, null, 2) + '\n');
  console.log('Prepared ' + key);
}
