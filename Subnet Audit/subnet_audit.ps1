#Requires -Version 5.1
<#
.SYNOPSIS
    SubnetAudit V.1 - Comprehensive Network Device Inventory Tool
    
.DESCRIPTION
    A cross-platform PowerShell script for conducting stealth network audits.
    Discovers devices on specified subnets and gathers comprehensive inventory data.
    
.NOTES
    File Name      : SubnetAudit_V1.ps1
    Author         : Network Admin
    Created        : December 2024
    Version        : 1.0
    Requirements   : PowerShell 5.1+, nmap
    
.PARAMETER Subnet
    Target subnet in CIDR notation (e.g., 192.168.1.0/24)
    
.PARAMETER ExportPath
    Optional path to export results to CSV file
#>

[CmdletBinding()]
param(
    [string]$Subnet,
    [string]$ExportPath
)

# Script header and version info
function Show-Header {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "                                                                                " -ForegroundColor Cyan
    Write-Host "         ███████╗██╗   ██╗██████╗ ███╗   ██╗███████╗████████╗                 " -ForegroundColor Cyan
    Write-Host "         ██╔════╝██║   ██║██╔══██╗████╗  ██║██╔════╝╚══██╔══╝                 " -ForegroundColor Cyan
    Write-Host "         ███████╗██║   ██║██████╔╝██╔██╗ ██║█████╗     ██║                    " -ForegroundColor Cyan
    Write-Host "         ╚════██║██║   ██║██╔══██╗██║╚██╗██║██╔══╝     ██║                    " -ForegroundColor Cyan
    Write-Host "         ███████║╚██████╔╝██████╔╝██║ ╚████║███████╗   ██║                    " -ForegroundColor Cyan
    Write-Host "         ╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝   ╚═╝                    " -ForegroundColor Cyan
    Write-Host "                                                                                " -ForegroundColor Cyan
    Write-Host "             █████╗ ██╗   ██╗██████╗ ██╗████████╗                             " -ForegroundColor Cyan
    Write-Host "            ██╔══██╗██║   ██║██╔══██╗██║╚══██╔══╝                             " -ForegroundColor Cyan
    Write-Host "            ███████║██║   ██║██║  ██║██║   ██║                                " -ForegroundColor Cyan
    Write-Host "            ██╔══██║██║   ██║██║  ██║██║   ██║                                " -ForegroundColor Cyan
    Write-Host "            ██║  ██║╚██████╔╝██████╔╝██║   ██║                                " -ForegroundColor Cyan
    Write-Host "            ╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚═╝   ╚═╝                                " -ForegroundColor Cyan
    Write-Host "                                                                                " -ForegroundColor Cyan
    Write-Host "                    NETWORK INVENTORY - MOTHER PROTOCOL                        " -ForegroundColor Cyan
    Write-Host "                                                                                " -ForegroundColor Cyan
    Write-Host "                         By Network Admin  |  v1.0                             " -ForegroundColor Cyan
    Write-Host "                              December 2024                                     " -ForegroundColor Cyan
    Write-Host "                                                                                " -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host ""
}

# Function to detect operating system
function Get-OperatingSystem {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return $PSVersionTable.OS
    } else {
        return "Windows PowerShell $($PSVersionTable.PSVersion)"
    }
}

# Function to check if running as administrator/root
function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    
    if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') {
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } elseif ($IsLinux -or $IsMacOS) {
        return (id -u) -eq 0
    }
    return $false
}

# Function to install nmap based on operating system
function Install-Nmap {
    Write-Host "`n[INFO] Nmap not found. Attempting installation..." -ForegroundColor Yellow
    
    $isAdmin = Test-AdminPrivileges
    if (-not $isAdmin) {
        Write-Host "[WARNING] Administrator/root privileges required for nmap installation." -ForegroundColor Yellow
        Write-Host "Please run this script as Administrator or install nmap manually." -ForegroundColor Yellow
        return $false
    }
    
    try {
        if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') {
            # Windows installation using winget or chocolatey
            Write-Host "[INFO] Detecting Windows package manager..." -ForegroundColor Cyan
            
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                Write-Host "[INFO] Installing nmap via winget..." -ForegroundColor Cyan
                winget install nmap --accept-package-agreements --accept-source-agreements
            } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
                Write-Host "[INFO] Installing nmap via Chocolatey..." -ForegroundColor Cyan
                choco install nmap -y
            } else {
                Write-Host "[ERROR] Please install nmap manually from https://nmap.org/download.html" -ForegroundColor Red
                return $false
            }
            
        } elseif ($IsMacOS) {
            # macOS installation using homebrew
            Write-Host "[INFO] Installing nmap via Homebrew..." -ForegroundColor Cyan
            if (Get-Command brew -ErrorAction SilentlyContinue) {
                brew install nmap
            } else {
                Write-Host "[ERROR] Homebrew not found. Please install from https://brew.sh/" -ForegroundColor Red
                return $false
            }
            
        } elseif ($IsLinux) {
            # Linux installation - detect package manager
            Write-Host "[INFO] Detecting Linux package manager..." -ForegroundColor Cyan
            
            if (Get-Command apt-get -ErrorAction SilentlyContinue) {
                sudo apt-get update && sudo apt-get install -y nmap
            } elseif (Get-Command yum -ErrorAction SilentlyContinue) {
                sudo yum install -y nmap
            } elseif (Get-Command dnf -ErrorAction SilentlyContinue) {
                sudo dnf install -y nmap
            } elseif (Get-Command pacman -ErrorAction SilentlyContinue) {
                sudo pacman -S --noconfirm nmap
            } else {
                Write-Host "[ERROR] Unable to detect package manager. Please install nmap manually." -ForegroundColor Red
                return $false
            }
        }
        
        # Verify installation
        Start-Sleep 3
        if (Get-Command nmap -ErrorAction SilentlyContinue) {
            Write-Host "[SUCCESS] Nmap installed successfully!" -ForegroundColor Green
            return $true
        } else {
            Write-Host "[ERROR] Nmap installation failed." -ForegroundColor Red
            return $false
        }
        
    } catch {
        Write-Host "[ERROR] Installation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to check and install nmap
function Test-NmapAvailability {
    if (Get-Command nmap -ErrorAction SilentlyContinue) {
        $nmapVersion = nmap --version | Select-Object -First 1
        Write-Host "[INFO] $nmapVersion" -ForegroundColor Green
        return $true
    } else {
        Write-Host "[WARNING] Nmap not found on system." -ForegroundColor Yellow
        
        $install = Read-Host "Would you like to attempt automatic installation? (y/n)"
        if ($install -eq 'y' -or $install -eq 'Y') {
            return Install-Nmap
        } else {
            Write-Host "[ERROR] Nmap is required for this script. Please install manually." -ForegroundColor Red
            return $false
        }
    }
}

# Function to get network interfaces
function Get-NetworkInterfaces {
    Write-Host "`n[INFO] Available Network Interfaces:" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
    
    try {
        if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') {
            Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object {
                $ip = (Get-NetIPAddress -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
                Write-Host "Interface: $($_.Name)" -ForegroundColor White
                Write-Host "  Status: $($_.Status)" -ForegroundColor Green
                Write-Host "  IP: $ip" -ForegroundColor Yellow
                Write-Host "  MAC: $($_.MacAddress)" -ForegroundColor Magenta
                Write-Host ""
            }
        } else {
            # Unix-like systems (macOS/Linux)
            $interfaces = ip addr show | grep -E "^\d+:|inet "
            if ($interfaces) {
                Write-Host $interfaces -ForegroundColor White
            } else {
                ifconfig | grep -E "flags=|inet "
            }
        }
    } catch {
        Write-Host "[WARNING] Could not retrieve interface information: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Function to validate subnet format
function Test-SubnetFormat {
    param([string]$Subnet)
    
    # Basic CIDR validation
    if ($Subnet -match '^(\d{1,3}\.){3}\d{1,3}/\d{1,2}$') {
        $parts = $Subnet.Split('/')
        $ip = $parts[0]
        $cidr = [int]$parts[1]
        
        # Validate IP octets
        $octets = $ip.Split('.')
        foreach ($octet in $octets) {
            if ([int]$octet -gt 255) { return $false }
        }
        
        # Validate CIDR
        if ($cidr -lt 1 -or $cidr -gt 30) { return $false }
        
        return $true
    }
    return $false
}

# Function to perform stealth network scan
function Start-StealthScan {
    param(
        [string]$TargetSubnet
    )
    
    Write-Host "`n[INFO] Starting stealth scan of $TargetSubnet..." -ForegroundColor Cyan
    Write-Host "[INFO] Using stealth SYN scan with timing template T2 (polite)" -ForegroundColor Cyan
    Write-Host "[INFO] Progress updates every 20 seconds..." -ForegroundColor Yellow
    Write-Host ""
    
    # Stealth nmap command - SYN scan with OS detection, polite timing
    # -sS: SYN scan (stealth)
    # -T2: Polite timing (slow but less detectable)
    # -O: OS detection
    # -sV: Service version detection (limited to avoid noise)
    # --max-rtt-timeout 2s: Shorter timeouts
    # --host-timeout 300s: Per-host timeout
    $nmapCommand = "nmap -sS -T2 -O -sV --max-rtt-timeout 2s --host-timeout 300s $TargetSubnet"
    
    Write-Host "[COMMAND] $nmapCommand" -ForegroundColor Gray
    Write-Host ""
    
    # Execute scan with progress monitoring
    $job = Start-Job -ScriptBlock {
        param($command)
        Invoke-Expression $command
    } -ArgumentList $nmapCommand
    
    # Monitor progress
    $startTime = Get-Date
    $lastUpdate = $startTime
    
    while ($job.State -eq 'Running') {
        $currentTime = Get-Date
        $elapsed = $currentTime - $startTime
        
        if (($currentTime - $lastUpdate).TotalSeconds -ge 20) {
            Write-Host "[PROGRESS] Scan running... Elapsed time: $($elapsed.ToString('mm\:ss'))" -ForegroundColor Yellow
            $lastUpdate = $currentTime
        }
        
        Start-Sleep 2
    }
    
    $results = Receive-Job $job
    Remove-Job $job
    
    return $results
}

# Function to parse nmap results
function Parse-NmapResults {
    param([string]$NmapOutput)
    
    $devices = @()
    $currentDevice = @{}
    
    $lines = $NmapOutput -split "`n"
    
    foreach ($line in $lines) {
        $line = $line.Trim()
        
        # New host detected
        if ($line -match "Nmap scan report for (.+)") {
            if ($currentDevice.Count -gt 0) {
                $devices += New-Object PSObject -Property $currentDevice
            }
            $currentDevice = @{
                Hostname = $matches[1]
                IP = ""
                MAC = ""
                OS = ""
                Status = ""
            }
        }
        
        # Extract IP address
        if ($line -match "\((\d+\.\d+\.\d+\.\d+)\)") {
            $currentDevice.IP = $matches[1]
        } elseif ($line -match "^(\d+\.\d+\.\d+\.\d+)$") {
            $currentDevice.IP = $matches[1]
            $currentDevice.Hostname = $matches[1]
        }
        
        # Host status
        if ($line -match "Host is (.+)") {
            $currentDevice.Status = $matches[1]
        }
        
        # MAC address
        if ($line -match "MAC Address: ([A-Fa-f0-9:]{17}) \((.+?)\)") {
            $currentDevice.MAC = $matches[1]
            $currentDevice.Vendor = $matches[2]
        }
        
        # OS detection
        if ($line -match "OS: (.+)") {
            $currentDevice.OS = $matches[1]
        } elseif ($line -match "Running: (.+)") {
            $currentDevice.OS = $matches[1]
        }
    }
    
    # Add last device
    if ($currentDevice.Count -gt 0) {
        $devices += New-Object PSObject -Property $currentDevice
    }
    
    return $devices
}

# Function to display results in formatted table
function Show-Results {
    param([array]$Devices)
    
    if ($Devices.Count -eq 0) {
        Write-Host "`n[INFO] No devices found on the specified subnet." -ForegroundColor Yellow
        return
    }
    
    Write-Host "`n╔═══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                              SCAN RESULTS                                     ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "Devices Found: $($Devices.Count)" -ForegroundColor Cyan
    Write-Host ""
    
    # Display formatted table
    $Devices | Select-Object @{Name="IP Address"; Expression={$_.IP}},
                             @{Name="Hostname"; Expression={if($_.Hostname -ne $_.IP){$_.Hostname}else{"N/A"}}},
                             @{Name="MAC Address"; Expression={if($_.MAC){$_.MAC}else{"N/A"}}},
                             @{Name="Status"; Expression={$_.Status}},
                             @{Name="Operating System"; Expression={if($_.OS){$_.OS}else{"Unknown"}}} | 
    Format-Table -AutoSize -Wrap
    
    return $Devices
}

# Function to export results
function Export-Results {
    param(
        [array]$Devices,
        [string]$Path
    )
    
    if (-not $Path) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $Path = "SubnetAudit_Results_$timestamp.csv"
    }
    
    try {
        $Devices | Select-Object @{Name="IP_Address"; Expression={$_.IP}},
                                 @{Name="Hostname"; Expression={if($_.Hostname -ne $_.IP){$_.Hostname}else{"N/A"}}},
                                 @{Name="MAC_Address"; Expression={if($_.MAC){$_.MAC}else{"N/A"}}},
                                 @{Name="Status"; Expression={$_.Status}},
                                 @{Name="Operating_System"; Expression={if($_.OS){$_.OS}else{"Unknown"}}},
                                 @{Name="Scan_Date"; Expression={Get-Date -Format "yyyy-MM-dd HH:mm:ss"}} |
        Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
        
        Write-Host "[SUCCESS] Results exported to: $Path" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Export failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Main execution function
function Start-SubnetAudit {
    Show-Header
    
    # Display system information
    $os = Get-OperatingSystem
    Write-Host "[INFO] Running on: $os" -ForegroundColor Cyan
    Write-Host "[INFO] PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
    
    # Check nmap availability
    if (-not (Test-NmapAvailability)) {
        Write-Host "`nExiting..." -ForegroundColor Red
        return
    }
    
    # Show network interfaces for reference
    Get-NetworkInterfaces
    
    # Get target subnet
    if (-not $Subnet) {
        do {
            $Subnet = Read-Host "`nEnter target subnet (e.g., 192.168.1.0/24)"
        } while (-not (Test-SubnetFormat -Subnet $Subnet))
    } else {
        if (-not (Test-SubnetFormat -Subnet $Subnet)) {
            Write-Host "[ERROR] Invalid subnet format. Use CIDR notation (e.g., 192.168.1.0/24)" -ForegroundColor Red
            return
        }
    }
    
    Write-Host "`n[INFO] Target subnet validated: $Subnet" -ForegroundColor Green
    
    # Confirm scan
    $confirm = Read-Host "`nProceed with stealth scan? (y/n)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "Scan cancelled." -ForegroundColor Yellow
        return
    }
    
    # Perform scan
    $scanResults = Start-StealthScan -TargetSubnet $Subnet
    
    # Parse and display results
    $devices = Parse-NmapResults -NmapOutput $scanResults
    $finalDevices = Show-Results -Devices $devices
    
    # Export option
    if ($finalDevices.Count -gt 0) {
        $exportChoice = Read-Host "`nWould you like to export results to CSV? (y/n)"
        if ($exportChoice -eq 'y' -or $exportChoice -eq 'Y') {
            if ($ExportPath) {
                Export-Results -Devices $finalDevices -Path $ExportPath
            } else {
                Export-Results -Devices $finalDevices
            }
        }
    }
    
    Write-Host "`n[INFO] Scan completed!" -ForegroundColor Green
    Write-Host "Thank you for using SubnetAudit V.1" -ForegroundColor Cyan
}

# Script entry point
try {
    Start-SubnetAudit
} catch {
    Write-Host "`n[FATAL ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
}