#!/usr/bin/env node
// ============================================================================
// 文档链接检查：把仓库里所有 .md 的 markdown 相对链接抽出来，验证目标存在
//   用法（仓库根目录）：node tools/check_links.js
//   用 Node 而不是 grep，是因为 grep 的字符类处理不好中文文件名。
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

// 匹配 [文字](目标) 和 ![文字](目标) 以及 <目标>
const linkRe = /!?\[[^\]]*\]\(([^)\s]+)\)/g;

let checked = 0, bad = 0;
const skipped = [];

for (const file of docs) {
  const text = fs.readFileSync(file, 'utf8');
  const lines = text.split(/\r?\n/);
  lines.forEach((line, i) => {
    let m;
    linkRe.lastIndex = 0;
    while ((m = linkRe.exec(line)) !== null) {
      let target = m[1];
      if (/^(https?:|mailto:|#)/.test(target)) { skipped.push(target); continue; }
      // 去掉锚点和查询串
      const clean = target.split('#')[0].split('?')[0];
      if (!clean) continue;
      checked++;
      const abs = path.resolve(path.dirname(file), decodeURIComponent(clean));
      if (!fs.existsSync(abs)) {
        bad++;
        console.log(`  失效链接  ${path.relative(root, file)}:${i + 1}`);
        console.log(`             -> ${target}`);
      }
    }
  });
}

console.log('');
console.log(`检查了 ${docs.length} 个 markdown 文件`);
console.log(`相对链接 ${checked} 个，失效 ${bad} 个`);
console.log(`外部链接/锚点（跳过） ${skipped.length} 个`);
process.exit(bad === 0 ? 0 : 1);
