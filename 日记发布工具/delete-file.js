// delete-file.js — 通过 GitHub API 删除远端文件
// 用法: node delete-file.js <token> <path> <commitMessage>
const https = require('https');
const fs = require('fs');
const path = require('path');
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(path.join(__dirname, 'config.json'), 'utf8').replace(/^\uFEFF/, '')); } catch (e) {}
const token = process.argv[2], filePath = process.argv[3], msg = process.argv[4];
if (!token || !filePath) { console.error('缺少参数'); process.exit(1); }
const OWNER = cfg.owner || 'JFZJSJ', REPO = cfg.repo || 'JFZJSJ.github.io', BRANCH = cfg.branch || 'main';
const API_HOST = '20.205.243.168', SERVERNAME = 'api.github.com';

function api(method, p, body) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const req = https.request({ host: API_HOST, servername: SERVERNAME, port: 443, path: p, method,
      headers: { 'Host': 'api.github.com', 'User-Agent': 'dsh-delete', 'Authorization': 'Bearer ' + token,
        'Accept': 'application/vnd.github+json', ...(payload ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload) } : {}) } },
      (res) => { let d = ''; res.on('data', (c) => (d += c)); res.on('end', () => resolve({ status: res.statusCode, body: d })); });
    req.on('error', reject);
    req.setTimeout(30000, () => req.destroy(new Error('timeout')));
    if (payload) req.write(payload);
    req.end();
  });
}

(async () => {
  const enc = encodeURIComponent(filePath);
  const meta = await api('GET', `/repos/${OWNER}/${REPO}/contents/${enc}?ref=${BRANCH}`);
  if (meta.status !== 200) { console.log('远端文件不存在或读取失败:', meta.status, meta.body.slice(0, 150)); process.exit(meta.status === 404 ? 0 : 1); }
  const sha = JSON.parse(meta.body).sha;
  const r = await api('DELETE', `/repos/${OWNER}/${REPO}/contents/${enc}`, { message: msg || ('删除 ' + filePath), branch: BRANCH, sha });
  console.log('DELETE result:', r.status, r.status === 200 ? 'OK' : r.body.slice(0, 150));
})();
