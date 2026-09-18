import React from 'react';
import { AbsoluteFill, Easing, interpolate, spring, useCurrentFrame, useVideoConfig, staticFile } from 'remotion';
import { colors } from '../theme';
import { PhoneFrame } from '../components/PhoneFrame';
import { JourneyProgress } from '../components/JourneyProgress';
import { Caption } from '../components/Caption';
import { Pill, ProgressBar, GoalCard, RouteBadge, StatChip, GradientCTA } from '../components/AppUI';
import { VoiceLine } from '../components/VoiceLine';
import { CharacterRunSprite } from '../components/CharacterRunSprite';

/**
 * 0:51.5-1:01.5 逆算ナビデモ(10秒/300f)。
 *
 * 修正3対応: 「あと何キロ必要か」ナレーション区間(0-130f)の構成を変更。
 * 従来はずっと逆算ナビカード(7.5%の進捗)が表示されていたが、ナレーション内容
 * 「あと何キロ必要か、逆算ナビが並走する」の文脈を実装側で再現するため、
 * 前半(0-130f)ではScene4ホーム画面の進捗カード(「あと522.9km!」状態)をズーム
 * フォーカスし、ナレーションの「あと何キロ」を視覚的に強調する。
 * その後(130f以降)クローズアップで逆算ナビへ遷移し、「逆算ナビが並走する」
 * ビジュアルに切り替える。
 *
 * 2レビュー統合対応(項目3、「最も弱いシーン」との指摘への全面的な再構成):
 * (a) 確立ショット(0-50f)では、ホーム画面を一部拡大表示。
 * (b) 進捗カードのみを強調し、周囲の情報(統計チップ等)は減光。
 * (c) ナレーション後半(130f以降)でクローズアップに遷移し、逆算ナビカードを表示。
 *
 * 2レビュー統合対応(優先項目、完走→逆算ナビの進捗バーのモーフィング):
 * Video.tsx側でScene6MapとこのシーンをMAP_NAVI_OVERLAP(0.67秒)だけクロスフェード
 * している。確立ショットのホーム画面では進捗7.5%を保ち、クローズアップ遷移で
 * ゴールド・100%→ブルー・7.5%のバーモーフィング発火。
 *
 * 3レビュー目対応(優先項目、クローズアップの文脈維持):
 * PhoneFrameを常時マウントしたままにし、クローズアップ以降はそれをbackdrop-blur+
 * 減光で背景として残す構成に変更。「アプリ画面の上にカードが浮いている」という
 * 文脈を維持しつつ、カード自体の登場スケールには強いEase-Out(1.15→1)を適用。
 */
const HOME_FOCUS_END = 130; // ナレーション「あと何キロ必要か」の区間終了フレーム
const CLOSEUP_START = HOME_FOCUS_END - 20; // クローズアップへの遷移フレーム
const CUT_FRAME = 50;
const BAR_MORPH_END = 20;
const BACKDROP_START = CUT_FRAME - 6;
const BACKDROP_END = CUT_FRAME + 16;

export const Scene7Navi: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // ビート0: ホーム画面フォーカス(0-130f)。ナレーション「あと何キロ必要か」に合わせ、
  // Scene4ホーム画面の進捗カードへズームイン。カメラは進捗カード(Y≈130px)に焦点を当てる
  const homeScreenZ = interpolate(
    frame,
    [0, 30, HOME_FOCUS_END - 40, HOME_FOCUS_END],
    [1, 1.15, 1.15, 1.3],
    { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' },
  );
  const homeScreenPanY = interpolate(
    frame,
    [0, 30, HOME_FOCUS_END - 40, HOME_FOCUS_END],
    [0, -50, -50, -100],
    { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' },
  );
  const homeScreenOpacity = interpolate(
    frame,
    [HOME_FOCUS_END - 20, HOME_FOCUS_END],
    [1, 0],
    { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' },
  );

  // ビート1: 確立ショット(逆算ナビ表示の確立)。HOME_FOCUS_ENDを過ぎたら登場
  const entrance = spring({ frame: Math.max(0, frame - HOME_FOCUS_END), fps, config: { damping: 14, stiffness: 210, mass: 0.6 } });
  const rotateX = interpolate(entrance, [0, 1], [16, 6]);
  const scaleIn = interpolate(entrance, [0, 1], [0.92, 1]);
  const drift = Math.sin(frame / 50) * 1.2;
  const HERO_SCALE = 1.3;

  // Scene6からのバーモーフィング: ゴールド・100% → ブルー・7.5%
  // ただし HOME_FOCUS_ENDを過ぎるまでは進行しない(遅延開始)
  const barMorphFrame = Math.max(0, frame - HOME_FOCUS_END);
  const barRatio = interpolate(barMorphFrame, [0, BAR_MORPH_END], [1, 0.075], { extrapolateRight: 'clamp' });
  const barColorMix = interpolate(barMorphFrame, [0, BAR_MORPH_END], [0, 1], { extrapolateRight: 'clamp' });

  // ビート2: クローズアップ。HOME_FOCUS_END以降の段階で逆算ナビへ遷移。
  // PhoneFrameは背景として減光+ぼかし、カードだけを強いEase-Outでポップアップさせる
  // クローズアップ段階での数字スポットライト(CUT_FRAMEはHOME_FOCUS_ENDの後に設定)
  // TDZ修正: adjustedCutFrameは使用箇所(このすぐ下)より前で定義する必要がある
  const adjustedCutFrame = Math.max(CUT_FRAME, HOME_FOCUS_END - 6);
  const adjBackdropStart = adjustedCutFrame - 6;
  const adjBackdropEnd = adjustedCutFrame + 16;
  const backdropBlur = interpolate(
    frame,
    [adjBackdropStart, adjBackdropEnd],
    [0, 16],
    { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' },
  );
  const backdropDim = interpolate(
    frame,
    [adjBackdropStart, adjBackdropEnd],
    [1, 0.4],
    { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' },
  );
  const backdropPullback = interpolate(
    frame,
    [adjBackdropStart, adjBackdropEnd],
    [1, 0.88],
    { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' },
  );
  const closeupOpacity = interpolate(
    frame,
    [adjBackdropStart, adjustedCutFrame + 10],
    [0, 1],
    { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' },
  );
  const closeupScale = interpolate(
    frame,
    [adjustedCutFrame, adjustedCutFrame + 24],
    [1.15, 1],
    {
      easing: Easing.out(Easing.cubic),
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    },
  );

  const emphasizeRemaining = interpolate(
    frame,
    [adjustedCutFrame + 10, adjustedCutFrame + 25, adjustedCutFrame + 70, adjustedCutFrame + 85],
    [0, 1, 1, 0],
    { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' },
  );
  const emphasizePace = interpolate(
    frame,
    [adjustedCutFrame + 95, adjustedCutFrame + 110, adjustedCutFrame + 150, adjustedCutFrame + 165],
    [0, 1, 1, 0],
    { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' },
  );
  const emphasizeDate = interpolate(
    frame,
    [adjustedCutFrame + 175, adjustedCutFrame + 190, adjustedCutFrame + 230, adjustedCutFrame + 245],
    [0, 1, 1, 0],
    { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' },
  );
  const dimRemaining = Math.max(emphasizePace, emphasizeDate);
  const dimPace = Math.max(emphasizeRemaining, emphasizeDate);
  const dimDate = Math.max(emphasizeRemaining, emphasizePace);
  // 個別指摘対応: Scene8への遷移が唐突なハードカットに見えないよう、このシーンの終端で
  // 黒へフェードする。Scene8も黒背景から始まるため、黒同士のブリッジで縫い目を目立たなくする
  const fadeToBlack = interpolate(frame, [282, 300], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });

  // 修正3対応: ホーム画面フォーカスと逆算ナビ表示の選択的レンダリング
  const showHomeScreen = frame < HOME_FOCUS_END;

  return (
    <AbsoluteFill
      style={{
        background: `radial-gradient(circle at 50% 40%, #3d3324 0%, ${colors.textPrimary} 78%)`,
        justifyContent: 'center',
        alignItems: 'center',
      }}
    >
      {/* ビート0: ホーム画面フォーカスフェーズ(0-130f)*/}
      {showHomeScreen && (
        <div
          style={{
            position: 'absolute',
            transform: `scale(${homeScreenZ}) translateY(${homeScreenPanY}px)`,
            opacity: homeScreenOpacity,
            zIndex: 10,
          }}
        >
          <PhoneFrame rotateY={-2} rotateX={0} glow="rgba(47,169,255,0.1)" scale={0.9}>
            {/* 修正3対応: 進捗カードのみのダイジェスト表示だと「カードの下が空白」に
                見えるとの指摘のため、Scene4Homeと同じ完成したホーム画面(背景+キャラクター+
                統計+ボタン)をここでも再現し、その中の進捗カードにカメラがズームする形にする */}
            <div style={{ height: 560, position: 'relative', overflow: 'hidden', padding: 18 }}>
              <img
                src={staticFile('assets/road-bg.webp')}
                style={{
                  position: 'absolute',
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  width: '100%',
                  height: '100%',
                  objectFit: 'cover',
                  objectPosition: '50% 28%',
                  zIndex: 0,
                }}
                alt="road-bg"
              />
              <CharacterRunSprite
                style={{
                  position: 'absolute',
                  bottom: 0,
                  left: '50%',
                  transform: 'translateX(-50%)',
                  height: '78%',
                  width: 'auto',
                  objectFit: 'contain',
                  objectPosition: 'bottom center',
                  zIndex: 2,
                }}
              />
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <RouteBadge text="国道1号" />
              </div>
              <div
                style={{
                  position: 'absolute',
                  top: 128,
                  left: 18,
                  right: 18,
                }}
              >
                <GoalCard
                  remainingKm="522.9km"
                  dailyKm="10.3km"
                  pct="7.5"
                  ratio={0.075}
                  kmToday="5.24km"
                  kmTotal="622.9km"
                  emphasize={Math.min(1, (frame - 20) / 40)}
                />
              </div>
            </div>
            <div style={{ padding: '16px 18px' }}>
              <div style={{ display: 'flex', gap: 12 }}>
                <div style={{ flex: 1 }}>
                  <StatChip label="本日の走行距離" value="5.24km" />
                </div>
                <div style={{ flex: 1 }}>
                  <StatChip label="今月の総走行距離" value="48.6km" />
                </div>
              </div>
              <div style={{ marginTop: 10 }}>
                <GradientCTA label="ランニング開始" />
              </div>
            </div>
          </PhoneFrame>
        </div>
      )}

      {/* ビート1+2: 逆算ナビ表示フェーズ(130f～) */}
      {frame >= HOME_FOCUS_END - 30 && (
        <div
          style={{
            transform: `scale(${scaleIn * HERO_SCALE * backdropPullback})`,
            filter: `blur(${backdropBlur}px) brightness(${backdropDim})`,
            opacity: interpolate(
              frame,
              [HOME_FOCUS_END - 30, HOME_FOCUS_END],
              [0, 1],
              { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' },
            ),
            zIndex: 5,
          }}
        >
          <PhoneFrame rotateX={rotateX} rotateY={-4 + drift}>
            <AbsoluteFill style={{ backgroundColor: colors.bgSurface, paddingTop: 110 }}>
              <div
                style={{
                  backgroundColor: colors.white,
                  borderRadius: 20,
                  padding: 20,
                  margin: '0 24px',
                  boxShadow: '0 22px 46px rgba(0,0,0,0.16)',
                  position: 'relative',
                }}
              >
                <div style={{ fontSize: 14, lineHeight: 1.6, color: colors.textPrimary, fontWeight: 500, paddingRight: 28 }}>
                  あと<span style={{ color: colors.accentGoldText, fontWeight: 900 }}>522.9km</span>！ 1日
                  <span style={{ color: colors.accentGoldText, fontWeight: 900 }}>10.3km</span>ペースで一緒に頑張ろう
                </div>
                <div style={{ marginTop: 10, position: 'relative' }}>
                  <div style={{ position: 'absolute', inset: 0, opacity: 1 - barColorMix }}>
                    <ProgressBar ratio={barRatio} height={6} color={colors.accentGold} />
                  </div>
                  <div style={{ opacity: barColorMix }}>
                    <ProgressBar ratio={barRatio} height={6} />
                  </div>
                </div>
                <div
                  style={{
                    position: 'absolute',
                    top: 14,
                    right: 14,
                    width: 22,
                    height: 22,
                    borderRadius: 999,
                    backgroundColor: colors.bgSurfaceRaised,
                  }}
                />
                <div style={{ marginTop: 12, paddingTop: 12, borderTop: `1px solid ${colors.borderSubtle}` }}>
                  <div style={{ display: 'flex', gap: 8 }}>
                    <Pill label="今月末" />
                    <Pill label="来月末" tone="active" />
                    <Pill label="3ヶ月後" />
                  </div>
                </div>
              </div>
            </AbsoluteFill>
          </PhoneFrame>
        </div>
      )}

      {/* クローズアップカード(HOME_FOCUS_END以降に表示) */}
      <div
        style={{
          position: 'absolute',
          top: '50%',
          left: '50%',
          width: 1180,
          maxWidth: '66%',
          padding: '52px 60px',
          borderRadius: 36,
          backgroundColor: colors.white,
          boxShadow: '0 34px 80px rgba(0,0,0,0.4)',
          opacity: interpolate(
            frame,
            [HOME_FOCUS_END, HOME_FOCUS_END + 20, 280, 300],
            [0, closeupOpacity, closeupOpacity, 0],
            { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' },
          ),
          transform: `translate(-50%, -50%) scale(${closeupScale})`,
          pointerEvents: closeupOpacity > 0.5 ? undefined : 'none',
          zIndex: 8,
        }}
      >
        <div style={{ fontSize: 36, lineHeight: 1.75, fontWeight: 600, color: colors.textPrimary }}>
            あと
            <NumberHighlight active={emphasizeRemaining} dim={dimRemaining}>
              522.9km
            </NumberHighlight>
            ！
            <br />
            1日
            <NumberHighlight active={emphasizePace} dim={dimPace}>
              10.3km
            </NumberHighlight>
            ペースで一緒に頑張ろう
          </div>
          <div style={{ marginTop: 28 }}>
            <ProgressBar ratio={0.075} height={14} />
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 32 }}>
            <div style={{ fontSize: 20, fontWeight: 800, color: colors.textSecondary }}>目標時期</div>
            <NumberHighlight active={emphasizeDate} dim={dimDate} fontSize={30}>
              来月末
            </NumberHighlight>
          </div>
      </div>
      <JourneyProgress step={4} />
      <Caption text={'あと何キロ\n必要か。'} appearAt={15} holdFrames={110} />
      <Caption text={'逆算ナビが、\n並走する。'} appearAt={130} holdFrames={270} />
      {/* 修正4対応: DC帯ノイズの原因究明を諦め、39秒以降の音声を全削除してから
          VOICEVOXでゼロから再生成したナレーション(BGM/SEなし、ナレーションのみ) */}
      <VoiceLine id="s7_1" from={15} />
      <VoiceLine id="s7_2" from={130} />
      <AbsoluteFill style={{ backgroundColor: colors.black, opacity: fadeToBlack, pointerEvents: 'none' }} />
    </AbsoluteFill>
  );
};

/** クローズアップ内で1つの数字だけを順番にスポットライト表示するための補助表示。 */
const NumberHighlight: React.FC<{ active: number; dim: number; fontSize?: number; children: React.ReactNode }> = ({
  active,
  dim,
  fontSize,
  children,
}) => (
  <span
    style={{
      display: 'inline-block',
      color: colors.accentGoldText,
      fontWeight: 900,
      fontSize,
      transform: `scale(${1 + active * 0.22})`,
      opacity: 1 - dim * 0.6,
      textShadow: active > 0.3 ? `0 0 ${18 * active}px rgba(255,178,56,0.7)` : 'none',
    }}
  >
    {children}
  </span>
);
