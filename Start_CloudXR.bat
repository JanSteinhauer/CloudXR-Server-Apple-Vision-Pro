@echo off
setlocal

set "REPO_ROOT=%~dp0"
set "DEPLOYMENT=%REPO_ROOT%Stream-Manager-6.1.0-win64-CloudXR-6.2.1"
set "SERVER_DIR=%DEPLOYMENT%\Server"
set "MANAGER=%SERVER_DIR%\NvStreamManager.exe"
set "CLIENT=%DEPLOYMENT%\SampleClient\SampleNvStreamManagerClient.exe"
set "XR_RUNTIME_JSON=%SERVER_DIR%\releases\6.2.1\openxr_cloudxr.json"

if /I "%~1"=="--check" (
    set "CHECK_ONLY=1"
    set "UNITY_EXE=%~f2"
) else (
    set "CHECK_ONLY=0"
    set "UNITY_EXE=%~f1"
)

if "%UNITY_EXE%"=="" (
    echo [ERROR] No Unity executable was supplied.
    echo Usage: %~nx0 "path\to\MasterThesisStarting.exe"
    exit /b 2
)

for %%F in ("%MANAGER%" "%CLIENT%" "%XR_RUNTIME_JSON%" "%UNITY_EXE%") do (
    if not exist "%%~fF" (
        echo [ERROR] Required file not found: %%~fF
        exit /b 3
    )
)

if "%CHECK_ONLY%"=="1" (
    echo [OK] Stream Manager: %MANAGER%
    echo [OK] Runtime JSON:  %XR_RUNTIME_JSON%
    echo [OK] Unity build:   %UNITY_EXE%
    exit /b 0
)

echo Configuring NVIDIA CloudXR Runtime 6.2.1...

rem Refuse to connect the sample client to a manager from an older deployment.
set "CLOUDXR_EXPECTED_MANAGER=%MANAGER%"
powershell -NoProfile -Command "$expected=[IO.Path]::GetFullPath($env:CLOUDXR_EXPECTED_MANAGER); $all=@(Get-Process NvStreamManager -ErrorAction SilentlyContinue); $wrong=$all ^| Where-Object { $_.Path -and -not [String]::Equals([IO.Path]::GetFullPath($_.Path),$expected,[StringComparison]::OrdinalIgnoreCase) }; if($wrong){ $wrong ^| ForEach-Object { Write-Host ('[ERROR] Another Stream Manager is running: ' + $_.Path) }; exit 2 }; if($all.Count -gt 0){exit 0}else{exit 1}"

if errorlevel 2 (
    echo Stop the old Stream Manager and run this launcher again.
    exit /b 4
)

if errorlevel 1 (
    echo Starting Stream Manager 6.1.0...
    start "" /min /d "%SERVER_DIR%" "%MANAGER%"
    timeout /t 3 /nobreak >nul
)

tasklist /fi "IMAGENAME eq CloudXrService.exe" 2>nul | find /i "CloudXrService.exe" >nul
if errorlevel 1 (
    echo Starting CloudXR Runtime 6.2.1...
    (
        echo StartCxrService 6.2.1
        echo GetCxrServiceStatus
        echo quit
    ) | "%CLIENT%"
) else (
    echo CloudXR Runtime is already running.
)

echo OpenXR runtime: %XR_RUNTIME_JSON%
echo Starting Unity build: %UNITY_EXE%
start "" /d "%~dp1" "%UNITY_EXE%"

echo Unity launched. Connect the visionOS 27 client and allow microphone access.
pause
