import React from 'react';
import { staticFile, useCurrentFrame, useVideoConfig } from 'remotion';

/**
 * 修正対応: character-run.webpと同一の問題がroad-bg.webpにも存在していた。
 * road-bg.webp はネイティブ15fps(66.7ms間隔)、142フレームのループアニメーション
 * (ffprobeで実測)で、Remotionコンポジションの30fpsと不一致。ブラウザの
 * アニメーションデコーダは実時間(システムクロック)基準で駒送りするため、
 * Remotionのフレーム単位・非リアルタイムなキャプチャとは同期せず「かくつき」の
 * 原因になっていた(CharacterRunSprite.tsxと同じ根本原因、詳細はそちらのコメント参照)。
 *
 * road-bg.webp を142枚のPNG連番(frame-001.png〜frame-142.png、
 * public/assets/road-bg-frames/、ffmpegで抽出、アルファチャンネル保持)に分解し、
 * useCurrentFrame() から決定的にフレーム番号を計算して明示的に切り替える。
 */
const BG_FRAME_COUNT = 142;
const BG_FPS = 15; // road-bg.webp のネイティブフレームレート(ffprobe実測)

export const RoadBackgroundSprite: React.FC<{ style?: React.CSSProperties }> = ({ style }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const bgFrameIndex = Math.floor((frame / fps) * BG_FPS) % BG_FRAME_COUNT;
  const frameNumber = String(bgFrameIndex + 1).padStart(3, '0');
  return (
    <img src={staticFile(`assets/road-bg-frames/frame-${frameNumber}.png`)} style={style} alt="road-bg" />
  );
};
