import os
import time
import serial 
import serial.tools.list_ports
import sys
from datetime import datetime

# Hardware ID of the trinkey neo
BUSYLIGHT_HWID = "239A:80EF"

# Map of glyph state to RGB value (0...255)
### In total there are 5 different glyphs indicating a total of 9 states ###
GlyphBadge = {
"available"     : b"0,150,0\r",  # "Available"
"busy"          : b"150,0,0\r",  # "Busy", "OnThePhone", "InAMeeting"
"doNotDistrb"   : b"150,0,0\r",  # "DoNotDisturb", "Presenting"
"away"          : b"0,0,0\r",    # "Away", "BeRightBack"
"offline"       : b"0,0,0\r",    # "Offline"
### There is no seperate glyph to indicate the following states ### 
"beRightBack"   : b"0,0,255\r",
"onThePhone"    : b"0,0,255\r",
"presenting"    : b"0,0,255\r",
"inAMeeting"    : b"0,0,255\r"
}


def err_handler(type, value, tb):
    LogEntry("Uncaught exception: {0}".format(str(value)))
    

def LogEntry(data):
    
    # Get script path for log file creation
    scriptpath = os.path.dirname(os.path.abspath(__file__))
    
    date_time = datetime.now()
    str_date_time = date_time.strftime("%Y-%m-%d %H:%M:%S > ")

    with open(scriptpath + "/busylight.log", "a") as scriptlog:
        scriptlog.write(str_date_time + data)
        
    


def UpdateIndicatorLight(state):
    comport = None
    # Get comports as list
    ports = serial.tools.list_ports.comports()

    # Search for hardware id
    for port, desc, hwid in sorted(ports):
        if hwid.find(BUSYLIGHT_HWID) >= 0:
            comport = port
            break

    # Check if comport was found
    if comport == None:
        LogEntry("No comport found, try again next time...\n")
        return 1
    
    # Send command to busylight
    with serial.Serial(comport) as ser:
        ser.write(GlyphBadge[state])
        
    # Return with success
    return 0


def FindLogfile():
    logfiles = []
    # Find MS Teams package folder
    temp = os.getenv('LOCALAPPDATA') + "\\Packages"
    for directory in os.listdir(temp):
        if directory.find("MSTeams") == 0:
            temp += "\\" + directory + "\\LocalCache\\Microsoft\\MSTeams\\Logs"

    # Find MS Teams logfiles
    for directory in os.listdir(temp):
        if directory.find("MSTeams_") == 0:
            logfiles.append(directory)

    # Check if logfile was found
    if len(logfiles) == 0:
        LogEntry("Logfile was not found: " + temp + "\n")
        return None
    
    # Find newest logfile
    logfiles.sort(reverse=True)

    # Return Logfile path
    return temp + "\\"+logfiles[0]

Currentstate = None

LogEntry("Script started\n")

# Install exception handler
sys.excepthook = err_handler

while(1):
    logfile = FindLogfile()
    if logfile is None:
        # File hasn't been found, try again later
        LogEntry("No logfile found, try again later\n")
        time.sleep(5)
        continue
    
    tmp_state = None
    
    # Seach for latest state in logfile
    with open(logfile, "r") as file:
        for line in file:
            if line.find("GlyphBadge") >= 0:
                # Line has availability information
                start = line.find("{\"") + len("{\"")
                end = line.find("\"}")
                if start >= 0 and end >= 0:
                    # Update temp string
                    tmp_state = line[start:end]
    
    # Update busylight with last found state
    if tmp_state != None:
        LogEntry("New State: " + tmp_state + "\n")
        UpdateIndicatorLight(tmp_state)
    
    # Open Logfile
    with open(logfile, "r") as file:
        # seek the end of the file
        file.seek(0, os.SEEK_END)
        
        # start infinite loop
        while True:
            # read last line of file
            line = file.readline()
            if not line:
                # File hasn't been updated
                time.sleep(0.5)
                newlogfile = FindLogfile()
                if newlogfile != logfile:
                    break
                continue
            else:
                # New line present => Search for keyword
                if line.find("GlyphBadge") >= 0:
                    # Line has availability information
                    start = line.find("{\"") + len("{\"")
                    end = line.find("\"}")
                    if start >= 0 and end >= 0:
                        if line[start:end] != Currentstate:
                            LogEntry("New State: " + line[start:end] + "\n")
                            # Update Busylight
                            temp = 1
                            while temp:
                                temp = UpdateIndicatorLight(line[start:end])
                                if temp:
                                    # Could not set state
                                    time.sleep(1)
                            Currentstate = line[start:end]
                    else:
                        LogEntry("Broken state line in logfile\n")
                elif line.find("TelemetryService: Telemetry service stopped") >= 0:
                    LogEntry("New State: Teams closed\n")
                    # Update Busylight
                    temp = 1
                    while temp:
                        temp = UpdateIndicatorLight("offline")
                        if temp:
                            # Could not set state
                            time.sleep(1)
                        
