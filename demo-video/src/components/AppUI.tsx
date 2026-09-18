import React from 'react';
import { colors } from '../theme';

/**
 * フィードバック3対応: 抽象的なモーショングラフィックスだけでなく、実アプリの
 * UIコンポーネント(StatTile/AppProgressBar/GradientButton/RouteCard等、
 * app/lib/widgets/配下)の配色・角丸・余白を忠実に再現した部品群。
 * flutter run -d chromeでの実機スクリーンショット取得はブラウザ自動操作が
 * この環境のセキュリティ制約でブロックされたため実施できず、代わりに
 * 実ウィジェットのソースコード(色・寸法・文言)を1行ずつ読んで再現する方針を採った。
 */

export const StatChip: React.FC<{
  label: string;
  value: string;
  dark?: boolean;
  valueSize?: number;
  /** 0-1: 2レビュー統合対応(空白区間の解消)。順番にスポットライトするための強調 */
  emphasize?: number;
}> = ({ label, value, dark = false, valueSize = 20, emphasize = 0 }) => (
  <div
    style={{
      padding: '11px 14px',
      borderRadius: 12,
      backgroundColor: dark ? 'rgba(255,255,255,0.06)' : colors.bgSurfaceRaised,
      border:
        emphasize > 0.25
          ? `1px solid rgba(47,169,255,${0.35 + emphasize * 0.5})`
          : `1px solid ${dark ? 'rgba(255,255,255,0.14)' : colors.borderSubtle}`,
      boxShadow: emphasize > 0.25 ? `0 0 ${14 * emphasize}px rgba(47,169,255,${0.4 * emphasize})` : undefined,
      transform: `scale(${1 + emphasize * 0.06})`,
    }}
  >
    <div style={{ fontSize: 11, fontWeight: 600, color: dark ? 'rgba(255,255,255,0.5)' : colors.textSecondary }}>
      {label}
    </div>
    <div style={{ fontSize: valueSize, fontWeight: 900, color: dark ? colors.white : colors.textPrimary, marginTop: 4 }}>
      {value}
    </div>
  </div>
);

export const Pill: React.FC<{ label: string; tone?: 'default' | 'gold' | 'active' }> = ({ label, tone = 'default' }) => {
  const styles =
    tone === 'gold'
      ? { bg: 'rgba(255,178,56,0.14)', border: 'rgba(255,178,56,0.3)', text: colors.accentGoldText }
      : tone === 'active'
        ? { bg: colors.routeSignBlue, border: colors.routeSignBlue, text: colors.white }
        : { bg: colors.bgSurfaceRaised, border: colors.borderSubtle, text: colors.textSecondary };
  return (
    <div
      style={{
        padding: '7px 12px',
        borderRadius: 999,
        backgroundColor: styles.bg,
        border: `1px solid ${styles.border}`,
        color: styles.text,
        fontSize: 12,
        fontWeight: 700,
        display: 'inline-block',
      }}
    >
      {label}
    </div>
  );
};

export const ProgressBar: React.FC<{ ratio: number; height?: number; color?: string; track?: string }> = ({
  ratio,
  height = 8,
  color,
  track = '#E3EEF3',
}) => (
  <div style={{ height, borderRadius: 999, backgroundColor: track, overflow: 'hidden' }}>
    <div
      style={{
        width: `${Math.max(0, Math.min(1, ratio)) * 100}%`,
        height: '100%',
        background: color ?? `linear-gradient(135deg, ${colors.routeSignBlueLight}, ${colors.routeSignBlue})`,
      }}
    />
  </div>
);

export const GradientCTA: React.FC<{ label: string; height?: number }> = ({ label, height = 54 }) => (
  <div
    style={{
      height,
      borderRadius: 999,
      background: `linear-gradient(135deg, ${colors.routeSignBlueLight}, ${colors.routeSignBlue})`,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      color: colors.white,
      fontSize: 17,
      fontWeight: 900,
      boxShadow: '0 14px 28px rgba(34,88,142,0.38)',
    }}
  >
    <PlayGlyph /> <span style={{ marginLeft: 8 }}>{label}</span>
  </div>
);

const PlayGlyph: React.FC = () => (
  <svg width="14" height="14" viewBox="0 0 24 24" fill={colors.white}>
    <path d="M8 5v14l11-7z" />
  </svg>
);

export const RouteBadge: React.FC<{ text: string }> = ({ text }) => (
  <div
    style={{
      padding: '5px 12px',
      borderRadius: 12,
      backgroundColor: colors.routeSignBlue,
      border: '1.5px solid rgba(255,255,255,0.85)',
      color: colors.white,
      fontWeight: 900,
      fontSize: 16,
      boxShadow: '0 6px 16px rgba(10,30,55,0.35)',
      display: 'inline-block',
    }}
  >
    {text}
  </div>
);

export const RouteMiniCard: React.FC<{
  number: string;
  name: string;
  meta: string;
  ratio: number;
  status: 'notStarted' | 'inProgress' | 'completed';
  /** 0-1: このカード単体にスポットライト的なグローを当てる(Scene6の完走カタルシス用) */
  glow?: number;
}> = ({ number, name, meta, ratio, status, glow = 0 }) => {
  const badgeBg =
    status === 'completed' ? colors.accentGold : status === 'inProgress' ? undefined : colors.routeInactive;
  const badgeGradient =
    status === 'inProgress' ? `linear-gradient(135deg, ${colors.routeSignBlueLight}, ${colors.routeSignBlue})` : undefined;
  const badgeText = status === 'completed' ? '#4A2F00' : colors.white;
  const barColor = status === 'completed' ? colors.accentGold : status === 'inProgress' ? colors.routeSignBlue : colors.routeInactive;

  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 10,
        padding: '9px 12px',
        borderRadius: 20,
        backgroundColor: colors.bgSurfaceRaised,
        border: glow > 0 ? `1px solid rgba(255,178,56,${0.3 + glow * 0.7})` : `1px solid ${colors.borderSubtle}`,
        boxShadow: glow > 0 ? `0 0 ${18 * glow}px rgba(255,178,56,${0.55 * glow})` : undefined,
        transform: `scale(${1 + glow * 0.04})`,
      }}
    >
      <div
        style={{
          width: 38,
          height: 38,
          minWidth: 38,
          borderRadius: 10,
          background: badgeGradient ?? badgeBg,
          color: badgeText,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: 10,
          fontWeight: 900,
          textAlign: 'center',
          lineHeight: 1.1,
        }}
      >
        国道
        <br />
        {number}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <div style={{ fontSize: 13, fontWeight: 700, color: colors.textPrimary, whiteSpace: 'nowrap' }}>{name}</div>
          {status === 'completed' && (
            <div
              style={{
                fontSize: 9,
                fontWeight: 800,
                color: colors.accentGoldText,
                backgroundColor: 'rgba(255,178,56,0.18)',
                borderRadius: 999,
                padding: '2px 6px',
              }}
            >
              完走
            </div>
          )}
        </div>
        <div style={{ fontSize: 10, color: colors.textTertiary, marginTop: 1 }}>{meta}</div>
        <div style={{ marginTop: 5 }}>
          <ProgressBar ratio={ratio} height={4} color={barColor} />
        </div>
      </div>
      <div style={{ fontSize: 12, fontWeight: 900, color: colors.textSecondary }}>{Math.round(ratio * 100)}%</div>
    </div>
  );
};

/** カード下段の1数字だけをスポットライト表示するための補助スパン(GoalCard用)。 */
const StatSpan: React.FC<{ active: number; children: React.ReactNode }> = ({ active, children }) => (
  <span
    style={{
      display: 'inline-block',
      transform: `scale(${1 + active * 0.4})`,
      color: active > 0.25 ? colors.routeSignBlue : undefined,
      fontWeight: active > 0.25 ? 800 : undefined,
      textShadow: active > 0.25 ? `0 0 ${10 * active}px rgba(34,88,142,0.5)` : undefined,
    }}
  >
    {children}
  </span>
);

/** ホーム画面のGoalSpeechBubble(吹き出し型の逆算ナビカード)を再現。
 *  emphasize系(0-1): 改善3対応+2レビュー統合対応(項目3)。注目させたい数字を
 *  順番にスポットライト表示し、「空白」を「数字が積み上がる過程」として見せる。 */
export const GoalCard: React.FC<{
  remainingKm: string;
  dailyKm: string;
  pct: string;
  ratio: number;
  kmToday: string;
  kmTotal: string;
  emphasize?: number;
  emphasizePct?: number;
  emphasizeKmToday?: number;
  emphasizeKmTotal?: number;
}> = ({
  remainingKm,
  dailyKm,
  pct,
  ratio,
  kmToday,
  kmTotal,
  emphasize = 0,
  emphasizePct = 0,
  emphasizeKmToday = 0,
  emphasizeKmTotal = 0,
}) => (
  <div
    style={{
      padding: '14px 16px',
      borderRadius: 20,
      backgroundColor: 'rgba(255,255,255,0.95)',
      boxShadow: '0 10px 26px rgba(20,40,56,0.22)',
      position: 'relative',
    }}
  >
    <div style={{ fontSize: 14, lineHeight: 1.55, fontWeight: 500, color: colors.textPrimary }}>
      あと
      <span
        style={{
          color: colors.accentGoldText,
          fontWeight: 900,
          display: 'inline-block',
          transformOrigin: 'left center',
          transform: `scale(${1 + emphasize * 0.2})`,
        }}
      >
        {remainingKm}
      </span>
      ！ 1日
      <span style={{ color: colors.accentGoldText, fontWeight: 900 }}>{dailyKm}</span>ペースで一緒に頑張ろう
    </div>
    <div style={{ marginTop: 8 }}>
      <ProgressBar ratio={ratio} height={6} />
    </div>
    <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8 }}>
      <div style={{ fontSize: 11, fontWeight: 800, color: colors.routeSignBlue }}>
        <StatSpan active={emphasizePct}>{pct}%</StatSpan> 完了
      </div>
      <div style={{ fontSize: 11, color: colors.textSecondary }}>
        <StatSpan active={emphasizeKmToday}>{kmToday}</StatSpan> / <StatSpan active={emphasizeKmTotal}>{kmTotal}</StatSpan>
      </div>
    </div>
    <div
      style={{
        position: 'absolute',
        bottom: -7,
        left: '50%',
        transform: 'translateX(-50%) rotate(45deg)',
        width: 14,
        height: 14,
        backgroundColor: 'rgba(255,255,255,0.95)',
        borderRadius: 3,
      }}
    />
  </div>
);
