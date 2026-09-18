import React from 'react';
import { AbsoluteFill, Audio, Easing, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors } from '../theme';
import { PhoneFrame } from '../components/PhoneFrame';
import { JourneyProgress } from '../components/JourneyProgress';
import { Caption } from '../components/Caption';
import { StatChip, ProgressBar } from '../components/AppUI';
import { TapRipple } from '../components/TapRipple';
import { VoiceLine } from '../components/VoiceLine';
import { TrailLine } from '../components/TrailLine';

/**
 * 0:21-0:27 ランニング計測デモ(6秒/180f)。
 *
 * 2レビュー統合対応(最優先項目1・2、「走る→地図になる」の因果接続と数字の連動):
 * (a) 距離のカウントアップを「0.79→保持→2.75→保持→5.24」という離散ジャンプから、
 *     0→5.24kmへの連続的なタイムラプス式カウントアップに変更(frame0-150、Ease-Out)。
 *     軌跡ライン(TrailLine)の伸長は distanceKm/5.24 に直結しているため、数字と
 *     軌跡が常に完全に同期する。バウンスも離散ジャンプ演出から、足音のような
 *     連続した微細パルスに変更し、「生きている」質感を出した。
 * (b) シーン終盤(frame150-180)で、ヘッダー・コントロール等のUIクロムを退場させ、
 *     数字+軌跡ラインだけを画面中央に残して拡大しながらフェードさせる「ハンドオフ」を
 *     実装。Video.tsx側でこの末尾0.8秒をScene6Mapの冒頭とクロスフェードさせており、
 *     Scene6側は同じ位置に軌跡が「着地」して地図に収束する形で受け止める
 *     (真のカット割りではなく、2つのシーンをまたぐ連続したモーションとして見せる)。
 *
 * 不具合対応(1回目): 「背景に走行軌跡が地図的に表示される演出が消えた」との指摘を受けて調査。
 * TrailLine自体は削除されておらず数字の下に小さく描画され続けていたが、「数字と競合する
 * 前景の添え物」に見えてしまい、意図していた「背景に薄く敷かれた軌跡」という印象が
 * 失われていた。数字の背後(zIndex 0)に大きく・淡く配置し直し、数字側はテキスト影で
 * 前景としての可読性を保つレイヤー構成に変更した(handoffScale/stepPulseの拡大にも
 * 追従するため、囲みのtransformはそのまま維持)。
 *
 * 不具合対応(2回目): 「以前は画面の左右それぞれに軌跡要素が1つずつ(計2つ)配置されて
 * いたはず」との指摘。demo-video/ はgit管理外(未コミットのディレクトリ)のため
 * `git log`での過去バージョン特定はできなかった(git statusで "?? demo-video/" と
 * 表示され、コミット履歴自体が存在しない)。そのため、中央に1つだけだった背景レイヤーを
 * 左右対称の2要素(互いに鏡像)に再構成した。数字・カウントアップ・"km"表記とは
 * zIndexで分離し、opacityも抑えて競合しないようにしている。
 *
 * 2レビュー統合対応(最優先項目、モーフィング遷移の完成): 「Scene6への遷移がディゾルブに
 * 見え、熱量が一度リセットされる」との指摘。ハンドオフ区間を「ズームイン」から
 * 「カメラがZ軸マイナス方向へ引く(ズームアウト)」に変更し、距離の数字は退場させて
 * 軌跡ラインだけを残すことで、Scene6側のズームイン+マーカー着地ポップ
 * (Scene6Map.tsx参照)と連続したワンモーションになるようにした。
 *
 * 3レビュー目対応(黒→白の輝度ジャンプ解消): クロスフェード幅を0.8秒→1.2秒
 * (RUNNING_MAP_OVERLAP)に延長し、ハンドオフの開始も前倒し。軌跡ラインのグローを
 * 区間の最後まで明るく保つことで、黒背景から明るい地図画面への遷移中も
 * 「青い光」が視覚的なアンカーとして持続し、輝度の急変を和らげる。
 */
export const Scene5Running: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const COUNT_END = 150;
  const distanceKm = interpolate(frame, [0, COUNT_END], [0, 5.24], {
    easing: Easing.out(Easing.cubic),
    extrapolateRight: 'clamp',
  });
  const durationSec = Math.floor(distanceKm * 323);
  const mm = String(Math.floor(durationSec / 60)).padStart(2, '0');
  const ss = String(durationSec % 60).padStart(2, '0');

  const entrance = spring({ frame, fps, config: { damping: 16, stiffness: 100 } });
  const rotateY = interpolate(entrance, [0, 1], [20, 6]);
  const enterScale = interpolate(entrance, [0, 1], [0.92, 1]);
  const controlsIn = spring({ frame: frame - 24, fps, config: { damping: 14, stiffness: 160 } });
  const drift = Math.sin(frame / 60) * 1.4;
  const HERO_SCALE = 1.22;

  // 個別指摘対応: 「押して次に進んだ」という空間連続性のため、右から左へスライドイン
  const slideIn = spring({ frame, fps, config: { damping: 18, stiffness: 90 } });
  const slideX = interpolate(slideIn, [0, 1], [420, 0]);

  // 離散ジャンプのバウンスを廃止し、足音のような連続パルスに変更(生きている質感)
  const stepPulse = 1 + Math.abs(Math.sin(frame / 6.5)) * 0.012;
  // 進捗バーのグローは距離の進み具合に比例して連続的に強くなる
  const progressGlow = interpolate(distanceKm, [0, 5.24], [0.15, 0.9]);

  // ハンドオフ(frame130-180、1.2秒のオーバーラップに合わせて前倒し): クロムを退場させ、
  // カメラをZ軸マイナス方向へ引きながら(ズームアウト)、数字は消えて軌跡ラインだけが残る。
  // Scene6側のズームイン+マーカー着地ポップと繋がって連続したワンモーションになる
  const chromeFade = interpolate(frame, [128, 148], [1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const numberFade = interpolate(frame, [135, 160], [1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const handoffScale = interpolate(frame, [135, 180], [1, 0.48], {
    easing: Easing.inOut(Easing.cubic),
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  // 軌跡の発光はシーン終端まで明るく保ち、黒→白の輝度変化を橋渡しする「光のアンカー」にする
  const handoffGlow = interpolate(frame, [135, 165, 180], [0, 1, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const trailBridgeOpacity = interpolate(frame, [135, 170], [0.26, 0.55], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });

  return (
    <AbsoluteFill
      style={{
        background: `radial-gradient(circle at 50% 42%, #1c3636 0%, ${colors.textPrimary} 80%)`,
        justifyContent: 'center',
        alignItems: 'center',
        transform: `translateX(${slideX}px)`,
      }}
    >
      <div style={{ transform: `scale(${enterScale * HERO_SCALE})` }}>
        <PhoneFrame rotateY={rotateY + drift} rotateX={-2}>
          <AbsoluteFill style={{ backgroundColor: colors.black }}>
            <div style={{ padding: '22px 20px 0', opacity: chromeFade }}>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <div style={{ fontSize: 11, fontWeight: 600, color: 'rgba(255,255,255,0.55)' }}>
                  次のチェックポイント：品川宿
                </div>
                <div style={{ fontSize: 11, fontWeight: 800, color: 'rgba(255,255,255,0.85)' }}>あと 9.5km</div>
              </div>
              <div
                style={{
                  marginTop: 6,
                  filter: `drop-shadow(0 0 ${progressGlow * 8}px ${colors.routeNeonBlue})`,
                }}
              >
                <ProgressBar ratio={Math.min(1, distanceKm / 5.24)} height={3} track="rgba(255,255,255,0.14)" />
              </div>
            </div>

            <div
              style={{
                flex: 1,
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'center',
                alignItems: 'center',
                position: 'relative',
                transform: `scale(${stepPulse * handoffScale})`,
                filter: handoffGlow > 0 ? `drop-shadow(0 0 ${28 * handoffGlow}px ${colors.routeNeonBlue})` : undefined,
              }}
            >
              {/* 背景レイヤー: 走行軌跡を左右対称に2つ、大きく・淡く「地図的」に敷く。
                  数字より背面(zIndex0)。互いに鏡像にすることで中央の数字を挟み込む構図にした */}
              <div
                style={{
                  position: 'absolute',
                  left: '2%',
                  top: '50%',
                  transform: 'translateY(-46%) scale(1.15)',
                  transformOrigin: 'left center',
                  opacity: trailBridgeOpacity,
                  zIndex: 0,
                  pointerEvents: 'none',
                }}
              >
                <TrailLine progress={Math.min(1, distanceKm / 5.24)} />
              </div>
              <div
                style={{
                  position: 'absolute',
                  right: '2%',
                  top: '50%',
                  transform: 'translateY(-46%) scaleX(-1.15) scaleY(1.15)',
                  transformOrigin: 'right center',
                  opacity: trailBridgeOpacity,
                  zIndex: 0,
                  pointerEvents: 'none',
                }}
              >
                <TrailLine progress={Math.min(1, distanceKm / 5.24)} />
              </div>

              <div style={{ position: 'relative', zIndex: 1, display: 'flex', alignItems: 'baseline', opacity: numberFade }}>
                <div
                  style={{
                    color: colors.white,
                    fontSize: 68,
                    fontWeight: 900,
                    letterSpacing: -2,
                    textShadow: '0 2px 16px rgba(0,0,0,0.85)',
                  }}
                >
                  {distanceKm.toFixed(2)}
                </div>
                <div style={{ color: 'rgba(255,255,255,0.6)', fontSize: 22, fontWeight: 700, marginLeft: 6, textShadow: '0 2px 12px rgba(0,0,0,0.85)' }}>km</div>
              </div>
              <div
                style={{
                  position: 'relative',
                  zIndex: 1,
                  color: 'rgba(255,255,255,0.6)',
                  fontSize: 24,
                  fontWeight: 700,
                  marginTop: 6,
                  opacity: chromeFade * numberFade,
                  textShadow: '0 2px 10px rgba(0,0,0,0.85)',
                }}
              >
                {mm}:{ss}
              </div>

              {/* 前景レイヤー: 現在地点を示す小さな軌跡(既存の同期表示、数字より手前) */}
              <div style={{ position: 'relative', zIndex: 1, marginTop: 18, opacity: 0.9 }}>
                <TrailLine progress={Math.min(1, distanceKm / 5.24)} />
              </div>
            </div>

            <div
              style={{
                padding: '0 20px 120px',
                opacity: controlsIn * chromeFade,
                transform: `translateY(${interpolate(controlsIn, [0, 1], [16, 0])}px)`,
                position: 'relative',
              }}
            >
              <TapRipple x={52} y={186} triggerFrame={30} />
              <div style={{ display: 'flex', gap: 12, marginBottom: 12 }}>
                <div style={{ flex: 1 }}>
                  <StatChip label="現在のペース" value="5'23&quot;" dark valueSize={22} />
                </div>
                <div style={{ flex: 1 }}>
                  <StatChip label="消費カロリー" value="325 kcal" dark valueSize={22} />
                </div>
              </div>
              <div style={{ display: 'flex', gap: 12 }}>
                <div style={{ width: 64, height: 64, borderRadius: 32, border: '2px solid rgba(255,255,255,0.2)', backgroundColor: 'rgba(255,255,255,0.08)' }} />
                <div style={{ flex: 1, height: 64, borderRadius: 32, backgroundColor: 'rgba(228,83,106,0.18)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <span style={{ color: colors.danger, fontWeight: 900, fontSize: 14 }}>終了(長押し)</span>
                </div>
              </div>
            </div>
          </AbsoluteFill>
        </PhoneFrame>
      </div>
      <JourneyProgress step={2} />
      <Caption text={'走った距離が、'} appearAt={5} holdFrames={72} />
      <Caption text={'そのまま、\n国道になる。'} appearAt={76} holdFrames={145} />
      <VoiceLine id="s5_1" from={5} />
      <VoiceLine id="s5_2" from={76} />
      {/* 音量バランス対応(「うるさい」との指摘): 0.15秒間隔で連続するティック音が
          相対的に主張しすぎていたため、0.5→0.32へ落として背景の質感程度に抑えた */}
      <Audio src={staticFile('audio/sfx_tick_loop.wav')} volume={0.32} />
    </AbsoluteFill>
  );
};
