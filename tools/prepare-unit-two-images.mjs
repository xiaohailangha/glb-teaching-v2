import fs from 'node:fs';
const dir = 'scene-preview/assets/avatar/images';
const write = (key, body) => fs.writeFileSync(`${dir}/${key}.svg`, `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 160">${body}</svg>\n`);
const apple = color => `<path d="M80 44C56 22 20 49 24 83c3 34 26 61 44 55 9-3 15-3 24 0 18 6 41-21 44-55 4-34-32-61-56-39z" fill="${color}"/><path d="M80 45l4-26" stroke="#73533d" stroke-width="7" stroke-linecap="round"/><path d="M86 30c3-20 26-20 28-20-1 15-11 25-28 20" fill="#638953"/><path d="M42 62c-8 11-6 24-3 31" stroke="white" stroke-opacity=".35" stroke-width="7" fill="none" stroke-linecap="round"/>`;
const banana = `<path d="M31 45c-9 40 14 79 55 84 29 4 51-12 56-40-31 25-77 6-82-35z" fill="#f4ce57" stroke="#c99f32" stroke-width="3"/><path d="M31 45l6-16 17 4 6 21" fill="#a58b46"/><path d="M42 64c4 35 42 58 75 43" fill="none" stroke="#ffe895" stroke-width="6" stroke-linecap="round"/>`;
const fruit = (kind, color = '#df665b') => kind === 'apple' ? apple(color) : banana;
const at = (body, x, y, scale) => `<g transform="translate(${x} ${y}) scale(${scale})">${body}</g>`;
const shadow = '<ellipse cx="80" cy="147" rx="62" ry="7" fill="#132d38" opacity=".16"/>';
for (const [name, color] of Object.entries({red: '#df665b', green: '#8ec77a', yellow: '#f4ce57', blue: '#6dafe4'})) {
  write('color_' + name, `<rect x="22" y="22" width="116" height="116" rx="30" fill="${color}"/><path d="M44 45h27" stroke="white" stroke-opacity=".35" stroke-width="7" stroke-linecap="round"/>`);
}
for (const [key, kind, color] of [['red_apple', 'apple', '#df665b'], ['green_apple', 'apple', '#8ec77a'], ['yellow_banana', 'banana', '']]) write(key, shadow + fruit(kind, color));
for (const kind of ['apple', 'banana']) {
  write('big_' + kind, shadow + fruit(kind));
  write('small_' + kind, shadow + at(fruit(kind), 40, 69, .5));
}
// Comparative word cards keep the same baseline and contain no English hint.
for (const size of ['big', 'small']) {
  write('size_' + size, shadow + at(apple(size === 'big' ? '#df665b' : '#687278'), 0, 15, .85) + at(apple(size === 'small' ? '#df665b' : '#687278'), 94, 87, .4));
}
write('small_red_apple', shadow + at(apple('#df665b'), 40, 69, .5));
const layouts = {
  1: [[36, 30, .55]], 2: [[1, 30, .5], [79, 30, .5]],
  3: [[2, 2, .45], [87, 2, .45], [45, 77, .45]],
  4: [[2, 2, .45], [87, 2, .45], [2, 77, .45], [87, 77, .45]],
  5: [[0, 0, .36], [51, 0, .36], [102, 0, .36], [25, 80, .36], [77, 80, .36]],
};
for (const [i, n] of ['one', 'two', 'three', 'four', 'five'].entries()) {
  const count = i + 1;
  write('count_' + n, layouts[count].map(([x, y, s]) => `<circle cx="${x + 80 * s}" cy="${y + 80 * s}" r="${37 * s}" fill="#bde5dd"/>`).join(''));
  for (const kind of [i % 2 === 0 ? 'apple' : 'banana']) {
    const plural = count === 1 ? kind : kind + 's';
    write(n + '_' + plural, layouts[count].map(([x, y, s]) => at(fruit(kind), x, y, s)).join(''));
  }
}
write('two_apples', layouts[2].map(([x, y, s]) => at(apple('#df665b'), x, y, s)).join(''));
write('two_green_apples', layouts[2].map(([x, y, s]) => at(apple('#8ec77a'), x, y, s)).join(''));
// Exactly three fruit; no faint comparison fruit that could be counted as six.
write('three_big_bananas', layouts[3].map(([x, y, s]) => at(banana, x, y, s)).join(''));
