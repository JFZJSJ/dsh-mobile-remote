// publish.js — 通过 GitHub Contents API 把本地网站改动发布上线
// 用法: node publish.js <token>
// 读取 D:\dsh\personal-blog 下所有本地文件，与 GitHub 对比后上传新增/修改的文件
const https = require('https');
const fs = require('fs');
const path = require('path');

const token = process.argv[2];
if (!token) { console.error('缺少 token'); process.exit(1); }
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(path.join(__dirname, 'config.json'), 'utf8').replace(/^\uFEFF/, '')); } catch (e) {}
const OWNER = cfg.owner || 'JFZJSJ', REPO = cfg.repo || 'JFZJSJ.github.io', BRANCH = cfg.branch || 'main';
const LOCAL = cfg.sitePath || 'D:\\dsh\\personal-blog';
const API_HOST = '20.205.243.168'; // api.github.com 直连 IP（绕过 hosts）
const SERVERNAME = 'api.github.com';

function api(method, p, body) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const req = https.request({ host: API_HOST, servername: SERVERNAME, port: 443, path: p, method,
      headers: { 'Host': 'api.github.com', 'User-Agent': 'dsh-publish', 'Authorization': 'Bearer ' + token,
        'Accept': 'application/vnd.github+json', ...(payload ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload) } : {}) } },
      (res) => { let d = ''; res.on('data', (c) => (d += c)); res.on('end', () => resolve({ status: res.statusCode, body: d })); });
    req.on('error', reject);
    req.setTimeout(30000, () => req.destroy(new Error('timeout')));
    if (payload) req.write(payload);
    req.end();
  });
}

function enc(p) { return p.split('/').map(encodeURIComponent).join('/'); }
async function remoteSha(p) {
  const r = await api('GET', `/repos/${OWNER}/${REPO}/contents/${enc(p)}?ref=${BRANCH}`);
  if (r.status === 200) { const o = JSON.parse(r.body); return o.sha; }
  return null; // 不存在（新文件）
}

(async () => {
  // 收集本地文件（排除 .git 和 .gitignore）
  const files = [];
  function walk(dir) {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      if (e.name === '.git') continue;
      const full = path.join(dir, e.name);
      const rel = path.relative(LOCAL, full).replace(/\\/g, '/');
      if (e.isDirectory()) walk(full);
      else files.push(rel);
    }
  }
  walk(LOCAL);

  // 跳过二进制文件（图片等）——它们不会因日记流程变化
  const BINARY = /\.(jpg|jpeg|png|gif|ico|webp|bmp|zip|gz|pdf|ttf|woff2?|mp3|mp4)$/i;
  const textFiles = files.filter((f) => !BINARY.test(f));

  console.log('本地文件数:', files.length, '，文本文件:', textFiles.length);
  let changed = 0, created = 0, skipped = 0, failed = 0;
  for (const rel of textFiles) {
    // 统一 LF，避免 CRLF 造成误判
    const content = fs.readFileSync(path.join(LOCAL, rel.replace(/\//g, '\\')), 'utf8').replace(/\r\n/g, '\n');
    const sha = await remoteSha(rel);
    if (sha) {
      // 已存在：用 API 拿远程内容比对，变了才传
      const r = await api('GET', `/repos/${OWNER}/${REPO}/contents/${enc(rel)}?ref=${BRANCH}`);
      const remoteContent = Buffer.from(JSON.parse(r.body).content.replace(/\n/g, ''), 'base64').toString('utf8');
      if (remoteContent === content) { skipped++; continue; }
    }
    const put = await api('PUT', `/repos/${OWNER}/${REPO}/contents/${enc(rel)}`, {
      message: '发布：更新 ' + rel, branch: BRANCH,
      content: Buffer.from(content, 'utf8').toString('base64'),
      ...(sha ? { sha } : {})
    });
    if (put.status === 200 || put.status === 201) { sha ? changed++ : created++; console.log('OK  ', sha ? '更新' : '新建', rel); }
    else { failed++; console.log('FAIL', rel, put.status, put.body.slice(0, 120)); }
  }
  console.log(`\n完成：新建 ${created}，更新 ${changed}，无变化跳过 ${skipped}，失败 ${failed}`);
  if (failed) process.exit(1);
})();
