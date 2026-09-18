import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors } from '../theme';

/**
 * 1周目レビューで追加: 4つの機能デモ(ホーム/ランニング/地図/ナビ)が
 * 単なる機能紹介の羅列に見えないよう、画面下部に「一続きの道のり」を
 * 示す進捗ドットを常時表示する。Strava Year in Sportのライン表現を参照し、
 * シンプルな図形(線+ドット)でストーリーの連続性を可視化する。
 *
 * AIっぽさレビュー2周目で発見: `transition: width 0.3s`はRemotionの
 * フレーム単位レンダリングでは何も作用しない死んだコードだった(CSS
 * transitionはリアルタイム再生用のプロパティで、静止画を1枚ずつ書き出す
 * サーバーサイドレンダリングでは意味を持たない)。springで実際に
 * アクティブなドットが伸びる動きを実装し直した。
 *
 * step: 1=ホーム, 2=ランニング, 3=地図, 4=ナビ
 */
export const JourneyProgress: React.FC<{ step: 1 | 2 | 3 | 4 }> = ({ step }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const grow = spring({ frame, fps, config: { damping: 14, stiffness: 120 } });
  const activeWidth = interpolate(grow, [0, 1], [8, 22]);

  return (
    <div
      style={{
        position: 'absolute',
        bottom: 48,
        left: '50%',
        transform: 'translateX(-50%)',
        display: 'flex',
        alignItems: 'center',
        gap: 10,
      }}
    >
      {[1, 2, 3, 4].map((i) => (
        <div
          key={i}
          style={{
            width: i === step ? activeWidth : 8,
            height: 8,
            borderRadius: 4,
            backgroundColor: i <= step ? colors.routeNeonBlue : 'rgba(255,255,255,0.3)',
          }}
        />
      ))}
    </div>
  );
};
