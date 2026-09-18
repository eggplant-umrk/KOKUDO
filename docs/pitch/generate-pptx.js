/**
 * docs/pitch/03_slides.md の内容から KOKUDO_pitch.pptx を生成するスクリプト。
 * ブランドカラーは app/lib/theme/app_colors.dart のトークンと一致させている。
 * 実行: node generate-pptx.js
 *
 * 可読性改善(4回目の大幅修正): 4分ピッチの会場後方からでも読める資料にするため、
 * (1) 見出し40pt以上・本文24pt以上を基準にフォントサイズを底上げ
 * (2) スライド本文をキーワード・短フレーズのみに削減し、詳細な話す内容は
 *     01_slide-structure.md の「話す内容」をそのままスピーカーノート(addNotes)へ移動
 * (3) 斜体(italic)をすべて廃止し、テキストはすべて水平表示に統一
 * (4) 長い見出しは意味のまとまり(文節)で手動改行し、自動折り返しに任せない
 * を行った。装飾(六角形テクスチャ・グラデーション等)の方針は変更していない。
 */
const pptxgen = require('pptxgenjs');

const COLORS = {
  routeSignBlue: '22588E',
  routeSignBlueLight: '2F74B8',
  routeSignBlueDark: '173F66',
  accentGreen: '34C98A',
  accentGold: 'FFB238',
  accentGoldText: 'B4720A',
  routeNeonBlue: '2FA9FF',
  textPrimary: '1C2B36',
  textSecondary: '5C6F7D',
  bgSurface: 'FFFFFF',
  bgSurfaceRaised: 'F3FAFD',
  borderSubtle: 'E1EEF5',
  placeholderGray: 'D9D9D9',
  placeholderText: '6B6B6B',
};

// パートごとのアクセントカラー運用ルール: 課題=寒色(ネオンブルー) / プロセス=中間(標識ブルー系) /
// 解決策=暖色(ゴールド) / 成果と展望=成長を示す緑
const SECTION = {
  problem: { key: '01', name: '課題', accent: COLORS.routeNeonBlue },
  process: { key: '02', name: 'プロセス', accent: COLORS.routeSignBlueLight },
  solution: { key: '03', name: '解決策', accent: COLORS.accentGold },
  outlook: { key: '04', name: '成果と展望', accent: COLORS.accentGreen },
};

const pptx = new pptxgen();
pptx.defineLayout({ name: 'KOKUDO_16x9', width: 13.333, height: 7.5 });
pptx.layout = 'KOKUDO_16x9';
pptx.author = 'KOKUDO Team';
pptx.title = 'KOKUDO 4分ピッチ資料';

const SLIDE_W = 13.333;
const SLIDE_H = 7.5;

const FONT_BODY = 'Yu Gothic';
const FONT_DISPLAY = 'Yu Mincho Demibold';

// ---------------------------------------------------------------------------
// ヘルパー
// ---------------------------------------------------------------------------

/** 国道標識モチーフの六角形をうっすら散らして質感を出す(扉ページのテクスチャ)。
 *  ※ここでのrotateは図形(六角形)の傾きであり、文字の傾きではない。 */
function addHexTexture(slide, { colorHex, count, region, sizeMin, sizeMax, transparency }) {
  let seed = 42;
  const rand = () => {
    seed = (seed * 9301 + 49297) % 233280;
    return seed / 233280;
  };
  for (let i = 0; i < count; i++) {
    const size = sizeMin + rand() * (sizeMax - sizeMin);
    const x = region.x + rand() * Math.max(0.01, region.w - size);
    const y = region.y + rand() * Math.max(0.01, region.h - size);
    slide.addShape(pptx.ShapeType.hexagon, {
      x, y, w: size, h: size,
      rotate: Math.floor(rand() * 60),
      fill: { type: 'none' },
      line: { color: colorHex, width: 1, transparency },
    });
  }
}

/** 帯を重ねて疑似的なグラデーション(質感)を作る(pptxgenjs 4.0.1はネイティブのグラデーション塗りを持たないため) */
function addGradientWash(slide, { washColor, bands = 6, fromTransparency = 100, toTransparency = 35, region }) {
  const r = region || { x: 0, y: 0, w: SLIDE_W, h: SLIDE_H };
  const bandH = r.h / bands;
  for (let i = 0; i < bands; i++) {
    const t = fromTransparency + ((toTransparency - fromTransparency) * i) / (bands - 1);
    slide.addShape(pptx.ShapeType.rect, {
      x: r.x, y: r.y + i * bandH, w: r.w, h: bandH,
      fill: { color: washColor, transparency: t },
      line: { type: 'none' },
    });
  }
}

/** [IMG: ...] プレースホルダーボックス。中の説明文は編集者向けの制作メモであり
 *  聴衆向けの本文ではないため小さめのままだが、斜体は可読性のため廃止した。 */
function addImagePlaceholder(slide, label, x, y, w, h) {
  slide.addShape(pptx.ShapeType.rect, {
    x, y, w, h,
    fill: { color: COLORS.placeholderGray },
    line: { color: 'BEBEBE', width: 1 },
  });
  slide.addText(label, {
    x, y, w, h,
    fontFace: FONT_BODY, fontSize: 12, color: COLORS.placeholderText,
    align: 'center', valign: 'middle',
    wrap: true,
  });
}

/** 扉ページ(パート区切り)。質感テクスチャ+巨大ゴーストナンバー+非対称タイトル配置。
 *  グラデーション+高密度テクスチャは表紙とクロージングだけの演出に絞ってある。 */
function addDividerSlide({ key, name, subtitle, accent, align = 'right' }) {
  const slide = pptx.addSlide();
  slide.background = { color: COLORS.routeSignBlue };
  addHexTexture(slide, {
    colorHex: accent, count: 5,
    region: { x: 0, y: 0, w: SLIDE_W, h: SLIDE_H },
    sizeMin: 1.4, sizeMax: 3.0, transparency: 90,
  });

  const numeralX = align === 'right' ? 6.0 : 0;
  slide.addText(key, {
    x: numeralX, y: 0.5, w: 7.1, h: 6.4,
    fontFace: FONT_DISPLAY, fontSize: 260, bold: true, color: 'FFFFFF', transparency: 87,
    align: align === 'right' ? 'right' : 'left', valign: 'middle',
  });

  const titleX = align === 'right' ? 5.9 : 0.9;
  slide.addShape(pptx.ShapeType.rect, {
    x: align === 'right' ? 12.0 : 0.9, y: 5.4, w: 0.55, h: 0.07,
    fill: { color: accent }, line: { type: 'none' },
  });
  slide.addText(name, {
    x: titleX, y: 5.55, w: 6.5, h: 1.2,
    fontFace: FONT_DISPLAY, fontSize: 72, bold: true, color: 'FFFFFF',
    align: align === 'right' ? 'right' : 'left',
  });
  if (subtitle) {
    slide.addText(subtitle, {
      x: titleX, y: 6.7, w: 6.5, h: 0.55,
      fontFace: FONT_BODY, fontSize: 24, color: 'FFFFFF', transparency: 15,
      align: align === 'right' ? 'right' : 'left',
    });
  }
  return slide;
}

/** 通常スライドの見出しラベル(タブ状の小さなラベル+アクセントの短い線)。 */
function addKicker(slide, kicker, accent) {
  slide.background = { color: COLORS.bgSurface };
  slide.addShape(pptx.ShapeType.rect, { x: 0.8, y: 0.6, w: 0.5, h: 0.08, fill: { color: accent }, line: { type: 'none' } });
  slide.addText(kicker, {
    x: 0.8, y: 0.72, w: 10, h: 0.45,
    fontFace: FONT_BODY, fontSize: 20, bold: true, color: accent, charSpacing: 1,
  });
}

// ===========================================================================
// Slide 1: 表紙
// ===========================================================================
{
  const slide = pptx.addSlide();
  slide.background = { color: COLORS.routeSignBlue };
  addGradientWash(slide, { washColor: COLORS.routeSignBlueDark, bands: 8, fromTransparency: 100, toTransparency: 25 });
  addHexTexture(slide, {
    colorHex: COLORS.routeNeonBlue, count: 22,
    region: { x: 0, y: 0, w: SLIDE_W, h: SLIDE_H },
    sizeMin: 0.4, sizeMax: 2.6, transparency: 85,
  });
  slide.addText('KOKUDO', {
    x: 0, y: 3.45, w: 9.85, h: 1.6,
    fontFace: FONT_BODY, fontSize: 96, bold: true, color: 'FFFFFF', align: 'left',
  });
  slide.addText('国道ラン', {
    x: 0.05, y: 3.05, w: 6, h: 0.45,
    fontFace: FONT_DISPLAY, fontSize: 24, color: COLORS.routeNeonBlue, align: 'left',
  });
  slide.addText('走った道が、\n日本地図になっていく。', {
    x: 0.05, y: 4.95, w: 9, h: 1.4,
    fontFace: FONT_DISPLAY, fontSize: 44, color: 'FFFFFF', align: 'left', lineSpacing: 52,
  });

  addHexTexture(slide, {
    colorHex: 'FFFFFF', count: 1,
    region: { x: 9.8, y: 0.9, w: 2.6, h: 2.6 },
    sizeMin: 2.2, sizeMax: 2.4, transparency: 55,
  });

  slide.addText('100 Program FINAL WEEK', {
    x: 0.5, y: 6.95, w: 7, h: 0.35,
    fontFace: FONT_BODY, fontSize: 14, color: 'FFFFFF', transparency: 25, align: 'left',
  });
  slide.addText('【日付PLACEHOLDER: 本番日程に差し替え】', {
    x: 8.0, y: 6.95, w: 4.8, h: 0.35,
    fontFace: FONT_BODY, fontSize: 14, color: COLORS.accentGold, align: 'right',
  });
  slide.addNotes('走った道が、日本地図になっていく。ランニングアプリ「KOKUDO(国道ラン)」です。');
}

// ===========================================================================
// Slide 2: Part1 扉(課題)
// ===========================================================================
addDividerSlide({ key: SECTION.problem.key, name: SECTION.problem.name, subtitle: 'なぜ作ったか', accent: SECTION.problem.accent, align: 'right' });

// ===========================================================================
// Slide 3: 課題をさまざまな解像度で
// ===========================================================================
{
  const slide = pptx.addSlide();
  addKicker(slide, '課題 ─ WHY', SECTION.problem.accent);
  // 非対称2カラム。矢印"↓"は使わず、縦の細いラインで接続を示す。
  slide.addText('よくある話', {
    x: 0.8, y: 1.65, w: 5.0, h: 0.5, fontFace: FONT_BODY, fontSize: 24, bold: true, color: COLORS.textSecondary,
  });
  slide.addText('ランニングは、\n3日坊主。', {
    x: 0.8, y: 2.3, w: 5.3, h: 2.0, fontFace: FONT_BODY, fontSize: 44, bold: true, color: COLORS.textPrimary, lineSpacing: 52,
  });

  slide.addShape(pptx.ShapeType.line, {
    x: 6.4, y: 1.6, w: 0, h: 5.2, line: { color: COLORS.borderSubtle, width: 1.5 },
  });

  slide.addText('私たちだから詳しい理由', {
    x: 6.8, y: 1.65, w: 5.73, h: 0.5, fontFace: FONT_BODY, fontSize: 24, bold: true, color: SECTION.problem.accent,
  });
  slide.addText('締切と、\n仲間の目。', {
    x: 6.8, y: 2.3, w: 5.73, h: 2.0, fontFace: FONT_DISPLAY, fontSize: 44, bold: true, color: COLORS.textPrimary, lineSpacing: 52,
  });
  slide.addText('その両方が、無い。\nだから、続かない。', {
    x: 6.8, y: 4.55, w: 5.73, h: 1.4, fontFace: FONT_BODY, fontSize: 28, bold: true, color: COLORS.textSecondary, lineSpacing: 36,
  });
  slide.addText('【実体験エピソードPLACEHOLDER】', {
    x: 6.8, y: 6.15, w: 5.73, h: 0.4, fontFace: FONT_BODY, fontSize: 14, color: COLORS.accentGoldText,
  });
  slide.addNotes(
    'ランニングが続かない、という話はよく聞きます。でも私たちは部活動で、「大会という締切」と「仲間に見られている感覚」がないと自分たちも続けられないことを痛感してきました。ランニングには、そのどちらも無い。だから続かないんです。',
  );
}

// ===========================================================================
// Slide 4: 「ユーザーの声」ポイント
// ===========================================================================
{
  const slide = pptx.addSlide();
  addKicker(slide, '課題 ─ VOICE', SECTION.problem.accent);
  addImagePlaceholder(slide, '[IMG: 人物写真1\nランニング歴3年/会社員]', 0.8, 1.6, 2.1, 2.1);
  slide.addShape(pptx.ShapeType.roundRect, {
    x: 3.15, y: 1.6, w: 9.35, h: 1.9, fill: { color: COLORS.bgSurfaceRaised }, line: { color: SECTION.problem.accent, width: 1 }, rectRadius: 0.06,
  });
  slide.addText('いつも同じ景色。\n正直、飽きる。', {
    x: 3.5, y: 1.78, w: 8.7, h: 1.2, fontFace: FONT_DISPLAY, fontSize: 28, bold: true, color: COLORS.textPrimary, lineSpacing: 34,
  });
  slide.addText('ランニング歴3年・会社員', {
    x: 3.5, y: 3.05, w: 8.7, h: 0.4, fontFace: FONT_BODY, fontSize: 16, color: COLORS.textSecondary,
  });

  addImagePlaceholder(slide, '[IMG: 人物写真2\nランニング初心者]', 2.6, 4.2, 2.1, 2.1);
  slide.addShape(pptx.ShapeType.roundRect, {
    x: 4.95, y: 4.2, w: 7.55, h: 1.9, fill: { color: COLORS.bgSurfaceRaised }, line: { color: SECTION.problem.accent, width: 1 }, rectRadius: 0.06,
  });
  slide.addText('あと何キロか、\n分からない。', {
    x: 5.3, y: 4.38, w: 6.9, h: 1.2, fontFace: FONT_DISPLAY, fontSize: 28, bold: true, color: COLORS.textPrimary, lineSpacing: 34,
  });
  slide.addText('ランニング初心者', {
    x: 5.3, y: 5.65, w: 6.9, h: 0.4, fontFace: FONT_BODY, fontSize: 16, color: COLORS.textSecondary,
  });

  slide.addText('【ユーザーの声PLACEHOLDER】', {
    x: 0.8, y: 6.85, w: 11.7, h: 0.35, fontFace: FONT_BODY, fontSize: 14, color: COLORS.accentGoldText,
  });
  slide.addNotes(
    '実際に周りのランナーに聞くと、同じ声が返ってきました。「いつも同じ景色でモチベが上がらない」「あと何キロか分からず心が折れる」。',
  );
}

// ===========================================================================
// Slide 5: Part2 扉(プロセス)
// ===========================================================================
addDividerSlide({ key: SECTION.process.key, name: SECTION.process.name, subtitle: 'どう作ったか', accent: SECTION.process.accent, align: 'left' });

// ===========================================================================
// Slide 6: 作ったプロトタイプを順番に紹介
// ===========================================================================
{
  const slide = pptx.addSlide();
  addKicker(slide, 'プロセス ─ HOW', SECTION.process.accent);
  const steps = [
    { label: 'v1\n画面モック', hero: true },
    { label: 'v2\nSQLite', hero: false },
    { label: 'v3\n実GPS', hero: false },
    { label: 'v4\n実地図', hero: false },
    { label: 'v5\nFirebase', hero: false },
  ];
  // 非対称フィルムストリップ: 最初のv1だけ大きく、以降は右へ小さくなりながら細い線でつながる
  let x = 0.8;
  const y0 = 2.0;
  steps.forEach((step, i) => {
    const w = step.hero ? 2.7 : 1.85;
    const h = step.hero ? 3.4 : 2.4;
    const y = step.hero ? y0 : y0 + 0.5;
    addImagePlaceholder(slide, `[IMG: ${step.label}]`, x, y, w, h);
    if (i < steps.length - 1) {
      slide.addShape(pptx.ShapeType.line, {
        x: x + w + 0.08, y: y + h / 2, w: 0.22, h: 0,
        line: { color: SECTION.process.accent, width: 1.5 },
      });
    }
    x += w + 0.38;
  });
  slide.addText('動くものを、\n毎週見せる。', {
    x: 0.8, y: 5.75, w: 7, h: 1.4, fontFace: FONT_DISPLAY, fontSize: 44, bold: true, color: COLORS.textPrimary, lineSpacing: 52,
  });
  slide.addNotes(
    '最初は画面のモックから始めて、SQLiteでのデータ保存、実際のGPS計測、実地図への可視化と、1週間ごとに「動くもの」を積み重ねてきました。今はFirebase連携を進めています。1枚にまとめる必要はなく、積み上げの記録そのものが資産になります。',
  );
}

// ===========================================================================
// Slide 7: Part3 扉(解決策)
// ===========================================================================
addDividerSlide({ key: SECTION.solution.key, name: SECTION.solution.name, subtitle: '何を作ったか', accent: SECTION.solution.accent, align: 'right' });

// ===========================================================================
// Slide 8: KOKUDOが実現すること
// ===========================================================================
{
  const slide = pptx.addSlide();
  addKicker(slide, '解決策 ─ WHAT', SECTION.solution.accent);

  // ヒーローパネル(大)+サブパネル2枚(小)の非対称グリッド
  slide.addShape(pptx.ShapeType.roundRect, {
    x: 0.8, y: 1.55, w: 6.6, h: 5.0, fill: { color: COLORS.bgSurfaceRaised }, line: { color: COLORS.borderSubtle, width: 1 }, rectRadius: 0.06,
  });
  slide.addText('距離が、\n国道になる。', {
    x: 1.15, y: 2.3, w: 5.9, h: 2.3, fontFace: FONT_DISPLAY, fontSize: 44, bold: true, color: COLORS.textPrimary, lineSpacing: 52,
  });

  slide.addShape(pptx.ShapeType.roundRect, {
    x: 7.65, y: 1.55, w: 4.9, h: 2.35, fill: { color: COLORS.textPrimary }, line: { type: 'none' }, rectRadius: 0.06,
  });
  slide.addText('地図が、\n色づく。', {
    x: 7.95, y: 1.9, w: 4.3, h: 1.6, fontFace: FONT_DISPLAY, fontSize: 40, bold: true, color: 'FFFFFF', lineSpacing: 48,
  });

  slide.addShape(pptx.ShapeType.roundRect, {
    x: 7.65, y: 4.1, w: 4.9, h: 2.45, fill: { color: COLORS.accentGold }, line: { type: 'none' }, rectRadius: 0.06,
  });
  slide.addText('逆算で、\nナビする。', {
    x: 7.95, y: 4.45, w: 4.3, h: 1.7, fontFace: FONT_DISPLAY, fontSize: 40, bold: true, color: '4A2F00', lineSpacing: 48,
  });

  slide.addText('グレー = 未走破\nネオン = 挑戦中\nゴールド = 完走', {
    x: 1.15, y: 4.75, w: 5.9, h: 1.6, fontFace: FONT_BODY, fontSize: 24, bold: true, color: COLORS.textSecondary, lineSpacing: 30,
  });

  slide.addText('続きは、動画で。', {
    x: 0.8, y: 6.75, w: 11.7, h: 0.55, fontFace: FONT_BODY, fontSize: 28, bold: true, color: COLORS.accentGoldText,
  });
  slide.addNotes(
    '私たちが作ったのは3つです。走った距離が実在の国道の走破距離になり、実地図の上に自分の挑戦が色分けされ、完走までの逆算ナビが伴走します。実際に動いているところを、75秒のデモ動画でご覧ください。',
  );
}

// ===========================================================================
// Slide 9: デモ動画埋め込み(準備中プレースホルダー)
// ===========================================================================
{
  const slide = pptx.addSlide();
  slide.background = { color: '000000' };
  slide.addShape(pptx.ShapeType.rect, {
    x: 2.17, y: 1.0, w: 9.0, h: 5.5, fill: { color: '1C2B36' }, line: { color: COLORS.routeNeonBlue, width: 2 },
  });
  slide.addText('▶', {
    x: 2.17, y: 2.1, w: 9.0, h: 1.5, fontFace: FONT_BODY, fontSize: 60, color: COLORS.routeNeonBlue, align: 'center',
  });
  slide.addText('デモ動画', {
    x: 2.17, y: 3.7, w: 9.0, h: 0.8, fontFace: FONT_BODY, fontSize: 40, bold: true, color: 'FFFFFF', align: 'center',
  });
  slide.addText('75秒', {
    x: 2.17, y: 4.6, w: 9.0, h: 0.6, fontFace: FONT_BODY, fontSize: 24, color: COLORS.routeNeonBlue, align: 'center',
  });
  slide.addText('準備中 / 後日埋め込み ─ KOKUDO_demo.mp4', {
    x: 2.17, y: 5.9, w: 9.0, h: 0.4, fontFace: FONT_BODY, fontSize: 12, color: 'FFFFFF', transparency: 50, align: 'center',
  });
  slide.addNotes('(ここでは話さず、動画の音声/字幕に委ねる)');
}

// ===========================================================================
// Slide 10: 技術で支えていること
// ===========================================================================
{
  const slide = pptx.addSlide();
  addKicker(slide, '解決策 ─ TECH', SECTION.solution.accent);
  slide.addText('モックは、\nひとつも無い。', {
    x: 0.8, y: 1.6, w: 6.2, h: 2.0, fontFace: FONT_DISPLAY, fontSize: 44, bold: true, color: COLORS.textPrimary, lineSpacing: 54,
  });
  slide.addText('GPS・地図・保存。\nすべて本物。', {
    x: 0.8, y: 3.75, w: 6.0, h: 1.4, fontFace: FONT_BODY, fontSize: 24, color: COLORS.textSecondary, lineSpacing: 30,
  });

  // 「同じ形の角丸カードを3枚並べる」パターンを避けるため、1つを主役に、
  // 残り2つは罫線と点だけのfootnote的な列挙にして視覚的な重みに差をつけている。
  slide.addShape(pptx.ShapeType.line, { x: 7.5, y: 1.7, w: 5.03, h: 0, line: { color: COLORS.borderSubtle, width: 1 } });
  slide.addText('1本で、\n全OSに。', {
    x: 7.5, y: 1.95, w: 5.03, h: 1.6, fontFace: FONT_DISPLAY, fontSize: 40, bold: true, color: COLORS.textPrimary, lineSpacing: 48,
  });

  const footnotes = [
    { label: 'GPS × MapLibre', sub: '実測・実地図' },
    { label: '端末内SQLite', sub: 'オフラインでも止まらない' },
  ];
  footnotes.forEach((tag, i) => {
    const y = 3.85 + i * 1.0;
    slide.addShape(pptx.ShapeType.ellipse, { x: 7.5, y: y + 0.13, w: 0.14, h: 0.14, fill: { color: SECTION.solution.accent }, line: { type: 'none' } });
    slide.addText(tag.label, { x: 7.8, y: y - 0.05, w: 4.7, h: 0.5, fontFace: FONT_BODY, fontSize: 24, bold: true, color: COLORS.textPrimary });
    slide.addText(tag.sub, { x: 7.8, y: y + 0.45, w: 4.7, h: 0.4, fontFace: FONT_BODY, fontSize: 16, color: COLORS.textSecondary });
  });
  slide.addShape(pptx.ShapeType.line, { x: 7.5, y: 5.95, w: 5.03, h: 0, line: { color: COLORS.borderSubtle, width: 1 } });
  slide.addNotes(
    '今ご覧いただいたGPSも地図もデータ保存も、すべてモックなしの本物です。Flutter1本でiOS・Android・Webに対応し、オフラインでも記録が止まりません。',
  );
}

// ===========================================================================
// Slide 11: Part4 扉(成果と展望)
// ===========================================================================
addDividerSlide({ key: SECTION.outlook.key, name: SECTION.outlook.name, subtitle: '', accent: SECTION.outlook.accent, align: 'left' });

// ===========================================================================
// Slide 12: 学び＝成果
// ===========================================================================
{
  const slide = pptx.addSlide();
  addKicker(slide, '成果と展望 ─ LEARNING', SECTION.outlook.accent);

  slide.addText('見えないと、\n続かない。', {
    x: 0.8, y: 1.6, w: 5.6, h: 2.0, fontFace: FONT_DISPLAY, fontSize: 44, bold: true, color: COLORS.textPrimary, lineSpacing: 52,
  });

  slide.addShape(pptx.ShapeType.line, { x: 6.7, y: 1.6, w: 0, h: 5.3, line: { color: COLORS.borderSubtle, width: 1.5 } });

  slide.addText('プロダクトの学び', { x: 7.1, y: 1.6, w: 5.4, h: 0.5, fontFace: FONT_BODY, fontSize: 24, bold: true, color: COLORS.textSecondary });
  slide.addText('動く地図と逆算ナビで、\n仮説を検証した。', {
    x: 7.1, y: 2.2, w: 5.4, h: 1.5, fontFace: FONT_BODY, fontSize: 24, color: COLORS.textPrimary, lineSpacing: 30,
  });
  slide.addText('実績: 【PLACEHOLDER】', {
    x: 7.1, y: 3.75, w: 5.4, h: 0.5, fontFace: FONT_BODY, fontSize: 20, bold: true, color: COLORS.accentGoldText,
  });

  slide.addText('チームの学び', { x: 7.1, y: 4.6, w: 5.4, h: 0.5, fontFace: FONT_BODY, fontSize: 24, bold: true, color: COLORS.textSecondary });
  slide.addText('分担しても、\n毎週見せれば、\nひとつになる。', {
    x: 7.1, y: 5.2, w: 5.4, h: 1.6, fontFace: FONT_BODY, fontSize: 24, color: COLORS.textPrimary, lineSpacing: 30,
  });
  slide.addNotes(
    '今回一番の成果は、完成度そのものより、「見えないと続かない」という仮説を、動くプロダクトで検証できたことです。実際に私たち自身が開発期間中に走ってみて、[実走行データ]という結果が出ました。そして、役割を分担しながら毎週統合し続けるチームの動き方も、大きな学びでした。',
  );
}

// ===========================================================================
// Slide 13: 展望
// ===========================================================================
{
  const slide = pptx.addSlide();
  addKicker(slide, '成果と展望 ─ NEXT', SECTION.outlook.accent);
  slide.addText('先行6路線の検証、完了。\n次は「広げる」フェーズへ。', {
    x: 0.8, y: 1.55, w: 11.7, h: 1.7, fontFace: FONT_DISPLAY, fontSize: 44, bold: true, color: COLORS.textPrimary, lineSpacing: 52,
  });

  slide.addShape(pptx.ShapeType.line, { x: 1.1, y: 3.55, w: 0, h: 3.35, line: { color: COLORS.borderSubtle, width: 2 } });

  const rows = [
    { label: '直近', text: 'キャラクターと走る。', y: 3.55 },
    { label: '中期', text: 'どこからでも続く。', y: 4.85 },
    { label: '長期', text: '全国459路線へ。', y: 6.15 },
  ];
  rows.forEach((row) => {
    slide.addShape(pptx.ShapeType.ellipse, {
      x: 1.03, y: row.y + 0.16, w: 0.14, h: 0.14, fill: { color: SECTION.outlook.accent }, line: { type: 'none' },
    });
    slide.addText(row.label, { x: 1.4, y: row.y, w: 1.8, h: 0.5, fontFace: FONT_BODY, fontSize: 24, bold: true, color: SECTION.outlook.accent });
    slide.addText(row.text, { x: 3.3, y: row.y - 0.08, w: 9.2, h: 0.7, fontFace: FONT_DISPLAY, fontSize: 40, bold: true, color: COLORS.textPrimary });
  });
  slide.addNotes(
    '先行6路線でコア体験の検証は終わりました。ここからはキャラクター体験と路線選択を広げ、クラウド同期でどの端末からでも続けられるようにし、最終的には全国459路線、日本地図そのものを走破フィールドにしていきます。',
  );
}

// ===========================================================================
// Slide 14: チーム紹介(ジグザグ配置)
// ===========================================================================
{
  const slide = pptx.addSlide();
  addKicker(slide, 'TEAM', COLORS.routeSignBlue);
  const members = [
    { name: '【氏名\nPLACEHOLDER】', role: 'PM / インフラ' },
    { name: '由美穂\n【姓PLACEHOLDER】', role: 'フロント実装' },
    { name: '新野琉壱', role: 'データ整理' },
    { name: '荒野\n【名PLACEHOLDER】', role: 'Firebase担当' },
  ];
  const colW = 2.85, gap = 0.22, startX = 0.8;
  members.forEach((m, i) => {
    const x = startX + i * (colW + gap);
    const y = i % 2 === 0 ? 1.6 : 2.15; // ジグザグに縦位置をずらす
    addImagePlaceholder(slide, '[IMG: 写真]', x, y, colW, 2.5);
    slide.addText(m.name, {
      x, y: y + 2.6, w: colW, h: 0.75, fontFace: FONT_BODY, fontSize: 24, bold: true, color: COLORS.textPrimary,
      align: 'center', valign: 'top', wrap: true,
    });
    slide.addText(m.role, { x, y: y + 3.4, w: colW, h: 0.4, fontFace: FONT_BODY, fontSize: 18, color: COLORS.routeSignBlue, align: 'center' });
  });
  slide.addText('所属・詳細は決まり次第、追記', {
    x: 0.8, y: 6.95, w: 11.7, h: 0.35, fontFace: FONT_BODY, fontSize: 12, color: COLORS.accentGoldText,
  });
  slide.addNotes(
    'チームは4人。PM・インフラ、フロント実装、データ整理、Firebase認証基盤と、役割を分担しながら作っています。(氏名・Why Youの詳細は割愛し、スライド上の情報に語らせる)',
  );
}

// ===========================================================================
// Slide 15: クロージング
// ===========================================================================
{
  const slide = pptx.addSlide();
  slide.background = { color: COLORS.routeSignBlue };
  addGradientWash(slide, { washColor: COLORS.routeSignBlueDark, bands: 8, fromTransparency: 100, toTransparency: 25 });
  addHexTexture(slide, {
    colorHex: COLORS.routeNeonBlue, count: 20,
    region: { x: 0, y: 0, w: SLIDE_W, h: SLIDE_H },
    sizeMin: 0.4, sizeMax: 2.4, transparency: 85,
  });

  slide.addText('走った道が、\n日本地図になっていく。', {
    x: 0.05, y: 1.85, w: 8.7, h: 1.9, fontFace: FONT_DISPLAY, fontSize: 44, color: 'FFFFFF', align: 'left', lineSpacing: 52,
  });
  slide.addText('KOKUDO', {
    x: 0, y: 3.9, w: 8.9, h: 1.2, fontFace: FONT_BODY, fontSize: 64, bold: true, color: 'FFFFFF', align: 'left',
  });
  slide.addText('これからも、国道を、走る。', {
    x: 0.05, y: 5.2, w: 8.5, h: 0.55, fontFace: FONT_BODY, fontSize: 28, color: COLORS.routeNeonBlue, align: 'left',
  });
  addImagePlaceholder(slide, '[QR/連絡先 PLACEHOLDER]', 10.2, 5.6, 2.3, 1.5);
  slide.addNotes('走った道が、日本地図になっていく。KOKUDO、これからも国道を走破していきます。');
}

pptx.writeFile({ fileName: 'KOKUDO_pitch.pptx' }).then(() => {
  console.log('OK: KOKUDO_pitch.pptx generated');
}).catch((err) => {
  console.error('FAILED:', err);
  process.exit(1);
});
