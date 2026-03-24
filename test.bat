@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo Test script
echo 参数1: %~1
echo 参数2: %~2

if /i "%~1"=="-h" (
    echo 帮助信息
    goto end
)

:end
endlocal
exit /b 0