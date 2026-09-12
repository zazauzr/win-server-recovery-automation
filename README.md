# Windows Server Component-Store Remediation & Out-of-Band Power Automation

An infrastructure automation and incident recovery toolkit designed to remediate transaction deadlocks in the Windows Component Store (CBS/DISM), resolve service hang conditions impacting remote access agents (RDP, RustDesk, LOB services), and establish out-of-band power recovery mechanisms via Wake-on-LAN (WoL).

---

## 📌 Architecture & Overview

During cumulative update installation sequences, Windows Server instances can enter a persistent servicing transaction loop (`TrustedInstaller` / `TiWorker.exe` starvation). This locks core dynamic-link libraries, stalling endpoint communication stacks and preventing incoming remote administration handshakes.

```
       [ Upstream Router / MikroTik ]
                     │  (Magic Packet / UDP 9)
                     ▼
      [ Target Server NIC (Physical) ]  <─── Powered via Standby Rail (+5VSB)
                     │  (ACPI S5 -> S0 State)
                     ▼
        [ Windows Server 2016 Host ]
         ├── WinSxS / Component Store (Clears Deadlocked pending.xml)
         ├── DISM Engine (Offline/Online Image Integrity)
         └── Management Endpoints (RDP / Remote Support Daemon)
```

### Key Capabilities
* **Component Store Recovery:** Programmatically clears uncommitted servicing locks (`pending.xml`) and corrupted staging directories without requiring image rebuilds.
* **Integrity Validation:** Automates subsystem health checks leveraging DISM and System File Checker (SFC).
* **Out-of-Band Power Automation:** Cross-platform Wake-on-LAN routines (PowerShell and MikroTik RouterOS scripts) to cycle bare-metal hosts remotely.

---

## 📂 Repository Structure

```text
├── scripts/
│   ├── Reset-WindowsUpdateServicing.ps1  # Transaction deadlock remediation
│   ├── Send-WOLPacket.ps1               # RFC-compliant PowerShell WoL engine
│   └── mikrotik-wol-trigger.rsc         # RouterOS hardware execution script
├── .gitignore
└── README.md
```

---

## 🚀 Execution & Deployment Guide

### Prerequisites
* PowerShell 5.1+ running in an elevated security context (`Run as Administrator`).
* Physical Target NIC supporting Wake-on-LAN (`PCIe PME / Magic Packet`).
* Network broadcast connectivity on target subnet (UDP Port 9/7).

---

### Step 1: System Service & Transaction Remediation
To release file system locks held by deadlocked servicing workers:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
.\scripts\Reset-WindowsUpdateServicing.ps1
```

Once executed, trigger standard file integrity repair:
```powershell
DISM.exe /Online /Cleanup-Image /RestoreHealth
sfc /scannow
```

---

### Step 2: Bare-Metal Power Automation (WoL)

#### Hardware Preparation (BIOS / UEFI)
1. **Power Management:** Set `Lan Wake up Control` (or `Power On By PCI-E`) to `[Enabled]`.
2. **Energy Regulations:** Set `ErP/EuP Support` to `[Disabled]` to preserve standby power (+5VSB) to the physical Ethernet PHY when the machine is shut down (ACPI S5 state).

#### Windows Adapter Configuration
Ensure the target physical adapter permits wake events:
* **Advanced Properties:** Set `Wake on Magic Packet` to `Enabled`.
* **Power Management:** Enable both *Allow this device to wake the computer* and *Only allow a magic packet to wake the computer*.

#### Dispatching Wake Signals

**Via PowerShell:**
```powershell
.\scripts\Send-WOLPacket.ps1 -MacAddress "00:1A:2B:3C:4D:5E" -BroadcastAddress "192.168.1.255" -Port 9
```

**Via MikroTik RouterOS (Console / WinBox):**
```routeros
/import file-name=scripts/mikrotik-wol-trigger.rsc
# Or run inline:
/tool wol mac=00:1A:2B:3C:4D:5E interface=bridge-lan
```

---

## 🔍 Verification & Health Checks

| Verification Step | Command / Methodology | Expected Output |
| :--- | :--- | :--- |
| **Physical Link State** | Visual check on RJ-45 Port / Switch Port | Active LED indicator in ACPI S5 (Off) |
| **Pending Servicing Lock** | `Test-Path "$env:SystemRoot\WinSxS\pending.xml"` | Returns `False` |
| **Component Store Health** | `dism /online /cleanup-image /checkhealth` | `No component store corruption detected` |
| **Remote Access Stack** | `Test-NetConnection -ComputerName 127.0.0.1 -Port 3389` | `TcpTestSucceeded : True` |

---

## 🛡 Security & Best Practices
* **Directed Broadcasts:** Avoid unrestricted global broadcast addresses (`255.255.255.255`) where internal routing filters drop non-directed packets; target specific subnet broadcast addresses (e.g., `192.168.1.255`).
* **Privilege Separation:** Component reset actions must be executed exclusively under authenticated administrative accounts.
