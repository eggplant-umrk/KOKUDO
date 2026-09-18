import React from 'react';
import { AbsoluteFill, Easing, interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors } from '../theme';
import { PhoneFrame } from '../components/PhoneFrame';
import { JourneyProgress } from '../components/JourneyProgress';
import { Caption } from '../components/Caption';
import { StatChip, Pill, RouteMiniCard } from '../components/AppUI';
import { JapanMapSilhouette, MapMarker } from '../components/JapanMapSilhouette';
import { VoiceLine } from '../components/VoiceLine';
import { Vignette } from '../components/Vignette';
import { TapRipple } from '../components/TapRipple';

/**
 * 0:26-0:40 走破・地図コレクション画面デモ(主役シーン、尺14秒は維持)。
 *
 * 2レビュー統合対応(最優先項目1、「走る→地図になる」因果接続):
 * シーン冒頭0.8秒はVideo.tsx側でScene5Runningとクロスフェードしている。その受け手として
 * `EntryMorph`(画面独立の青い光の帯)を最初の30フレームだけ重ね、Scene5末尾の
 * 軌跡+数字が「着地」してこの地図に収束するように見せる。
 *
 * 2レビュー統合対応(優先項目、地図を主役にする): 画面切り替え直後は地図パネルだけを
 * 130-140%程度に大きく見せ(ヘッダー・統計チップは非表示)、その後にヘッダー→タブ→
 * リストの順でUI全体へ戻る(以前のラウンドはこの「戻る」動きが弱く、逆順に見えると
 * 指摘されたため、地図の拡大幅と非表示区間を大幅に強化した)。
 *
 * 2レビュー統合対応(優先項目、ゴールド演出の局所化 + マーカー整合性の修正):
 * 従来は完走マーカーの色変化を国道1号(実際は挑戦中/7.5%)に適用しており、
 * 完走済みの国道134号カードと矛盾していた。今回、地図上の「1号」マーカーは常に
 * ブルー(挑戦中)、「134号」マーカーは常にゴールド(完走済み)で固定し、クライマックスは
 * 134号マーカー+134号カードへの局所グロー+カメラズーム(130%)+軽いバウンスに絞った。
 * 全画面フラッシュは廃止済み(前ラウンド)。主要路線(1号・134号)以外は視覚的に弱めた。
 *
 * 2レビュー統合対応(最優先項目、モーフィング遷移の完成): Scene5末尾の「ズームアウト」
 * (handoffScale 1→0.58)を受け止める側として、シーン冒頭でHERO_SCALEに
 * `entryZoom`(0.58→1)を掛けてズームインさせ、同時に「1号」マーカーに着地ポップ
 * (arrivalPop)を発火させた。Scene5の軌跡が「1号(挑戦中・ブルー)の位置に着地する」
 * という因果が視覚的につながるようにしている。旧EntryMorph(独立した青い帯)は撤廃。
 *
 * 2レビュー統合対応(優先項目、ゴールド化演出の強化): バウンス+発光だけでは
 * 「アチーブメント感」が弱いとの指摘。完走の瞬間に斜めのライトスイープと、
 * 134号地点周辺への淡いゴールドパーティクル(固定シード、決定的なアニメーション)を追加。
 * また134号にスポットライトが当たっている間、1号カードを一時的に減光した。
 *
 * 2レビュー統合対応(優先項目、完走→逆算ナビの進捗バーのモーフィング):
 * シーン終盤(MAP_NAVI_OVERLAP分)で134号カード以外を退場させ、完走バーに視線を
 * 収束させる。Video.tsx側でScene7Naviとこの終端をクロスフェードさせており、
 * Scene7側でこのバーがブルー・7.5%へ変形するモーフィングに繋がる
 * (詳細はScene7Navi.tsxのコメント参照)。
 *
 * 3レビュー目対応:
 * (a) 黒→白の輝度ジャンプ解消: Scene5側のオーバーラップ延長(1.2秒)に合わせて
 *     entryZoom/arrivalPop/arrivalGlowの区間を伸ばし、さらにシーン冒頭だけ黒の
 *     ダークニングオーバーレイ(entryDarken)を重ねて明るい地図パネルが瞬間的に
 *     「フラッシュ」して見えないようにした。
 * (b) クライマックスズームだけEase-Outに戻す: 前ラウンドで全カメラモーションを
 *     Ease-in-outに統一したが、「完走ズームだけは力強いEase-Outの方がアチーブメント感が
 *     出る」との指摘を受け、climaxZoomのみEase-Outに変更(継続的なパン系はinOutのまま)。
 * (c) ヘッダー・タブ・路線リストの個別フェードイン/スライドインを撤廃し、Scene4Homeと
 *     同じ「最初から完成画面がある+カメラ/減光による強調のみ」の語法に統一。ヘッダーは
 *     「非表示→出現」ではなく「暗い→明るい」の減光表現に変更し、地図が主役の間は
 *     暗めに沈める形にした。さらにクライマックス前に134号カードへ軽いプレビュー
 *     ズーム+グローを追加し、「地図→完走カード→100%」の3拍子のカメラ巡回を明確にした。
 */
/* 修正1対応(2回目): マーカー座標をJapanMapSilhouetteの新しい画像座標系
   (地図画像に対するパーセンテージ、JapanMapSilhouette.tsxのREGION_POSITIONS参照)に変更 */
const FOCUS_MARKERS = [
  { id: '1', left: 56, top: 63, color: colors.routeNeonBlue },
  { id: '134', left: 58.5, top: 66, color: colors.accentGold },
] as const;
const MINOR_MARKERS = [
  { id: '4', left: 62, top: 33 },
  { id: '292', left: 48, top: 52 },
] as const;
/** ゴールド化パーティクルの固定配置(決定的レンダリングのためMath.randomは使わない) */
const GOLD_PARTICLES = [
  { x: 42, y: 30, size: 4, opacity: 0.8, rise: 6 },
  { x: 52, y: 26, size: 3, opacity: 0.6, rise: 9 },
  { x: 60, y: 33, size: 5, opacity: 0.7, rise: 5 },
  { x: 47, y: 22, size: 3, opacity: 0.5, rise: 11 },
  { x: 56, y: 38, size: 4, opacity: 0.65, rise: 7 },
  { x: 38, y: 35, size: 3, opacity: 0.55, rise: 8 },
] as const;

export const Scene6Map: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const entrance = spring({ frame, fps, config: { damping: 16, stiffness: 95 } });
  const mainRotateY = interpolate(entrance, [0, 1], [-16, -6]);
  const mainX = interpolate(entrance, [0, 1], [90, 0]);

  const drift = Math.sin(frame / 60) * 1.2;
  // Scene5からの着地: 1号マーカーに素早いポップ+グローを発火させ、「軌跡が着地した」ことを示す
  const arrivalPop = interpolate(frame, [12, 26, 38], [0.4, 1.7, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const arrivalGlow = interpolate(frame, [10, 24, 40], [0, 1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  // シーン冒頭、Scene5の「ズームアウト」(0.48)を受けてズームインする(モーフィング遷移)。
  // オーバーラップ幅(1.2秒)に合わせて区間を延長した
  const entryZoom = interpolate(frame, [0, 36], [0.48, 1], {
    easing: Easing.inOut(Easing.cubic),
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  // 黒→白の輝度ジャンプを和らげるダークニング: シーン冒頭だけ黒く沈め、地図パネルの
  // 明るさが「フラッシュ」して見えないようにする
  const entryDarken = interpolate(frame, [0, 34], [0.55, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  // 「挑戦中はブルー」の強調(1号マーカー、着地ポップの後、先に完結させる)
  const marker1Pop = Math.max(
    arrivalPop,
    interpolate(frame, [130, 140, 150], [1, 1.5, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }),
  );
  // ゴールド完走のカタルシス(134号マーカー、その後に来る)
  const marker134Pop = interpolate(frame, [265, 288, 335], [1, 2.4, 1.5], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  // クライマックスの決めズームだけはEase-Out(力強く加速して滑らかに止まる)に戻す
  const climaxZoom = interpolate(frame, [260, 292, 345], [1, 1.3, 1.18], {
    easing: Easing.out(Easing.cubic),
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  // 「地図→完走カード→100%」の3拍子を明確にするための、クライマックス前のプレビューズーム
  const previewZoom = interpolate(frame, [175, 205, 235], [1, 1.1, 1], {
    easing: Easing.inOut(Easing.cubic),
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const previewCardGlow = interpolate(frame, [180, 200, 225, 240], [0, 0.5, 0.5, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  // ゴールド確定の瞬間、スマホ全体にも軽いバウンスを加える(1.0→1.05→1.0)
  const phoneBounce = interpolate(frame, [265, 278, 292], [1, 1.05, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const climaxVignette = interpolate(frame, [258, 282, 330, 350], [0, 1, 1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  // 地図上の134号地点そのものに当てる局所グロー(全画面フラッシュの代替、カードのグローと対になる)
  const mapPointGlow = interpolate(frame, [258, 280, 325, 348], [0, 1, 1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  // ゴールド化のアチーブメント感を強化するライトスイープ(斜めに一閃)とパーティクル
  const lightSweep = interpolate(frame, [266, 286], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const particleBurst = interpolate(frame, [266, 285, 320], [0, 1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  // 134号にスポットが当たる間、1号カードを一時的に減光する
  const card1Dim = interpolate(frame, [260, 280, 330, 350], [1, 0.35, 0.35, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  // 地図を主役にする: ヘッダーは「非表示→出現」ではなく「暗い→明るい」の減光で表現
  // (Scene4Homeと同じ「要素は最初から存在し、カメラ/減光だけで誘導する」語法に統一)
  const headerDim = interpolate(frame, [0, 46], [0.22, 1], {
    easing: Easing.inOut(Easing.cubic),
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const mapAloneScale = interpolate(frame, [0, 46], [1.38, 1], {
    easing: Easing.inOut(Easing.cubic),
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const cardGlow = Math.max(
    previewCardGlow,
    interpolate(frame, [263, 285, 325, 345], [0, 1, 1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }),
  );
  // シーン終端(MAP_NAVI_OVERLAP分): 134号カード以外を退場させ、完走バーに視線を収束させる。
  // Scene7Naviとのクロスフェード後、このバーがブルー・7.5%へモーフィングする
  const listFocus = interpolate(frame, [398, 415], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });

  const HERO_SCALE = 1.24;

  return (
    <AbsoluteFill style={{ backgroundColor: colors.textPrimary, justifyContent: 'center', alignItems: 'center' }}>
      <div
        style={{
          transform: `translateX(${mainX}px) scale(${HERO_SCALE * entryZoom * climaxZoom * previewZoom * phoneBounce})`,
          filter: arrivalGlow > 0 ? `drop-shadow(0 0 ${22 * arrivalGlow}px ${colors.routeNeonBlue})` : undefined,
        }}
      >
        <PhoneFrame rotateY={mainRotateY + drift} rotateX={2} glow="rgba(255,178,56,0.16)">
          {/* 黒→白の輝度ジャンプ解消: シーン冒頭だけ黒く沈め、明るい地図パネルの
              「フラッシュ」感を和らげる */}
          {entryDarken > 0 && (
            <div
              style={{
                position: 'absolute',
                inset: 0,
                zIndex: 6,
                pointerEvents: 'none',
                backgroundColor: colors.black,
                opacity: entryDarken,
              }}
            />
          )}
          {/* ゴールド化のライトスイープ: 斜めに光が一閃する(アチーブメント感の強化) */}
          <div
            style={{
              position: 'absolute',
              inset: 0,
              zIndex: 5,
              pointerEvents: 'none',
              opacity: lightSweep > 0 && lightSweep < 1 ? 1 : 0,
              background: 'linear-gradient(115deg, transparent 42%, rgba(255,255,255,0.75) 50%, transparent 58%)',
              transform: `translateX(${interpolate(lightSweep, [0, 1], [-420, 420])}px)`,
            }}
          />
          {/* ゴールド化のパーティクル: 134号地点周辺への淡い散布(固定シード、決定的) */}
          {particleBurst > 0 && (
            <div style={{ position: 'absolute', inset: 0, zIndex: 5, pointerEvents: 'none' }}>
              {GOLD_PARTICLES.map((p, i) => (
                <div
                  key={i}
                  style={{
                    position: 'absolute',
                    left: `${p.x}%`,
                    top: `${p.y - particleBurst * p.rise}%`,
                    width: p.size,
                    height: p.size,
                    borderRadius: '50%',
                    background: colors.accentGold,
                    opacity: particleBurst * p.opacity,
                    filter: 'blur(0.5px)',
                  }}
                />
              ))}
            </div>
          )}
          <div style={{ padding: '18px 16px 0' }}>
            <div
              style={{
                opacity: headerDim * (1 - listFocus),
              }}
            >
              <div style={{ fontSize: 15, fontWeight: 900, color: colors.textPrimary }}>走破・地図コレクション</div>
              <div style={{ display: 'flex', gap: 6, marginTop: 10 }}>
                <div style={{ flex: 1 }}>
                  <StatChip label="制覇路線数" value="2/6" valueSize={15} />
                </div>
                <div style={{ flex: 1 }}>
                  <StatChip label="累計走行距離" value="86.4km" valueSize={15} />
                </div>
                <div style={{ flex: 1 }}>
                  <StatChip label="カバー率" value="0.83%" valueSize={15} />
                </div>
              </div>
            </div>

            <div
              style={{
                marginTop: 10,
                borderRadius: 20,
                border: '1px solid #93CFE9',
                padding: '10px 8px',
                backgroundColor: '#C3E7F5',
                transform: `scale(${mapAloneScale})`,
                opacity: 1 - listFocus,
              }}
            >
              <div style={{ height: 168, display: 'flex', justifyContent: 'center', overflow: 'hidden', position: 'relative' }}>
                <div style={{ transform: 'scale(0.84)', transformOrigin: 'top center', position: 'relative' }}>
                  <JapanMapSilhouette>
                    {MINOR_MARKERS.map((m) => (
                      <MapMarker key={m.id} leftPct={m.left} topPct={m.top} color={colors.routeInactive} scale={0.5} />
                    ))}
                    {/* 134号地点の局所グロー(全画面フラッシュの代替) */}
                    <div
                      style={{
                        position: 'absolute',
                        left: '58.5%',
                        top: '66%',
                        transform: 'translate(-50%, -50%)',
                        width: (6 + mapPointGlow * 14) * 2,
                        height: (6 + mapPointGlow * 14) * 2,
                        borderRadius: '50%',
                        background: colors.accentGold,
                        opacity: mapPointGlow * 0.35,
                        filter: 'blur(4px)',
                      }}
                    />
                    {FOCUS_MARKERS.map((m) => (
                      <div
                        key={m.id}
                        style={{
                          position: 'absolute',
                          left: `${m.left}%`,
                          top: `${m.top}%`,
                          transform: `translate(-50%, -50%) scale(${m.id === '1' ? marker1Pop : marker134Pop})`,
                        }}
                      >
                        <div
                          style={{
                            width: 10,
                            height: 10,
                            borderRadius: '50%',
                            background: m.color,
                            border: `1.5px solid ${colors.white}`,
                            boxShadow: `0 0 4px ${m.color}`,
                          }}
                        />
                      </div>
                    ))}
                  </JapanMapSilhouette>
                </div>
              </div>
              <div style={{ display: 'flex', justifyContent: 'center', gap: 12, marginTop: 6 }}>
                <LegendDot color={colors.routeInactive} label="未走破" />
                <LegendDot color={colors.routeNeonBlue} label="挑戦中" />
                <LegendDot color={colors.accentGold} label="完走" />
              </div>
            </div>

            <div
              style={{
                display: 'flex',
                gap: 6,
                marginTop: 10,
                opacity: (0.4 + 0.6 * headerDim) * (1 - listFocus),
                position: 'relative',
              }}
            >
              <Pill label="すべて" tone="active" />
              <Pill label="挑戦中" />
              <Pill label="走破済み" />
              <Pill label="未挑戦" />
              <TapRipple x={35} y={12} triggerFrame={150} />
            </div>
          </div>

          <div
            style={{
              padding: '10px 16px',
              display: 'flex',
              flexDirection: 'column',
              gap: 7,
              opacity: 0.5 + 0.5 * headerDim,
            }}
          >
            <div style={{ opacity: card1Dim * (1 - listFocus) }}>
              <RouteMiniCard number="1" name="国道1号" meta="関東 ・ 622.9km ・ 目標 2026/12/31" ratio={0.075} status="inProgress" />
            </div>
            <RouteMiniCard number="134" name="国道134号" meta="関東 ・ 18.2km" ratio={1} status="completed" glow={cardGlow} />
            <div style={{ opacity: 0.5 * (1 - listFocus) }}>
              <RouteMiniCard number="4" name="国道4号" meta="東北 ・ 741.5km" ratio={0} status="notStarted" />
            </div>
            <div style={{ opacity: 0.5 * (1 - listFocus) }}>
              <RouteMiniCard number="292" name="国道292号" meta="中部 ・ 217.6km" ratio={0} status="notStarted" />
            </div>
          </div>
        </PhoneFrame>
      </div>

      <Vignette intensity={climaxVignette} />
      <JourneyProgress step={3} />
      <Caption text={'自分だけの軌跡が、\n地図に刻まれる。'} appearAt={15} holdFrames={150} />
      <Caption text={'挑戦中はブルー、\n完走でゴールドに。'} appearAt={170} holdFrames={300} />
      <VoiceLine id="s6_1" from={15} />
      <VoiceLine id="s6_2" from={170} />
    </AbsoluteFill>
  );
};

const LegendDot: React.FC<{ color: string; label: string }> = ({ color, label }) => (
  <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
    <div style={{ width: 7, height: 7, borderRadius: 4, backgroundColor: color }} />
    <span style={{ fontSize: 9, fontWeight: 600, color: colors.textSecondary }}>{label}</span>
  </div>
);
