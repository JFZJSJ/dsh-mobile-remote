# ============================================================
#  DSH 手机遥控台 —— 一键安装向导（工业版 / 面向小白）
# ------------------------------------------------------------
#  用法：右键此文件 → 「使用 PowerShell 运行」
#  前提：电脑已安装 DeepSeek 桌面版，且能正常打开使用
#  功能：自动完成 Tailscale 安装/登录、DSH 信任配置、手机页面
#        部署、网站与发布配置 —— 全程按提示输入账号即可
# ============================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'DSH 手机遥控台 · 一键安装'

function Step($n, $t)  { Write-Host "`n════════ [$n/$script:Total] $t ════════" -ForegroundColor Cyan }
function Info($t)      { Write-Host "  $t" -ForegroundColor Gray }
function Good($t)      { Write-Host "  ✅ $t" -ForegroundColor Green }
function Warn($t)      { Write-Host "  ⚠️  $t" -ForegroundColor Yellow }
function Ask($q)       { Write-Host "  $q" -ForegroundColor Yellow; return (Read-Host '  请输入') }
function Pause1()      { Read-Host "`n  按回车继续…" | Out-Null }

$script:Total = 6
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║    DSH 手机遥控台 · 一键安装向导              ║" -ForegroundColor Cyan
Write-Host "  ║    安装过程中会弹出授权窗口，请点“是”         ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
Pause1

# ───────────────────────── 0. 环境检查 ─────────────────────────
Step 1 "检查电脑环境"
$dshHome = "$env:USERPROFILE\.dsh"
$attempts = 0
if (-not (Test-Path "$dshHome\profiles\web")) {
  while ($attempts -lt 3) {
  Write-Host "  ❌ 还没有 DSH 的数据目录（$dshHome）" -ForegroundColor Red
  Write-Host "     需要先安装 DeepSeek Harness 桌面客户端（开源社区构建，GitHub 下载）——它是“大脑”" -ForegroundColor Yellow
  Write-Host "     在 GitHub 搜 dsh-desktop，任选一个社区构建（如 foolgry/dsh-desktop、EasyTZ/dsh-desktop）" -ForegroundColor Yellow
  $do = Ask "现在打开 GitHub 搜索页？(y/n)"
  if ($do -match '^[yY]') { Start-Process 'https://github.com/search?q=dsh-desktop&type=repositories' }
  Warn "装好并打开一次（登录账号、确认能聊天）后，按回车让我重新检查……"
  Pause1
  $attempts++
  }
}
if (-not (Test-Path "$dshHome\profiles\web")) {
  Write-Host "  ❌ 仍未检测到 DSH，请安装好后再运行本向导" -ForegroundColor Red
  Pause1; exit 1
}
Good "发现 DSH 环境"
$dist = Get-ChildItem "$dshHome\profiles\node_modules\@deepseek-ai\dsh-web-frontend\dist" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
if ($dist) { Good "发现手机页面部署目录：$($dist.FullName)" } else { Warn "未找到部署目录，稍后会重新查找" }

# ───────────────────────── 1. Tailscale ─────────────────────────
Step 2 "安装并登录 Tailscale（加密远程通道）"
$ts = 'C:\Program Files\Tailscale\tailscale.exe'
if (-not (Test-Path $ts)) {
  Warn "电脑上还没有 Tailscale，正在自动安装……"
  Warn "稍后会弹出“用户账户控制”窗口，请点【是】"
  $installed = $false
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    try { winget install --id Tailscale.Tailscale -e --accept-source-agreements --accept-package-agreements 2>$null; $installed = $true } catch {}
  }
  if (-not $installed -or -not (Test-Path $ts)) {
    Warn "自动安装未成功，请手动安装后重跑本向导："
    Write-Host "       https://tailscale.com/download/windows" -ForegroundColor Yellow
    Warn "（国内若打不开 Tailscale 官网，可先打开梯子再下载，或稍后重试）"
    Pause1; exit 1
  }
  Good "Tailscale 已安装"
} else { Good "Tailscale 已存在" }

$st = (& $ts status 2>&1 | Out-String)
if ($st -match 'Logged out|NeedsLogin') {
  Warn "现在需要登录 Tailscale（用你的 Google/微软/邮箱账号）"
  Warn "下一步会显示一个网址：如果浏览器没自动弹出，请手动复制网址到浏览器打开并登录"
  Warn "登录完成后回到这个窗口，按回车继续……"
  Pause1
  & $ts up
  if ($LASTEXITCODE -ne 0) { Warn "登录未完成，请重试或手动运行：tailscale up"; Pause1; exit 1 }
}
$ip = (& $ts ip -4 | Select-Object -First 1).Trim()
$json = (& $ts status --json | Out-String | ConvertFrom-Json)
$dns = $json.Self.DNSName -replace '\.$',''
Good "远程地址已就绪：IP=$ip  域名=$dns"

# ───────────────────────── 2. DSH 信任配置 ─────────────────────────
Step 3 "配置 DSH 信任（让手机能访问）"
$patchFile = "$dshHome\profiles\web\cordis.patch.yml"
if (Test-Path $patchFile) {
  Copy-Item $patchFile "$patchFile.bak-$(Get-Date -Format yyyyMMdd-HHmmss)" -Force
  Warn "已备份原配置"
}
$patch = @"
# 由 DSH 手机遥控台一键安装向导自动生成
# 信任 Tailscale 地址，允许手机浏览器通过 /api 围栏
- id: web-runtime
  config:
    printUrl: true
    surfaceContext: true
    trustedHosts: !!js "[...(ctx.webStartup?.trustedHosts ?? []), '$ip', '$dns']"

- id: connection
  config:
    trustedHosts: !!js "[...(ctx.webRuntime?.trustedHosts ?? []), '$ip', '$dns']"
"@
Set-Content -Path $patchFile -Value $patch -Encoding UTF8
Good "信任配置已写入（含备份）"

# ───────────────────────── 3. 开启隧道 ─────────────────────────
Step 4 "开启远程隧道（HTTP + HTTPS）"
& $ts serve --bg --yes --http=3080 http://127.0.0.1:3080 2>&1 | Out-Null
Good "HTTP 隧道已开启（端口 3080）"
& $ts serve --bg --yes --https=443 http://127.0.0.1:3080 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
  Good "HTTPS 隧道已开启（端口 443，手机 App 安装用）"
} else {
  Warn "HTTPS 没开成功。请在浏览器打开 https://login.tailscale.com/admin/dns"
  Warn "打开【HTTPS Certificates】开关后，重新运行本向导即可补上。"
}

# ───────────────────────── 4. 部署手机页面 ─────────────────────────
Step 5 "部署手机页面"
$distDir = $null
$cand = Get-ChildItem "$dshHome\profiles\node_modules\@deepseek-ai\dsh-web-frontend\dist" -ErrorAction SilentlyContinue
if (Test-Path "$dshHome\profiles\node_modules\@deepseek-ai\dsh-web-frontend\dist") { $distDir = "$dshHome\profiles\node_modules\@deepseek-ai\dsh-web-frontend\dist" }
if (-not $distDir) { Warn "没找到部署目录，请手动把【手机遥控台】文件夹的内容复制到 dist 目录"; Pause1 }
else {
  $src = Join-Path $PSScriptRoot '手机遥控台'
  if (Test-Path $src) {
    Copy-Item (Join-Path $src '*') -Destination $distDir -Recurse -Force
    Good "手机页面已部署到：$distDir"
  } else { Warn "找不到本目录下的【手机遥控台】文件夹，请保持文件夹完整" }
}

# ───────────────────────── 5. 网站发布配置 ─────────────────────────
Step 6 "配置你的个人网站（可选）"
$wantSite = Ask "要不要配置“写日记自动发布网站”？(y/n)"
if ($wantSite -match '^[yY]') {
  $owner   = Ask "GitHub 用户名（例如 JFZJSJ）："
  $repo    = Ask "网站仓库名（例如 JFZJSJ.github.io）："
  $branch  = Ask "分支（一般填 main）："
  $token   = Ask "GitHub 令牌（不会显示，粘贴后回车）—— 没有可留空，稍后补"
  $token   = $token.Trim()
  if ($token) { Set-Content -Path "$dshHome\.github-token" -Value $token -NoNewline -Encoding Ascii; Good "令牌已保存" }
  $sitePath = "$env:USERPROFILE\my-website"
  $cfg = @{ sitePath = $sitePath; owner = $owner; repo = $repo; branch = $branch } | ConvertTo-Json
  Set-Content -Path (Join-Path $PSScriptRoot '日记发布工具\config.json') -Value $cfg -Encoding UTF8
  Good "发布配置已写入"
  Warn "请把本目录下的【日记发布工具】文件夹复制到电脑任意位置，并记下路径"
  Warn "（生成/发布脚本以后都从那里运行）"
} else { Info "跳过网站配置（以后可随时补）" }

# ───────────────────────── 完成 ─────────────────────────
Write-Host "`n════════════ 安装完成 ════════════" -ForegroundColor Green
Write-Host "  1. 【重要】请完全退出并重新打开 DeepSeek 应用（让配置生效）" -ForegroundColor Yellow
Write-Host "  2. 手机上：安装 Tailscale App → 用同一账号登录" -ForegroundColor Yellow
Write-Host "  3. 手机浏览器打开：https://$dns/mobile.html" -ForegroundColor Yellow
Write-Host "  4. 浏览器菜单 → 添加到主屏幕 / 安装应用" -ForegroundColor Yellow
Write-Host "`n  详细步骤见同目录：手机端操作.md" -ForegroundColor Gray
Pause1
