@echo off

setlocal EnableExtensions
setlocal ENABLEDELAYEDEXPANSION

REM HardwareID used to identify the Arduino Neo Trinkey (should be the same on all windows machines)
set "HardwareID=VID_239A&PID_80EF&MI_00"
REM Registry path to search for the HardwareID
set "RegistryPath=HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\USB"

REM Local variable definitions
set "ProductName=Arduino Neo Trinkey"
set "DeviceFound=0"

REM ############# Main Entry Point #############

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
	REM Send color string to Trinkey
	set /p x="255,0,0\r" <nul >\\.\%SerialPort%
	
	REM Exit script
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
