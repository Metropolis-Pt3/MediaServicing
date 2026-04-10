
<#
.SUMMARY
  Microsoft Windows 11 Installation Media Servicing

.DESCRIPTION
  Microsoft Windows 11 (25H2) Installation Media Servicing. Uses the Microsoft Media Creation to to build USB
  Media, then adds utilties, scripts and drivers to support Dell and HP Models.

  Note: Download drivers prior to servicing.

.NOTES/REFERENCES
  Current Version=1.0.12
  Date: 4.1.2026
  Author: Neo (Steve Molzahn)

  Changelog:
  4.1.2026 - Initial script. v1.0.2
  4.4.2026 - Updated Logic and features. v1.0.8
  4.10.2026
      -Added automation feature to create updated ISO. v1.0.10
      -Added autopilotinfo.ps1 and autopilotinfo-online.ps1 to install.wim. v1.0.11
      -Added logic to wait for ISO creation prior to script continuing. v1.0.12
 
#>

[CmdletBinding(SupportsShouldProcess = $true)]
Param(
    [Parameter(Mandatory=$False,Position=1)]
    [string]$Boot = $False,

    [Parameter(Mandatory=$False,Position=2)]
    [string]$Install = $False,

    [Parameter(Mandatory=$False,Position=3)]
    [switch]$Utilities=$False,

    [Parameter(Mandatory=$False,Position=4)]
    [switch]$Confirm=$False,

    [Parameter(Mandatory=$False,Position=5)]
    [switch]$ISO = $False
    )

#=======================SERVICING====================#

# PREPARE WINDOWS MEDIA
$MediaRoot = "C:\Temp\Virtual\Media\Source"
$ImagePath = "C:\Temp\Virtual\Media\Image"
$ScriptsPath = "C:\Temp\Virtual\Scripts"
$ToolsPath = "C:\Temp\Virtual\Tools"

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

#===========GATHER BOOT.WIM and INSTALL.WIM INFO============#
# gathers images info and indexes
dism /Get-WimInfo /WimFile:$BootWimPath

# gathers image info and indexes from usb media
dism /Get-WimInfo /WimFile:$InstWimPath

#===================BOOT.WIM SERVICING===============#

if($Boot -eq $True)
{
# gathers images info and indexes
dism /Get-WimInfo /WimFile:$BootWimPath

# copy boot.wim files to temp folder
Copy-Item -Path "$BootWimPath" -Destination "$ImagePath" -Recurse

# mount boot.wim image (boot.wim indexes, typically Index #1 = WinPE, Index #2 = Windows Setup (recommend Index 2 for driver injection)
dism /Mount-Wim /WimFile:$ImagePath\boot.wim /Index:2 /MountDir:$MountPath

# mount image for driver servicing
dism /Image:$MountPath /Add-Driver /Driver:$DriverPath /Recurse

# unmount image and commit changes
dism /Unmount-Wim /MountDir:$MountPath /Commit

# Copy updated .wim to Sources folder
Copy-Item -Path "$ImagePath\boot.wim" -Destination "$MediaRoot\sources\" -Recurse
}

#=======INSTALL.WIM or INSTALL.SWM SERVICING=========#

if($Install -eq $True)
{
# gathers images info and indexes from temp location
dism /Get-WimInfo /WimFile:$InstWimPath

# Windows 11 Pro is recommended baseline. This will only need to be done once.
dism /export-image /sourceimagefile:$InstWimPath /sourceindex:6 /destinationimagefile:$ImagePath\install.wim /Compress:max

# mount install.wim image
dism /Mount-Wim /WimFile:$ImagePath\Install.wim /Index:1 /MountDir:$MountPath

# mount image for driver servicing
dism /Image:$MountPath /Add-Driver /Driver:$DriverPath\Drivers /Recurse

# unmount image and commit changes
dism /Unmount-Wim /MountDir:$MountPath /Commit

# Copy updated .wim to Sources folder
Copy-Item -Path "$ImagePath\Install.wim" -Destination "$MediaRoot\sources" -Recurse
}

if($Utilities -eq $True)
{
# mount install.wim image
dism /Mount-Wim /WimFile:$ImagePath\Install.wim /Index:1 /MountDir:$MountPath

# Copy scripts and tools .wim to Sources folder
Copy-Item -Path "$ScriptsPath\AutopilotInfo.ps1" -Destination "$MountPath\Windows\System32" -Recurse
Copy-Item -Path "$ScriptsPath\AutopilotInfo-Online.ps1" -Destination "$MountPath\Windows\System32" -Recurse
Copy-Item -Path "$ToolsPath\CMTrace.exe" -Destination "$MountPath\Windows\System32" -Recurse

# unmount image and commit changes
dism /Unmount-Wim /MountDir:$MountPath /Commit

# Copy updated .wim to Sources folder
Copy-Item -Path "$ImagePath\Install.wim" -Destination "$MediaRoot\sources" -Recurse
}

#=======WINDOWS INSTALLATION MEDIA SERVICING CONFIRMATION=======#

if($Confirm -eq $True)
{
# gathers image info and indexes from usb media
dism /Get-WimInfo /WimFile:$InstWimPath
dism /Get-WimInfo /WimFile:$BootWimPath
}

# Create new ISO with updated .wim's
# ADK Location = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"
# OSCDIMG Command = oscdimg.exe  -m -o -pEF -u1 -udfver102 -bC:\Temp\Virtual\Media\Source\efi\microsoft\boot\efisys.bin C:\Temp\Virtual\Media\Source C:\Temp\Virtual\Media\Win11_25H2_English_x64-New.iso

if($ISO -eq $True)
{
$path = 'C:\Temp\Win11_25H2_English_x64-New.iso'
if (Test-Path $path) {
    Remove-Item $path -Force
    Write-Output "Deleted: $path"
} else {
    Write-Output "File not found: $path"
}

Start-Process $ScriptsPath\OSCDIMG.CMD -Wait

Write-Host "Updated .iso available. Located - C:\Temp\Virtual\Media\Win11_25H2_English_x64-New.iso" -ForegroundColor Cyan
}

Stop-Transcript
