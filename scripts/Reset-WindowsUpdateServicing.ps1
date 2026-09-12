<#
.SYNOPSIS
    Remediates stalled Windows Update transactions, resets CBS servicing locks,
    and restarts critical management dependencies on Windows Server.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Test-IsElevated {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsElevated)) {
    Write-Error "Execution halted: This utility requires elevated Administrative privileges."
    exit 1
}

$services = @('wuauserv', 'bits', 'cryptSvc', 'trustedinstaller')
$winsxsPath = "$env:SystemRoot\WinSxS"
$pendingFile = Join-Path$winsxsPath "pending.xml"
$distributionPath = "$env:SystemRoot\SoftwareDistribution"

Write-Host "[1/4] Stopping target services..." -ForegroundColor Cyan
foreach ($svc in$services) {
    if ((Get-Service -Name $svc -ErrorAction SilentlyContinue).Status -eq 'Running') {
        Stop-Service -Name $svc -Force -Verbose
    }
}

Write-Host "[2/4] Resolving CBS servicing locks..." -ForegroundColor Cyan
if (Test-Path -Path $pendingFile) {
    try {
        & takeown /f $pendingFile /a | Out-Null
        & icacls $pendingFile /grant "Administrators:F" | Out-Null
        $backupPath = "$pendingFile.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Move-Item -Path $pendingFile -Destination$backupPath -Force
        Write-Host "Stuck pending.xml archived to: $backupPath" -ForegroundColor Green
    } catch {
        Write-Warning "Could not rotate pending.xml. System might still be holding handles."
    }
} else {
    Write-Host "No pending.xml locks detected." -ForegroundColor Yellow
}

Write-Host "[3/4] Purging corrupted software distribution caches..." -ForegroundColor Cyan
if (Test-Path -Path $distributionPath) {$archivedDist = "$distributionPath.old.$(Get-Date -Format 'yyyyMMddHHmmss')"
    try {
        Move-Item -Path $distributionPath -Destination$archivedDist -Force
        Write-Host "Cache moved to $archivedDist" -ForegroundColor Green
    } catch {
        Write-Warning "SoftwareDistribution folder is locked by another process. Skipping rename."
    }
}

Write-Host "[4/4] Triggering component cleanup and restarting services..." -ForegroundColor Cyan
Start-Process -FilePath "dism.exe" -ArgumentList "/online /cleanup-image /startcomponentcleanup" -Wait -NoNewWindow

foreach ($svc in @('cryptSvc', 'bits', 'wuauserv')) {
    Start-Service -Name $svc -ErrorAction SilentlyContinue
}

Write-Host "Remediation sequence completed. Please schedule an orderly system reboot." -ForegroundColor Green
