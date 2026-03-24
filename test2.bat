@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

echo Test script working!
echo Parameter 1: %~1
echo Parameter 2: %~2

if /i "%~1"=="-h" (
    echo Help information displayed!
    goto end
)

:end
endlocal
exit /b 0