import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors } from '../theme';

/**
 * ナレーション音声の補助テロップ。音声が主、字幕は補助という位置づけ。
 *
 * 2レビュー統合対応(再修正): 画面下部固定だとUIと視線が上下に往復する
 * 「ピンポン現象」が起きるとの指摘を受け、スマホ画面の外(左側の余白)に
 * 完全に移動した。スマホは画面中央に大きく表示されるため、左側の余白
 * (x=90px、画面幅の左4.7%あたり)に縦中央揃えで配置すれば、UIとテロップが
 * 物理的に重ならず、視線の往復自体が発生しない。全シーン共通のルールとして統一。
 */
export const Caption: React.FC<{ text: string; appearAt?: number; holdFrames?: number }> = ({
  text,
  appearAt = 0,
  holdFrames,
}) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();
  const exitAt = (holdFrames ?? durationInFrames) - 12;

  const enter = spring({ frame: frame - appearAt, fps, config: { damping: 14, stiffness: 140, mass: 0.6 } });
  const exit = interpolate(frame, [exitAt, exitAt + 10], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const opacity = Math.min(enter, exit);
  const translateX = interpolate(enter, [0, 1], [-10, 0]);

  if (!text) return null;

  return (
    <div
      style={{
        position: 'absolute',
        left: 84,
        top: '50%',
        transform: `translateY(-50%) translateX(${translateX}px)`,
        maxWidth: 300,
        opacity,
      }}
    >
      <div style={{ width: 22, height: 3, background: colors.routeNeonBlue, opacity: 0.8, marginBottom: 12 }} />
      <div
        style={{
          color: colors.white,
          fontSize: 30,
          fontWeight: 800,
          textAlign: 'left',
          whiteSpace: 'pre-line',
          lineHeight: 1.35,
          textShadow: '0 2px 14px rgba(0,0,0,0.9), 0 0 6px rgba(0,0,0,0.7)',
        }}
      >
        {text}
      </div>
    </div>
  );
};
