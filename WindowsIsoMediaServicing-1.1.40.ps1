
<#
.SUMMARY
  Microsoft Windows 11 Installation Media Servicing

  First run the script with the -Folders switch only. This will create the folder structure for servicing.

  ***IMPORTANT - PRIOR TO SERVICING***
  1. Install the latest version of the Windows Automated Installation Kit (ADK)
     Reference Url: https://go.microsoft.com/fwlink/?linkid=2289980
     
  2. Download Windows 11 Installation Media ISO
     Reference Url: https://www.microsoft.com/en-us/software-download/windows11
     Place ISO in C:\Temp 
  
  3. Download autopilot scripts (AutopilotInfo.ps1 and/or AutopilotInfo-Online.ps1)
     Reference Url: https://github.com/Metropolis-Pt3/Autopilot
     Please in C:\Temp\Virtual\Scripts

  4. Download any drivers (storage, network and wireless). If using Hyper-V for testing, include network drivers for the host machine.
     If using "External Switch" in Hyper-V sometimes network driver is needed in the ISO.

.DESCRIPTION
  Microsoft Windows 11 (25H2) Installation Media Servicing. Uses the Microsoft Media Creation to to build iso
  Media, then adds utilties, scripts and drivers to support Dell and HP Models.

  Supports multiple versions of Windows 11 (25H3 and 23H2) for feature update testing.

  Note: Download drivers prior to servicing.

.PARAMETERS

  .\WindowsIsoMediaServicing-1.1.40.ps1

  -Folders - Creates the servicing folder structure.

  -IsoMedia - Mounts the iso, gathers drive letter and copies .iso contents to servicing location  <--- Only needs to be done once...

  -Boot - Services the boot.wim <----- injects drivers into the boot.wim. Rare this will be needed.

  -Install - Services the install.wim <----- injects drivers into the install.wim. Storage, network and wifi drivers are recommend.

  -Tools - Adds tools and utilities to install.wim.

  -Confirm - Confirms .wim updates.

  -UpdatSourceMedia - imports boot.wim and install.wim from servicing location for media creation.

  -Iso - Creates NEW iso media with all servicing updates.

.NOTES/REFERENCES
  Current Version=1.1.40
  Date: 4.1.2026
  Author: Steve Molzahn

  Changelog:
  4.1.2026 - Initial script. v1.0.2
  4.4.2026 - Updated Logic and features. v1.0.8
  4.10.2026
      -Added automation feature to create updated ISO. v1.0.10
      -Added autopilotinfo.ps1 and autopilotinfo-online.ps1 to install.wim. v1.0.11
      -Added logic to wait for ISO creation prior to script continuing. v1.0.12

  4.16.2026 - Mass update to logic and features. v1.0.24
  4.28.2026
      - Fixed issue with ISO mount and file copy. v1.0.25
      - Added tooling to unmount .wim that was not sucessful or partically mounted. v1.0.26

  5.1.2026 - Full run through and logic/function fixes. Add checks for Windows ADk. v1.0.32
  5.16.2026 - Updated automated workflows, useage documentation, logic and functionl enhancements. v1.1.32
  7.9.2026
      - Updated logic and added functionality for ACL's and permissions. v1.1.36
      - Added logic for multiple versions of Windows 11, for feature update testing. v1.1.38
      - Fixed logic and syntax issues. v1.1.40

#>

[CmdletBinding(SupportsShouldProcess = $true)]
Param(
    [Parameter(Mandatory=$False,Position=1)]
    [string]$Folders = $False,

    [Parameter(Mandatory=$False,Position=2)]
    [string]$ISOCheck = $False,

    [Parameter(Mandatory=$False,Position=3)]
    [string]$ISOMedia = $False,

    [Parameter(Mandatory=$False,Position=4)]
    [string]$Boot = $False,

    [Parameter(Mandatory=$False,Position=5)]
    [string]$Install = $False,

    [Parameter(Mandatory=$False,Position=6)]
    [switch]$Tools=$False,

    [Parameter(Mandatory=$False,Position=7)]
    [switch]$Confirm=$False,

    [Parameter(Mandatory=$False,Position=8)]
    [switch]$UpdateSourceMedia=$False,

    [Parameter(Mandatory=$False,Position=9)]
    [switch]$Iso = $False
    )

# VARIABLES (RUN)
$ErrorActionPreference = "SilentlyContinue"
$timestamp = (Get-Date).ToString("MM-dd-yyyy-HH:mm:ss")

# START LOGGING
#Get-timestamp for logging
function Get-TimeStamp {  
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)  
}

#Log path/name/location
$LogPath = "C:\Windows\Logs\WindowsIsoMediaServicing.log"
$LogDir = Split-Path $LogPath
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
Start-Transcript -Path $logPath -Append

# ENVIRONMENT
$Options = @{
    "1" = "Windows 11 25H2"
    "2" = "Windows 11 23H2"
}

do {
    Write-Host ""
    Write-Host "1. Windows 11 25H2"
    Write-Host "2. Windows 11 23H2"

    $Choice = Read-Host "Select an option"
}
until ($Options.ContainsKey($Choice))

$Environment = $Options[$Choice]

Write-Host "Environment selected: $Environment" -ForegroundColor Cyan

#==================SERVICING VARIABLES=====================#
# PREPARE FOLDER STRUCTURE
$Temp = "C:\Temp"
$Virtual = "C:\Temp\Virtual"
$Media = "C:\Temp\Virtual\Media"

# PREPARE WINDOWS MEDIA
$MediaRoot = "C:\Temp\Virtual\Media\Source"
$ImagePath = "C:\Temp\Virtual\Media\Image"
$ScriptsPath = "C:\Temp\Virtual\Scripts"
$ToolsPath = "C:\Temp\Virtual\Tools"

#Environment variable
if($Environment -eq "Windows 11 25H2")
{
    #Windows 11 23H2
    $IsoPath = "C:\Temp\Virtual\Media\Win11_25H2_English_x64-New.iso"
    $isoCheck = "C:\Temp\Win11_25H2_English_x64_v2.iso"
    $IsoPattern = "Win11_25H2_English_x64_v2.iso"
    $MediaPattern = "Win11_25H2_English_x64-New.iso"
    Write-Host "Environment selected: $Environment" -ForegroundColor Cyan
}

if($Environment -eq "Windows 11 23H2")
{
    #Windows 11 23H2
    $IsoPath = "C:\Temp\Virtual\Media\Win11_23H2_English_x64-New.iso"
    $isoCheck = "C:\Temp\Win11_23H2_English_x64_v1.iso"
    $IsoPattern = "Win11_23H2_English_x64_v1.iso"
    $MediaPattern = "Win11_23H2_English_x64-New.iso"
    Write-Host "Environment selected: $Environment" -ForegroundColor Cyan
}

# SET WIM, MOUNT and DRIVER PATHS
$InstWimPath = "$MediaRoot\sources\install.wim"
$BootWimPath = "$MediaRoot\sources\boot.wim"
$MountPath = "C:\Temp\Virtual\Media\Mount"
$DriverPath = "C:\Temp\Drivers"

# VARIABLE VERIFICATION
$MediaRoot
$InstWimPath
$BootWimPath
$MountPath
$DriverPath
$ImagePath

#=================Resetting Environment=====================#
# ENVIRONMENT
$ResetOptions = @{
    "1" = "Reset"
    "2" = "Preserve"
}

do {
    Write-Host ""
    Write-Host "1. Reset Servicing Environment"
    Write-Host "2. Perserve Servicing Environment"

    $Choice2 = Read-Host "Select an option"
}
until ($ResetOptions.ContainsKey($Choice2))

$Reset = $ResetOptions[$Choice2]

Write-Host "Servicing Environment selected: $Reset"

if ($Reset -eq "Reset") {
    Write-Host "Resetting Servicing Environment" -ForegroundColor Yellow
    Remove-Item -Path "$MediaRoot\*" -Recurse -Force
    Remove-Item -Path "$ImagePath\*" -Recurse -Force
    Write-Host "Reset Servicing Environment Complete" -ForegroundColor Green
    #Remove-Item -Path "C:\ProgramData\JBC\TriageData\Gather\*" -Recurse -Force
} 

if ($Reset -eq "Preserve") {
    Write-Host "Perserving Servicing Environment" -ForegroundColor Cyan
}

#=================CREATE FOLDER STRUCTURE===================#

if($Folders -eq $True)
{
    $TempDir = Split-Path $Temp
    if (-not (Test-Path $TempDir)) {
        New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
    }

    $VirtualDir = Split-Path $Virtual
    if (-not (Test-Path $VirtualDir)) {
        New-Item -ItemType Directory -Path $VirtualDir -Force | Out-Null
    }

    $MediaDir = Split-Path $Media
    if (-not (Test-Path $MediaDir)) {
    New-Item -ItemType Directory -Path $MediaDir -Force | Out-Null
    }

    $MediaRootDir = Split-Path $MediaRoot
    if (-not (Test-Path $MediaRootDir)) {
        New-Item -ItemType Directory -Path $MediaRootDir -Force | Out-Null
    }

    $ImageRootDir = Split-Path $ImagePath
    if (-not (Test-Path $ImageRootDir)) {
        New-Item -ItemType Directory -Path $ImageRootDir -Force | Out-Null
    }

    $ScriptsDir = Split-Path $ScriptsPath
    if (-not (Test-Path $ScriptsDir)) {
        New-Item -ItemType Directory -Path $ScriptsDir -Force | Out-Null
    }

    $ToolsDir = Split-Path $ToolsPath
    if (-not (Test-Path $ToolsDir)) {
        New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
    }

    $MountDir = Split-Path $MountPath
    if (-not (Test-Path $MountDir)) {
        New-Item -ItemType Directory -Path $MountDir -Force | Out-Null
    }

    $DriverDir = Split-Path $DriverPath
    if (-not (Test-Path $DriverDir)) {
        New-Item -ItemType Directory -Path $DriverDir -Force | Out-Null
    }
}

#=======CHECK FOR WINDOWS ADK, DOWNLOAD IF NOT EXIST========#

Write-Host "Checking for Microsoft Windows Automated Installation kit (ADK)..." -ForegroundColor Cyan

# Windows ADK location
$ADK = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"
$AdkPattern = "oscdimg.exe"

# Microsoft Windows ADK download page
$AdkDownloadUrl = "https://go.microsoft.com/fwlink/?linkid=2289980"

function Test-ADK {
    return Get-ChildItem -Path $ADK -Filter $AdkPattern -File -ErrorAction SilentlyContinue
}

# Windows ADK Check
while ($true) {

    $AdkExists = Test-ADK

    if ($AdkExists) {
        Write-Host "Windows 11 ADK installed:" -ForegroundColor Green
        $AdkExists | ForEach-Object {
            Write-Host " - $($_.FullName)"
        }
        break  # Exit loop and continue script
    }

    # ADK not found
    Write-Host "Windows 11 ADK not installed." -ForegroundColor Yellow
    Write-Host "Opening Microsoft ADK download page..." -ForegroundColor Yellow
    Start-Process $AdkDownloadUrl

    Write-Host ""
    Write-Host "Please install the Windows ADK, then return here." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Press Enter to continue or type X to exit" -ForegroundColor Cyan

    $choice = Read-Host

    if ($choice -match '^[Xx]$') {
        Write-Host "Exiting script..." -ForegroundColor Red
        exit
    }

    Write-Host "Rechecking for Windows ADK..." -ForegroundColor Cyan

}

#===CHECK FOR WINDOWS INSTALL ISO, DOWNLOAD IF NOT EXIST====#
#================RENAME ISO FOR CONSISTENCY=================#

Write-Host "Checking for Windows 11 installation media (ISO)..." -ForegroundColor Cyan

# Microsoft Windows 11 download page
$DownloadUrl = "https://www.microsoft.com/en-us/software-download/windows11"

function Test-ISO {
    return Get-ChildItem -Path $Temp -Filter $IsoPattern -File -ErrorAction SilentlyContinue
}

# Windows Installation Media ISO CHECK
while ($true) {

    $IsoExists = Test-ISO

    if ($IsoExists) {
        Write-Host "Windows 11 ISO found:" -ForegroundColor Green
        $IsoExists | ForEach-Object {
            Write-Host " - $($_.FullName)"
        }
        break  # ISO found → exit loop and continue script
    }

    # ISO not found
    Write-Host "Windows 11 ISO not found." -ForegroundColor Yellow
    Write-Host "Opening Microsoft Windows 11 download page..." -ForegroundColor Yellow
    Start-Process $DownloadUrl

    Write-Host ""
    Write-Host "Please download the Windows 11 ISO and place it in: $Temp" -ForegroundColor Cyan
    Write-Host ""
    Write=Host "Press ENTER to continue or type X to exit" -ForegroundColor Cyan

    $choice = Read-Host

    if ($choice -match '^[Xx]$') {
        Write-Host "Exiting script..." -ForegroundColor Red
        exit
    }

    Write-Host "Rechecking for Windows 11 ISO..." -ForegroundColor Cyan

}

Write-Host "Checking for Windows 11 installation Development media (ISO)..." -ForegroundColor Cyan

# Check if Windows 11 ISO exists in the media directory
$MediaExists = Get-ChildItem -Path $Media -Filter $MediaPattern -File -ErrorAction SilentlyContinue

if (-not $MediaExist) {
    Write-Host "Windows 11 ISO not found. Copy iso media..." -ForegroundColor Yellow
    
    #Windows 11 25H2
    if ($Environment -eq "Windows 11 25H2") {
    Copy-Item "$Temp\Win11_25H2_English_x64_v2.iso" "$Media\Win11_25H2_English_x64-New.iso"
    }
    
    #Windows 11 23H2
    if ($Environment -eq "Windows 11 23H2") {
    Copy-Item "$Temp\Win11_23H2_English_x64_v1.iso" "$Media\Win11_23H2_English_x64-New.iso"
    }
}

#===MOUNT WINDOWS INSTALL ISO, COPY CONTENTS, UNMOUNT ISO===#

Write-Host "Creating Windows 11 Installation Development Source..." -ForegroundColor Cyan

if($ISOMedia -eq $True)
{
# Mount ISO
$DiskImage = Mount-DiskImage -ImagePath $IsoCheck -PassThru
$DriveLetter = ($DiskImage | Get-Volume).DriveLetter
$DrivePath = "$($DriveLetter):\"

# Copy contents
Copy-Item -Path "$DrivePath*" -Destination $MediaRoot -Recurse -Force

Write-Host "Removing ReadOnly attribute from files under: $MediaRoot" -ForegroundColor Cyan

Get-ChildItem -Path $MediaRoot -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        if ($_.IsReadOnly) {
            $_.IsReadOnly = $false
            Write-Host "Updated: $($_.FullName)"
        }
    }
    catch {
        Write-Warning "Failed: $($_.FullName) - $($_.Exception.Message)"
    }
}

Write-Host "ACL's and Permissions Adjusted on $MediaRoot Successfully." -ForegroundColor Cyan

# Unmount ISO
Dismount-DiskImage -ImagePath $IsoCheck

#===========GATHER BOOT.WIM and INSTALL.WIM INFO============#

# gathers images info and indexes
dism /Get-WimInfo /WimFile:$BootWimPath

# gathers image info and indexes from usb media
dism /Get-WimInfo /WimFile:$InstWimPath
}

#==================BOOT.WIM SERVICING CHECK=================#

Write-Host "Checking for development boot.wim..." -ForegroundColor Cyan

# Check if file exists
if (Test-Path $ImagePath\boot.wim) {
    Write-Host "File exists. Continuing script..." -ForegroundColor Green
}
else {
    Write-Host "File does NOT exist. Copying file..." -ForegroundColor Yellow
    Copy-Item -Path $BootWimPath -Destination $ImagePath -Force
}

#=======================BOOT.WIM SERVICING==================#

if($Boot -eq $True)
{
# mount boot.wim image (boot.wim indexes, typically Index #1 = WinPE, Index #2 = Windows Setup (recommend Index 2 for driver injection)
dism /Mount-Wim /WimFile:$ImagePath\boot.wim /Index:2 /MountDir:$MountPath

# mount image for driver servicing
dism /Image:$MountPath /Add-Driver /Driver:$DriverPath /Recurse

# unmount image and commit changes
dism /Unmount-Wim /MountDir:$MountPath /Commit

#Unmount without commit, if mount does not complete properly
#dism /Unmount-Wim /MountDir:C:\Temp\Virtual\Media\Mount /Discard
}

#===============INSTALL.WIM or INSTALL.SWM==================#

# Check if file exists
if (Test-Path $ImagePath\install.wim) {
    Write-Host "File exists. Continuing script..." -ForegroundColor Green
}
else {
    Write-Host "File does NOT exist. Copying file..." -ForegroundColor Yellow
    if ($Environment -eq "Windows 11 25H2") {
    # Windows 11 Pro (index 6) is recommended baseline. Export index, this will only need to be done once.
    dism /export-image /sourceimagefile:$InstWimPath /sourceindex:6 /destinationimagefile:$ImagePath\install.wim /Compress:max
    }

    if ($Environment -eq "Windows 11 23H2") {
    # Windows 11 Pro (index 5) is recommended baseline. Export index, this will only need to be done once.
    dism /export-image /sourceimagefile:$InstWimPath /sourceindex:5 /destinationimagefile:$ImagePath\install.wim /Compress:max
    }
}

# gathers images info and indexes from temp location
dism /Get-WimInfo /WimFile:$ImagePath\install.wim

#=============INSTALL.WIM or INSTALL.SWM SERVICING==========#

if($Install -eq $True)
{
# mount install.wim image
dism /Mount-Wim /WimFile:$ImagePath\Install.wim /Index:1 /MountDir:$MountPath

# mount image for driver servicing
dism /Image:$MountPath /Add-Driver /Driver:$DriverPath /Recurse

# unmount image and commit changes
dism /Unmount-Wim /MountDir:$MountPath /Commit

#Unmount without commit, if mount does not complete properly
#dism /Unmount-Wim /MountDir:C:\Temp\Virtual\Media\Mount /Discard
}

#============ADDITIONAL UTILITIIES SERVICING================#

if($Tools -eq $True)
{
# mount install.wim image
dism /Mount-Wim /WimFile:$ImagePath\Install.wim /Index:1 /MountDir:$MountPath

# Copy scripts and tools .wim to Sources folder
Copy-Item -Path "$ScriptsPath\AutopilotInfo.ps1" -Destination "$MountPath\Windows\System32" -Recurse
Copy-Item -Path "$ScriptsPath\AutopilotInfo-Online.ps1" -Destination "$MountPath\Windows\System32" -Recurse
Copy-Item -Path "$ToolsPath\CMTrace.exe" -Destination "$MountPath\Windows\System32" -Recurse

# unmount image and commit changes
dism /Unmount-Wim /MountDir:$MountPath /Commit

#Unmount without commit, if mount does not complete properly
#dism /Unmount-Wim /MountDir:C:\Temp\Virtual\Media\Mount /Discard
}

#====WINDOWS INSTALLATION MEDIA SERVICING CONFIRMATION======#

if($Confirm -eq $True)
{
# gathers image info and indexes from servicing location
dism /Get-WimInfo /WimFile:$ImagePath\boot.wim
dism /Get-WimInfo /WimFile:$ImagePath\install.wim
}

#====================UPDATE SOURCE MEDIA====================#

if($UpdateSourceMedia -eq $True)
{
# Copy updated .wim to Sources folder
Copy-Item -Path "$ImagePath\Install.wim" -Destination "$MediaRoot\sources" -Recurse

# Copy updated .wim to Sources folder
Copy-Item -Path "$ImagePath\boot.wim" -Destination "$MediaRoot\sources\" -Recurse
}

#==========WINDOWS INSTALLATION MEDIA ISO CREATION==========#

if($Iso -eq $True)
{
    if ($Environment -eq "Windows 11 25H2") {
    #Windows 11 25H2
    $Path = 'C:\Temp\Virtual\Media\Win11_25H2_English_x64-New.iso'
    }

    if ($Environment -eq "Windows 11 23H2") {
    #Windows 11 23H2
    $Path = 'C:\Temp\Virtual\Media\Win11_23H2_English_x64-New.iso'
    }

    if (Test-Path $Path) {
        Remove-Item $Path -Force
        Write-Host "Deleted: $Path" -ForegroundColor Green
    } else {
        Write-Host "File not found: $Path" -ForegroundColor Yellow
    }

# Create new ISO with updated .wim's
# ADK Location = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"
# OSCDIMG.CMD = oscdimg.exe  -m -o -pEF -u1 -udfver102 -bC:\Temp\Virtual\Media\Source\efi\microsoft\boot\efisys.bin C:\Temp\Virtual\Media\Source C:\Temp\Virtual\Media\Win11_25H2_English_x64-New.iso

    if ($Environment -eq "Windows 11 25H2") {
    #Windows 11 25H2
    Start-Process $ScriptsPath\OSCDIMG-25H2.CMD -Wait
    }

    if ($Environment -eq "Windows 11 23H2") {
    #Windows 11 25H2
    Start-Process $ScriptsPath\OSCDIMG-23H2.CMD -Wait
    }

Write-Host "Updated $Environment .Iso available. Located - $Media" -ForegroundColor Green
}

# This is done earlier in the script. Leaving this here for t-shooting\development purposes
#Dismount-DiskImage -ImagePath "C:\Temp\Virtual\Media\Win11_25H2_English_x64.iso"

Write-Host "WITH THIS INSTALLATION MEDIA, USE HYPER-V FOR TESTING AUTOPILOT." -ForegroundColor Cyan
Write-Host "SCRIPT IS AVAILABLE TO AUTOMATE HYPER-V INSTALLATION AND AUTOMATED" -ForegroundColor Cyan
Write-Host "VIRTUAL MACHINE CREATION." -ForegroundColor Cyan
Write-Host ""
Write-Host "Scripts available at: https://github.com/Metropolis-Pt3/Hyper-V" -ForegroundColor Cyan

Write-Host "WINDOWS ISO SERVICING PROCESS COMPLETE" -ForegroundColor Green

Stop-Transcript
