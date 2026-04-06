
<#
.SUMMARY
  Microsoft Windows 11 Installation Media Servicing

.DESCRIPTION
  Microsoft Windows 11 (25H2) Installation Media Servicing. Uses the Microsoft Media Creation to to build USB
  Media, then adds utilties, scripts and drivers to support Dell and HP Models.

  Note: Download drivers prior to servicing.

  x64 media only....

.PARAMETERS
  -Media = Downloads the Microsoft Media Creation Tool from Microsoft CDN and builds new USB Media. Located: $MediaPath = "C:\ESD\Servicing\Media" .
  
  -CreateImages = Creates the Boot.wim and Install.wim images. Located: $ImagePath = "C:\ESD\Servicing\Images".

  -Gather = Gathers *.wim info from images. Located: $ImagePath = "C:\ESD\Servicing\Images".
  
  -Boot = Services the boot.wim, injects drivers and then updates the USB Media. 

  -Install = Services the install.wim, injects drivers, splits the install.wim into install.swm/install2.swm and then updates the USB Media.

  -Confirm = Gathers *.wim info from USB Media.

  Examples:
  .\DriverMediaServicing-1.0.48.ps1 -Media  (Only have to run this once.)

  .\DriverMediaServicing-1.0.48.ps1 -CreateImages  (Only have to run this once.)

  .\DriverMediaServicing-1.0.48.ps1 -Gather

  .\DriverMediaServicing-1.0.48.ps1 -Boot

  .\DriverMediaServicing-1.0.48.ps1 -Install

  .\DriverMediaServicing-1.0.48.ps1 -Confirm

  For reoccuring driver updates, you can used multiple parameters:

  .\DriverMediaServicing-1.0.48.ps1 -Gather -Boot -Install -Confirm 


.NOTES/REFERENCES
  Current Version=1.0.48
  Date: 3.23.2026
  Author: Steve.Molzahn

  References:
  Microsoft Media Creation Tool = "https://go.microsoft.com/fwlink/?linkid=2156295"

  Notes:
  Run with Administrative rights.

  Changelog:
  3.18.2026
    - Intital script in concept. v1.0.2
    - Logic, syntax and other refinements. v1.0.45

  3.23.2026 - Adding parameters to aid in servicing. v1.0.48
  
#>

[CmdletBinding(SupportsShouldProcess = $true)]
Param(
    [Parameter(Mandatory=$False,Position=1)]
    [switch]$Media = $False,

    [Parameter(Mandatory=$False,Position=2)]
    [switch]$CreateImages = $False,

    [Parameter(Mandatory=$False,Position=3)]
    [switch]$Gather = $False,

    [Parameter(Mandatory=$False,Position=4)]
    [switch]$Boot = $False,

    [Parameter(Mandatory=$False,Position=5)]
    [switch]$Install = $False,

    [Parameter(Mandatory=$False,Position=6)]
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
$LogPath = "C:\ESD\Logs\Driver_Media_Servicing.log"
$LogDir = Split-Path $LogPath
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
Start-Transcript -Path $logPath -Append

# RUNTIME STATUS
$64Bit=[Environment]::Is64BitProcess
Write-Host "$(Get-TimeStamp) Is64BitProcess = $64Bit"

# CREATE INSTALLATION MEDIA FOLDER STRUCTURE
$DriverPath = "C:\ESD\Servicing\Drivers"
$DriverDir = Split-Path $DriverPath
if (-not (Test-Path $DriverDir)) {
    New-Item -ItemType Directory -Path $DriverDir -Force | Out-Null
}

$ArchPath = "C:\ESD\Servicing\Drivers\x64"
$ArchDir = Split-Path $ArchPath
if (-not (Test-Path $ArchDir)) {
    New-Item -ItemType Directory -Path $ArchDir -Force | Out-Null
}

$CatPath = "C:\ESD\Servicing\Drivers\_Catalog"
$CatDir = Split-Path $CatPath
if (-not (Test-Path $CatDir)) {
    New-Item -ItemType Directory -Path $CatDir -Force | Out-Null
}

$MediaPath = "C:\ESD\Servicing\Media"
$MediaDir = Split-Path $MediaPath
if (-not (Test-Path $MediaDir)) {
    New-Item -ItemType Directory -Path $MediaDir -Force | Out-Null
}

$ImagePath = "C:\ESD\Servicing\Images"
$ImageDir = Split-Path $ImagePath
if (-not (Test-Path $ImageDir)) {
    New-Item -ItemType Directory -Path $ImageDir -Force | Out-Null
}

$MntPath = "C:\ESD\Servicing\Mount"
$MntDir = Split-Path $MntPath
if (-not (Test-Path $MntDir)) {
    New-Item -ItemType Directory -Path $MntDir -Force | Out-Null
}

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


# CREATE USB INSTALLATION MEDIA FROM MEDIA CREATION TOOL
$MediaTool = "$MediaPath\MediaCreationTool.exe"
Start-Process $MediaTool -Wait
}

#=======================SERVICING====================#

# PREPARE USB INSTALLATION MEDIA
$UsbRoot = (Get-WmiObject Win32_Volume -Filter "DriveType='2'").DriveLetter | Where-Object { -not [String]::IsNullOrEmpty($_) } | Sort-Object

# determines usb drive letter, sets variables
$WimPath1 = "$UsbRoot\sources\Install.swm"
$WimPath2 = "$UsbRoot\sources\Install*.swm"
$bootPath = "$UsbRoot\sources\Boot.wim"

# variable testing
$UsbRoot
$WimPath1
$WimPath2
$bootPath
$ImagePath

if (-not (Test-Path -LiteralPath $UsbRoot\Catalog -PathType Container)) {
    New-Item -ItemType Directory -Path $UsbRoot\Catalog -Force | Out-Null
}

#===========COPY BOOT.WIM AND INSTALL.WIM============#
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

#==================GATHER IMAGE INFO=================#

if($Gather -eq $True)
{
# gathers image info and indexes from share media
dism /Get-WimInfo /WimFile:$ImagePath\install.wim
dism /Get-WimInfo /WimFile:$ImagePath\boot.wim
}

#===================BOOT.WIM SERVICING===============#

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

# copy boot.wim files to usb sources folder
Copy-Item -Path "$ImagePath\boot.wim" -Destination "$UsbRoot\sources" -Recurse

# gathers image info and indexes from usb media
dism /Get-WimInfo /WimFile:$bootPath
}

#=======INSTALL.WIM or INSTALL.SWM SERVICING=========#

if($Install -eq $True)
{
# gathers images info and indexes from temp location
dism /Get-WimInfo /WimFile:$ImagePath\Install.wim

# mount install.wim image
dism /Mount-Wim /WimFile:$ImagePath\Install.wim /Index:1 /MountDir:$MntPath

# mount image for driver servicing
dism /Image:$MntPath /Add-Driver /Driver:$DriverPath\Drivers /Recurse

# unmount image and commit changes
dism /Unmount-Wim /MountDir:$MntPath /Commit

# split image to be placed on usb
dism /Split-Image /ImageFile:"$ImagePath\install.wim" /SWMFile:"$ImagePath\install.swm" /FileSize:3800

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

Stop-Transcript
