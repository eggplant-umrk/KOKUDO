import React from 'react';
import { colors } from '../theme';

/**
 * スマホ画面のモックアップ枠。動画内でアプリ画面を「再現」して見せる際の共通フレーム。
 * Linear/Notion系のプロダクト動画に倣い、生のスクリーン録画ではなく
 * モーショングラフィックスとして画面を再構築する方針(演出テクニック: docs/pitch/README参照)。
 *
 * フィードバック4対応: 正面固定の配置をやめ、3D的な傾き(rotateX/Y/Z)を
 * 各シーンから指定できるようにした。Nike Run Club/Apple Fitness+のプロモ動画で
 * 使われる「製品を斜めに置いて奥行きを出す」演出を参照(README参照)。
 *
 * 2レビュー統合対応(最優先項目、デバイスの物理的な実在感): ダークモードのUIが
 * 背景に溶け込み、スマホの境界が曖昧に見えるとの指摘。外側の黒ベゼルの内側に
 * 1.5px・白15%のインナーストロークを追加し、ガラス/金属エッジが光を反射している
 * ような質感を全編のPhoneFrameに一括適用した(boxShadowのinset併用)。
 */
export const PhoneFrame: React.FC<{
  children: React.ReactNode;
  rotateY?: number;
  rotateX?: number;
  rotateZ?: number;
  scale?: number;
  glow?: string;
}> = ({ children, rotateY = 0, rotateX = 0, rotateZ = 0, scale = 1, glow }) => {
  return (
    <div
      style={{
        width: 450,
        height: 900,
        borderRadius: 56,
        border: `12px solid ${colors.textPrimary}`,
        backgroundColor: colors.bgSurface,
        overflow: 'hidden',
        boxShadow: [
          glow ? `0 40px 90px rgba(0,0,0,0.45), 0 0 60px ${glow}` : '0 40px 90px rgba(0,0,0,0.45)',
          'inset 0 0 0 1.5px rgba(255,255,255,0.15)',
          'inset 0 1px 0 rgba(255,255,255,0.22)',
        ].join(', '),
        position: 'relative',
        transform: `perspective(1800px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) rotateZ(${rotateZ}deg) scale(${scale})`,
        transformStyle: 'preserve-3d',
      }}
    >
      {children}
    </div>
  );
};
