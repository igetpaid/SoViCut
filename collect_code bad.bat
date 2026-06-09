@echo off
title Collect Code Files
echo Сбор всех Dart файлов проекта...

set OUTPUT=allcode.txt
if exist %OUTPUT% del %OUTPUT%

echo ======================================== >> %OUTPUT%
echo SoViCut - Полный код проекта >> %OUTPUT%
echo Собрано: %date% %time% >> %OUTPUT%
echo ======================================== >> %OUTPUT%
echo. >> %OUTPUT%

for /r %%f in (*.dart) do (
    echo. >> %OUTPUT%
    echo ======================================== >> %OUTPUT%
    echo FILE: %%f >> %OUTPUT%
    echo ======================================== >> %OUTPUT%
    echo. >> %OUTPUT%
    type "%%f" >> %OUTPUT%
    echo. >> %OUTPUT%
)

echo Готово! Файл сохранён: %OUTPUT%
pause