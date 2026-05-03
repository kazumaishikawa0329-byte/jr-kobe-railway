@echo off
chcp 65001 >nul

set "PROJECT_DIR=D:\Roblox\JR神戸鉄道\project"
set "PLACE_FILE=D:\Roblox\JR神戸鉄道\project\RobloxStudioData.rbxl"

echo ===== 開発環境起動 =====

if not exist "%PROJECT_DIR%" (
    echo Project folder not found:
    echo %PROJECT_DIR%
    pause
    exit /b
)

if not exist "%PLACE_FILE%" (
    echo Roblox file not found:
    echo %PLACE_FILE%
    pause
    exit /b
)

REM =========================
REM VSCode
REM =========================
tasklist /FI "IMAGENAME eq Code.exe" | find /I "Code.exe" >nul
if errorlevel 1 (
    echo VSCode 起動
    start "" code "%PROJECT_DIR%"
) else (
    echo VSCode は既に起動済み
)

REM =========================
REM Roblox Studio
REM =========================
echo Roblox Studio 起動（rbxl読み込み）
start "" "%PLACE_FILE%"

REM =========================
REM Rojo server
REM =========================
netstat -ano | findstr ":34872" | findstr "LISTENING" >nul
if errorlevel 1 (
    echo Rojo Server 起動
    start "Rojo Server" cmd /k "cd /d "%PROJECT_DIR%" && rojo serve"
) else (
    echo Rojo Server は既に起動済み
)

timeout /t 2 >nul

REM =========================
REM Claude Code
REM =========================
tasklist /FI "WINDOWTITLE eq Claude Code*" | find /I "Claude Code" >nul
if errorlevel 1 (
    echo Claude Code 起動
    start "Claude Code" cmd /k "cd /d "%PROJECT_DIR%" && claude"
) else (
    echo Claude Code は既に起動済み
)

REM =========================
REM Webサービス起動
REM =========================
echo Webサービス起動

REM ChatGPT
start "" https://chat.openai.com/

REM Claude（Anthropic）
start "" https://claude.ai/

REM GitHub（あなたのリポジトリ）
start "" https://github.com/kazumaishikawa0329-byte/jr-kobe-railway

REM Roblox Creator Dashboard
start "" https://create.roblox.com/

echo ===== 起動完了 =====
echo Roblox Studioで Rojo の Connect を押してください（localhost:34872）
pause