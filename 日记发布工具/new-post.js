// new-post.js — 生成一篇日记页面并更新首页文章列表
// 用法: node new-post.js <file> <date> <title> <tags> <excerpt> <contentFile>
//   file       文件名基准，如 9.2  -> posts/9.2.html
//   date       显示日期，如 2026-09-02
//   title      卡片标题，如 9.2日记
//   tags       逗号分隔，如 生活,随笔
//   excerpt    卡片摘要（可空字符串 ""）
//   contentFile 正文文件路径（段落之间用空行分隔）
const fs = require('fs');
const path = require('path');

let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(path.join(__dirname, 'config.json'), 'utf8').replace(/^\uFEFF/, '')); } catch (e) {}

const [file, date, title, tags, excerpt, contentFile] = process.argv.slice(2);
const SITE = cfg.sitePath || 'D:\\dsh\\personal-blog';
if (!file || !date || !title || !tags || !contentFile) {
  console.error('缺少参数。用法: node new-post.js <file> <date> <title> <tags> <excerpt> <contentFile>');
  process.exit(1);
}

const content = fs.readFileSync(contentFile, 'utf8').replace(/\r\n/g, '\n').trim();
const paragraphs = content.split(/\n\s*\n/).filter(Boolean);
const body = paragraphs.map((p) => '      <p>' + p.replace(/\n/g, ' ') + '</p>').join('\n');

const tagSpans = tags.split(',').map((t) => t.trim()).filter(Boolean).map((t) => `          <span class="tag">${t}</span>`).join('\n');

// 从 file 推导 <title>（9.2 -> 9月2号日记）
const m = String(file).match(/^(\d+)\.(\d+)$/);
const pageTitle = m ? `${m[1]}月${m[2]}号日记 · 鸡分拯救世界` : `${title} · 鸡分拯救世界`;

const html = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${pageTitle}</title>
  <meta name="description" content="${excerpt || ''}" />
  <link rel="stylesheet" href="../css/style.css" />
</head>
<body>

  <!-- ===== 顶部导航 ===== -->
  <header class="site-header">
    <div class="container header-inner">
      <a class="site-logo" href="../index.html">鸡分拯救世界</a>
      <nav class="site-nav">
        <a href="../index.html">首页</a>
        <a href="../about.html">关于</a>
      </nav>
    </div>
  </header>

  <main class="article">
    <a class="back-link" href="../index.html">← 返回首页</a>

    <header class="article-header">
      <h1 class="article-title">${file}</h1>
      <div class="article-meta">
        <span>${date}</span>
        <span>·</span>
        <span id="reading-time"></span>
        <div class="tags">
${tagSpans}
        </div>
      </div>
    </header>

    <div class="prose" id="prose">
${body}
    </div>
  </main>

  <!-- ===== 页脚 ===== -->
  <footer class="site-footer">
    <div class="container">
      © <span data-year>2026</span> 鸡分拯救世界 · 手工搭建
    </div>
  </footer>

  <script src="../js/main.js"></script>
</body>
</html>
`;

const postPath = path.join(SITE, 'posts', file + '.html');
fs.writeFileSync(postPath, html, 'utf8');
console.log('POST WRITTEN:', postPath);

// 更新首页文章列表：若已有同名卡片则替换，否则在第一个卡片前插入
const indexPath = path.join(SITE, 'index.html');
let index = fs.readFileSync(indexPath, 'utf8');
const anchor = '        <a class="post-card" href="posts/hello-world.html">';
if (!index.includes(anchor)) {
  console.error('首页未找到插入锚点，请手动检查 index.html');
  process.exit(2);
}
const card = `        <a class="post-card" href="posts/${file}.html">
          <div class="post-meta">
            <span>${date}</span>
            <span class="dot"></span>
          </div>
          <h3>${title}</h3>
          <p class="post-excerpt">${excerpt || ''}</p>
          <div class="tags">
${tagSpans}
          </div>
        </a>`;
const fileEsc = String(file).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const cardRe = new RegExp('        <a class="post-card" href="posts/' + fileEsc + '\\.html">[\\s\\S]*?\\n        </a>');
if (cardRe.test(index)) {
  index = index.replace(cardRe, card);
  console.log('INDEX CARD REPLACED (同名卡片已更新)');
} else {
  index = index.replace(anchor, card + '\n\n' + anchor);
  console.log('INDEX CARD INSERTED (新卡片已插入)');
}
fs.writeFileSync(indexPath, index, 'utf8');
console.log('INDEX UPDATED:', indexPath);
