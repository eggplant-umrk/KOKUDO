import React from 'react';
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors } from '../theme';
import { VoiceLine } from '../components/VoiceLine';
import { HexWatermark } from '../components/HexWatermark';
import { TrailLine } from '../components/TrailLine';

/**
 * 0:03.5-0:06.0 転換(2.5秒/75f、4秒から短縮)。白→ブランドブルーへワイプ。
 * 2レビュー統合対応(項目1): Scene2で0→0.4まで伸びた`TrailLine`を、この
 * シーンでは0.4→1.0まで伸ばして引き継ぐ。「距離を、地図に変えよう。」という
 * コピーの完了とライン完成(=地図が完成する)を同期させ、コピーとビジュアルの
 * 因果関係を明確にする。ライン完成の瞬間に軽いグローパルスを追加。
 * 個別指摘対応: 冒頭コピー3行(Scene1-3)の合計を約6秒に圧縮するため4秒→2.5秒に
 * 短縮(内部タイミングは比例縮小)。
 */
export const Scene3Turn: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const wipe = interpolate(frame, [0, 10], [0, 100], { extrapolateRight: 'clamp' });
  const s = spring({ frame: frame - 4, fps, config: { damping: 11, stiffness: 160 } });
  const textScale = interpolate(s, [0, 1], [0.85, 1]);
  const textOpacity = interpolate(s, [0, 1], [0, 1]);
  const glowPulse = 0.4 + Math.sin(frame / 9) * 0.3;
  const trailProgress = interpolate(frame, [0, 50], [0.4, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const trailComplete = interpolate(frame, [49, 58], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });

  return (
    <AbsoluteFill style={{ backgroundColor: colors.white }}>
      <AbsoluteFill
        style={{
          backgroundColor: colors.routeSignBlue,
          clipPath: `inset(0 ${100 - wipe}% 0 0)`,
          justifyContent: 'center',
          alignItems: 'center',
        }}
      >
        <HexWatermark size={520} opacity={0.1} color={colors.white} x="14%" y="82%" spinSpeed={-0.02} />
        <div
          style={{
            position: 'absolute',
            right: 70,
            bottom: 60,
            opacity: 0.85,
            transform: 'scale(0.7)',
            transformOrigin: 'bottom right',
            filter: `drop-shadow(0 0 ${trailComplete * 16}px ${colors.accentGold})`,
          }}
        >
          <TrailLine progress={trailProgress} />
        </div>
        <div
          style={{
            opacity: textOpacity,
            transform: `scale(${textScale})`,
            color: colors.white,
            fontSize: 48,
            fontWeight: 900,
            filter: `drop-shadow(0 0 ${10 * glowPulse}px rgba(255,255,255,0.55))`,
          }}
        >
          距離を、地図に変えよう。
        </div>
      </AbsoluteFill>
      <VoiceLine id="s3" from={8} />
    </AbsoluteFill>
  );
};
