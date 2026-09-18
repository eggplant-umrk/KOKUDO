import React from 'react';
import { interpolate, useCurrentFrame } from 'remotion';
import { colors } from '../theme';

/**
 * 改善2対応: 「今ここを操作している」という手元感を出すためのタップ演出。
 * triggerFrame(シーン内フレーム)の直前に指先のドットが上から降りてきて着地し、
 * 着地の瞬間にリング状の波紋が広がって消える。x/yは親要素基準の絶対配置(px)。
 */
export const TapRipple: React.FC<{
  x: number;
  y: number;
  triggerFrame: number;
  color?: string;
}> = ({ x, y, triggerFrame, color = colors.white }) => {
  const frame = useCurrentFrame();
  const t = frame - triggerFrame;
  if (t < -16 || t > 28) return null;

  const approach = interpolate(t, [-16, -2], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const fingerY = interpolate(approach, [0, 1], [-30, 0]);
  const fingerOpacity = interpolate(t, [-16, -10, 6], [0, 1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const pressScale = interpolate(t, [-2, 2, 8], [1, 0.65, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });

  const rippleProgress = interpolate(t, [0, 26], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const rippleScale = interpolate(rippleProgress, [0, 1], [0.15, 1.6]);
  const rippleOpacity = interpolate(rippleProgress, [0, 0.15, 1], [0, 0.7, 0]);

  return (
    <div style={{ position: 'absolute', left: x, top: y, width: 0, height: 0, pointerEvents: 'none', zIndex: 50 }}>
      <div
        style={{
          position: 'absolute',
          left: -30,
          top: -30,
          width: 60,
          height: 60,
          borderRadius: 999,
          border: `2px solid ${color}`,
          transform: `scale(${rippleScale})`,
          opacity: t >= 0 ? rippleOpacity : 0,
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: -9,
          top: fingerY - 9,
          width: 18,
          height: 18,
          borderRadius: 999,
          background: color,
          opacity: fingerOpacity,
          transform: `scale(${pressScale})`,
          boxShadow: `0 0 12px ${color}`,
        }}
      />
    </div>
  );
};
