@echo off
title SoViCut - Flutter Runner
echo ========================================
echo   Запуск SoViCut
echo ========================================
echo.

echo [1/2] Очистка...
start /wait cmd /c flutter clean

echo.
echo [2/2] Запуск приложения...
echo.

start /wait cmd /c flutter run -d windows

echo.
echo ========================================
echo   Нажмите любую клавишу для выхода
echo ========================================
pause > nul