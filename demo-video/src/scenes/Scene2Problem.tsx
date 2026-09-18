import React from 'react';
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors } from '../theme';
import { VoiceLine } from '../components/VoiceLine';
import { HexWatermark } from '../components/HexWatermark';
import { TrailLine } from '../components/TrailLine';

/**
 * 0:01.5-0:03.5 課題提起(2秒/60f、3秒から短縮)。
 * 2レビュー統合対応(項目1): コピー→ビジュアルの因果が離れすぎているという指摘に
 * 対応するため、静的な地図ドットの点灯ではなく、実際に軌跡ラインが伸びていく
 * `TrailLine`をここから使用開始。「見えないと、続かない。」の間は軌跡がごく
 * わずかにしか進まない=「見えていない」状態を可視化し、Scene3で同じラインが
 * 続きから伸びていくことで、コピーとプロダクト体験の連続性を作る。
 * 個別指摘対応: 冒頭コピー3行(Scene1-3)の合計を約6秒に圧縮するため3秒→2秒に短縮
 * (内部タイミングは比例縮小)。
 *
 * 2レビュー統合対応(優先項目、冒頭タイポグラフィのインパクト強化): 「見えないと、
 * 続かない。」が細く静かすぎて視線を引く力が弱いとの指摘。1行目のフォントウェイトを
 * 700→900に強化し、テキスト全体をZ軸手前(120%)から奥(100%)へスケールダウン
 * しながら力強く配置されるモーションを追加した(spring由来のイージング付き)。
 */
export const Scene2Problem: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const s1 = spring({ frame, fps, config: { damping: 12, stiffness: 120 } });
  const s2 = spring({ frame: frame - 9, fps, config: { damping: 12, stiffness: 140 } });
  const breathe = 1 + Math.sin(frame / 7) * 0.025;
  // Z軸手前(120%)から奥(100%)へ力強くスケールダウンしながら配置される(タイポグラフィのインパクト強化)
  const entryScale = interpolate(s1, [0, 1], [1.2, 1]);
  const underline = interpolate(frame, [31, 41], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const underlineGlow = 0.5 + Math.sin(frame / 8) * 0.3;
  const trailProgress = interpolate(frame, [12, 52], [0, 0.4], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const trailOpacity = interpolate(frame, [7, 17], [0, 0.75], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });

  const op1 = interpolate(s1, [0, 1], [0, 1]);
  const y1 = interpolate(s1, [0, 1], [20, 0]);
  const op2 = interpolate(s2, [0, 1], [0, 1]);
  const y2 = interpolate(s2, [0, 1], [24, 0]);
  const scale2 = interpolate(s2, [0, 1], [0.88, 1]);

  return (
    <AbsoluteFill style={{ backgroundColor: colors.white, justifyContent: 'center', alignItems: 'center' }}>
      <HexWatermark size={480} opacity={0.05} color={colors.routeSignBlue} x="88%" y="14%" />
      <div style={{ position: 'absolute', right: 70, bottom: 60, opacity: trailOpacity, transform: 'scale(0.7)', transformOrigin: 'bottom right' }}>
        <TrailLine progress={trailProgress} />
      </div>
      <div style={{ textAlign: 'center', transform: `scale(${breathe * entryScale})` }}>
        <div style={{ opacity: op1, transform: `translateY(${y1}px)`, color: colors.textSecondary, fontSize: 40, fontWeight: 900 }}>
          見えないと、
        </div>
        <div
          style={{
            opacity: op2,
            transform: `translateY(${y2}px) scale(${scale2})`,
            color: colors.routeSignBlue,
            fontSize: 56,
            fontWeight: 900,
            marginTop: 4,
          }}
        >
          続かない。
        </div>
        <div
          style={{
            height: 3,
            width: `${underline * 140}px`,
            background: colors.routeSignBlue,
            margin: '10px auto 0',
            opacity: frame > 41 ? underlineGlow : 0.5,
          }}
        />
      </div>
      <VoiceLine id="s2" from={3} />
    </AbsoluteFill>
  );
};
