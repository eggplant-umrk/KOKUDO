/**
 * シーン尺の一元管理。02_demo-video-script.md のタイムラインと対応。
 * fps=30。合計約53.9秒(2人のレビュアーの指摘を統合した再編集、第2ラウンド)。
 *
 * 主な変更(今回の2レビュー統合ラウンド):
 * - hook: 1.5秒→1.2秒(個別指摘: 冒頭をさらに圧縮)
 * - problem/turn: 変更なし
 * - home/map/navi: 尺は変更なし(内部構成の再設計で対応)
 * - running: 5秒→6秒(「走る→地図になる」因果接続モーションの尺を確保するため
 *   わずかに延長。浮いた時間は他のシーンではなくこの接続モーション自体に使う)
 * - closing: 変更なし
 *
 * RUNNING_MAP_OVERLAP: Scene5(ランニング)→Scene6(地図)の間だけ、カット割りではなく
 * 連続したモーションに見せるため、Video.tsx側でこの2シーンをオーバーラップさせて
 * クロスフェードしている(Seriesの単純な連結ではなくSequenceで手動配置)。
 * そのため合計フレーム数は単純な足し算より短くなる(TOTAL_FRAMES_WITH_OVERLAP)。
 *
 * ここを変更したら docs/pitch/02_demo-video-script.md 側の表も合わせて更新すること。
 */
export const FPS = 30;

export const SCENE_SECONDS = {
  hook: 1.2, // Scene1: フック(ロゴ)
  problem: 2, // Scene2: 課題提起
  turn: 2.5, // Scene3: 転換
  home: 15, // Scene4: ホーム画面デモ
  running: 6, // Scene5: ランニング計測デモ(因果接続モーションの尺を確保し5→6秒)
  map: 14, // Scene6: 実地図デモ(主役シーン。尺は維持)
  navi: 10, // Scene7: 逆算ナビデモ(尺は維持)
  closing: 4, // Scene8: クロージング
} as const;

/** Scene5→Scene6のクロスフェード・オーバーラップ幅(フレーム数、1.2秒)。
 *  レビュー統合対応(黒→白の輝度ジャンプ解消): 0.8秒では黒背景(ランニング)から
 *  白/水色主体の地図パネルへの色調変化を吸収しきれないとの指摘を受け、36フレームに延長した */
export const RUNNING_MAP_OVERLAP = 36;
/** Scene6→Scene7のオーバーラップ幅(フレーム数、0.67秒)。完走の進捗バーが
 *  逆算ナビの進捗バーへ変形するモーフィングのための重なり */
export const MAP_NAVI_OVERLAP = 20;

export const SCENE_ORDER = [
  'hook',
  'problem',
  'turn',
  'home',
  'running',
  'map',
  'navi',
  'closing',
] as const;

export type SceneKey = (typeof SCENE_ORDER)[number];

export const sceneFrames = (key: SceneKey): number => Math.round(SCENE_SECONDS[key] * FPS);

export const TOTAL_SECONDS = SCENE_ORDER.reduce((sum, k) => sum + SCENE_SECONDS[k], 0);
export const TOTAL_FRAMES = SCENE_ORDER.reduce((sum, k) => sum + sceneFrames(k), 0);
/** 実際の再生尺(Scene5/6・Scene6/7のオーバーラップ分を引いたもの)。Root.tsxのComposition尺に使う */
export const TOTAL_FRAMES_WITH_OVERLAP = TOTAL_FRAMES - RUNNING_MAP_OVERLAP - MAP_NAVI_OVERLAP;

/** 指定シーンの開始フレーム(絶対フレーム番号)を返す。Video.tsx側でシーン横断のAudio配置に使う。 */
export const sceneStartFrame = (key: SceneKey): number => {
  const idx = SCENE_ORDER.indexOf(key);
  return SCENE_ORDER.slice(0, idx).reduce((sum, k) => sum + sceneFrames(k), 0);
};
