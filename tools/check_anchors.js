#!/usr/bin/env node
// ============================================================================
// 目录锚点检查：验证 markdown 里的 [文字](#锚点) 是否真能找到对应的标题
//   用法（仓库根目录）：node tools/check_anchors.js
//   GitHub 的锚点规则：标题转小写、去标点、空格转连字符、保留中日韩字符和数字
// ============================================================================
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const docs = [];

(function walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.name === '.git' || e.name === 'node_modules') continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p);
    else if (e.name.endsWith('.md')) docs.push(p);
  }
})(root);

function slug(title) {
  return title
    .trim()
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s-]/gu, '')   // 去掉标点，保留字母/数字/空白/连字符（含中文）
    .replace(/\s+/g, '-')                // 空白转连字符
    .replace(/-+/g, '-')                 // 连续连字符合并成一个
    .replace(/^-|-$/g, '');              // 去掉首尾连字符
}

let checked = 0, bad = 0;
const anchorRe = /\[[^\]]*\]\(#([^)\s]+)\)/g;

for (const file of docs) {
  const text = fs.readFileSync(file, 'utf8');
  const lines = text.split(/\r?\n/);

  // 收集本文件的标题锚点
  const anchors = new Set();
  for (const line of lines) {
    const m = /^#{1,6}\s+(.+?)\s*$/.exec(line);
    if (m) {
      anchors.add(slug(m[1]));
      // 标题里如果有 `代码` 或 **粗体**，GitHub 会去掉标记符，这里也补一个变体
      anchors.add(slug(m[1].replace(/[`*_]/g, '')));
    }
  }

  lines.forEach((line, i) => {
    let m;
    anchorRe.lastIndex = 0;
    while ((m = anchorRe.exec(line)) !== null) {
      let a = m[1];
      try { a = decodeURIComponent(a); } catch (_) {}
      checked++;
      if (!anchors.has(a) && !anchors.has(slug(a))) {
        bad++;
        console.log(`  锚点失效  ${path.relative(root, file)}:${i + 1}`);
        console.log(`            -> #${m[1]}`);
      }
    }
  });
}

console.log('');
console.log(`内部锚点链接 ${checked} 个，失效 ${bad} 个`);
process.exit(bad === 0 ? 0 : 1);
