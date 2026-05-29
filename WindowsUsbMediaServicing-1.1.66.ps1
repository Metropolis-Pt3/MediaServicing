
<#
.SUMMARY
  Microsoft Windows 11 Installation Media Servicing

  First run the script with the -Folders switch only. This will create the folder structure for servicing.

  ***IMPORTANT - PRIOR TO SERVICING***
  1. Download any drivers (storage, network and wireless) prior to running the script.
     Place in C:\Temp\Drivers
  
  2. Download the Windows Installation Media Creation Tool and build the usb using that tool.
     The script will automate some portions of this process but its faster to perform prior to servicing.
     Reference Url: https://go.microsoft.com/fwlink/?linkid=2156295

  3. If building for Autopilot testing, download scripts to autopilot importing. (AutopilotInfo.ps1 and/or AutopilotInfo-Online.ps1)
     Reference Url: https://github.com/Metropolis-Pt3/Autopilot
     Place scripts in C:\Temp\Virtual\Scripts

  x64 media only... Can be modified for arm64 architecture, but will need to be run on Windows 11 26H1 arm64.

.DESCRIPTION
  Microsoft Windows 11 (25H2) Installation Media Servicing. Uses the Microsoft Media Creation to to build USB
  Media, then adds utilties, scripts and drivers to support Dell, HP, etc.

.PARAMETERS
  .\WindowsUsbMediaServicing-1.1.66.ps1
        *Information* = You must choose the drive letter where you want to install the servicing structure.

        -Folders = Creates the folder structure used for USB and ISO servicing.

        -Media = Downloads the Microsoft Media Creation Tool from Microsoft CDN and builds new USB Media. Located: $MediaPath = "$Drive\ESD\Servicing\Media" .
  
        -CreateImages = Creates the Boot.wim and Install.wim images. Located: $ImagePath = "$Drive\ESD\Servicing\Images".

        -Gather = Gathers *.wim info from images. Located: $ImagePath = "$Drive\ESD\Servicing\Images".
  
        -Boot = Services the boot.wim, injects drivers and then updates the USB Media. 

        -Install = Services the install.wim, injects drivers, splits the install.wim into install.swm/install2.swm and then updates the USB Media.

        -Tools = Scripts and other utilities

        -UpdateMedia = Updates the source media with the updated .wim

        -Confirm = Gathers *.wim info from USB Media.

    # For reoccuring driver updates, you can used multiple parameters:

  .\WindowsUsbMediaServicing-1.1.66.ps1 -Gather -Boot -Install -UpdateMedia -Confirm 


.NOTES/REFERENCES
  Current Version=1.1.66
  Date: 3.23.2026
  Author: Steve.Molzahn

  References:
  Microsoft Media Creation Tool = "https://go.microsoft.com/fwlink/?linkid=2156295"

  Notes:
  Run with Administrative rights.

  Changelog:
  3.18.2026
    - Intital script in concept. v1.0.2
    - Logic, syntax and other refinements. v1.0.25

  3.23.2026 - Adding parameters to aid in servicing. v1.0.42
  4.16.2026 - Mass Updates to logic and features. v1.0.58
  5.14.2026 - Added logic create streamline setup (drive letter logic). v1.1.51
  5.15.2026 - Added choice/elements for the workflow. v1.1.60
  5.16.2026 - Added Utilities for more functionality. v1.1.64
  5.28.2026 - Added logic for arm64. v1.1.66
  
#>

[CmdletBinding(SupportsShouldProcess = $true)]
Param(
    [Parameter(Mandatory=$False,Position=1)]
    [switch]$Folders = $False,

    [Parameter(Mandatory=$False,Position=2)]
    [switch]$Media = $False,

    [Parameter(Mandatory=$False,Position=3)]
    [switch]$CreateImages = $False,

    [Parameter(Mandatory=$False,Position=4)]
    [switch]$Gather = $False,

    [Parameter(Mandatory=$False,Position=5)]
    [switch]$Boot = $False,

    [Parameter(Mandatory=$False,Position=6)]
    [switch]$Install = $False,

    [Parameter(Mandatory=$False,Position=7)]
    [switch]$Tools = $False,

    [Parameter(Mandatory=$False,Position=8)]
    [switch]$UpdateMedia = $False,

    [Parameter(Mandatory=$False,Position=9)]
    [switch]$Confirm = $False
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
$LogPath = "C:\Windows\Logs\WindowsUsbMediaServicing.log"
$LogDir = Split-Path $LogPath
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
Start-Transcript -Path $logPath -Append

# RUNTIME STATUS
$64Bit=[Environment]::Is64BitProcess
Write-Host "$(Get-TimeStamp) Is64BitProcess = $64Bit"

#==========CHOOSE DRIVE FOR INSTALL=============================#

# Get all filesystem drives ($Drive, D:, E:, etc.)
$Drives = Get-PSDrive -PSProvider FileSystem

Write-Host "This will install the servicing foundation. Choose a" -ForegroundColor Cyan
Write-Host "drive the servicing scripts will be ran from. Do NOT" -ForegroundColor Cyan
Write-Host "choose a USB drive for this option." -ForegroundColor Cyan
Write-Host ""
Write-Host "`nChoose a drive for install:`n" -ForegroundColor Cyan

# Display numbered menu
for ($i = 0; $i -lt $Drives.Count; $i++) {
    Write-Host "$($i+1). $($Drives[$i].Name):"
}

# Ask user for selection
$Choice = Read-Host "`nChoose a drive number"

# Validate and assign to $Drive
if ($Choice -as [int] -and $Choice -ge 1 -and $Choice -le $Drives.Count) {
    $Drive = $drives[$Choice - 1].Name + ":"
    Write-Host "`nYou selected drive: $Drive"
} else {
    Write-Host "`nInvalid choice."
}

#==========CREATE FOLDER STRUCTURE==============================#

if($Folders -eq $True)
{
    $TempPath = "$Drive\Temp"
    $TempPathDir = Split-Path $TempPath
    if (-not (Test-Path $TempPathDir)) {
        New-Item -ItemType Directory -Path $TempPathDir -Force | Out-Null
    }
    
    $DriverPath = "$Drive\Temp\Drivers"
    $DriverDir = Split-Path $DriverPath
    if (-not (Test-Path $DriverDir)) {
        New-Item -ItemType Directory -Path $DriverDir -Force | Out-Null
    }

    $ArchPath = "$Drive\Temp\Drivers\x64"
    $ArchDir = Split-Path $ArchPath
    if (-not (Test-Path $ArchDir)) {
        New-Item -ItemType Directory -Path $ArchDir -Force | Out-Null
    }

    $ArchArmPath = "$Drive\Temp\Drivers\arm64"
    $ArchArmDir = Split-Path $ArchArmPath
    if (-not (Test-Path $ArchArmDir)) {
        New-Item -ItemType Directory -Path $ArchArmDir -Force | Out-Null
    }

    $VirtPath = "$Drive\Temp\Virtual"
    $VirtDir = Split-Path $VirtPath
    if (-not (Test-Path $VirtDir)) {
        New-Item -ItemType Directory -Path $VirtDir -Force | Out-Null
    }

    $ToolsPath = "$Drive\Temp\Virtual\Tools"
    $ToolsDir = Split-Path $ToolsPath
    if (-not (Test-Path $ToolsDir)) {
        New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
    }

    $MedPath = "$Drive\Temp\Virtual\Media"
    $MedDir = Split-Path $MedPath
    if (-not (Test-Path $MedDir)) {
        New-Item -ItemType Directory -Path $MedDir -Force | Out-Null
    }

    $MediaPath = "$Drive\Temp\Virtual\Media\Source"
    $MediaDir = Split-Path $MediaPath
    if (-not (Test-Path $MediaDir)) {
        New-Item -ItemType Directory -Path $MediaDir -Force | Out-Null
    }
    
    $ScriptsPath = "$Drive\Temp\Virtual\Scripts"
    $ScriptsDir = Split-Path $ScriptsPath
    if (-not (Test-Path $ScriptsDir)) {
        New-Item -ItemType Directory -Path $ScriptsDir -Force | Out-Null
    }

    $ImagePath = "$Drive\Temp\Virtual\Media\Image"
    $ImageDir = Split-Path $ImagePath
    if (-not (Test-Path $ImageDir)) {
        New-Item -ItemType Directory -Path $ImageDir -Force | Out-Null
    }

    $MntPath = "$Drive\Temp\Virtual\Media\Mount"
    $MntDir = Split-Path $MntPath
    if (-not (Test-Path $MntDir)) {
        New-Item -ItemType Directory -Path $MntDir -Force | Out-Null
    }
}

#==============DRIVER DOWNLOAD NOTIFICATION=====================#

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "       IMPORTANT: HAVE DRIVERS BEEN DOWNLOADED?     " -ForegroundColor Cyan
Write-Host ""
Write-Host "     Download and copy drivers to $DriverPath       " -ForegroundColor Cyan
Write-Host ""
Write-Host "       Press ENTER to continue or type X to exit    " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

$choice = Read-Host

if ($choice -match '^[Xx]$') {
    Write-Host "Exiting script..." -ForegroundColor Red
    exit
}

Write-Host "Continuing..." -ForegroundColor Green

#==============MEDIA CREATION TOOL==============================#

if($Media -eq $True)
{
# PROCURE MEDIA CREATION TOOL
#url to Microsoft Media Creation Tool (Windows 11):
$Url  = "https://go.microsoft.com/fwlink/?linkid=2156295"
$Dest = $MediaPath

#Check if file exists, delete it
if (Test-Path $Dest) {
    Remove-Item $Dest -Force
}

# Download file
Invoke-WebRequest -Uri $Url -OutFile $Dest

# Check for USB drive (loop)
function Get-UsbDriveLetters {
    (Get-WmiObject Win32_Volume -Filter "DriveType='2'").DriveLetter |
        Where-Object { -not [String]::IsNullOrEmpty($_) } |
        Sort-Object
}

# Loop until USB drive is detected
$UsbRoot = Get-UsbDriveLetters

while (-not $UsbRoot) {
    Write-Host "`nNo USB drive detected. Please plug in a USB drive." -ForegroundColor Red
    Write-Host ""
    Write-Host "Press ENTER to check again" -ForegroundColor Cyan
    #Read-Host "Press ENTER to check again"
    $input = Read-Host
    $UsbRoot = Get-UsbDriveLetters
}

Write-Host "`nUSB drive(s) detected:`n"

# Display menu if multiple USB drives exist
for ($i = 0; $i -lt $UsbRoot.Count; $i++) {
    Write-Host "$($i+1). $($UsbRoot[$i])\"
}

# If more than one USB drive, ask user to choose
if ($UsbRoot.Count -gt 1) {
    $choice = Read-Host "`nChoose a drive number"

    if ($choice -as [int] -and $choice -ge 1 -and $choice -le $UsbRoot.Count) {
        $UsbRoot = $UsbRoot[$choice - 1] + "\"
    } else {
        Write-Host "`nInvalid choice."
        exit
    }

} else {
    # Only one USB drive found
    $UsbRoot = $UsbRoot[0] + "\"
}

Write-Host "`nSelected USB drive: $UsbRoot"

Write-Host "CLOSE THE MEDIA CREATION TOOL ONCE USB MEDIA" -ForegroundColor Cyan
Write-Host "IS PROVISIONED TO CONTINUE" -ForegroundColor Cyan

# CREATE USB INSTALLATION MEDIA FROM MEDIA CREATION TOOL
$MediaTool = "$MediaPath\MediaCreationTool.exe"
Start-Process $MediaTool -Wait
}

#=============SERVICING VARIABLES===============================#

# PREPARE USB INSTALLATION MEDIA
# $UsbRoot = (Get-WmiObject Win32_Volume -Filter "DriveType='2'").DriveLetter | Where-Object { -not [String]::IsNullOrEmpty($_) } | Sort-Object

# determines usb drive letter, sets variables
$WimPath1 = "$UsbRoot\sources\Install.swm"
$WimPath2 = "$UsbRoot\sources\Install*.swm"
$bootPath = "$UsbRoot\sources\Boot.wim"
$MntPath = "$Drive\Temp\Virtual\Media\Mount"
$ImagePath = "$Drive\Temp\Virtual\Media\Image"
$MediaPath = "$Drive\Temp\Virtual\Media\Source"
$DriverPath = "$Drive\Temp\Drivers"
$ArchArmPath = "$Drive\Temp\Drivers\arm64"
$ArchPath = "$Drive\Temp\Drivers\x64"
$ToolsPath = "$Drive\Temp\Virtual\Tools"
$ScriptsPath = "$Drive\Temp\Virtual\Scripts"

# variable testing
$UsbRoot
$WimPath1
$WimPath2
$bootPath
$MntPath
$ImagePath
$MediaPath
$DriverPath
$ArchArmPath
$ArchPath
$ToolsPath
$ScriptsPath

#===========COPY BOOT.WIM AND INSTALL.WIM=======================#
#Only need to run this step once

if($CreateImages -eq $True)
{
# gathers image info and indexes from usb media
dism /Get-WimInfo /WimFile:$bootPath

# copy boot.wim files to temp folder
Copy-Item -Path "$UsbRoot\sources\boot.wim" -Destination "$ImagePath" -Recurse

# gathers image info and indexes from usb media
dism /Get-WimInfo /WimFile:$WimPath1

# exports *.SWM image index to install.wim from usb media (When usb is created from the media creation tool, index 6 is Windows 11 Pro)
# Windows 11 Pro is recommended baseline. This will only need to be done once.
dism /export-image /sourceimagefile:$UsbRoot\sources\install.swm /SWMFile:$UsbRoot\sources\install*.swm /sourceindex:6 /destinationimagefile:$ImagePath\install.wim /Compress:max
}

#==================GATHER IMAGE INFO============================#

if($Gather -eq $True)
{
# gathers image info and indexes from share media
dism /Get-WimInfo /WimFile:$ImagePath\install.wim
dism /Get-WimInfo /WimFile:$ImagePath\boot.wim
}

#===================BOOT.WIM SERVICING==========================#

if($Boot -eq $True)
{
# gathers images info and indexes
dism /Get-WimInfo /WimFile:$ImagePath\boot.wim

# mount boot.wim image (boot.wim indexes, typically Index #1 = WinPE, Index #2 = Windows Setup (recommend Index 2 for driver injection)
dism /Mount-Wim /WimFile:$ImagePath\boot.wim /Index:2 /MountDir:$MntPath

# mount image for driver servicing
dism /Image:$MntPath /Add-Driver /Driver:$DriverPath /Recurse

# unmount image and commit changes
dism /Unmount-Wim /MountDir:$MntPath /Commit

#Unmount without commit, if mount does not complete properly
#dism /Unmount-Wim /MountDir:C:\Temp\Virtual\Media\Mount /Discard

}

#=======INSTALL.WIM or INSTALL.SWM SERVICING====================#

if($Install -eq $True)
{
# gathers images info and indexes from temp location
dism /Get-WimInfo /WimFile:$ImagePath\Install.wim

# Delete existing .svm image files, from $Drive\Temp\Virtual\Media\Image
$ImageSwm = Get-ChildItem "$ImagePath" -Filter *.swm

if ($ImageSwm) {
    Remove-Item $ImagePath\*swm -Force
}

# mount install.wim image
dism /Mount-Wim /WimFile:$ImagePath\Install.wim /Index:1 /MountDir:$MntPath

# mount image for driver servicing
dism /Image:$MntPath /Add-Driver /Driver:$DriverPath /Recurse

# unmount image and commit changes
dism /Unmount-Wim /MountDir:$MntPath /Commit

#Unmount without commit, if mount does not complete properly
#dism /Unmount-Wim /MountDir:C:\Temp\Virtual\Media\Mount /Discard

}

#===========================UTILITIES===========================#

if($Tools -eq $True)
{
# mount install.wim image
dism /Mount-Wim /WimFile:$ImagePath\Install.wim /Index:1 /MountDir:$MntPath

# Copy scripts and tools .wim to Sources folder
Copy-Item -Path "$ScriptsPath\AutopilotInfo.ps1" -Destination "$MntPath\Windows\System32" -Recurse
Copy-Item -Path "$ScriptsPath\AutopilotInfo-Online.ps1" -Destination "$MntPath\Windows\System32" -Recurse
Copy-Item -Path "$ToolsPath\CMTrace.exe" -Destination "$MntPath\Windows\System32" -Recurse

# unmount image and commit changes
dism /Unmount-Wim /MountDir:$MntPath /Commit

#Unmount without commit, if mount does not complete properly
#dism /Unmount-Wim /MountDir:C:\Temp\Virtual\Media\Mount /Discard
}

#=========================UPDATE MEDIA==========================#

if($UpdateMedia -eq $True)
{
# split image to be placed on usb
dism /Split-Image /ImageFile:"$ImagePath\install.wim" /SWMFile:"$ImagePath\install.swm" /FileSize:3800

# copy boot.wim files to usb sources folder
Copy-Item -Path "$ImagePath\boot.wim" -Destination "$UsbRoot\sources" -Recurse

# Copy split SWM files to USB Sources folder
Copy-Item -Path "$ImagePath\*.swm" -Destination "$UsbRoot\sources\" -Recurse
}

#=======WINDOWS INSTALLATION MEDIA SERVICING CONFIRMATION=======#

if($Confirm -eq $True)
{
# gathers image info and indexes from usb media
dism /Get-WimInfo /WimFile:$WimPath1
dism /Get-WimInfo /WimFile:$bootPath
}

#====================SERVICING CONFIRMATION=====================#

Write-Host "SERVICING PROCESS HAS COMPLETED" -ForegroundColor Green

Stop-Transcript
