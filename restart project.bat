@echo off
cd /d D:\SoViCut
title SoViCut - Flutter Runner
echo ========================================
echo   Starting SoViCut...
echo ========================================
echo.

echo [1/2] Cleaning...
call flutter clean

echo.
echo [2/2] Starting SoViCut...
echo.

call flutter run -d windows

echo.
echo ========================================
echo   Press any button to exit
echo ========================================
:: pause > nul