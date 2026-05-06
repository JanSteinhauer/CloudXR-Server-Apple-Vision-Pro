@echo off
setlocal enabledelayedexpansion

echo ========================================
echo Running CloudXR Setup Validation...
echo ========================================
echo.

set ERRORS=0

:: 1. Check SDK Headers
echo [1/3] Checking CloudXR SDK Headers...
if exist "plugins\nvidia\include\cxrServiceAPI.h" (
    echo    [PASS] cxrServiceAPI.h found.
) else (
    echo    [FAIL] cxrServiceAPI.h missing! CloudXR SDK was not extracted properly.
    set /a ERRORS+=1
)
echo.

:: 2. Check SDK Libraries
echo [2/3] Checking CloudXR SDK Libraries...
dir /b "plugins\nvidia\lib\windows-x86_64\*.dll" >nul 2>&1
if errorlevel 1 (
    echo    [FAIL] CloudXR DLLs missing from plugins\nvidia\lib\windows-x86_64\
    set /a ERRORS+=1
) else (
    echo    [PASS] CloudXR libraries found.
)
echo.

:: 3. Check GPU Compatibility 
echo [3/3] Checking Host GPU...
echo    Detected Video Controller(s):
powershell -NoProfile -Command "Get-CimInstance -ClassName Win32_VideoController | Select-Object -ExpandProperty Name"

echo.
echo    ========================================
echo    CRITICAL: CloudXR 6.x GPU Requirements
echo    ========================================
echo    CloudXR 6.x requires specific newer GPUs for the encoder pipeline.
echo    Using an unsupported GPU (like the RTX 2070 Super) will cause the 
echo    signaling server to fail on port 48010.
echo.
echo    Supported GPUs include:
echo     - NVIDIA GeForce RTX 4090
echo     - NVIDIA GeForce RTX 5080
echo     - NVIDIA GeForce RTX 5090
echo     - NVIDIA RTX 6000 Ada Generation
echo     - NVIDIA RTX PRO 6000 Blackwell Server Edition
echo     - NVIDIA L40
echo     - NVIDIA L40S
echo.

echo ========================================
if %ERRORS%==0 (
    echo STATUS: SDK components are in place! 
    echo Please verify your GPU against the list above.
) else (
    echo STATUS: Found %ERRORS% missing SDK component(s). 
    echo Please ensure the SDK zip is in the root and run build.bat.
)
echo ========================================