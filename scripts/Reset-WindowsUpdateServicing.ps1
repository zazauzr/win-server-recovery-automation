<#
.SYNOPSIS
    Remediates stalled Windows Update transactions, resets CBS servicing locks,
    and restarts critical management dependencies on Windows Server.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Test-IsElevated {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

if (-not (Test-IsElevated)) {
    Write-Error "Execution halted: This utility requires elevated Administrative privileges."
    exit 1
}

$services = @('wuauserv', 'bits', 'cryptSvc', 'trustedinstaller')
$pendingFile = "$env:SystemRoot\WinSxS\pending.xml"
$distributionPath = "$env:SystemRoot\SoftwareDistribution"

Write-Output "[1/4] Stopping target services..."
foreach ($svc in $services) {
    if ((Get-Service -Name $svc -ErrorAction SilentlyContinue).Status -eq 'Running') {
        Stop-Service -Name $svc -Force -Verbose
    }
}

Write-Output "[2/4] Resolving CBS servicing locks..."
if (Test-Path -Path $pendingFile) {
    try {
        & takeown /f $pendingFile /a | Out-Null
        & icacls $pendingFile /grant "Administrators:F" | Out-Null
        Move-Item -Path $pendingFile -Destination "$pendingFile.bak" -Force
        Write-Output "Stuck pending.xml successfully archived."
    } catch {
        Write-Warning "Could not rotate pending.xml. System might still be holding handles."
    }
} else {
    Write-Output "No pending.xml locks detected."
}

Write-Output "[3/4] Purging corrupted software distribution caches..."
if (Test-Path -Path $distributionPath) {
    try {
        Move-Item -Path $distributionPath -Destination "$distributionPath.old" -Force
        Write-Output "SoftwareDistribution cache successfully archived."
    } catch {
        Write-Warning "SoftwareDistribution folder is locked by another process. Skipping rename."
    }
}

Write-Output "[4/4] Triggering component cleanup and restarting services..."
Start-Process -FilePath "dism.exe" -ArgumentList "/online /cleanup-image /startcomponentcleanup" -Wait -NoNewWindow

foreach ($svc in @('cryptSvc', 'bits', 'wuauserv')) {
    Start-Service -Name $svc -ErrorAction SilentlyContinue
}

Write-Output "Remediation sequence completed. Please schedule an orderly system reboot."
