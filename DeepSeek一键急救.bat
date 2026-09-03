@echo off
title DeepSeek 一键急救
echo.
echo  ==================================================
echo    DeepSeek 一键急救脚本
echo    用途：DeepSeek 打不开 / 界面无反应时使用
echo    作用：清理所有 DeepSeek 进程，然后重新打开
echo    注意：会关闭正在运行的 DeepSeek（含当前对话）
echo  ==================================================
echo.
echo  按回车开始（如果 DeepSeek 现在能用就别运行）...
pause >nul
echo.
echo  [1/4] 清理 DeepSeek 进程...
taskkill /IM DeepSeek.exe /F >nul 2>&1
timeout /t 2 /nobreak >nul
echo  [2/4] 清理残留后端（端口 3080）...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr "127.0.0.1:3080" ^| findstr LISTENING') do (
  taskkill /PID %%a /F >nul 2>&1
)
timeout /t 2 /nobreak >nul
echo  [3/4] 重新打开 DeepSeek...
start "" "C:\Users\25931\AppData\Local\Programs\DeepSeek\DeepSeek.exe"
echo  [4/4] 拉起日记服务看门狗...
start "" wscript.exe "D:\dsh\site-tools\diary-watchdog.vbs"
echo.
echo  ==================================================
echo    完成！DeepSeek 正在启动，请稍等几秒出现窗口
echo    如果 10 秒后还没窗口，再运行一次本脚本
echo  ==================================================
pause
