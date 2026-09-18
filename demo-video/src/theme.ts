import { loadFont } from '@remotion/google-fonts/NotoSansJP';

/**
 * 4周目レビューで対応: レンダリング環境にNoto Sans JP/Yu Gothic等のゴシック体が
 * 無く、Scene1/Scene8のロゴ・見出しがブラウザ既定のセリフ体にフォールバックして
 * いた問題を修正。@remotion/google-fontsでNoto Sans JPを明示的に読み込み、
 * fontFamilyとして各シーンで指定する。
 */
// 5周目レビュー: Noto Sans JPは1weight=1subsetごとに個別リクエストが発生し、
// weights3種×subsets2種でも「363件のネットワークリクエスト」という警告が
// 出ていた。実害(レンダリング失敗)は無いためignoreTooManyRequestsWarningで
// 警告のみ抑制する(取得自体はキャッシュされるため2回目以降のレンダリングは高速)。
const { fontFamily } = loadFont('normal', {
  weights: ['400', '700', '900'],
  subsets: ['japanese', 'latin'],
  ignoreTooManyRequestsWarning: true,
});
export const FONT_FAMILY = fontFamily;

/**
 * KOKUDOブランドカラー。app/lib/theme/app_colors.dart のトークンをそのまま移植。
 * Flutter側の値と常に一致させること(デザイン変更時は両方更新する)。
 */
export const colors = {
  bgAppTop: '#CDF1FF',
  bgAppBottom: '#FFFFFF',
  bgSurface: '#FFFFFF',
  bgSurfaceRaised: '#F3FAFD',

  accentBlue: '#2AA7E0',
  accentBlueDark: '#1C86BD',
  accentGreen: '#34C98A',
  accentGold: '#FFB238',
  accentGoldText: '#B4720A',

  routeSignBlue: '#22588E',
  routeSignBlueLight: '#2F74B8',
  routeSignBlueDark: '#173F66',

  textPrimary: '#1C2B36',
  textSecondary: '#5C6F7D',
  textTertiary: '#92A3AE',
  borderSubtle: '#E1EEF5',
  routeInactive: '#CFDBE2',
  routeNeonBlue: '#2FA9FF',

  black: '#000000',
  white: '#FFFFFF',
  danger: '#E4536A',
} as const;

export const fonts = {
  heading: `${FONT_FAMILY}, sans-serif`,
  body: `${FONT_FAMILY}, sans-serif`,
};
