Set WshShell = CreateObject("WScript.Shell") 
WshShell.Run chr(34) & ".\10_TeamsStatus\TeamsStatus.bat" & Chr(34), 0
Set WshShell = Nothing