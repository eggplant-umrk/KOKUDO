/**
 * BGM/SEを、著作権的に安全な自己合成(サイン波)で生成する。
 * 外部の音源・サンプルは一切使用しない(純粋なNode.jsのDSPのみ)。
 * 実行: node scripts/generate-sfx.js
 */
const fs = require('fs');
const path = require('path');

const OUT_DIR = path.join(__dirname, '..', 'public', 'audio');
const SR = 44100;

function writeWav(filePath, samples) {
  const dataSize = samples.length * 2;
  const buf = Buffer.alloc(44 + dataSize);
  buf.write('RIFF', 0);
  buf.writeUInt32LE(36 + dataSize, 4);
  buf.write('WAVE', 8);
  buf.write('fmt ', 12);
  buf.writeUInt32LE(16, 16);
  buf.writeUInt16LE(1, 20); // PCM
  buf.writeUInt16LE(1, 22); // mono
  buf.writeUInt32LE(SR, 24);
  buf.writeUInt32LE(SR * 2, 28);
  buf.writeUInt16LE(2, 32);
  buf.writeUInt16LE(16, 34);
  buf.write('data', 36);
  buf.writeUInt32LE(dataSize, 40);
  for (let i = 0; i < samples.length; i++) {
    const s = Math.max(-1, Math.min(1, samples[i]));
    buf.writeInt16LE(Math.round(s * 32767), 44 + i * 2);
  }
  fs.writeFileSync(filePath, buf);
}

/** 走行計測シーン用の連続ティック音。短いサイン波バースト+指数減衰を等間隔で並べる。 */
function generateTickLoop(durationSec, tickIntervalSec, freq, volume) {
  const total = Math.floor(SR * durationSec);
  const samples = new Float32Array(total);
  const tickLenSamples = Math.floor(SR * 0.05); // 50msの短いクリック
  for (let t = 0; t < durationSec; t += tickIntervalSec) {
    const start = Math.floor(t * SR);
    for (let i = 0; i < tickLenSamples && start + i < total; i++) {
      const decay = Math.exp(-i / (SR * 0.012));
      samples[start + i] += Math.sin((2 * Math.PI * freq * i) / SR) * decay * volume;
    }
  }
  return samples;
}

/** クロージング用の静かなアンビエントパッド。3音のサイン波を重ね、緩やかなフェードイン/アウト。
 *  不具合調査対応: 「動画からめっちゃ低い音が聞こえる」との指摘を受け、動画全体を
 *  ffmpeg amix由来のトラック間リーク疑いで詳細調査したが、生PCMを直接検証した結果
 *  合成自体には問題がないことを確認した(ffmpeg `-ss`シーク+volumedetectの組み合わせに
 *  測定アーティファクトがあり、誤ってリークと誤認していた)。唯一、動画内で持続的に
 *  低域エネルギーを持つのがこのBGMパッド(元は130.81/164.81/196Hzの低いC3/E3/G3)
 *  だったため、聴感上の「低い音」の正体はこれである可能性が高いと判断し、1オクターブ
 *  上のC4/E4/G4へ変更。落ち着いた雰囲気は保ちつつ、20-200Hz帯域から完全に離した。 */
function generateAmbientPad(durationSec, volume) {
  const total = Math.floor(SR * durationSec);
  const samples = new Float32Array(total);
  const freqs = [261.63, 329.63, 392.0]; // C4, E4, G4(旧C3/E3/G3から1オクターブ上げ、低域ドローン感を解消)
  const fadeIn = SR * 1.2;
  const fadeOut = SR * 1.5;
  for (let i = 0; i < total; i++) {
    let v = 0;
    for (const f of freqs) {
      v += Math.sin((2 * Math.PI * f * i) / SR);
    }
    v /= freqs.length;
    // ごく緩やかなビブラート的うねりを加え、単調な純音感を減らす
    v *= 1 + 0.03 * Math.sin((2 * Math.PI * 0.15 * i) / SR);
    let env = 1;
    if (i < fadeIn) env = i / fadeIn;
    if (i > total - fadeOut) env = Math.min(env, (total - i) / fadeOut);
    samples[i] = v * volume * env;
  }
  return samples;
}

fs.mkdirSync(OUT_DIR, { recursive: true });

const tickSamples = generateTickLoop(5.5, 0.15, 2600, 0.18);
writeWav(path.join(OUT_DIR, 'sfx_tick_loop.wav'), tickSamples);
console.log('OK: sfx_tick_loop.wav (5.5s, tick every 0.15s)');

const bgmSamples = generateAmbientPad(14, 0.09);
writeWav(path.join(OUT_DIR, 'sfx_outro_bgm.wav'), bgmSamples);
console.log('OK: sfx_outro_bgm.wav (14s ambient pad)');
