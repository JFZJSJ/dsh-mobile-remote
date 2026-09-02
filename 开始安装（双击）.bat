@echo off
chcp 65001 >nul
title DSH 手机遥控台 · 一键安装
echo.
echo   正在启动安装向导，请稍候……
echo   （如果弹出"用户账户控制"窗口，请点【是】）
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0一键安装.ps1"
echo.
pause
