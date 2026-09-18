import React from 'react';
import { AbsoluteFill, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors } from '../theme';
import { HexWatermark } from '../components/HexWatermark';

/**
 * 1:32.5-1:36.5 クロージング(4秒/120f、9秒から短縮)。Scene1と同じロゴの組み方で
 * 再登場させ、円環構造で締める。
 *
 * 3レビュー統合対応:
 * - 「QR PLACEHOLDERがそのまま出ていて未完成に見える」(3人全員が最重要指摘)
 *   → QR枠を完全に削除し、「詳しくはこちら」の1行テキストCTAのみに変更
 * - 「エンドカードを3-4秒に短縮」(レビューA)と「無音区間の解消」(レビューC)を両立
 *   → 尺は9秒→4秒に短縮しつつ、Video.tsx側でScene7後半〜このシーン終端まで
 *     アウトロBGM(自己合成)を途切れさせずに敷いた
 * - 「動画が突然終わる」→ 最後の0.5秒で黒へフェードアウトする処理を追加
 *
 * 2レビュー統合対応(修正コスト低・効果大):
 * - VOICEVOXクレジット表記を動画から完全に削除(「これだけで完成度の印象が下がる」との
 *   指摘。話者クレジットは動画外・スライド資料側の謝辞等で対応する運用に変更)。
 * - 「詳しくはこちら」というWeb広告的なCTA文言を廃止。代わりにキャッチコピー
 *   「走った道が、日本地図になっていく。」自体を終盤でもう一段階拡大・発光させ、
 *   フェードアウト直前の最後の残像として強く残す構成に変更した。
 */
export const Scene8Closing: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const logoIn = spring({ frame, fps, config: { damping: 14, stiffness: 130 } });
  const logoScale = interpolate(logoIn, [0, 1], [0.85, 1]);
  const flashOpacity = interpolate(frame, [10, 15, 22], [0, 0.5, 0], { extrapolateRight: 'clamp' });
  const taglineIn = spring({ frame: frame - 18, fps, config: { damping: 13, stiffness: 150 } });
  const underline = interpolate(taglineIn, [0, 1], [0, 1]);
  const glow = 0.55 + Math.sin(frame / 11) * 0.25;
  // キャッチコピーを終盤でもう一度強く残す(CTA文言の代わり)
  const taglineEmphasis = interpolate(frame, [48, 70], [1, 1.1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const taglineGlowBoost = interpolate(frame, [48, 70], [1, 2.2], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });

  const ambientPulse = 0.05 + Math.sin(frame / 24) * 0.03;
  const fadeToBlack = interpolate(frame, [104, 119], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });

  return (
    <AbsoluteFill style={{ backgroundColor: colors.black, justifyContent: 'center', alignItems: 'center' }}>
      <HexWatermark size={620} opacity={ambientPulse} color={colors.routeNeonBlue} x="50%" y="50%" spinSpeed={0.045} />
      <HexWatermark size={340} opacity={ambientPulse * 0.8} color={colors.accentGold} x="78%" y="80%" spinSpeed={-0.03} />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          backgroundColor: colors.accentGold,
          opacity: flashOpacity * 0.12,
        }}
      />
      <div style={{ textAlign: 'center' }}>
        <div
          style={{
            opacity: logoIn,
            transform: `scale(${logoScale})`,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: 10,
          }}
        >
          {/* 新アプリアイコン反映(Scene1と同じapp-icon.pngを使用) */}
          <img
            src={staticFile('assets/app-icon.png')}
            style={{
              width: 78,
              height: 78,
              borderRadius: 18,
              filter: `drop-shadow(0 0 ${8 * glow}px rgba(47,169,255,0.6))`,
            }}
            alt="app-icon"
          />
          <div
            style={{
              color: colors.white,
              fontSize: 44,
              fontWeight: 900,
              letterSpacing: 4,
            }}
          >
            KOKUDO
          </div>
        </div>
        <div
          style={{
            opacity: taglineIn,
            transform: `translateY(${interpolate(taglineIn, [0, 1], [12, 0])}px) scale(${taglineEmphasis})`,
            color: colors.routeNeonBlue,
            fontSize: 28,
            marginTop: 18,
            filter: `drop-shadow(0 0 ${6 * glow * taglineGlowBoost}px rgba(47,169,255,0.7))`,
          }}
        >
          走った道が、日本地図になっていく。
          <div
            style={{
              height: 3,
              width: `${underline * 100}%`,
              background: colors.routeNeonBlue,
              margin: '12px auto 0',
              opacity: 0.7,
            }}
          />
        </div>
      </div>

      <AbsoluteFill style={{ backgroundColor: colors.black, opacity: fadeToBlack, pointerEvents: 'none' }} />
    </AbsoluteFill>
  );
};
