import React from 'react';

/**
 * 改善3対応: 注目してほしい数字・要素へ視線を誘導するためのビネット(周辺減光)。
 * intensity: 0(無し)〜1(最大)。呼び出し側でinterpolateしてフェードイン/アウトさせる。
 */
export const Vignette: React.FC<{ intensity: number; focusY?: string }> = ({ intensity, focusY = '45%' }) => {
  if (intensity <= 0) return null;
  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        pointerEvents: 'none',
        background: `radial-gradient(circle at 50% ${focusY}, rgba(0,0,0,0) 28%, rgba(0,0,0,${0.62 * intensity}) 100%)`,
      }}
    />
  );
};
