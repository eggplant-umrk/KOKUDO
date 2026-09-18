import React from 'react';
import { useCurrentFrame } from 'remotion';
import { colors } from '../theme';

/**
 * レビュー対応: Scene1→2→3のハードカットで背景色が完全に切り替わり、
 * 場面をつなぐ視覚的な要素が無かったため、Scene1で使う六角形モチーフを
 * 薄い透かしとして各シーンに persistent に置き、シリーズ全体の連続性を出す。
 */
const HEX_POINTS = '130,10 235,55 235,145 130,190 25,145 25,55';

export const HexWatermark: React.FC<{
  size?: number;
  opacity?: number;
  color?: string;
  x?: string | number;
  y?: string | number;
  spinSpeed?: number;
}> = ({ size = 260, opacity = 0.08, color = colors.routeSignBlue, x = '50%', y = '50%', spinSpeed = 0.03 }) => {
  const frame = useCurrentFrame();
  const rotate = frame * spinSpeed;
  return (
    <svg
      width={size}
      height={size * 0.86}
      viewBox="0 0 260 200"
      style={{
        position: 'absolute',
        left: x,
        top: y,
        transform: `translate(-50%, -50%) rotate(${rotate}deg)`,
        opacity,
        pointerEvents: 'none',
      }}
    >
      <polygon points={HEX_POINTS} fill="none" stroke={color} strokeWidth={2} />
    </svg>
  );
};
