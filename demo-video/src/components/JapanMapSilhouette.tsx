import React from 'react';
import { colors } from '../theme';

/**
 * 修正2対応: japan_map_panel.dart は実際にはMapLibre GL(Web地図タイル)を描画しており、
 * 動画レンダリング(ヘッドレスブラウザでの1585フレーム連続キャプチャ)で外部タイル
 * サーバーに依存するのは非現実的なため、地理的特徴(本州の弓なり・瀬戸内海のくびれ・
 * 四国/九州/北海道の分離)を保ったSVGシルエットで近似する。以前の単一pathの
 * プレースホルダーから、4つの島(本州・四国・九州・北海道)に分けて再設計。
 * viewBox(0 0 100 210)とマーカー座標系はFOCUS_MARKERS/MINOR_MARKERS(Scene6Map.tsx)
 * との互換性のため維持している。
 */
const HONSHU_PATH =
  'M 58 12 L 70 28 L 74 50 L 80 78 L 72 96 L 60 108 L 44 118 L 28 122 ' +
  'L 24 115 L 38 104 L 48 88 L 42 66 L 36 42 L 30 20 L 46 10 Z';
const SHIKOKU_PATH = 'M 42 128 L 55 125 L 62 133 L 58 142 L 45 145 L 38 138 Z';
const KYUSHU_PATH = 'M 15 145 L 28 140 L 35 150 L 32 168 L 20 178 L 10 170 L 12 155 Z';
const HOKKAIDO_PATH = 'M 55 -8 L 68 -10 L 75 2 L 70 15 L 58 18 L 50 8 Z';

export const JapanMapSilhouette: React.FC<{ children?: React.ReactNode }> = ({ children }) => {
  const islandProps = {
    fill: colors.bgSurfaceRaised,
    stroke: colors.routeSignBlueLight,
    strokeWidth: 1.5,
  };
  return (
    <svg width="200" height="420" viewBox="0 0 100 210" style={{ overflow: 'visible' }}>
      <path d={HOKKAIDO_PATH} {...islandProps} />
      <path d={HONSHU_PATH} {...islandProps} />
      <path d={SHIKOKU_PATH} {...islandProps} />
      <path d={KYUSHU_PATH} {...islandProps} />
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
