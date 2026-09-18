import React from 'react';
import { AbsoluteFill, Easing, interpolate, useCurrentFrame } from 'remotion';
import { colors } from '../theme';

/**
 * 0:00-0:01.2(1.2s/36f) フック。黒背景に国道標識モチーフの六角形が
 * 光の線として描かれ、中でKOKUDOロゴがキネティックタイポグラフィで組み上がる。
 *
 * 3レビュー統合対応: 「冒頭のロゴ表示が長い」(レビューA)との指摘を受け、
 * 3秒→1.5秒に短縮。2レビュー統合対応(個別指摘): さらに1.5秒→1.2秒へ短縮
 * (内部タイミングはすべて比例縮小)。
 * VOICEVOXクレジットはこのシーンから削除し、エンドカード(Scene8)に統合した。
 */
const HEX_POINTS = '130,10 235,55 235,145 130,190 25,145 25,55';
const HEX_PERIMETER = 400;

export const Scene1Hook: React.FC = () => {
  const frame = useCurrentFrame();

  const hexDraw = interpolate(frame, [0, 16], [0, 1], { extrapolateRight: 'clamp' });
  const hexOpacity = interpolate(frame, [0, 3], [0, 1], { extrapolateRight: 'clamp' });
  const logoOpacity = interpolate(frame, [14, 25], [0, 1], { extrapolateRight: 'clamp' });
  const logoScale = interpolate(frame, [14, 25], [0.9, 1], { extrapolateRight: 'clamp' });
  const glowPulse = 0.6 + Math.sin(frame / 8) * 0.2;
  const slowSpin = frame > 25 ? (frame - 25) * 0.3 : 0;
  const breathe = frame > 25 ? 1 + Math.sin((frame - 25) / 7) * 0.012 : 1;

  // 2レビュー統合対応(優先項目、カメライージング統一): 前ラウンドはEase-Outを適用したが、
  // 今回のレビューで「パンはEase-in-outの方が自然」との指摘を受け、全編のカメラモーションを
  // Ease-in-out(ゆっくり加速→滑らかに減速)に統一し直した
  const pushIn = interpolate(frame, [0, 35], [0.62, 1.55], {
    easing: Easing.inOut(Easing.cubic),
    extrapolateRight: 'clamp',
  });

  const confirmBounce = interpolate(frame, [25, 27, 30], [1, 1.1, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const confirmFlash = interpolate(frame, [25, 26, 31], [0, 0.5, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill style={{ backgroundColor: colors.black, justifyContent: 'center', alignItems: 'center' }}>
      <div
        style={{
          position: 'absolute',
          inset: 0,
          backgroundColor: colors.routeNeonBlue,
          opacity: confirmFlash * 0.12,
          pointerEvents: 'none',
        }}
      />
      <div style={{ transform: `scale(${pushIn * confirmBounce})`, position: 'relative', width: 360, height: 310, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <svg
          width="360"
          height="310"
          viewBox="0 0 260 200"
          style={{ position: 'absolute', opacity: hexOpacity, transform: `rotate(${slowSpin}deg)` }}
        >
          <polygon
            points={HEX_POINTS}
            fill="none"
            stroke={colors.routeNeonBlue}
            strokeWidth={2}
            strokeDasharray={HEX_PERIMETER}
            strokeDashoffset={HEX_PERIMETER * (1 - hexDraw)}
            style={{ filter: `drop-shadow(0 0 ${8 * glowPulse}px ${colors.routeNeonBlue})` }}
          />
        </svg>
        <div
          style={{
            opacity: logoOpacity,
            transform: `scale(${logoScale * breathe})`,
            color: colors.white,
            fontSize: 56,
            fontWeight: 900,
            letterSpacing: 4,
            textAlign: 'center',
          }}
        >
          KOKUDO
        </div>
      </div>
    </AbsoluteFill>
  );
};
