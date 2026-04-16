
<#
.SUMMARY
  Microsoft Windows 11 Installation Media Servicing

.DESCRIPTION
  Microsoft Windows 11 (25H2) Installation Media Servicing. Uses the Microsoft Media Creation to to build USB
  Media, then adds utilties, scripts and drivers to support Dell and HP Models.

  Note: Download drivers prior to servicing.

.PARAMETERS

  .\WindowsIsoMediaServicing-1.0.24.ps1

  -Folders - Creates the servicing folder structure

  -IsoMedia - Mounts the iso, gathers drive letter and copies .iso contents to servicing location

  -Boot - Exports the boot.wim to servicing location

  -BootServ - Services the boot.wim

  -Install - Exports the install.wim to servicing location

  -InstallServ - Services the install.wim

  -Utilities - Adds tools and utilities to install.wim

  -Confirm - Confirms .wim updates

  -UpdateMedia - imports boot.wim and install.wim from servicing location into 

  -Iso - Creates NEW iso media with all servicing updates 

.NOTES/REFERENCES
  Current Version=1.0.24
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
#>

[CmdletBinding(SupportsShouldProcess = $true)]
Param(
    [Parameter(Mandatory=$False,Position=1)]
    [string]$Folders = $False,

    [Parameter(Mandatory=$False,Position=2)]
    [string]$ISOMedia = $False,

    [Parameter(Mandatory=$False,Position=3)]
    [string]$Boot = $False,

    [Parameter(Mandatory=$False,Position=4)]
    [string]$BootServ = $False,

    [Parameter(Mandatory=$False,Position=5)]
    [string]$Install = $False,

    [Parameter(Mandatory=$False,Position=6)]
    [string]$InstallServ = $False,

    [Parameter(Mandatory=$False,Position=7)]
    [switch]$Utilities=$False,

    [Parameter(Mandatory=$False,Position=8)]
    [switch]$Confirm=$False,

    [Parameter(Mandatory=$False,Position=9)]
    [switch]$UpdateMedia=$False,

    [Parameter(Mandatory=$False,Position=10)]
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

#=======================SERVICING====================#
# PREPARE FOLDER STRUCTURE
$Temp = "C:\Temp"
$Virtual = "C:\Temp\Virtual"
$Media = "C:\Temp\Virtual\Media"

# PREPARE WINDOWS MEDIA
$MediaRoot = "C:\Temp\Virtual\Media\Source"
$ImagePath = "C:\Temp\Virtual\Media\Image"
$ScriptsPath = "C:\Temp\Virtual\Scripts"
$ToolsPath = "C:\Temp\Virtual\Tools"
$IsoPath = "C:\Temp\Virtual\Media\Win11_25H2_English_x64.iso"

# SET WIM, MOUNT and DRIVER PATHS
$InstWimPath = "$MediaRoot\sources\install.wim"
$BootWimPath = "$MediaRoot\sources\boot.wim"
$MountPath = "C:\Temp\Virtual\Media\Mount"
$DriverPath = "C:\Temp\Drivers"

# VARIABLE TESTING
$MediaRoot
$InstWimPath
$BootWimPath
$MountPath
$DriverPath
$ImagePath

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

#================MOUNT WINDOWS INSTALL ISO==================#

if($ISOMedia -eq $True)
{
$DiskImage = Mount-DiskImage -ImagePath $IsoPath -PassThru
$DriveLetter = ($DiskImage | Get-Volume).DriveLetter

$DriveLetter

Copy-Item -Path "$DriverLetter\*.*" -Destination "$MediaRoot" -Recurse

#===========GATHER BOOT.WIM and INSTALL.WIM INFO============#
# gathers images info and indexes
dism /Get-WimInfo /WimFile:$BootWimPath

# gathers image info and indexes from usb media
dism /Get-WimInfo /WimFile:$InstWimPath
}

#========================BOOT.WIM====================#

if($Boot -eq $True)
{
# gathers images info and indexes
dism /Get-WimInfo /WimFile:$BootWimPath

# copy boot.wim files to temp folder
Copy-Item -Path "$BootWimPath" -Destination "$ImagePath" -Recurse
}

#===================BOOT.WIM SERVICING===============#

if($BootServ -eq $True)
{
# mount boot.wim image (boot.wim indexes, typically Index #1 = WinPE, Index #2 = Windows Setup (recommend Index 2 for driver injection)
dism /Mount-Wim /WimFile:$ImagePath\boot.wim /Index:2 /MountDir:$MountPath

# mount image for driver servicing
dism /Image:$MountPath /Add-Driver /Driver:$DriverPath /Recurse

# unmount image and commit changes
dism /Unmount-Wim /MountDir:$MountPath /Commit
}

#==============INSTALL.WIM or INSTALL.SWM================#

if($Install -eq $True)
{
# gathers images info and indexes from temp location
dism /Get-WimInfo /WimFile:$InstWimPath

# Windows 11 Pro is recommended baseline. This will only need to be done once.
dism /export-image /sourceimagefile:$InstWimPath /sourceindex:6 /destinationimagefile:$ImagePath\install.wim /Compress:max
}

#===========INSTALL.WIM or INSTALL.SWM SERVICING=========#

if($InstallServ -eq $True)
{
# mount install.wim image
dism /Mount-Wim /WimFile:$ImagePath\Install.wim /Index:1 /MountDir:$MountPath

# mount image for driver servicing
dism /Image:$MountPath /Add-Driver /Driver:$DriverPath\Drivers /Recurse

# unmount image and commit changes
dism /Unmount-Wim /MountDir:$MountPath /Commit
}

#=======ADDITIONAL UTILITIIES SERVICING=========#

if($Utilities -eq $True)
{
# mount install.wim image
dism /Mount-Wim /WimFile:$ImagePath\Install.wim /Index:1 /MountDir:$MountPath

# Copy scripts and tools .wim to Sources folder
Copy-Item -Path "$ScriptsPath\AutopilotInfo.ps1" -Destination "$MountPath\Windows\System32" -Recurse
Copy-Item -Path "$ScriptsPath\AutopilotInfo-Online.ps1" -Destination "$MountPath\Windows\System32" -Recurse
Copy-Item -Path "$ScriptsPath\Get-WindowsAutoPilotInfo.ps1" -Destination "$MountPath\Windows\System32" -Recurse
Copy-Item -Path "$ToolsPath\CMTrace.exe" -Destination "$MountPath\Windows\System32" -Recurse

# unmount image and commit changes
dism /Unmount-Wim /MountDir:$MountPath /Commit
}

#=======WINDOWS INSTALLATION MEDIA SERVICING CONFIRMATION=======#

if($Confirm -eq $True)
{
# gathers image info and indexes from usb media
dism /Get-WimInfo /WimFile:$InstWimPath
dism /Get-WimInfo /WimFile:$BootWimPath

# Create new ISO with updated .wim's
# ADK Location = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"
# OSCDIMG Command = oscdimg.exe  -m -o -pEF -u1 -udfver102 -bC:\Temp\Virtual\Media\Source\efi\microsoft\boot\efisys.bin C:\Temp\Virtual\Media\Source C:\Temp\Virtual\Media\Win11_25H2_English_x64-New.iso
}

#===================UPDATE SOURCE MEDIA===================#

if($UpdateMedia -eq $True)
{
# Copy updated .wim to Sources folder
Copy-Item -Path "$ImagePath\Install.wim" -Destination "$MediaRoot\sources" -Recurse

# Copy updated .wim to Sources folder
Copy-Item -Path "$ImagePath\boot.wim" -Destination "$MediaRoot\sources\" -Recurse
}

#=======WINDOWS INSTALLATION MEDIA ISO CREATION=======#

if($Iso -eq $True)
{
$Path = 'C:\Temp\Win11_25H2_English_x64-New.iso'
if (Test-Path $Path) {
    Remove-Item $Path -Force
    Write-Output "Deleted: $Path"
} else {
    Write-Output "File not found: $Path"
}

Start-Process $ScriptsPath\OSCDIMG.CMD -Wait

Write-Host "Updated .Iso available. Located - C:\Temp\Virtual\Media\Win11_25H2_English_x64-New.iso" -ForegroundColor Cyan
}

Dismount-DiskImage -ImagePath "C:\Temp\Virtual\Media\Win11_25H2_English_x64.iso"

Stop-Transcript
