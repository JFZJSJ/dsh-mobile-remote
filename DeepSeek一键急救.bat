@echo off
chcp 65001 >nul
title DeepSeek 一键急救（清理卡死进程并重启）
echo.
echo  ╔══════════════════════════════════════════════╗
echo  ║   DeepSeek 一键急救脚本                       ║
echo  ║  用途：DeepSeek 打不开/无窗口时使用            ║
echo  ║  作用：清理所有 DeepSeek 进程 -^> 重新打开     ║
echo  ║  注意：会关闭正在运行的 DeepSeek（含本对话）   ║
echo  ╚══════════════════════════════════════════════╝
echo.
echo  按回车开始（如果 DeepSeek 现在能用就别运行这个）...
pause >nul

echo.
echo  [1/4] 清理 DeepSeek 进程…
taskkill /IM DeepSeek.exe /F >nul 2>&1
timeout /t 2 /nobreak >nul

echo  [2/4] 检查并清理残留后端（端口 3080）…
for /f "tokens=5" %%a in ('netstat -ano ^| findstr "127.0.0.1:3080" ^| findstr LISTENING') do (
  taskkill /PID %%a /F >nul 2>&1
)
timeout /t 2 /nobreak >nul

echo  [3/4] 重新打开 DeepSeek…
start "" "C:\Users\25931\AppData\Local\Programs\DeepSeek\DeepSeek.exe"

echo  [4/4] 拉起日记服务看门狗…
start "" wscript.exe "D:\dsh\site-tools\diary-watchdog.vbs"

echo.
echo  ✅ 完成！DeepSeek 正在启动，请稍等几秒出现窗口
echo     （如果 10 秒后还没窗口，再运行一次本脚本）
echo.
pause
