# KOKUDO デモ動画(Remotion)

100 Program FINAL WEEK 予選ピッチ、Part3「解決策」内で使用するデモ動画(約52.8秒/1585フレーム@30fps)。
**レンダリング済み。ナレーション音声(VOICEVOX)入り。** 出力: `out/kokudo-demo.mp4`(= `../docs/pitch/KOKUDO_demo.mp4` と同一)。

Scene5(ランニング)→Scene6(地図)、Scene6(地図)→Scene7(逆算ナビ)の2箇所は、`Series`の
ハードカットではなく`Sequence`を手動配置したクロスフェードになっている
(`src/durations.ts`の`RUNNING_MAP_OVERLAP`(1.2秒、黒→白の輝度ジャンプ解消のため0.8秒から延長)・
`MAP_NAVI_OVERLAP`(0.67秒)、`src/Video.tsx`参照)。そのため合計フレーム数は
各シーン尺の単純合計より56フレーム短い。

Scene7の逆算ナビ・クローズアップは、PhoneFrameを常時マウントしたままbackdrop-blur+
減光で背景として残し、カードをその手前にポップアップさせる構成(旧: ハードカットで
背景ごと入れ替え)。

対応する台本: [`../docs/pitch/02_demo-video-script.md`](../docs/pitch/02_demo-video-script.md)

## 構成

```
src/
  index.ts        Remotionエントリーポイント
  Root.tsx         Composition登録(KokudoDemo, 1920x1080, 30fps, フレーム数はdurations.tsから算出)
  Video.tsx        各シーンを<Sequence>で配置する本体(Scene5→6は0.8秒、Scene6→7は0.67秒オーバーラップ)
  durations.ts     シーン尺の一元管理(秒数と台本を対応させる唯一のソース)
  theme.ts         Flutter側 app_colors.dart から移植したブランドカラー
  components/
    PhoneFrame.tsx          スマホ画面モックアップの共通フレーム(450x960)
    JourneyProgress.tsx     Scene4-7で一貫表示する進捗ドット
    Caption.tsx             ナレーションの補助テロップ(短い字幕、38px)
    TapRipple.tsx           タップ位置に指先+波紋を出す「手元感」演出
    Vignette.tsx            注目させたい数字の周辺を減光するビネット
    VoiceLine.tsx           VOICEVOX音声(public/audio/*.wav)をシーン内の指定フレームから再生
    TrailLine.tsx           Scene5の走行軌跡ライン(SVG, strokeDashoffsetで伸長)
    JapanMapSilhouette.tsx  Scene6の簡易日本地図シルエット+マーカー
  scenes/
    Scene1Hook.tsx      0:00-0:01.2 ロゴ登場(六角形SVGパスアニメーション)
    Scene2Problem.tsx   0:01.2-0:03.2 課題提起(一文+伸びていく軌跡ライン)
    Scene3Turn.tsx      0:03.2-0:05.7 転換(ワイプ+軌跡ラインの完成)
    Scene4Home.tsx      0:05.7-0:20.7 ホーム画面デモ(3数字の順番スポットライト)
    Scene5Running.tsx   0:20.7-0:26.7 ランニング計測デモ(連続カウントアップ+Scene6への因果接続モーション)
    Scene6Map.tsx       0:26.7-0:39.1 実地図デモ(主役シーン。着地ポップ+ゴールド化のライトスイープ/パーティクル)
    Scene7Navi.tsx      0:39.1-0:49.1 逆算ナビデモ(進捗バーのモーフィング→拡大カードへのハードカット、3数字を順番にスポットライト)
    Scene8Closing.tsx   0:49.1-0:53.2 クロージング(キャッチコピーの再強調で終える。CTA文言・VOICEVOXクレジットは廃止)
scripts/
  generate-voice.js     VOICEVOX ENGINE(Docker, localhost:50021)でナレーション音声を生成するスクリプト
public/audio/            生成されたナレーションWAVファイル(s2, s3, s4_1, s4_2, ...)
```

## 実行方法

```bash
cd demo-video
npm install
npm run start      # Remotion Studioでプレビュー
npm run render      # out/kokudo-demo.mp4 へ書き出し(このコマンドで再レンダリング可能)
```

## 設計方針(大規模改訂版)

- **画面は録画ではなく再現するが、実ウィジェットに忠実に**: `flutter run -d chrome`での実機スクリーンショット取得を試みたが、この制作環境ではブラウザ自動操作(localhost navigation)がセキュリティ制約でブロックされ実施できなかった。代わりに`app/lib/screens/*.dart` `app/lib/widgets/*.dart`を1行ずつ読み、配色・角丸・余白・実際のコピーを忠実に再現する方針に切り替えた(`components/AppUI.tsx`)。
- **1:1でシーン=台本の行**: `durations.ts`のキーが台本(`02_demo-video-script.md`)の表の行と対応する。尺を変える場合は両方を必ず同時に更新すること(今回の改訂では各シーンの合計秒数は変更していない。中身の間の取り方だけを作り直した)。
- **スマホは正面固定をやめ、3D的に配置**: `PhoneFrame`に`rotateX/rotateY/rotateZ`を追加し、シーンごとに異なる角度で構える。Scene6では2台を斜めに重ねる「複数プロダクトショット」も導入した。
- **参考にした実例**:
  - Apple製品紹介動画: 抑制の効いた黒背景+ロゴのキネティックタイポグラフィ(Scene1/8)。
  - Nike Run Club / Apple Fitness+ 等のアプリプロモ動画に見られる「デバイスを傾けて奥行きを出す」「複数画面を重ねて見せる」演出(Scene4-7のPhoneFrame角度・Scene6の2台構成)。
  - Linear/Notionのプロダクト動画: スクリーン録画ではなくUIをコンポーネントとして再構築する手法。
  - (Web検索で一般的なトレンドとして「1つの主要な動き+1つの補助的な動き」「イージングを物理的に感じさせる」という考え方を確認し、springベースのモーションに反映した。個別の動画URLは検索結果に具体的なものが見つからなかったため、一般的な技法の言及に留まる。)

## 音声について

**ナレーションはVOICEVOXで音声化済みです。** BGM/SEは依然として無音です。

- **ナレーション(VOICEVOX)**: この環境にDocker Desktopが導入されていたため、`voicevox/voicevox_engine:cpu-ubuntu20.04-latest`をDockerで起動し(`docker run -d --rm -p 50021:50021 --name voicevox_engine ...`)、REST API(`/audio_query` → `/synthesis`)経由で`02_demo-video-script.md`のナレーション全文を音声化した。生成スクリプトは`scripts/generate-voice.js`、出力は`public/audio/*.wav`。話者は **玄野武宏(ノーマル, speaker id=11)** — ユーザー指定により選定。動画冒頭2シーン(Scene1・Scene2)の右下に`VoiceCredit`コンポーネントで「VOICEVOX:玄野武宏」のクレジットを小さく表示している。`VoiceLine`コンポーネントで各シーンの発話タイミング(フレーム番号)から`<Audio>`を再生している。
- **字幕(Caption)の位置づけ変更**: 音声が主情報になったため、字幕は「音声の補助となる短いテロップ」に役割を変更した。フォントサイズを21px→38pxに拡大する一方、1画面あたりの文字数は半分程度に削減し、ナレーションの区切りに合わせて2回に分けて表示している。
- **BGM/SE**: 依然として無音。理由は変わらず、この制作環境では著作権的に安全性を確認できる音源を調達できなかったため。台本にキュー出しタイミングを明記済みなので、本実装時に追加してください。
- **音声を再生成する場合**: `docker run -d --rm -p 50021:50021 --name voicevox_engine voicevox/voicevox_engine:cpu-ubuntu20.04-latest` でエンジンを起動してから `node scripts/generate-voice.js` を実行する。

## 実装検証で見つかり、修正済みの不具合

過去の修正(PhoneFrameサイズ、Scene4ズームの見切れ、Scene8文言の同期漏れ、Scene6地図サイズ)に加え、今回の大規模改訂で新たに見つかったもの:

1. **Scene1/Scene8のロゴがセリフ体にフォールバックしていた**: `@remotion/google-fonts`でNoto Sans JPを明示的に読み込み解消(`theme.ts`)。
2. **Scene1のKOKUDOロゴが六角形の辺に接触していた**: 六角形を横長に再形成して解消。
3. **Scene6の日本地図パネルが縦に長すぎ、路線リストの3枚目が字幕ボックスと重なっていた**: `JapanMapSilhouette`(実サイズ200x420px)をそのままカード内に置いていたのが原因。`transform: scale(0.4)`のコンテナで縮小し解消。
4. **Scene5のランニング計測画面で、下部の「終了(長押し)」ボタンが字幕ボックスとスマホ本体の角丸に隠れていた**: コントロール行のbottom paddingが20pxしかなく、900px高のPhoneFrame下端ギリギリに配置されていたのが原因。paddingを140pxに拡大し、字幕ゾーンより上に収まるようにした。
5. **Scene4のズーム/パンがlinear interpolateで機械的だった**: `Easing.inOut(Easing.cubic)`を適用し、加減速を感じられるようにした。
6. **TapRippleが親要素のopacityアニメーションに巻き込まれ、タップ演出がほぼ見えなかった**: Scene5(コントロール行)・Scene6(タブ行)で`TapRipple`をopacityがまだ0に近い間に発火させていたのが原因。トリガーフレームを親のフェードインが完了した後にずらして解消。

## 未実装・既知の制約(正直な現状)

- [ ] BGM・SEの追加(著作権的に安全性を確認できる音源をこの環境では調達できていない。台本にキュー出しタイミングは明記済み)
- [ ] Scene6の日本地図は簡易シルエット(概形の近似)。より精緻な地図データやMapLibreの実キャプチャへの差し替えを検討
- [ ] `flutter run -d chrome`での実機スクリーンショット取得は、この環境のブラウザ自動操作制約により実施できなかった。実ウィジェットのソースコードを読んで手動再現する方針で代替したが、実機を撮影したものではない点は要注意
- [ ] 扉ページ・クロージングの「暗いブルー地に幾何学模様+グラデーション」という方向性は、Web調査で2025-2026年の汎用スタートアップテンプレートにも非常によく見られる意匠だと分かった。KOKUDOのブランド(国道標識の六角形)には合致しているが、「独自性」という観点では一般的なテンプレート感が完全には払拭できていない可能性がある
- [ ] VOICEVOXの読み上げは標準設定(抑揚・間のデフォルト値)のままで生成しており、感情表現やアクセント辞書の調整は行っていない。本番前に人間の耳で通し確認することを推奨
- [ ] 全体を通しで最終確認(1920x1080でのフル尺プレビュー、本レポート作成時点ではstillコマンドでの主要フレーム抜き取り確認のみ)
