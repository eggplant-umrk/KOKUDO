/**
 * VOICEVOX ENGINE(Docker: localhost:50021)を使ってナレーション音声を生成する。
 * docs/pitch/02_demo-video-script.md の「ナレーション全文」をそのまま読み上げる。
 * 話者: 玄野武宏(ノーマル, speaker=11) — ユーザー指定により変更。
 * 実行: node scripts/generate-voice.js
 */
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ENGINE = 'http://localhost:50021';
const SPEAKER = 11; // 玄野武宏 ノーマル
const OUT_DIR = path.join(__dirname, '..', 'public', 'audio');
// BGM/SE(sfx_*.wav)は44100Hzで生成されているため、ミックスダウン時のサンプルレート
// 不一致によるアーティファクトを避けるためナレーションもこれに統一する。
const TARGET_SAMPLE_RATE = 44100;

/** VOICEVOXの出力(24000Hz)をffmpegで44100Hzにリサンプリングしてから保存する。 */
function writeResampled(outPath, buf) {
  const tmpPath = `${outPath}.tmp.wav`;
  fs.writeFileSync(tmpPath, buf);
  execFileSync('ffmpeg', ['-y', '-i', tmpPath, '-ar', String(TARGET_SAMPLE_RATE), '-acodec', 'pcm_s16le', outPath], {
    stdio: 'ignore',
  });
  fs.unlinkSync(tmpPath);
}

const LINES = [
  { id: 's2', text: '見えないと、続かない。' },
  { id: 's3', text: '距離を、地図に変えよう。' },
  { id: 's4_1', text: '国道を選んで登録すれば、あとはいつも通り走るだけ。' },
  { id: 's4_2', text: '今どこまで来たか、いつでも一目で分かります。' },
  // 2レビュー統合対応(項目2): 「GPSが記録する」という一般的な言い回しから、
  // KOKUDO独自の価値表現「走った距離が、そのまま国道になる」に変更。
  { id: 's5_1', text: '走った距離が、' },
  { id: 's5_2', text: 'そのまま、国道になる。' },
  { id: 's6_1', text: '日本地図の上に、自分だけの走行の軌跡が刻まれていく。' },
  { id: 's6_2', text: '挑戦中はブルー、完走したらゴールドに変わります。' },
  { id: 's7_1', text: '目標の日までに、あと何キロ必要か。' },
  { id: 's7_2', text: '逆算ナビがいつも並走してくれます。' },
];

function wavDurationSeconds(buf) {
  // 簡易WAVヘッダ解析: dataチャンクのサイズとフォーマットから秒数を算出
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
      const dataSize = chunkSize;
      if (byteRate) return dataSize / byteRate;
      return dataSize / (sampleRate * 2);
    }
    offset += 8 + chunkSize + (chunkSize % 2);
  }
  return 0;
}

async function synthesize({ id, text }) {
  const queryRes = await fetch(
    `${ENGINE}/audio_query?text=${encodeURIComponent(text)}&speaker=${SPEAKER}`,
    { method: 'POST' },
  );
  if (!queryRes.ok) throw new Error(`audio_query failed for ${id}: ${queryRes.status} ${await queryRes.text()}`);
  const query = await queryRes.json();

  const synthRes = await fetch(`${ENGINE}/synthesis?speaker=${SPEAKER}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(query),
  });
  if (!synthRes.ok) throw new Error(`synthesis failed for ${id}: ${synthRes.status} ${await synthRes.text()}`);
  const buf = Buffer.from(await synthRes.arrayBuffer());
  const outPath = path.join(OUT_DIR, `${id}.wav`);
  writeResampled(outPath, buf);
  const dur = wavDurationSeconds(fs.readFileSync(outPath));
  return { id, text, durationSec: dur, bytes: fs.statSync(outPath).size };
}

(async () => {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const filterIds = process.argv.slice(2);
  const targets = filterIds.length ? LINES.filter((l) => filterIds.includes(l.id)) : LINES;
  const results = [];
  for (const line of targets) {
    const r = await synthesize(line);
    console.log(`${r.id}: ${r.durationSec.toFixed(2)}s  "${r.text}"`);
    results.push(r);
  }
  const durationsPath = path.join(OUT_DIR, 'durations.json');
  let merged = results;
  if (filterIds.length && fs.existsSync(durationsPath)) {
    const prev = JSON.parse(fs.readFileSync(durationsPath, 'utf8'));
    const byId = new Map(prev.map((r) => [r.id, r]));
    for (const r of results) byId.set(r.id, r);
    merged = Array.from(byId.values());
  }
  fs.writeFileSync(durationsPath, JSON.stringify(merged, null, 2));
  console.log('OK: all narration audio generated.');
})().catch((err) => {
  console.error('FAILED:', err);
  process.exit(1);
});
