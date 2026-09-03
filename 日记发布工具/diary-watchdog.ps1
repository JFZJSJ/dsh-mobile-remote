# diary-watchdog.ps1 — 日记服务看门狗 + DeepSeek 自动急救 v2
# 每 5 秒检测一次：
#   A. 3080 开着（DeepSeek 后端正常）→ 确保日记服务(3099)在跑
#   B. 3080 关着 但 DeepSeek.exe 进程还在（僵尸状态）→ 连续 3 次（约15秒）后自动急救：
#      清理 DeepSeek 进程 → 重启 DeepSeek（日记服务随后由 A 拉回）
#   C. DeepSeek 完全没开（用户没启动）→ 什么都不做
# 注意：绝不按名字杀 node（避免误杀 DeepSeek 后端），只处理 DeepSeek.exe
$node = 'C:\Users\25931\AppData\Local\Programs\DeepSeek\runtime\node.exe'
$dse  = 'C:\Users\25931\AppData\Local\Programs\DeepSeek\DeepSeek.exe'
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

Write-Host '[diary-watchdog v2] 运行中：保活日记服务 + 自动急救僵尸 DeepSeek' -ForegroundColor Cyan
$downCount = 0
while ($true) {
  try {
    if (Test-PortOpen 3080) {
      Ensure-DiaryServer
      if ($downCount -ne 0) { Write-Host '[diary-watchdog] 后端已恢复正常' -ForegroundColor Green }
      $downCount = 0
    } elseif (Get-Process -Name DeepSeek -ErrorAction SilentlyContinue) {
      $downCount++
      Write-Host "[diary-watchdog] 后端异常（进程在但 3080 没开），第 ${downCount}/3 次检测" -ForegroundColor Yellow
      if ($downCount -ge 3) {
        Write-Host '[diary-watchdog] 触发自动急救：清理僵尸 DeepSeek 并重启...' -ForegroundColor Red
        Get-Process -Name DeepSeek -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 2
        Start-Process -FilePath $dse
        Write-Host "[diary-watchdog] 已重启 DeepSeek $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Green
        $downCount = 0
      }
    } else {
      $downCount = 0
    }
  } catch {
    Write-Host "[diary-watchdog] 异常: $($_.Exception.Message)" -ForegroundColor DarkYellow
  }
  Start-Sleep -Seconds 5
}
