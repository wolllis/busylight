@echo off
REM ######################################################
REM 
REM                     TeamStatus.bat
REM 
REM This script does a couple of things:
REM 1.) Search for USB device based on given HardwareID
REM 2.) Retrieves COM port name if the device is found
REM 3.) Parses Teams logs.txt and looks for status
REM 4.) Sends color values to Trinkey based on status
REM 
REM ######################################################

setlocal EnableExtensions
setlocal ENABLEDELAYEDEXPANSION

REM HardwareID used to identify the Arduino Neo Trinkey (should be the same on all windows machines)
set "HardwareID=VID_239A&PID_80EF&MI_00"
REM Registry path to search for the HardwareID
set "RegistryPath=HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\USB"

REM Local variable definitions
set "ProductName=Arduino Neo Trinkey"
set "DeviceFound=0"
set "TeamsStatusOld=Init"

REM ############# Main Entry Point #############

REM Read config data
for /f "delims=" %%a in ('call ini.cmd config.ini General Brightness') do (
    set brigthness=%%a
)
echo ####### Config Data #######
echo Brigthness=%brigthness%
echo ###########################
echo.

REM Get all objects matching RegistryPath+HardwareID using reg.exe
for /F "delims=" %%I in ('%SystemRoot%\System32\reg.exe QUERY "%RegistryPath%\%HardwareID%" 2^>nul') do (
    REM Search for correct COM port number
    call :GetPort "%%I"
)

REM Check if any matching USB devices have been found
if "%DeviceFound%" == "0" (
    REM Output error message
    echo WARNING: Could not find any connected %ProductName%s
    REM Wait for user interaction
    pause
    REM Return from script here
    goto :EOF
)

REM Configure COM port settings
mode %SerialPort% BAUD=9600 PARITY=n DATA=8

REM Jump to main function
goto MainLoop

REM Never reached
goto :EOF
    
REM ############### Sub Functions ##############

:MainLoop
    REM Check if teams.exe is running
    tasklist /fi "ImageName eq teams.exe" /fo csv 2>NUL | find /I "teams.exe">NUL
    if "%ERRORLEVEL%"=="0" (
        REM Parse Teams logs.txt to retrieve status and change color of Trinkey
        call :ParseStatus
    ) else (
        REM Set status
        set "TeamsStatus=Offline"
    )
    
    REM Check if status changed
    if NOT "%TeamsStatusOld%" == "%TeamsStatus%" (
        echo New status is %TeamsStatus%
        REM Set color for Available
        if "%TeamsStatus%" == "Available" (
            set /p x="0,255,0\r" <nul >\\.\%SerialPort%
        ) else if "%TeamsStatus%" == "Busy" (
            set /p x="255,50,0\r" <nul >\\.\%SerialPort%
        ) else if "%TeamsStatus%" == "DoNotDisturb" (
            set /p x="255,0,0\r" <nul >\\.\%SerialPort%
        ) else if "%TeamsStatus%" == "BeRightBack" (
            set /p x="255,200,0\r" <nul >\\.\%SerialPort%
        ) else if "%TeamsStatus%" == "Away" (
            set /p x="255,200,0\r" <nul >\\.\%SerialPort%
        ) else if "%TeamsStatus%" == "Offline" (
            set /p x="0,0,0\r" <nul >\\.\%SerialPort%
        ) else if "%TeamsStatus%" == "OnThePhone" (
            set /p x="255,0,0\r" <nul >\\.\%SerialPort%
        ) else if "%TeamsStatus%" == "Presenting" (
            set /p x="0,0,255\r" <nul >\\.\%SerialPort%
        ) else if "%TeamsStatus%" == "InAMeeting" (
            set /p x="255,50,0\r" <nul >\\.\%SerialPort%
        ) else (
            echo Status %TeamsStatus% unknown
            set /p x="255,255,255\r" <nul >\\.\%SerialPort%
        )
        REM Store current status
        set "TeamsStatusOld=%TeamsStatus%"
    )
    REM Wait 1 seconds before refresh
    timeout /t 2 /nobreak > nul
    REM Loop forever
    goto MainLoop
    REM Never reached
    goto :EOF
    
:GetPort
    REM Looks for parameter "PortName". This contains the used COM port name.
    for /F "skip=2 tokens=1,3" %%A in ('%SystemRoot%\System32\reg.exe QUERY "%~1\Device Parameters" /v PortName 2^>nul') do (
        if /I "%%A" == "PortName" (
            REM Save COM port name to variable
            set "SerialPort=%%B"
            REM Parse COM port number
            goto OutputPort
        )
    )
    REM Return from subfunction
    goto :EOF

:OutputPort
    REM Looks for real COM port number
    %SystemRoot%\System32\reg.exe query HKLM\HARDWARE\DEVICEMAP\SERIALCOMM | %SystemRoot%\System32\findstr.exe /E /I /L /C:%SerialPort% >nul
    if errorlevel 1 goto :EOF
    set "DeviceFound=1"
    echo %ProductName% is connected through %SerialPort%
    REM Return from subfunction
    goto :EOF

:ParseStatus
    
    REM Find the last line containing a status change
    for /f "tokens=*" %%a in ('findstr "Added" %APPDATA%\Microsoft\Teams\logs.txt') do (
        set line="%%a"
    )
    
    REM Search in line for status
    echo %line% | find /c "Added Available" > nul
    REM Errorlevel is one if the string is found
    if not %errorlevel% equ 1 (
        REM Set status
        set "TeamsStatus=Available"
    )
    
    REM Search in line for status
    echo %line% | find /c "Added Busy" > nul
    REM Errorlevel is one if the string is found
    if not %errorlevel% equ 1 (
        REM Set status
        set "TeamsStatus=Busy"
    )
    
    REM Search in line for status
    echo %line% | find /c "Added DoNotDisturb" > nul
    REM Errorlevel is one if the string is found
    if not %errorlevel% equ 1 (
        REM Set status
        set "TeamsStatus=DoNotDisturb"
    )
    
    REM Search in line for status
    echo %line% | find /c "Added BeRightBack" > nul
    REM Errorlevel is one if the string is found
    if not %errorlevel% equ 1 (
        REM Set status
        set "TeamsStatus=BeRightBack"
    )
    
    REM Search in line for status
    echo %line% | find /c "Added Away" > nul
    REM Errorlevel is one if the string is found
    if not %errorlevel% equ 1 (
        REM Set status
        set "TeamsStatus=Away"
    )
    
    REM Search in line for status
    echo %line% | find /c "Added Offline" > nul
    REM Errorlevel is one if the string is found
    if not %errorlevel% equ 1 (
        REM Set status
        set "TeamsStatus=Offline"
    )
    
    REM Search in line for status
    echo %line% | find /c "Added OnThePhone" > nul
    REM Errorlevel is one if the string is found
    if not %errorlevel% equ 1 (
        REM Set status
        set "TeamsStatus=OnThePhone"
    )
    
    REM Search in line for status
    echo %line% | find /c "Added Presenting" > nul
    REM Errorlevel is one if the string is found
    if not %errorlevel% equ 1 (
        REM Set status
        set "TeamsStatus=Presenting"
    )
    
    REM Search in line for status
    echo %line% | find /c "Added InAMeeting" > nul
    REM Errorlevel is one if the string is found
    if not %errorlevel% equ 1 (
        REM Set status
        set "TeamsStatus=InAMeeting"
    )

    REM Return from subfunction
    goto :EOF
