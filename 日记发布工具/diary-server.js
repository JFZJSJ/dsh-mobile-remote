// diary-server.js — 日记服务：手机表单直接调用，不经过 AI
// 接收 POST /new-post → 运行 new-post.js 生成页面 → 运行 publish.js 发布
// 启动: node diary-server.js  （监听 127.0.0.1:3099，经 Tailscale 隧道对外）
const http = require('http');
const { execFile } = require('child_process');
const fs = require('fs');
const path = require('path');

const NODE = process.execPath;
const TOOLS = __dirname;
const TOKEN_FILE = path.join('D:\\dsh', '.github-token');
const PORT = 3099;

function run(script, args) {
  return new Promise((resolve) => {
    execFile(NODE, [path.join(TOOLS, script), ...args], { timeout: 90000, encoding: 'utf8' },
      (err, stdout, stderr) => resolve({ err: err ? (err.message || '执行失败') : null, out: (stdout || '') + (stderr || '') }));
  });
}
function json(res, code, obj) {
  res.writeHead(code, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type'
  });
  res.end(JSON.stringify(obj));
}

http.createServer(async (req, res) => {
  const url = req.url || '';
  const isHealth = url === '/health' || url.endsWith('/health');
  const isNewPost = url === '/new-post' || url.endsWith('/new-post');
  if (req.method === 'OPTIONS') { json(res, 204, {}); return; }
  if (req.method === 'GET' && isHealth) { json(res, 200, { ok: true, time: Date.now() }); return; }
  if (req.method === 'POST' && isNewPost) {
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', async () => {
      try {
        const d = JSON.parse(body);
        const file = String(d.file || '').trim(), date = String(d.date || '').trim();
        const title = String(d.title || '').trim(), tags = String(d.tags || '').trim();
        const excerpt = String(d.excerpt || '').trim(), content = String(d.content || '').trim();
        if (!file || !date || !title || !tags || !content) { json(res, 400, { ok: false, message: '缺少必要字段（日期/标题/标签/正文）' }); return; }
        const contentFile = path.join(TOOLS, 'content-in.txt');
        fs.writeFileSync(contentFile, content, 'utf8');
        const gen = await run('new-post.js', [file, date, title, tags, excerpt, contentFile]);
        if (gen.err) { json(res, 500, { ok: false, message: '生成失败：' + gen.err, out: gen.out.slice(-300) }); return; }
        if (d.skipPublish) { json(res, 200, { ok: true, message: '已生成（未发布，测试模式）' }); return; }
        let token = '';
        try { token = fs.readFileSync(TOKEN_FILE, 'utf8').trim(); } catch (e) {}
        if (!token) { json(res, 500, { ok: false, message: '未找到 GitHub 令牌' }); return; }
        const pub = await run('publish.js', [token]);
        if (pub.err) { json(res, 500, { ok: false, message: '发布失败：' + pub.err, out: pub.out.slice(-300) }); return; }
        json(res, 200, { ok: true, message: '✅ 已生成并发布上线' });
      } catch (e) { json(res, 500, { ok: false, message: '服务异常：' + e.message }); }
    });
    return;
  }
  json(res, 404, { ok: false, message: 'not found' });
}).listen(PORT, '127.0.0.1', () => console.log('diary-server listening on 127.0.0.1:' + PORT));
