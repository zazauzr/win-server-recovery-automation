<#
.SYNOPSIS
    Sends a Wake-on-LAN (WoL) Magic Packet across subnet broadcast interfaces.
.DESCRIPTION
    Constructs an RFC-compliant 102-byte Magic Packet payload (6x 0xFF followed
    by 16 iterations of the target MAC address) and dispatches it via UDP broadcast.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]     [ValidatePattern('^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$')]
    [string]$MacAddress,

    [Parameter(Mandatory = $false, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [string]$BroadcastAddress = '255.255.255.255',

    [Parameter(Mandatory = $false, Position = 2)]     [ValidateRange(1, 65535)]     [int]$Port = 9
)

$ErrorActionPreference = 'Stop'

try {
    $cleanMac =$MacAddress -replace '[:-]', ''
    $macBytes = for ($i = 0; $i -lt 12; $i += 2) {
        [Convert]::ToByte($cleanMac.Substring($i, 2), 16)
    }

    $payload = [byte[]](@([byte]0xFF) * 6) + ($macBytes * 16)$udpClient = New-Object System.Net.Sockets.UdpClient
    $destination = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Parse($BroadcastAddress),$Port)

    $sentBytes = $udpClient.Send($payload, $payload.Length, $destination)
    Write-Host "Dispatched $sentBytes-byte Magic Packet to target [$MacAddress] via $BroadcastAddress:$Port" -ForegroundColor Green
} catch {
    Write-Error "Failed to transmit WoL Magic Packet: $($_.Exception.Message)"
} finally {
    if ($udpClient -ne$null) {
        $udpClient.Close()$udpClient.Dispose()
    }
}
