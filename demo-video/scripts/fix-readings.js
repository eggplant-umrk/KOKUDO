/**
 * 誤読修正専用スクリプト。VOICEVOXのaudio_queryが返すaccent_phrases(モーラ単位の
 * 発音情報)を、該当箇所だけ正しい読みの参照クエリから差し替えてsynthesisする。
 * - s4_1: 「いつも通り」の「通り」が「とおり」と読まれていたのを「どおり」(連濁)に修正
 * - s4_2: 「一目で」の「一目」が「いちもく」と読まれていたのを「ひとめ」に修正
 * 実行: node scripts/fix-readings.js
 */
const fs = require('fs');
const path = require('path');

const ENGINE = 'http://localhost:50021';
const SPEAKER = 11;
const OUT_DIR = path.join(__dirname, '..', 'public', 'audio');

async function audioQuery(text) {
  const res = await fetch(`${ENGINE}/audio_query?text=${encodeURIComponent(text)}&speaker=${SPEAKER}`, { method: 'POST' });
  if (!res.ok) throw new Error(`audio_query failed: ${res.status} ${await res.text()}`);
  return res.json();
}

function moraText(phrase) {
  return phrase.moras.map((m) => m.text).join('');
}

function wavDurationSeconds(buf) {
  let offset = 12;
  let sampleRate = 24000;
  let byteRate = null;
  while (offset < buf.length) {
    const chunkId = buf.toString('ascii', offset, offset + 4);
    const chunkSize = buf.readUInt32LE(offset + 4);
    if (chunkId === 'fmt ') {
      sampleRate = buf.readUInt32LE(offset + 12);
      byteRate = buf.readUInt32LE(offset + 16);
    } else if (chunkId === 'data') {
      if (byteRate) return chunkSize / byteRate;
      return chunkSize / (sampleRate * 2);
    }
    offset += 8 + chunkSize + (chunkSize % 2);
  }
  return 0;
}

async function synthesizeFixed(id, text, targetMoraText, replacementText) {
  const query = await audioQuery(text);
  const refQuery = await audioQuery(replacementText);
  // 参照クエリの最後のaccent_phraseが、置き換えたい語(+助詞)に対応する
  const refPhrase = refQuery.accent_phrases[refQuery.accent_phrases.length - 1];

  const idx = query.accent_phrases.findIndex((p) => moraText(p) === targetMoraText);
  if (idx === -1) {
    throw new Error(`Could not find accent_phrase with moras "${targetMoraText}" in "${text}"`);
  }
  const before = moraText(query.accent_phrases[idx]);
  query.accent_phrases[idx] = {
    ...refPhrase,
    pause_mora: query.accent_phrases[idx].pause_mora,
    is_interrogative: query.accent_phrases[idx].is_interrogative,
  };
  console.log(`${id}: replaced accent_phrase[${idx}] "${before}" -> "${moraText(query.accent_phrases[idx])}"`);

  const synthRes = await fetch(`${ENGINE}/synthesis?speaker=${SPEAKER}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(query),
  });
  if (!synthRes.ok) throw new Error(`synthesis failed for ${id}: ${synthRes.status} ${await synthRes.text()}`);
  const buf = Buffer.from(await synthRes.arrayBuffer());
  fs.writeFileSync(path.join(OUT_DIR, `${id}.wav`), buf);
  const dur = wavDurationSeconds(buf);
  console.log(`${id}: ${dur.toFixed(2)}s  "${text}"`);
  return { id, text, durationSec: dur, bytes: buf.length };
}

(async () => {
  const results = [];
  // s4_1: 「いつも通り」の「とおり」(accent_phrase "トオリ") を「どおり」に差し替え
  results.push(
    await synthesizeFixed(
      's4_1',
      '国道を選んで登録すれば、あとはいつも通り走るだけ。',
      'トオリ',
      'いつもどおり',
    ),
  );
  // s4_2: 「一目で」の「いちもくで」(accent_phrase "イチモクデ") を「ひとめで」に差し替え
  results.push(
    await synthesizeFixed(
      's4_2',
      '今どこまで来たか、いつでも一目で分かります。',
      'イチモクデ',
      'ひとめで',
    ),
  );

  const durationsPath = path.join(OUT_DIR, 'durations.json');
  const prev = JSON.parse(fs.readFileSync(durationsPath, 'utf8'));
  const byId = new Map(prev.map((r) => [r.id, r]));
  for (const r of results) byId.set(r.id, r);
  fs.writeFileSync(durationsPath, JSON.stringify(Array.from(byId.values()), null, 2));
  console.log('OK: readings fixed and re-synthesized.');
})().catch((err) => {
  console.error('FAILED:', err);
  process.exit(1);
});
