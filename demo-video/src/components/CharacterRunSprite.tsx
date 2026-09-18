import React from 'react';
import { staticFile, useCurrentFrame, useVideoConfig } from 'remotion';

/**
 * 修正2対応: character-run.webp(ネイティブ25/3fps≒8.33fps、21フレームループ、
 * ffprobeで確認)を <img> でそのまま再生すると、ブラウザのアニメーションデコーダは
 * システム時計(実時間)基準で駒送りするため、Remotionのフレーム単位・非リアルタイムな
 * キャプチャ(各コンポジションフレームを個別にシークして静止画としてレンダリングする
 * 仕組み)と同期しない。レンダリング処理速度によって実際に経過する壁時計時間が
 * フレームごとに変動するため、GIF内部の再生位置とコンポジションのフレーム番号が
 * 一致せず、同じフレームが連続キャプチャされたり飛んだりして「かくつき」が発生する。
 *
 * 対策として character-run.webp を21枚のPNG連番(frame-01.png〜frame-21.png、
 * public/assets/character-run-frames/、ffmpegで抽出、アルファチャンネル保持)に分解し、
 * useCurrentFrame() から決定的にGIFフレーム番号を計算して明示的に切り替える。
 * これによりレンダリングが何秒かかっても、同じコンポジションフレーム番号は常に
 * 同じGIFフレームを指す(決定的レンダリング)。
 */
const GIF_FRAME_COUNT = 21;
const GIF_FPS = 25 / 3; // character-run.webp のネイティブフレームレート(ffprobe実測)

export const CharacterRunSprite: React.FC<{ style?: React.CSSProperties }> = ({ style }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const gifFrameIndex = Math.floor((frame / fps) * GIF_FPS) % GIF_FRAME_COUNT;
  const frameNumber = String(gifFrameIndex + 1).padStart(2, '0');
  return (
    <img src={staticFile(`assets/character-run-frames/frame-${frameNumber}.png`)} style={style} alt="character-run" />
  );
};
