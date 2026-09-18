import React from 'react';
import { interpolate } from 'remotion';
import { colors } from '../theme';

/**
 * 走行軌跡のミニマップ表現。Strava Year in Sportのライン表現を参照し、
 * シンプルな1本の折れ線をネオンブルーで発光させながら伸ばす。
 * progress: 0(未走行)〜1(全区間走破)
 */
const PATH = 'M 20 140 C 60 100, 40 60, 90 50 S 160 20, 190 40';
const PATH_LENGTH = 220; // 概算値(実測ではなく視覚効果として十分な近似値)

export const TrailLine: React.FC<{ progress: number }> = ({ progress }) => {
  const dashOffset = interpolate(progress, [0, 1], [PATH_LENGTH, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <svg width="210" height="160" viewBox="0 0 210 160" style={{ overflow: 'visible' }}>
      {/* ベースの薄い道路ライン(未走行区間の示唆) */}
      <path d={PATH} stroke={colors.textSecondary} strokeWidth={3} fill="none" opacity={0.25} />
      {/* 走破済み区間(発光するネオンブルー) */}
      <path
        d={PATH}
        stroke={colors.routeNeonBlue}
        strokeWidth={4}
        fill="none"
        strokeLinecap="round"
        strokeDasharray={PATH_LENGTH}
        strokeDashoffset={dashOffset}
        style={{ filter: `drop-shadow(0 0 6px ${colors.routeNeonBlue})` }}
      />
      {/* 現在地点のドット */}
      {progress > 0 && (
        <circle
          cx={20 + progress * 170}
          cy={140 - progress * 100}
          r={5}
          fill={colors.white}
          stroke={colors.routeNeonBlue}
          strokeWidth={2}
        />
      )}
    </svg>
  );
};
