@echo off
chcp 1251
title SoViCut - Flutter Runner
echo ========================================
echo   Запуск SoViCut
echo ========================================
echo.

echo [1/2] Очистка...
flutter clean

echo.
echo [2/2] Запуск приложения...
echo.

cmd /k flutter run -d windows