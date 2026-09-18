import React from 'react';
import { AbsoluteFill, Sequence, interpolate, useCurrentFrame } from 'remotion';
import { MAP_NAVI_OVERLAP, RUNNING_MAP_OVERLAP, sceneFrames } from './durations';
import { fonts } from './theme';
import { Scene1Hook } from './scenes/Scene1Hook';
import { Scene2Problem } from './scenes/Scene2Problem';
import { Scene3Turn } from './scenes/Scene3Turn';
import { Scene4Home } from './scenes/Scene4Home';
import { Scene5Running } from './scenes/Scene5Running';
import { Scene6Map } from './scenes/Scene6Map';
import { Scene7Navi } from './scenes/Scene7Navi';
import { Scene8Closing } from './scenes/Scene8Closing';

/**
 * KOKUDO デモ動画本体。各シーンは docs/pitch/02_demo-video-script.md の
 * タイムラインと1:1対応。シーン尺は src/durations.ts で一元管理。
 *
 * 2レビュー統合対応(最優先項目: 「走る→地図になる」の因果接続):
 * Scene5(ランニング)とScene6(地図)だけは、`Series`の単純な連結(ハードカット)ではなく
 * `Sequence`を手動配置してRUNNING_MAP_OVERLAP(0.8秒)だけ重ねている。重なっている間、
 * Scene5は末尾でクロマ(ヘッダー等)を消してズームアウトしながらフェードアウトし、
 * Scene6は同じタイミングでズームインしながら「1号」マーカーが着地ポップする
 * オープニングでフェードインする。2つの独立コンポーネントを跨いだ真のクロスフェードに
 * することで、カット割りではなく連続したモーションとして見せている
 * (詳細はScene5Running.tsx/Scene6Map.tsxのコメント参照)。
 *
 * 2レビュー統合対応(優先項目: 完走→逆算ナビの進捗バーのモーフィング):
 * 同様にScene6(地図)とScene7(逆算ナビ)もMAP_NAVI_OVERLAP(0.67秒)だけ重ね、
 * Scene6終盤で134号カードの完走(ゴールド・100%)進捗バーにカメラを収束させ、
 * Scene7冒頭でそのバーが国道1号の進捗(ブルー・7.5%)へアニメーションしながら
 * 変形するモーフィングを実装した。他のシーン境界は従来通りハードカット。
 */
const RunningLayer: React.FC = () => {
  const frame = useCurrentFrame();
  const dur = sceneFrames('running');
  const opacity = interpolate(frame, [dur - RUNNING_MAP_OVERLAP, dur - 2], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <AbsoluteFill style={{ opacity }}>
      <Scene5Running />
    </AbsoluteFill>
  );
};

const MapLayer: React.FC = () => {
  const frame = useCurrentFrame();
  const dur = sceneFrames('map');
  const opacityIn = interpolate(frame, [0, RUNNING_MAP_OVERLAP - 4], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const opacityOut = interpolate(frame, [dur - MAP_NAVI_OVERLAP, dur - 2], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <AbsoluteFill style={{ opacity: Math.min(opacityIn, opacityOut) }}>
      <Scene6Map />
    </AbsoluteFill>
  );
};

const NaviLayer: React.FC = () => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, MAP_NAVI_OVERLAP - 4], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <AbsoluteFill style={{ opacity }}>
      <Scene7Navi />
    </AbsoluteFill>
  );
};

export const KokudoDemoVideo: React.FC = () => {
  const hookStart = 0;
  const problemStart = hookStart + sceneFrames('hook');
  const turnStart = problemStart + sceneFrames('problem');
  const homeStart = turnStart + sceneFrames('turn');
  const runningStart = homeStart + sceneFrames('home');
  const mapStart = runningStart + sceneFrames('running') - RUNNING_MAP_OVERLAP;
  const naviStart = mapStart + sceneFrames('map') - MAP_NAVI_OVERLAP;
  const closingStart = naviStart + sceneFrames('navi');

  // 修正4対応: 39秒以降(Scene7/8)のDC帯ノイズが原因究明できないまま何度も再発したため、
  // 該当区間のBGM自体を完全に削除し、ナレーションのみのシンプルな構成にした。
  return (
    <div style={{ fontFamily: fonts.body, width: '100%', height: '100%' }}>
      <Sequence from={hookStart} durationInFrames={sceneFrames('hook')}>
        <Scene1Hook />
      </Sequence>
      <Sequence from={problemStart} durationInFrames={sceneFrames('problem')}>
        <Scene2Problem />
      </Sequence>
      <Sequence from={turnStart} durationInFrames={sceneFrames('turn')}>
        <Scene3Turn />
      </Sequence>
      <Sequence from={homeStart} durationInFrames={sceneFrames('home')}>
        <Scene4Home />
      </Sequence>
      <Sequence from={runningStart} durationInFrames={sceneFrames('running')}>
        <RunningLayer />
      </Sequence>
      <Sequence from={mapStart} durationInFrames={sceneFrames('map')}>
        <MapLayer />
      </Sequence>
      <Sequence from={naviStart} durationInFrames={sceneFrames('navi')}>
        <NaviLayer />
      </Sequence>
      <Sequence from={closingStart} durationInFrames={sceneFrames('closing')}>
        <Scene8Closing />
      </Sequence>
    </div>
  );
};
