import React from 'react';
import { colors } from '../theme';

/**
 * 簡易日本地図シルエット。正確な地理データではなく、弓なりの列島形状を
 * 近似したプレースホルダーグラフィック。本実装ではMapLibreの実キャプチャや
 * より精緻なSVG地図データへの差し替えを想定(README参照)。
 */
const JAPAN_PATH =
  'M 40 10 L 55 25 L 50 45 L 65 55 L 60 80 L 75 95 L 68 120 L 80 140 L 70 165 L 55 175 ' +
  'L 45 195 L 30 190 L 35 165 L 25 150 L 35 130 L 20 115 L 32 95 L 22 75 L 35 60 L 28 40 L 40 10 Z';

export const JapanMapSilhouette: React.FC<{ children?: React.ReactNode }> = ({ children }) => {
  return (
    <svg width="200" height="420" viewBox="0 0 100 210" style={{ overflow: 'visible' }}>
      <path d={JAPAN_PATH} fill={colors.bgSurfaceRaised} stroke={colors.routeSignBlueLight} strokeWidth={1.5} />
      {children}
    </svg>
  );
};

/** 地図上の1マーカー(路線起点)。色はステータスに応じて呼び出し側で指定。 */
export const MapMarker: React.FC<{ cx: number; cy: number; color: string; scale?: number }> = ({
  cx,
  cy,
  color,
  scale = 1,
}) => (
  <circle
    cx={cx}
    cy={cy}
    r={5 * scale}
    fill={color}
    stroke={colors.white}
    strokeWidth={1.5}
    style={{ filter: `drop-shadow(0 0 4px ${color})` }}
  />
);
