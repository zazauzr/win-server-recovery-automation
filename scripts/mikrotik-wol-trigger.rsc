# =====================================================================
# Script: trigger-server-wol
# Description: Dispatches a Wake-on-LAN Magic Packet to target server
# Environment: MikroTik RouterOS v6.x / v7.x
# =====================================================================

:local TargetMac "00:1A:2B:3C:4D:5E"
:local TargetInterface "bridge-lan"

:do {
    :log info ("WOL: Sending Magic Packet to " . $TargetMac . " via " . $TargetInterface)
    /tool wol mac=$TargetMac interface=$TargetInterface
    :log info ("WOL: Magic Packet successfully dispatched")
} on-error={
    :log error ("WOL: Failed to send Magic Packet to " . $TargetMac)
}
