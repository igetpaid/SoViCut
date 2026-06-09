@echo off
title SoViCut - Flutter Runner
echo ========================================
echo   Запуск SoViCut
echo ========================================
echo.

echo [1/2] Очистка...
call flutter clean

echo.
echo [2/2] Запуск приложения...
echo.

call flutter run -d windows

echo.
echo ========================================
echo   Нажмите любую клавишу для выхода
echo ========================================
pause > nul