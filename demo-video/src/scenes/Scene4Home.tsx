import React from 'react';
import { AbsoluteFill, Easing, interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors } from '../theme';
import { PhoneFrame } from '../components/PhoneFrame';
import { JourneyProgress } from '../components/JourneyProgress';
import { Caption } from '../components/Caption';
import { StatChip, GradientCTA, RouteBadge, GoalCard } from '../components/AppUI';
import { TapRipple } from '../components/TapRipple';
import { Vignette } from '../components/Vignette';
import { VoiceLine } from '../components/VoiceLine';
import { JapanMapSilhouette } from '../components/JapanMapSilhouette';
import { CharacterRunSprite } from '../components/CharacterRunSprite';
import { RoadBackgroundSprite } from '../components/RoadBackgroundSprite';

/**
 * 0:16-0:31 ホーム画面デモ。app/lib/screens/home_screen.dart + widgets/hero_stage.dart +
 * widgets/goal_speech_bubble.dart の実装(配色・角丸・コピー)を忠実に再現している。
 *
 * 演出方針の変更(要素の個別フェードイン→カメラワーク+強調表示):
 * 従来は進捗カード(cardIn)・統計チップ(statsIn)・CTAボタン(ctaIn)・チェックリスト
 * (checklistIn)がそれぞれ別々のspringでフェードイン/スライドインする「1つずつ出現する」
 * 演出だった。これを「最初から完成した画面がそこにある」状態に変更し、視線誘導は
 * カメラのズーム/パン(Easing.inOut)とVignette+各要素のemphasize(スケール+グロー)の
 * 組み合わせだけで行う。カメラは 進捗カード→統計チップ→CTAボタン→全体を見渡す引き、
 * の順で3箇所を巡ってから引く。パンの目標値は、各要素のフレーム内での垂直位置を
 * 実測ベースで見積もり、その要素が画面中央付近に来るように計算した
 * (translateYがscaleより後に書かれているため、パン量はズーム倍率に関わらず
 * 「要素のY位置 - フレーム中心」の符号を反転した値でよい)。
 * 個別指摘対応: 「6.5秒時点で日本地図の一部を表示開始」に対応するため、シーン開始
 * 直後に日本地図のアンビエントウォーターマークを薄く出し、Scene6の地図伏線とする。
 */
export const Scene4Home: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // フェーズ0: スマホ自体の登場(デバイスの入場であり、UI要素の個別アニメーションではない)
  const entrance = spring({ frame, fps, config: { damping: 16, stiffness: 90 } });
  const rotateY = interpolate(entrance, [0, 1], [-24, -7]);
  const enterX = interpolate(entrance, [0, 1], [120, 0]);
  const enterScale = interpolate(entrance, [0, 1], [0.9, 1]);
  const slowDrift = Math.sin(frame / 55) * 1.6;

  // フェーズ1-3: カメラワークだけで視線誘導する(進捗カード→統計チップ→CTAボタン→全体を引く)
  const camEase = { extrapolateLeft: 'clamp' as const, extrapolateRight: 'clamp' as const, easing: Easing.inOut(Easing.cubic) };
  const HERO_SCALE = 1.15;
  const zoom = interpolate(
    frame,
    [0, 70, 160, 180, 260, 280, 360, 400, 450],
    [1, 1, 1.28, 1.22, 1.22, 1.25, 1.25, 1.0, 1.0],
    camEase,
  );
  const panY = interpolate(
    frame,
    [0, 70, 160, 180, 260, 280, 360, 400, 450],
    [0, 0, 180, -110, -110, -160, -160, 0, 0],
    camEase,
  );
  const mapHint = interpolate(frame, [0, 40], [0, 0.07], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });

  // 各要素の強調(スケール+グロー)。要素は常時表示済みで、フォーカスが当たっている間だけ
  // 目立たせる。カメラのホールド区間(上のzoom/panYの各セグメント)と揃えてある
  const cardFocus = interpolate(frame, [75, 95, 145, 160], [0, 1, 1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const statsFocus = interpolate(frame, [185, 205, 245, 260], [0, 1, 1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const ctaFocus = interpolate(frame, [285, 305, 345, 360], [0, 1, 1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const anyFocus = Math.max(cardFocus, statsFocus, ctaFocus);

  // CTAフォーカスの終盤で「押した」感覚のアクセントを一度だけ加える(要素の出現ではなく操作の演出)
  const buttonPress = interpolate(frame, [335, 338, 343], [1, 0.95, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill
      style={{
        background: `radial-gradient(circle at 50% 38%, #2c3d4d 0%, ${colors.textPrimary} 78%)`,
        justifyContent: 'center',
        alignItems: 'center',
      }}
    >
      <div
        style={{
          position: 'absolute',
          width: 380,
          height: 56,
          borderRadius: '50%',
          background: 'radial-gradient(ellipse at center, rgba(0,0,0,0.4) 0%, rgba(0,0,0,0) 72%)',
          top: '80%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          filter: 'blur(2px)',
        }}
      />
      {/* 個別指摘対応: シーン開始直後に日本地図をごく薄く見せ、Scene6への伏線とする */}
      <div style={{ position: 'absolute', right: '6%', top: '10%', opacity: mapHint, transform: 'scale(1.6)' }}>
        <JapanMapSilhouette showLabels={false} showMockDots={false} />
      </div>
      <div style={{ transform: `translateX(${enterX}px) scale(${enterScale}) scale(${HERO_SCALE}) scale(${zoom}) translateY(${panY}px)` }}>
        <PhoneFrame rotateY={rotateY + slowDrift} rotateX={2} glow="rgba(47,169,255,0.18)">
          {/* hero_stage.dart: Column内でExpanded(Stack: 背景+バッジ+カード+キャラクター)と
              チェックポイントチップ行が非重複の別セクション、その外側(home_screen.dart)に
              StatTile+ボタンの固定ブロックがさらに別セクションとして続く。
              修正1対応: 背景・キャラクター画像はこのhero領域(560px)の内部に限定し、
              78%の高さ計算がPhoneFrame全体(900px)ではなくhero領域基準になるようにする
              (以前は900px基準で計算され、キャラクターが下部の統計カードと重なっていた)。 */}
          <div
            style={{
              height: 560,
              position: 'relative',
              overflow: 'hidden',
              padding: 18,
              zIndex: 3,
            }}
          >
            {/* 実アプリの road-bg.webp アニメーション背景を再現。
                修正対応: RoadBackgroundSpriteでRemotionフレームに明示同期(かくつき対策) */}
            <RoadBackgroundSprite
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
            />
            {/* キャラクター走行アニメーション。hero_stage.dart の FractionallySizedBox(heightFactor: 0.78) に対応。
                78%はこのhero div(560px)基準 = 実アプリのExpanded(Stack)領域基準と一致させている。
                修正2対応: CharacterRunSpriteでRemotionフレームに明示同期(かくつき対策) */}
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
              <RouteBadge text={route.name} />
              <div
                style={{
                  width: 34,
                  height: 34,
                  borderRadius: 17,
                  backgroundColor: 'rgba(255,255,255,0.85)',
                }}
              />
            </div>
            <div
              style={{
                marginTop: 10,
                display: 'inline-block',
                padding: '6px 12px',
                borderRadius: 999,
                backgroundColor: 'rgba(20,34,54,0.4)',
                color: colors.white,
                fontSize: 12,
                fontWeight: 700,
              }}
            >
              {route.section}
            </div>

            <div
              style={{
                position: 'absolute',
                top: 128,
                left: 18,
                right: 18,
                transform: `scale(${1 + cardFocus * 0.05})`,
                filter: cardFocus > 0.15 ? `drop-shadow(0 0 ${16 * cardFocus}px rgba(47,169,255,0.55))` : undefined,
              }}
            >
              <GoalCard
                remainingKm="522.9km"
                dailyKm="10.3km"
                pct="7.5"
                ratio={0.075}
                kmToday="5.24km"
                kmTotal="622.9km"
                emphasize={cardFocus}
                emphasizePct={cardFocus}
                emphasizeKmTotal={cardFocus}
              />
            </div>
          </div>

          {/* hero_stage.dart: Expanded(Stack)の直後、HeroStage自身の末尾にあるチェックポイントチップ行
              (StatTile/ボタンより前、かつキャラクター領域の外)。修正1対応でここに独立させた */}
          <div
            style={{
              padding: '10px 20px 0',
              display: 'flex',
              flexDirection: 'column',
              gap: 8,
            }}
          >
            <div
              style={{
                padding: '10px 14px',
                borderRadius: 12,
                backgroundColor: colors.bgSurfaceRaised,
                fontSize: 13,
                color: colors.textPrimary,
                fontWeight: 700,
              }}
            >
              42.5km地点 ・ 品川宿を通過
            </div>
            <div
              style={{
                padding: '10px 14px',
                borderRadius: 12,
                backgroundColor: '#FFF4E0',
                fontSize: 13,
                color: colors.accentGoldText,
                fontWeight: 700,
              }}
            >
              次のチェックポイント: 箱根峠まであと52.5km
            </div>
          </div>

          {/* home_screen.dart: HeroStageの外側、SafeArea+Paddingで続くStatTile+ボタンの
              固定ブロック(HeroStageとは非重複の完全に別セクション) */}
          <div style={{ padding: '16px 18px' }}>
            <div style={{ display: 'flex', gap: 12 }}>
              <div style={{ flex: 1 }}>
                <StatChip label="本日の走行距離" value="5.24km" emphasize={statsFocus} />
              </div>
              <div style={{ flex: 1 }}>
                <StatChip label="今月の総走行距離" value="48.6km" emphasize={statsFocus} />
              </div>
            </div>
            <div
              style={{
                marginTop: 10,
                position: 'relative',
                transform: `scale(${buttonPress * (1 + ctaFocus * 0.05)})`,
                filter: ctaFocus > 0.15 ? `drop-shadow(0 0 ${18 * ctaFocus}px rgba(47,169,255,0.6))` : undefined,
              }}
            >
              <GradientCTA label="ランニング開始" />
              <TapRipple x={207} y={27} triggerFrame={338} />
            </div>
          </div>
        </PhoneFrame>
      </div>
      <Vignette intensity={anyFocus} />
      <JourneyProgress step={1} />
      <Caption text={'国道を選んで、\n登録するだけ。'} appearAt={50} holdFrames={185} />
      <Caption text={'今どこまで来たか、\n一目で分かる。'} appearAt={195} holdFrames={310} />
      <VoiceLine id="s4_1" from={50} />
      <VoiceLine id="s4_2" from={195} />
    </AbsoluteFill>
  );
};

const route = { name: '国道1号', section: '日本橋 〜 梅田新道' };
