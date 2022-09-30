@echo off
mode COM10 BAUD=9600 PARITY=n DATA=8 > nul
:Loop
echo RED
set /p x="255,0,0\r" <nul >\\.\COM10
timeout /t 2 /nobreak > nul
echo GREEN
set /p x="0,255,0\r" <nul >\\.\COM10
timeout /t 2 /nobreak > nul
echo BLUE
set /p x="0,0,255\r" <nul >\\.\COM10
timeout /t 2 /nobreak > nul
goto Loop