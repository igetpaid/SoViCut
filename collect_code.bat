@echo off
title Collect Code Files
echo Сбор всех Dart файлов проекта (кроме системных)...

set OUTPUT=allcode.txt
if exist %OUTPUT% del %OUTPUT%

echo ======================================== >> %OUTPUT%
echo SoViCut - Полный код проекта >> %OUTPUT%
echo Собрано: %date% %time% >> %OUTPUT%
echo ======================================== >> %OUTPUT%
echo. >> %OUTPUT%

:: Ищем только в папках lib, windows/runner (только наши файлы)
for /r "D:\SoViCut\lib" %%f in (*.dart) do (
    echo. >> %OUTPUT%
    echo ======================================== >> %OUTPUT%
    echo FILE: %%f >> %OUTPUT%
    echo ======================================== >> %OUTPUT%
    echo. >> %OUTPUT%
    type "%%f" >> %OUTPUT%
    echo. >> %OUTPUT%
)

:: Добавляем main.dart из корня (если есть)
if exist "D:\SoViCut\lib\main.dart" (
    echo. >> %OUTPUT%
    echo ======================================== >> %OUTPUT%
    echo FILE: D:\SoViCut\lib\main.dart >> %OUTPUT%
    echo ======================================== >> %OUTPUT%
    echo. >> %OUTPUT%
    type "D:\SoViCut\lib\main.dart" >> %OUTPUT%
    echo. >> %OUTPUT%
)

:: Добавляем pubspec.yaml (важный файл)
if exist "D:\SoViCut\pubspec.yaml" (
    echo. >> %OUTPUT%
    echo ======================================== >> %OUTPUT%
    echo FILE: D:\SoViCut\pubspec.yaml >> %OUTPUT%
    echo ======================================== >> %OUTPUT%
    echo. >> %OUTPUT%
    type "D:\SoViCut\pubspec.yaml" >> %OUTPUT%
    echo. >> %OUTPUT%
)

echo Готово! Файл сохранён: %OUTPUT%
echo Собраны только папки: lib/, а также pubspec.yaml
pause