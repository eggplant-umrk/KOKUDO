import { Config } from '@remotion/cli/config';

Config.setVideoImageFormat('jpeg');
Config.setOverwriteOutput(true);

// 16:9横型を既定にしている。ピッチ資料のスライド(Slide 9)に埋め込んで
// プロジェクター投影する用途が主目的のため。スマホ画面自体は動画内で
// 縦長のモックアップとして中央に配置する(src/scenes参照)。
