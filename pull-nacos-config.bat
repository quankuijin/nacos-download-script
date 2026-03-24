@echo off
chcp 65001 > nul
setlocal

set "SERVER_URL=http://localhost:8848"
set "DATA_ID="
set "GROUP=DEFAULT_GROUP"
set "NAMESPACE="
set "OUTPUT_DIR="
set "USERNAME="
set "PASSWORD="

:parse_args
if "%~1"=="" goto run_script
if /i "%~1"=="-h" goto show_help
if /i "%~1"=="/h" goto show_help
if /i "%~1"=="--help" goto show_help
if /i "%~1"=="-s" (
    set "SERVER_URL=%~2"
    shift
    shift
    goto parse_args
)
if /i "%~1"=="--server" (
    set "SERVER_URL=%~2"
    shift
    shift
    goto parse_args
)
if /i "%~1"=="-d" (
    set "DATA_ID=%~2"
    shift
    shift
    goto parse_args
)
if /i "%~1"=="--data-id" (
    set "DATA_ID=%~2"
    shift
    shift
    goto parse_args
)
if /i "%~1"=="-g" (
    set "GROUP=%~2"
    shift
    shift
    goto parse_args
)
if /i "%~1"=="--group" (
    set "GROUP=%~2"
    shift
    shift
    goto parse_args
)
if /i "%~1"=="-n" (
    set "NAMESPACE=%~2"
    shift
    shift
    goto parse_args
)
if /i "%~1"=="--namespace" (
    set "NAMESPACE=%~2"
    shift
    shift
    goto parse_args
)
if /i "%~1"=="-o" (
    set "OUTPUT_DIR=%~2"
    shift
    shift
    goto parse_args
)
if /i "%~1"=="--output" (
    set "OUTPUT_DIR=%~2"
    shift
    shift
    goto parse_args
)
if /i "%~1"=="-u" (
    set "USERNAME=%~2"
    shift
    shift
    goto parse_args
)
if /i "%~1"=="--username" (
    set "USERNAME=%~2"
    shift
    shift
    goto parse_args
)
if /i "%~1"=="-p" (
    set "PASSWORD=%~2"
    shift
    shift
    goto parse_args
)
if /i "%~1"=="--password" (
    set "PASSWORD=%~2"
    shift
    shift
    goto parse_args
)
echo 未知参数: %~1
goto show_help

:run_script
set "PS_ARGS="
if not "%SERVER_URL%"=="" set "PS_ARGS=%PS_ARGS% --server ""%SERVER_URL%"""
if not "%DATA_ID%"=="" set "PS_ARGS=%PS_ARGS% --dataId ""%DATA_ID%"""
if not "%GROUP%"=="" set "PS_ARGS=%PS_ARGS% --group ""%GROUP%"""
if not "%NAMESPACE%"=="" set "PS_ARGS=%PS_ARGS% --namespace ""%NAMESPACE%"""
if not "%OUTPUT_DIR%"=="" set "PS_ARGS=%PS_ARGS% --output ""%OUTPUT_DIR%"""
if not "%USERNAME%"=="" set "PS_ARGS=%PS_ARGS% --username ""%USERNAME%"""
if not "%PASSWORD%"=="" set "PS_ARGS=%PS_ARGS% --password ""%PASSWORD%"""

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pull-nacos-config.ps1" %PS_ARGS%
goto end

:show_help
echo.
echo Nacos配置拉取工具 v1.0.0
echo.
echo 用法: pull-nacos-config.bat [选项]
echo.
echo 选项:
echo   -s, --server     Nacos服务器地址 (默认: http://localhost:8848)
echo   -d, --data-id   配置文件ID (必需)
echo   -g, --group     配置分组 (默认: DEFAULT_GROUP)
echo   -n, --namespace  命名空间ID (可选)
echo   -o, --output     输出目录 (必需)
echo   -u, --username  Nacos用户名 (可选)
echo   -p, --password  Nacos密码 (可选)
echo   -h, --help       显示帮助信息
echo.
echo 示例:
echo   pull-nacos-config.bat -d application.yml -o ./config
echo   pull-nacos-config.bat -s http://192.168.1.100:8848 -d app.yml -g DEV_GROUP -o ./config
echo   pull-nacos-config.bat -s http://localhost:8848 -d config.json -n dev -o ./config -u nacos -p nacos
echo.

:end
endlocal
exit /b %ERRORLEVEL%