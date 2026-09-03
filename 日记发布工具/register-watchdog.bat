@echo off
chcp 65001 >nul
title DSH 日记服务看门狗 · 注册开机自启
echo.
echo  正在注册"日记服务看门狗"为开机自启任务……
echo  （以后只要 DeepSeek 打开，日记服务就会自动启动）
echo.
schtasks /create /tn "DSH日记服务看门狗" /tr "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%~dp0diary-watchdog.ps1\"" /sc onlogon /f
echo.
if %errorlevel%==0 (
  echo  ? 注册成功！现在立即启动看门狗……
  schtasks /run /tn "DSH日记服务看门狗"
  echo   ? 看门狗已在后台运行
) else (
  echo  ? 注册失败（可能需要管理员权限：右键本文件 → 以管理员身份运行）
)
echo.
pause
