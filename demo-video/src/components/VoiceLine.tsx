import React from 'react';
import { Audio, Sequence, staticFile } from 'remotion';

/**
 * 改善5対応: VOICEVOX(玄野武宏・ノーマル)で生成したナレーション
 * 音声(public/audio/*.wav)をシーン内の指定フレームから再生する。
 * from はシーンローカルのフレーム番号(台本の発話タイミングに合わせて各Sceneから指定)。
 *
 * 音量バランス対応(「うるさい」との指摘): VOICEVOXの出力は元々ほぼフルスケール
 * (ピーク-3〜-10dB程度)で書き出されており、無音区間(BGM/SEも鳴っていない静かな
 * 間)との音量差が大きく、ナレーションが入るたびに音量が跳ね上がるように感じられていた。
 * volume=0.65をかけて全体のダイナミックレンジを縮め、聞き疲れしにくいバランスにした。
 */
export const VoiceLine: React.FC<{ id: string; from: number }> = ({ id, from }) => (
  <Sequence from={from} layout="none">
    <Audio src={staticFile(`audio/${id}.wav`)} volume={0.65} />
  </Sequence>
);
