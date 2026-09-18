import React from 'react';
import { staticFile } from 'remotion';
import { colors } from '../theme';

/**
 * 修正1対応(2回目): 実アプリのjapan_map_panel.dartはMapLibre GL(Web地図タイル)を
 * 描画しており動画レンダリングでの再現は非現実的なため、モックとして
 * 精緻な日本地図SVG(geolonia/japanese-prefectures, GFDL、Wikipediaの日本地図.svgを
 * 元にした都道府県別SVG)をオレンジ系配色に変更して使用する。
 * 出典: https://github.com/geolonia/japanese-prefectures (GFDL)
 * public/assets/japan-map.svg に fill/strokeをオレンジ系へ置換して配置済み。
 *
 * マーカー・地方ラベルは、この画像(viewBox 0 0 1000 1000、外側matrix変換込み)上の
 * 実座標をNode.jsスクリプトで都道府県ごとのtranslate値から地方ごとに平均して算出した
 * パーセンテージ座標を使い、position:absoluteでオーバーレイする(以前のSVG circle/g
 * ベースの実装から、img+div オーバーレイ方式に変更)。
 */
/* 修正対応(2回目): 前回は各地方の全都道府県translate座標の単純平均を使っていたが、
   中部地方は新潟・富山等の北寄りの県が平均を北へ強く引っ張り(top=54)、実際の
   代表的位置(名古屋)よりかなり北(=関東に近い緯度)に表示されてしまい、結果として
   「近畿が関東寄りに見える」という指摘につながっていた。今回は地方ごとに地理的に
   代表的な1県(県庁所在地の都道府県、地方の中心)のtranslate座標をそのまま使い、
   北→南・東→西の実際の位置関係を正しく再現する。代表県: 東北=宮城(仙台)、
   関東=東京、中部=愛知(名古屋)、近畿=大阪、中国=岡山、四国=香川(高松)、
   九州=熊本。北海道のみtranslateがbbox起点で北端に寄るため、視覚的重心へ
   手動オフセット。ラベル同士が重ならないよう微調整済み。 */
/* 修正対応(4回目): 「関東」(51,59)と「中部」(43,58)が経度差8・緯度差1しかなく
   隣接して読みにくかったため、関東をさらに北へ、中部をさらに南西へ離して
   ラベル同士が重ならないようにした。 */
export const REGION_POSITIONS: Record<string, { left: number; top: number }> = {
  hokkaido: { left: 57.8, top: 13 },
  tohoku: { left: 64, top: 41 },
  kanto: { left: 55, top: 52 },
  chubu: { left: 40, top: 62 },
  kinki: { left: 35, top: 70 },
  chugoku: { left: 24, top: 66 },
  shikoku: { left: 28, top: 76 },
  kyushu: { left: 8, top: 80 },
};

const REGION_LABELS: Record<string, string> = {
  hokkaido: '北海道',
  tohoku: '東北',
  kanto: '関東',
  chubu: '中部',
  kinki: '近畿',
  chugoku: '中国',
  shikoku: '四国',
  kyushu: '九州',
};

/** モック用の完走マーカー(オレンジの丸)を各地方に複数配置し、地図に賑やかさを持たせる。
 *  固定シードの配置(Math.randomは使わない、決定的レンダリングのため)。 */
const MOCK_COMPLETED_DOTS: { left: number; top: number }[] = [
  { left: 60, top: 42 },
  { left: 62.5, top: 46 },
  { left: 56, top: 63 },
  { left: 59, top: 66 },
  { left: 47, top: 56 },
  { left: 41, top: 60 },
  { left: 38, top: 70 },
  { left: 33, top: 66 },
  { left: 22, top: 68 },
  { left: 16, top: 63 },
  { left: 27, top: 80 },
  { left: 9, top: 68 },
  { left: 5, top: 64 },
];

export const JapanMapSilhouette: React.FC<{ children?: React.ReactNode; showLabels?: boolean; showMockDots?: boolean }> = ({
  children,
  showLabels = true,
  showMockDots = true,
}) => {
  return (
    <div style={{ position: 'relative', width: 200, height: 200 }}>
      <img
        src={staticFile('assets/japan-map.svg')}
        style={{ width: '100%', height: '100%', objectFit: 'contain', display: 'block' }}
        alt="japan-map"
      />
      {showLabels &&
        Object.entries(REGION_POSITIONS).map(([key, pos]) => (
          <div
            key={key}
            style={{
              position: 'absolute',
              left: `${pos.left}%`,
              top: `${pos.top}%`,
              transform: 'translate(-50%, -50%)',
              fontSize: 7,
              fontWeight: 800,
              color: '#7A4200',
              textShadow: '0 0 3px rgba(255,255,255,0.95), 0 0 3px rgba(255,255,255,0.95)',
              pointerEvents: 'none',
              whiteSpace: 'nowrap',
            }}
          >
            {REGION_LABELS[key]}
          </div>
        ))}
      {showMockDots &&
        MOCK_COMPLETED_DOTS.map((d, i) => (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: `${d.left}%`,
              top: `${d.top}%`,
              transform: 'translate(-50%, -50%)',
              width: 4,
              height: 4,
              borderRadius: '50%',
              background: colors.accentGold,
              opacity: 0.75,
              boxShadow: `0 0 2px ${colors.accentGold}`,
            }}
          />
        ))}
      {children}
    </div>
  );
};

/** 地図上の1マーカー(路線起点)。leftPct/topPctは地図画像に対するパーセンテージ座標。
 *  色はステータスに応じて呼び出し側で指定。 */
export const MapMarker: React.FC<{ leftPct: number; topPct: number; color: string; scale?: number }> = ({
  leftPct,
  topPct,
  color,
  scale = 1,
}) => (
  <div
    style={{
      position: 'absolute',
      left: `${leftPct}%`,
      top: `${topPct}%`,
      transform: `translate(-50%, -50%) scale(${scale})`,
      width: 10,
      height: 10,
      borderRadius: '50%',
      background: color,
      border: `1.5px solid ${colors.white}`,
      boxShadow: `0 0 4px ${color}`,
    }}
  />
);
