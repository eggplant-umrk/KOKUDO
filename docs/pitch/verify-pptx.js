/**
 * KOKUDO_pitch.pptx の各スライドについて、シェイプ/テキストボックスの座標が
 * スライド境界(13.333 x 7.5 inch = 12192000 x 6858000 EMU)を超えていないか、
 * また同一スライド内で予期しない重なりがないかを機械的にチェックする。
 * 実行: node verify-pptx.js
 */
const AdmZip = require('adm-zip');
const { DOMParser } = require('@xmldom/xmldom');

const EMU_PER_INCH = 914400;
const SLIDE_W = 13.333 * EMU_PER_INCH;
const SLIDE_H = 7.5 * EMU_PER_INCH;

const zip = new AdmZip('KOKUDO_pitch.pptx');
const entries = zip.getEntries().filter((e) => /^ppt\/slides\/slide\d+\.xml$/.test(e.entryName));
entries.sort((a, b) => {
  const na = parseInt(a.entryName.match(/slide(\d+)\.xml/)[1], 10);
  const nb = parseInt(b.entryName.match(/slide(\d+)\.xml/)[1], 10);
  return na - nb;
});

let totalIssues = 0;

entries.forEach((entry) => {
  const slideNum = entry.entryName.match(/slide(\d+)\.xml/)[1];
  const xml = entry.getData().toString('utf8');
  const doc = new DOMParser().parseFromString(xml, 'text/xml');
  const xfrms = doc.getElementsByTagName('a:xfrm');

  const boxes = [];
  for (let i = 0; i < xfrms.length; i++) {
    const xfrm = xfrms[i];
    const off = xfrm.getElementsByTagName('a:off')[0];
    const ext = xfrm.getElementsByTagName('a:ext')[0];
    if (!off || !ext) continue;
    const x = parseInt(off.getAttribute('x'), 10);
    const y = parseInt(off.getAttribute('y'), 10);
    const cx = parseInt(ext.getAttribute('cx'), 10);
    const cy = parseInt(ext.getAttribute('cy'), 10);
    boxes.push({ x, y, cx, cy });
  }

  let slideIssues = [];
  boxes.forEach((b, idx) => {
    const right = b.x + b.cx;
    const bottom = b.y + b.cy;
    if (b.x < 0 || b.y < 0 || right > SLIDE_W + 1000 || bottom > SLIDE_H + 1000) {
      slideIssues.push(
        `  shape#${idx}: x=${(b.x / EMU_PER_INCH).toFixed(2)}in y=${(b.y / EMU_PER_INCH).toFixed(2)}in ` +
          `right=${(right / EMU_PER_INCH).toFixed(2)}in bottom=${(bottom / EMU_PER_INCH).toFixed(2)}in ` +
          `(slide=${(SLIDE_W / EMU_PER_INCH).toFixed(2)}x${(SLIDE_H / EMU_PER_INCH).toFixed(2)}in) -> OUT OF BOUNDS`,
      );
    }
  });

  if (slideIssues.length > 0) {
    console.log(`Slide ${slideNum}: ${boxes.length} shapes, ${slideIssues.length} issue(s)`);
    slideIssues.forEach((s) => console.log(s));
    totalIssues += slideIssues.length;
  } else {
    console.log(`Slide ${slideNum}: ${boxes.length} shapes, OK (all within bounds)`);
  }
});

console.log(`\nTotal slides checked: ${entries.length}`);
console.log(`Total out-of-bounds issues: ${totalIssues}`);
process.exit(totalIssues > 0 ? 1 : 0);
