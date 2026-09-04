# diary-watchdog.ps1 — 日记服务看门狗 v3（安全版）
# 职责（只有一条）：DeepSeek 后端(3080)在跑 → 确保日记服务(3099)也在跑。
# v3 变更：移除了 v2 的"自动重启 DeepSeek"功能！
#   原因：v2 分不清"用户主动关闭 DeepSeek"和"DeepSeek 崩溃僵尸"，
#   导致用户关掉 DeepSeek 后 15 秒又被自动拉起（"关不掉"事故，2026-09-04）。
# DeepSeek 打不开/卡死时：手动运行 DeepSeek一键急救.bat 处理。
$node = 'C:\Users\25931\AppData\Local\Programs\DeepSeek\runtime\node.exe'
$server = Join-Path $PSScriptRoot 'diary-server.js'

function Test-PortOpen($port) {
  $c = New-Object System.Net.Sockets.TcpClient
  try { $c.Connect('127.0.0.1', $port); return $true } catch { return $false } finally { $c.Close() }
}
function Ensure-DiaryServer {
  if (-not (Test-Path $node)) { return }
  if (-not (Test-Path $server)) { return }
  if (-not (Test-PortOpen 3099)) {
    Start-Process -FilePath $node -ArgumentList "`"$server`"" -WindowStyle Hidden
    Write-Host "[diary-watchdog] 日记服务已启动 $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Green
  }
}

if ($args -contains '-Once') {
  if (Test-PortOpen 3080) { Ensure-DiaryServer; Write-Host '[diary-watchdog] 检查完成' }
  else { Write-Host '[diary-watchdog] DSH 未运行' }
  exit 0
}

Write-Host '[diary-watchdog v3] 运行中：只在 DeepSeek 启动后保活日记服务（不自动重启 DeepSeek）' -ForegroundColor Cyan
while ($true) {
  try {
    if (Test-PortOpen 3080) { Ensure-DiaryServer }
  } catch {
    Write-Host "[diary-watchdog] 异常: $($_.Exception.Message)" -ForegroundColor DarkYellow
  }
  Start-Sleep -Seconds 5
}
