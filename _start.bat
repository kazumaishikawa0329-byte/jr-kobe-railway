@echo off
chcp 65001 >nul

REM =========================
REM 相対パス設定
REM このbatファイルを project フォルダ内に置く
REM =========================
set "PROJECT_DIR=%~dp0"
set "PLACE_FILE=%PROJECT_DIR%RobloxStudioData.rbxl"

echo ===== 開発環境起動 =====
echo PROJECT_DIR=%PROJECT_DIR%
echo PLACE_FILE=%PLACE_FILE%

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
REM PowerShellでプロジェクトフォルダに移動して実行
REM Claudeアプリ自体は別で開いてOK
REM =========================
echo Claude Code 起動（PowerShell）

where claude >nul 2>nul
if errorlevel 1 (
    echo claude コマンドが見つかりません。
    echo Claude Code がインストール済みか、PATHが通っているか確認してください。
    pause
) else (
    start "Claude Code" powershell -NoExit -NoProfile -ExecutionPolicy Bypass -Command "Set-Location -LiteralPath '%PROJECT_DIR%'; claude"
)
REM =========================
REM アプリ起動・前面表示
REM =========================
echo アプリ起動

REM ChatGPT
echo ChatGPT 起動
start "" "shell:AppsFolder\OpenAI.ChatGPT-Desktop_2p2nqsd0c76g0!ChatGPT"
timeout /t 3 >nul
powershell -NoProfile -Command "$ws = New-Object -ComObject WScript.Shell; $ws.AppActivate('ChatGPT') | Out-Null"

REM Claude
echo Claude 起動
start "" "shell:AppsFolder\Claude_pzs8sxrjxfjjc!Claude"
timeout /t 3 >nul
powershell -NoProfile -Command "$ws = New-Object -ComObject WScript.Shell; $ws.AppActivate('Claude') | Out-Null"
REM GitHub（リポジトリ）
start "" https://github.com/kazumaishikawa0329-byte/jr-kobe-railway

REM Roblox Creator Dashboard
start "" https://create.roblox.com/

echo ===== 起動完了 =====
echo Roblox Studioで Rojo の Connect を押してください（localhost:34872）
pause
exit /b

REM =========================
REM Storeアプリを起動して前面表示する共通処理
REM %1 = 表示名
REM %2 = AppUserModelID
REM %3 = プロセス名/タイトル検索文字
REM =========================
:LaunchAndFocus
set "APP_NAME=%~1"
set "APP_ID=%~2"
set "APP_KEY=%~3"

echo %APP_NAME% 起動・前面表示

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"Add-Type -Name Win -Namespace Native -MemberDefinition '[DllImport(\"user32.dll\")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow); [DllImport(\"user32.dll\")] public static extern bool SetForegroundWindow(IntPtr hWnd);'; ^
Start-Process explorer.exe 'shell:AppsFolder\%APP_ID%'; ^
Start-Sleep -Milliseconds 2500; ^
$end=(Get-Date).AddSeconds(10); ^
do { ^
  $p=Get-Process -ErrorAction SilentlyContinue | Where-Object { ($_.ProcessName -like '*%APP_KEY%*' -or $_.MainWindowTitle -like '*%APP_KEY%*') -and $_.MainWindowHandle -ne 0 } | Select-Object -First 1; ^
  if($p){ [Native.Win]::ShowWindowAsync($p.MainWindowHandle,9) | Out-Null; Start-Sleep -Milliseconds 300; [Native.Win]::SetForegroundWindow($p.MainWindowHandle) | Out-Null; exit 0 } ^
  Start-Sleep -Milliseconds 500 ^
} while((Get-Date) -lt $end); ^
exit 1"

if errorlevel 1 (
    echo %APP_NAME% の前面表示に失敗しました。手動でクリックしてください。
)

exit /b