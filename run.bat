@echo off
chcp 65001 >nul
title SoViCut

:: Check if flutter is on PATH
where flutter >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Flutter not found in PATH.
    echo.
    echo Make sure Flutter is installed and added to PATH.
    echo Download: https://flutter.dev/docs/get-started/install/windows
    pause
    exit /b 1
)

echo ^============================================^
echo ^|           SoViCut — Run Script            ^|
echo ^============================================^
echo.
echo Available commands:
echo   1 or Enter — flutter run ^(default^)
echo   2         — flutter run -d windows
echo   3         — flutter analyze
echo   4         — flutter clean ^&^& flutter pub get
echo   5         — flutter build windows
echo   Q         — Quit
echo.

set /p cmd="Select [1-5, Q]: "
if "%cmd%"=="" set cmd=1

if "%cmd%"=="1" (
    echo.
    echo ^> flutter run
    flutter run
) else if "%cmd%"=="2" (
    echo.
    echo ^> flutter run -d windows
    flutter run -d windows
) else if "%cmd%"=="3" (
    echo.
    echo ^> flutter analyze
    flutter analyze
    echo.
    pause
) else if "%cmd%"=="4" (
    echo.
    echo ^> flutter clean ^&^& flutter pub get
    flutter clean
    if %ERRORLEVEL% equ 0 (
        flutter pub get
    )
    echo.
    pause
) else if "%cmd%"=="5" (
    echo.
    echo ^> flutter build windows
    flutter build windows
    echo.
    pause
) else if /i "%cmd%"=="Q" (
    exit /b 0
) else (
    echo Unknown option.
    pause
)
