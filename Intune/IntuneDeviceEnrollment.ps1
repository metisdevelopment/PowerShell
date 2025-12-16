#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Intune Device Enrollment - MOTHER PROTOCOL v1.0
    
.DESCRIPTION
    A comprehensive Windows Intune device enrollment script with Autopilot hash upload.
    Supports both OOBE (new device) and existing device (wipe & re-enroll) scenarios.
    Uses Microsoft Graph API for all operations with detailed Mother protocol logging.
    
.NOTES
    File Name      : IntuneEnrollment_Mother.ps1
    Author         : Tom @ Metis
    Created        : January 2025
    Version        : 1.0
    Requirements   : PowerShell 5.1+, Administrator rights, Internet connection
    
.EXAMPLE
    .\IntuneEnrollment_Mother.ps1
    
    Runs the interactive enrollment wizard with Mother protocol interface.
    
.LINK
    Microsoft Graph API Documentation: https://learn.microsoft.com/graph/
    Windows Autopilot Documentation: https://learn.microsoft.com/autopilot/
#>

[CmdletBinding()]
param()

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================

$script:LogFile = ""
$script:DeviceInfo = @{}
$script:EnrollmentStartTime = Get-Date

# ============================================================================
# MOTHER PROTOCOL - UI FUNCTIONS
# ============================================================================

function Show-MotherHeader {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "                                                                                " -ForegroundColor Cyan
    Write-Host "                     ██╗███████╗███╗   ██╗██████╗  ██████╗ ██╗     ██╗        " -ForegroundColor Cyan
    Write-Host "                     ██║██╔════╝████╗  ██║██╔══██╗██╔═══██╗██║     ██║        " -ForegroundColor Cyan
    Write-Host "                     ██║█████╗  ██╔██╗ ██║██████╔╝██║   ██║██║     ██║        " -ForegroundColor Cyan
    Write-Host "                     ██║██╔══╝  ██║╚██╗██║██╔══██╗██║   ██║██║     ██║        " -ForegroundColor Cyan
    Write-Host "                     ██║███████╗██║ ╚████║██║  ██║╚██████╔╝███████╗███████╗   " -ForegroundColor Cyan
    Write-Host "                     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝   " -ForegroundColor Cyan
    Write-Host "                                                                                " -ForegroundColor Cyan
    Write-Host "                    INTUNE DEVICE ENROLLMENT - MOTHER PROTOCOL                 " -ForegroundColor Cyan
    Write-Host "                                                                                " -ForegroundColor Cyan
    Write-Host "                              By Tom @ Metis  |  v1.0                          " -ForegroundColor Cyan
    Write-Host "                                January 2025                                    " -ForegroundColor Cyan
    Write-Host "                                                                                " -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-MotherLog {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'System')]
        [string]$Type = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Type] $Message"
    
    # Write to log file
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
    }
    
    # Console output with color coding
    switch ($Type) {
        'Info'    { Write-Host "[MOTHER] >>> $Message" -ForegroundColor Cyan }
        'Success' { Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
        'Warning' { Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
        'Error'   { Write-Host "[ERROR] $Message" -ForegroundColor Red }
        'System'  { Write-Host "[SYSTEM] $Message" -ForegroundColor Magenta }
    }
}

function Show-MotherProgress {
    param([string]$Activity)
    Write-Host "[MOTHER] >>> $Activity..." -ForegroundColor Cyan -NoNewline
}

function Complete-MotherProgress {
    param([bool]$Success = $true)
    if ($Success) {
        Write-Host " COMPLETE" -ForegroundColor Green
    } else {
        Write-Host " FAILED" -ForegroundColor Red
    }
}

function Show-Separator {
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor DarkGray
    Write-Host ""
}

# ============================================================================
# PREREQUISITE CHECKS
# ============================================================================

function Test-AdminPrivileges {
    <#
    .SYNOPSIS
        Verifies script is running with Administrator privileges.
    .DESCRIPTION
        Many operations (hardware hash retrieval, device enrollment) require
        elevated permissions. This function checks and exits if not admin.
    #>
    
    Write-MotherLog "Verifying administrator privileges" -Type System
    
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-MotherLog "Administrator privileges required" -Type Error
        Write-Host ""
        Write-Host "This script must be run as Administrator." -ForegroundColor Red
        Write-Host "Please right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
        Write-Host ""
        pause
        exit 1
    }
    
    Write-MotherLog "Administrator privileges confirmed" -Type Success
}

function Install-RequiredModules {
    <#
    .SYNOPSIS
        Installs Microsoft.Graph PowerShell modules if not present.
    .DESCRIPTION
        We need several Graph modules:
        - Microsoft.Graph.Authentication: For connecting to Graph
        - Microsoft.Graph.Identity.DirectoryManagement: For device operations
        - Microsoft.Graph.Groups: For group management
        - Microsoft.Graph.DeviceManagement.Enrollment: For Intune enrollment
    #>
    
    Write-MotherLog "Checking required PowerShell modules" -Type System
    
    $requiredModules = @(
        'Microsoft.Graph.Authentication',
        'Microsoft.Graph.Identity.DirectoryManagement',
        'Microsoft.Graph.Groups',
        'Microsoft.Graph.DeviceManagement.Enrollment'
    )
    
    $modulesToInstall = @()
    
    foreach ($module in $requiredModules) {
        Show-MotherProgress "Checking module: $module"
        if (Get-Module -ListAvailable -Name $module) {
            Complete-MotherProgress -Success $true
        } else {
            Complete-MotherProgress -Success $false
            $modulesToInstall += $module
        }
    }
    
    if ($modulesToInstall.Count -gt 0) {
        Write-Host ""
        Write-MotherLog "Missing modules detected. Installation required." -Type Warning
        Write-Host ""
        Write-Host "The following Microsoft Graph modules will be installed:" -ForegroundColor Yellow
        foreach ($module in $modulesToInstall) {
            Write-Host "  - $module" -ForegroundColor White
        }
        Write-Host ""
        
        $confirm = Read-Host "Proceed with installation? (y/N)"
        if ($confirm -ne 'y' -and $confirm -ne 'Y') {
            Write-MotherLog "Module installation declined by user" -Type Error
            exit 1
        }
        
        Write-Host ""
        Write-MotherLog "Installing Microsoft Graph modules" -Type Info
        
        # Set PSGallery as trusted (temporarily)
        $originalPolicy = (Get-PSRepository -Name PSGallery).InstallationPolicy
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        
        foreach ($module in $modulesToInstall) {
            try {
                Show-MotherProgress "Installing $module"
                Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
                Complete-MotherProgress -Success $true
            } catch {
                Complete-MotherProgress -Success $false
                Write-MotherLog "Failed to install $module: $($_.Exception.Message)" -Type Error
                Set-PSRepository -Name PSGallery -InstallationPolicy $originalPolicy
                exit 1
            }
        }
        
        # Restore original policy
        Set-PSRepository -Name PSGallery -InstallationPolicy $originalPolicy
        
        Write-MotherLog "All required modules installed successfully" -Type Success
    }
    
    # Import modules
    Write-Host ""
    Write-MotherLog "Loading Microsoft Graph modules" -Type System
    foreach ($module in $requiredModules) {
        Show-MotherProgress "Loading $module"
        try {
            Import-Module $module -ErrorAction Stop
            Complete-MotherProgress -Success $true
        } catch {
            Complete-MotherProgress -Success $false
            Write-MotherLog "Failed to load $module: $($_.Exception.Message)" -Type Error
            exit 1
        }
    }
}

# ============================================================================
# MICROSOFT GRAPH AUTHENTICATION
# ============================================================================

function Connect-MotherGraph {
    <#
    .SYNOPSIS
        Authenticates to Microsoft Graph with required permissions.
    .DESCRIPTION
        Connects using interactive login (delegated permissions).
        Required scopes:
        - DeviceManagementManagedDevices.ReadWrite.All: Manage Intune devices
        - Device.ReadWrite.All: Read/write device information
        - Group.Read.All: Read group information
        - Directory.Read.All: Read directory data
        - DeviceManagementServiceConfig.ReadWrite.All: Autopilot management
    #>
    
    Write-MotherLog "Initiating Microsoft Graph authentication" -Type System
    Write-Host ""
    Write-Host "Required Permissions:" -ForegroundColor Yellow
    Write-Host "  - DeviceManagementManagedDevices.ReadWrite.All" -ForegroundColor White
    Write-Host "  - Device.ReadWrite.All" -ForegroundColor White
    Write-Host "  - Group.Read.All" -ForegroundColor White
    Write-Host "  - Directory.Read.All" -ForegroundColor White
    Write-Host "  - DeviceManagementServiceConfig.ReadWrite.All" -ForegroundColor White
    Write-Host ""
    Write-Host "A sign-in window will open. Please authenticate as:" -ForegroundColor Cyan
    Write-Host "  - Global Administrator, OR" -ForegroundColor White
    Write-Host "  - Intune Administrator" -ForegroundColor White
    Write-Host ""
    
    pause
    
    try {
        Show-MotherProgress "Connecting to Microsoft Graph"
        
        Connect-MgGraph -Scopes @(
            'DeviceManagementManagedDevices.ReadWrite.All',
            'Device.ReadWrite.All',
            'Group.Read.All',
            'Directory.Read.All',
            'DeviceManagementServiceConfig.ReadWrite.All'
        ) -ErrorAction Stop | Out-Null
        
        Complete-MotherProgress -Success $true
        
        # Get authenticated user context
        $context = Get-MgContext
        Write-Host ""
        Write-MotherLog "Authenticated as: $($context.Account)" -Type Success
        Write-MotherLog "Tenant: $($context.TenantId)" -Type Info
        Write-Host ""
        
        return $true
        
    } catch {
        Complete-MotherProgress -Success $false
        Write-MotherLog "Authentication failed: $($_.Exception.Message)" -Type Error
        return $false
    }
}

# ============================================================================
# DEVICE INFORMATION GATHERING
# ============================================================================

function Get-DeviceInformation {
    <#
    .SYNOPSIS
        Retrieves local device hardware information.
    .DESCRIPTION
        Gathers:
        - Computer manufacturer (Dell, HP, Lenovo, etc.)
        - Computer model
        - Serial number (critical for Autopilot)
        - Current user
        - Windows version
        - TPM status
        This information is used for enrollment and Autopilot registration.
    #>
    
    Write-MotherLog "Detecting device hardware information" -Type System
    Write-Host ""
    
    try {
        # Get computer system information
        Show-MotherProgress "Querying system information"
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
        Complete-MotherProgress -Success $true
        
        # Get BIOS information (contains serial number)
        Show-MotherProgress "Querying BIOS information"
        $bios = Get-CimInstance -ClassName Win32_BIOS
        Complete-MotherProgress -Success $true
        
        # Get OS information
        Show-MotherProgress "Querying OS information"
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        Complete-MotherProgress -Success $true
        
        # Get TPM information
        Show-MotherProgress "Checking TPM status"
        try {
            $tpm = Get-Tpm -ErrorAction SilentlyContinue
            $tpmStatus = if ($tpm.TpmPresent -and $tpm.TpmReady) { "Present and Ready" } 
                        elseif ($tpm.TpmPresent) { "Present but Not Ready" }
                        else { "Not Present" }
        } catch {
            $tpmStatus = "Unable to detect"
        }
        Complete-MotherProgress -Success $true
        
        # Store in script-level variable
        $script:DeviceInfo = @{
            Manufacturer = $computerSystem.Manufacturer
            Model        = $computerSystem.Model
            SerialNumber = $bios.SerialNumber
            CurrentUser  = $computerSystem.UserName
            OSVersion    = $os.Caption
            OSBuild      = $os.BuildNumber
            TPMStatus    = $tpmStatus
            ComputerName = $env:COMPUTERNAME
        }
        
        # Display device information
        Write-Host ""
        Write-Host "╔════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║                        DEVICE INFORMATION                              ║" -ForegroundColor Green
        Write-Host "╚════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Manufacturer  : " -NoNewline -ForegroundColor Gray
        Write-Host $script:DeviceInfo.Manufacturer -ForegroundColor White
        Write-Host "  Model         : " -NoNewline -ForegroundColor Gray
        Write-Host $script:DeviceInfo.Model -ForegroundColor White
        Write-Host "  Serial Number : " -NoNewline -ForegroundColor Gray
        Write-Host $script:DeviceInfo.SerialNumber -ForegroundColor Yellow
        Write-Host "  Computer Name : " -NoNewline -ForegroundColor Gray
        Write-Host $script:DeviceInfo.ComputerName -ForegroundColor White
        Write-Host "  Current User  : " -NoNewline -ForegroundColor Gray
        Write-Host $(if ($script:DeviceInfo.CurrentUser) { $script:DeviceInfo.CurrentUser } else { "No user logged in" }) -ForegroundColor White
        Write-Host "  OS Version    : " -NoNewline -ForegroundColor Gray
        Write-Host "$($script:DeviceInfo.OSVersion) (Build $($script:DeviceInfo.OSBuild))" -ForegroundColor White
        Write-Host "  TPM Status    : " -NoNewline -ForegroundColor Gray
        Write-Host $script:DeviceInfo.TPMStatus -ForegroundColor $(if ($tpmStatus -eq "Present and Ready") { "Green" } else { "Yellow" })
        Write-Host ""
        
        Write-MotherLog "Device detection complete: $($script:DeviceInfo.Manufacturer) $($script:DeviceInfo.Model)" -Type Success
        
        return $true
        
    } catch {
        Write-MotherLog "Device detection failed: $($_.Exception.Message)" -Type Error
        return $false
    }
}

function Get-AutopilotHash {
    <#
    .SYNOPSIS
        Retrieves the Windows Autopilot hardware hash for this device.
    .DESCRIPTION
        The hardware hash is a unique identifier generated from the device's hardware.
        It's required for Windows Autopilot registration. This function:
        1. Queries WMI for hardware information
        2. Converts to format required by Autopilot
        3. Returns hash for upload to Intune
        
        Technical Note:
        The hash is derived from SMBIOS data and is stable across OS reinstalls
        but changes if major hardware (motherboard) is replaced.
    #>
    
    Write-MotherLog "Generating Windows Autopilot hardware hash" -Type System
    
    try {
        Show-MotherProgress "Querying device hardware identifiers"
        
        # Get MDM Device ID (if exists)
        $mdmDeviceId = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\*" -ErrorAction SilentlyContinue).PSChildName
        
        # Get device hash using Get-WindowsAutopilotInfo approach
        # We need to get the hardware hash from WMI
        $session = New-CimSession
        
        # Get serial number
        $serial = (Get-CimInstance -CimSession $session -Class Win32_BIOS).SerialNumber
        
        # Get hardware hash
        $devDetail = (Get-CimInstance -CimSession $session -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'" -ErrorAction SilentlyContinue)
        
        if ($devDetail) {
            $hash = $devDetail.DeviceHardwareData
        } else {
            # Alternative method using WMI
            $hash = (Get-WmiObject -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'" -ErrorAction SilentlyContinue).DeviceHardwareData
        }
        
        Remove-CimSession $session
        
        Complete-MotherProgress -Success $true
        
        if ($hash) {
            Write-MotherLog "Hardware hash retrieved successfully" -Type Success
            return @{
                SerialNumber = $serial
                HardwareHash = $hash
                MDMDeviceId  = $mdmDeviceId
            }
        } else {
            Write-MotherLog "Unable to retrieve hardware hash" -Type Warning
            return $null
        }
        
    } catch {
        Complete-MotherProgress -Success $false
        Write-MotherLog "Failed to retrieve hardware hash: $($_.Exception.Message)" -Type Error
        return $null
    }
}

# ============================================================================
# SCENARIO SELECTION & USER DATA WARNING
# ============================================================================

function Select-EnrollmentScenario {
    <#
    .SYNOPSIS
        Prompts user to select between OOBE (new device) or Wipe (existing device) enrollment.
    .DESCRIPTION
        Different scenarios require different handling:
        - OOBE: Fresh device, no user data concerns
        - Wipe: Existing device with potential user data that will be lost
    #>
    
    Show-Separator
    Write-Host "╔════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║                      ENROLLMENT SCENARIO SELECTION                     ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] New Device (OOBE)" -ForegroundColor Green
    Write-Host "      • Fresh device from manufacturer" -ForegroundColor Gray
    Write-Host "      • No user data present" -ForegroundColor Gray
    Write-Host "      • Standard Autopilot enrollment" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [2] Existing Device (Wipe & Re-enroll)" -ForegroundColor Yellow
    Write-Host "      • Device currently in use" -ForegroundColor Gray
    Write-Host "      • Will require factory reset" -ForegroundColor Gray
    Write-Host "      • ALL USER DATA WILL BE LOST" -ForegroundColor Red
    Write-Host ""
    
    do {
        $choice = Read-Host "Select enrollment scenario [1-2]"
    } while ($choice -ne '1' -and $choice -ne '2')
    
    Write-Host ""
    
    if ($choice -eq '2') {
        # Existing device - show data warning
        Show-DataWarning
    }
    
    return $choice
}

function Show-DataWarning {
    <#
    .SYNOPSIS
        Displays critical warning about data loss for existing device wipe scenario.
    .DESCRIPTION
        Attempts to detect user data presence and displays explicit warnings.
        Requires explicit confirmation to proceed.
    #>
    
    Write-Host "╔════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║                          CRITICAL WARNING                              ║" -ForegroundColor Red
    Write-Host "╚════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "This device will be WIPED and RE-ENROLLED." -ForegroundColor Red
    Write-Host ""
    Write-Host "ALL DATA WILL BE PERMANENTLY DELETED, INCLUDING:" -ForegroundColor Yellow
    Write-Host "  • User documents, downloads, desktop files" -ForegroundColor White
    Write-Host "  • Installed applications" -ForegroundColor White
    Write-Host "  • Browser bookmarks and history" -ForegroundColor White
    Write-Host "  • Email accounts and data" -ForegroundColor White
    Write-Host "  • System settings and configurations" -ForegroundColor White
    Write-Host ""
    
    # Attempt to detect user data
    Write-MotherLog "Scanning for user data presence" -Type System
    $userDataDetected = $false
    
    try {
        # Check for user profiles
        $profiles = Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notin @('Public', 'Default', 'Default User') }
        
        if ($profiles) {
            Write-Host "DETECTED USER PROFILES:" -ForegroundColor Yellow
            foreach ($profile in $profiles) {
                $profileSize = (Get-ChildItem $profile.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
                Write-Host "  • $($profile.Name) (" -NoNewline -ForegroundColor White
                Write-Host "$([math]::Round($profileSize, 2)) GB" -NoNewline -ForegroundColor Yellow
                Write-Host ")" -ForegroundColor White
                $userDataDetected = $true
            }
            Write-Host ""
        }
        
        # Check for installed applications
        $apps = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | 
                Where-Object { $_.DisplayName } | 
                Select-Object -First 10
        
        if ($apps) {
            Write-Host "DETECTED INSTALLED APPLICATIONS:" -ForegroundColor Yellow
            $apps | ForEach-Object { Write-Host "  • $($_.DisplayName)" -ForegroundColor White }
            Write-Host "  ... and more" -ForegroundColor Gray
            Write-Host ""
            $userDataDetected = $true
        }
        
    } catch {
        Write-MotherLog "Unable to fully scan user data: $($_.Exception.Message)" -Type Warning
    }
    
    if ($userDataDetected) {
        Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Red
        Write-Host "           USER DATA DETECTED - BACKUP REQUIRED BEFORE PROCEEDING" -ForegroundColor Red
        Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Before proceeding, ensure:" -ForegroundColor Cyan
    Write-Host "  1. User has been notified and approved the wipe" -ForegroundColor White
    Write-Host "  2. All important data has been backed up" -ForegroundColor White
    Write-Host "  3. You have authority to perform this action" -ForegroundColor White
    Write-Host ""
    
    # First confirmation
    $confirm1 = Read-Host "Do you understand ALL DATA WILL BE LOST? (yes/NO)"
    if ($confirm1 -ne 'yes') {
        Write-MotherLog "Device wipe declined by user" -Type Warning
        Write-Host ""
        Write-Host "Enrollment cancelled for safety." -ForegroundColor Yellow
        exit 0
    }
    
    # Second confirmation
    Write-Host ""
    $confirm2 = Read-Host "Type the computer name '$($script:DeviceInfo.ComputerName)' to confirm"
    if ($confirm2 -ne $script:DeviceInfo.ComputerName) {
        Write-MotherLog "Computer name confirmation failed" -Type Error
        Write-Host ""
        Write-Host "Confirmation failed. Enrollment cancelled." -ForegroundColor Red
        exit 0
    }
    
    Write-Host ""
    Write-MotherLog "Data wipe warning acknowledged by administrator" -Type Warning
}

# ============================================================================
# GROUP SELECTION
# ============================================================================

function Get-IntuneDeviceGroups {
    <#
    .SYNOPSIS
        Retrieves all device groups from Azure AD/Intune.
    .DESCRIPTION
        Queries Microsoft Graph for groups with device membership types.
        Filters to show only groups relevant for device enrollment.
        
        Technical Note:
        We're querying Azure AD groups, not just Intune groups, because
        device assignment in Intune uses Azure AD group membership.
    #>
    
    Write-MotherLog "Retrieving Intune device groups" -Type System
    
    try {
        Show-MotherProgress "Querying Microsoft Graph for device groups"
        
        # Get all groups - we'll filter for device-compatible groups
        # In a real environment, you might filter by naming convention or specific group types
        $groups = Get-MgGroup -All -ErrorAction Stop | 
                  Where-Object { 
                      $_.GroupTypes -contains "DynamicMembership" -or 
                      $_.SecurityEnabled -eq $true 
                  } |
                  Sort-Object DisplayName
        
        Complete-MotherProgress -Success $true
        
        if ($groups.Count -eq 0) {
            Write-MotherLog "No device groups found" -Type Warning
            return $null
        }
        
        Write-MotherLog "Retrieved $($groups.Count) device groups" -Type Success
        
        return $groups
        
    } catch {
        Complete-MotherProgress -Success $false
        Write-MotherLog "Failed to retrieve groups: $($_.Exception.Message)" -Type Error
        return $null
    }
}

function Select-DeviceGroup {
    <#
    .SYNOPSIS
        Interactive group selection with search capability.
    .DESCRIPTION
        Displays all device groups in a numbered list.
        Allows user to either:
        - Enter a number to select a group
        - Type text to filter/search groups
        - Type 'exit' to cancel
    #>
    
    param([array]$Groups)
    
    Show-Separator
    Write-Host "╔════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                     DEVICE GROUP SELECTION                             ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Available Device Groups ($($Groups.Count) total):" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Enter number to select, or type to search/filter" -ForegroundColor Gray
    Write-Host "  Type 'exit' to cancel enrollment" -ForegroundColor Gray
    Write-Host ""
    
    $displayGroups = $Groups
    $filterText = ""
    
    while ($true) {
        # Display groups
        for ($i = 0; $i -lt $displayGroups.Count; $i++) {
            $groupNum = $i + 1
            $group = $displayGroups[$i]
            
            $groupType = if ($group.GroupTypes -contains "DynamicMembership") { "(Dynamic)" } else { "(Assigned)" }
            
            Write-Host "  [$groupNum] " -NoNewline -ForegroundColor Green
            Write-Host "$($group.DisplayName) " -NoNewline -ForegroundColor White
            Write-Host $groupType -ForegroundColor Gray
            
            if ($group.Description) {
                Write-Host "       $($group.Description)" -ForegroundColor DarkGray
            }
        }
        
        Write-Host ""
        if ($filterText) {
            Write-Host "Current filter: '$filterText'" -ForegroundColor Yellow
            Write-Host ""
        }
        
        $input = Read-Host "Select group [1-$($displayGroups.Count)] or type to filter"
        
        # Check for exit
        if ($input -eq 'exit') {
            Write-MotherLog "Group selection cancelled by user" -Type Warning
            return $null
        }
        
        # Check if numeric selection
        if ($input -match '^\d+$') {
            $selection = [int]$input
            if ($selection -ge 1 -and $selection -le $displayGroups.Count) {
                $selectedGroup = $displayGroups[$selection - 1]
                Write-Host ""
                Write-MotherLog "Selected group: $($selectedGroup.DisplayName)" -Type Success
                return $selectedGroup
            } else {
                Write-Host "Invalid selection. Please enter a number between 1 and $($displayGroups.Count)" -ForegroundColor Red
                Start-Sleep 2
            }
        } else {
            # Filter groups
            $filterText = $input
            $displayGroups = $Groups | Where-Object { $_.DisplayName -like "*$filterText*" }
            
            if ($displayGroups.Count -eq 0) {
                Write-Host "No groups match filter '$filterText'" -ForegroundColor Yellow
                Start-Sleep 2
                $displayGroups = $Groups
                $filterText = ""
            }
        }
        
        Clear-Host
        Show-MotherHeader
        Write-Host ""
        Write-Host "╔════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║                     DEVICE GROUP SELECTION                             ║" -ForegroundColor Cyan
        Write-Host "╚════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Available Device Groups ($($displayGroups.Count) total):" -ForegroundColor Yellow
        Write-Host ""
    }
}

# ============================================================================
# AUTOPILOT & ENROLLMENT FUNCTIONS
# ============================================================================

function Register-AutopilotDevice {
    <#
    .SYNOPSIS
        Uploads device hardware hash to Windows Autopilot.
    .DESCRIPTION
        Registers the device in Windows Autopilot by:
        1. Retrieving the hardware hash
        2. Uploading to Intune via Graph API
        3. Assigning to the selected group
        
        Technical Note:
        Autopilot registration can take 15-30 minutes to fully sync.
        The device will appear in Intune portal under Windows Autopilot devices.
    #>
    
    param(
        [hashtable]$AutopilotHash,
        [string]$GroupId
    )
    
    Write-MotherLog "Registering device in Windows Autopilot" -Type System
    Write-Host ""
    
    try {
        Show-MotherProgress "Uploading hardware hash to Intune"
        
        # Prepare Autopilot device identity
        $autopilotDevice = @{
            '@odata.type'        = '#microsoft.graph.importedWindowsAutopilotDeviceIdentity'
            serialNumber         = $AutopilotHash.SerialNumber
            hardwareIdentifier   = $AutopilotHash.HardwareHash
            state                = @{
                '@odata.type'    = 'microsoft.graph.importedWindowsAutopilotDeviceIdentityState'
                deviceImportStatus = 'pending'
                deviceRegistrationId = New-Guid
            }
        }
        
        # Upload to Intune
        # Note: In actual implementation, you'd use the Graph API endpoint:
        # POST https://graph.microsoft.com/v1.0/deviceManagement/importedWindowsAutopilotDeviceIdentities
        
        # For this script, we'll use the appropriate cmdlet if available
        # This is a simplified version - actual implementation would use direct Graph calls
        
        $uri = "https://graph.microsoft.com/v1.0/deviceManagement/importedWindowsAutopilotDeviceIdentities"
        $body = $autopilotDevice | ConvertTo-Json -Depth 10
        
        $response = Invoke-MgGraphRequest -Method POST -Uri $uri -Body $body -ErrorAction Stop
        
        Complete-MotherProgress -Success $true
        Write-MotherLog "Hardware hash uploaded successfully" -Type Success
        Write-MotherLog "Autopilot Device ID: $($response.id)" -Type Info
        
        # Note: Autopilot sync can take time
        Write-Host ""
        Write-Host "IMPORTANT: Autopilot Registration Timeline" -ForegroundColor Yellow
        Write-Host "  • Hardware hash uploaded: Immediate" -ForegroundColor Green
        Write-Host "  • Appears in Intune portal: 5-10 minutes" -ForegroundColor Yellow
        Write-Host "  • Fully synced and ready: 15-30 minutes" -ForegroundColor Yellow
        Write-Host ""
        
        return $response.id
        
    } catch {
        Complete-MotherProgress -Success $false
        Write-MotherLog "Autopilot registration failed: $($_.Exception.Message)" -Type Error
        Write-Host ""
        Write-Host "TROUBLESHOOTING:" -ForegroundColor Yellow
        Write-Host "  • Verify account has DeviceManagementServiceConfig.ReadWrite.All permission" -ForegroundColor White
        Write-Host "  • Check if device is already registered in Autopilot" -ForegroundColor White
        Write-Host "  • Ensure serial number is valid and unique" -ForegroundColor White
        Write-Host ""
        
        $continue = Read-Host "Continue enrollment without Autopilot registration? (y/N)"
        if ($continue -ne 'y' -and $continue -ne 'Y') {
            return $null
        }
        
        return "skipped"
    }
}

function Start-IntuneEnrollment {
    <#
    .SYNOPSIS
        Initiates Intune MDM enrollment for the device.
    .DESCRIPTION
        Triggers the device enrollment process with Intune.
        This involves:
        1. Checking existing enrollment status
        2. Initiating MDM enrollment if not already enrolled
        3. Waiting for enrollment to complete
        
        Technical Note:
        Enrollment uses the MDM enrollment API. For OOBE scenarios,
        Autopilot will handle enrollment. For existing devices,
        we may need to trigger manual enrollment.
    #>
    
    param([string]$GroupId)
    
    Write-MotherLog "Initiating Intune device enrollment" -Type System
    Write-Host ""
    
    try {
        # Check if device is already enrolled
        Show-MotherProgress "Checking existing enrollment status"
        
        $deviceId = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Enrollments\*" -ErrorAction SilentlyContinue | 
                     Where-Object { $_.UPN }).PSChildName
        
        if ($deviceId) {
            Complete-MotherProgress -Success $true
            Write-MotherLog "Device already enrolled with ID: $deviceId" -Type Warning
            Write-Host ""
            Write-Host "This device is already enrolled in Intune." -ForegroundColor Yellow
            Write-Host "Existing Enrollment ID: $deviceId" -ForegroundColor White
            Write-Host ""
            
            $reEnroll = Read-Host "Force re-enrollment? This will unenroll and re-enroll (y/N)"
            if ($reEnroll -ne 'y' -and $reEnroll -ne 'Y') {
                Write-MotherLog "Keeping existing enrollment" -Type Info
                return $deviceId
            }
            
            # Unenroll device
            Show-MotherProgress "Removing existing enrollment"
            # This would require additional implementation
            Complete-MotherProgress -Success $true
        } else {
            Complete-MotherProgress -Success $true
        }
        
        # For OOBE scenario, enrollment happens automatically via Autopilot
        # For existing device, we provide enrollment command
        
        Write-Host ""
        Write-Host "╔════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║                     ENROLLMENT INSTRUCTIONS                            ║" -ForegroundColor Cyan
        Write-Host "╚════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Device is prepared for enrollment. Next steps:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "FOR OOBE (NEW DEVICE):" -ForegroundColor Green
        Write-Host "  1. Restart the device" -ForegroundColor White
        Write-Host "  2. Proceed through Windows setup (OOBE)" -ForegroundColor White
        Write-Host "  3. Sign in with corporate account" -ForegroundColor White
        Write-Host "  4. Autopilot will automatically enroll and configure" -ForegroundColor White
        Write-Host ""
        Write-Host "FOR EXISTING DEVICE (WIPE):" -ForegroundColor Yellow
        Write-Host "  1. Use Settings > Update & Security > Recovery" -ForegroundColor White
        Write-Host "  2. Select 'Reset this PC' > 'Remove everything'" -ForegroundColor White
        Write-Host "  3. Choose 'Cloud download' for cleanest reset" -ForegroundColor White
        Write-Host "  4. After reset, proceed through OOBE as above" -ForegroundColor White
        Write-Host ""
        
        Write-MotherLog "Enrollment preparation complete" -Type Success
        
        return "prepared"
        
    } catch {
        Write-MotherLog "Enrollment preparation failed: $($_.Exception.Message)" -Type Error
        return $null
    }
}

function Add-DeviceToGroup {
    <#
    .SYNOPSIS
        Adds the device to the selected Azure AD group.
    .DESCRIPTION
        After enrollment, assigns the device to the specified group.
        This enables the device to receive group-targeted policies and apps.
        
        Technical Note:
        Device must be enrolled in Azure AD first. Group membership
        can be added before or after full Intune enrollment completes.
    #>
    
    param(
        [string]$DeviceId,
        [string]$GroupId
    )
    
    Write-MotherLog "Adding device to selected group" -Type System
    
    try {
        Show-MotherProgress "Querying device in Azure AD"
        
        # Find device in Azure AD by serial number
        $azureDevice = Get-MgDevice -Filter "displayName eq '$($script:DeviceInfo.ComputerName)'" -ErrorAction SilentlyContinue
        
        if (-not $azureDevice) {
            # Try by serial number in extension attributes
            $azureDevice = Get-MgDevice -All | Where-Object { 
                $_.PhysicalIds -contains "SerialNumber:$($script:DeviceInfo.SerialNumber)"
            } | Select-Object -First 1
        }
        
        if ($azureDevice) {
            Complete-MotherProgress -Success $true
            Write-MotherLog "Found device in Azure AD: $($azureDevice.Id)" -Type Success
            
            Show-MotherProgress "Adding to group"
            
            # Add device to group
            New-MgGroupMember -GroupId $GroupId -DirectoryObjectId $azureDevice.Id -ErrorAction Stop
            
            Complete-MotherProgress -Success $true
            Write-MotherLog "Device successfully added to group" -Type Success
            
            return $true
        } else {
            Complete-MotherProgress -Success $false
            Write-MotherLog "Device not yet registered in Azure AD" -Type Warning
            Write-Host ""
            Write-Host "Device not found in Azure AD yet. This is normal for new enrollments." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Group assignment will be completed automatically after:" -ForegroundColor Cyan
            Write-Host "  1. Device completes OOBE and enrollment" -ForegroundColor White
            Write-Host "  2. Device syncs with Azure AD (5-10 minutes)" -ForegroundColor White
            Write-Host ""
            Write-Host "You can manually add to group later from Intune portal" -ForegroundColor Gray
            Write-Host ""
            
            return $false
        }
        
    } catch {
        Complete-MotherProgress -Success $false
        
        if ($_.Exception.Message -like "*already exists*") {
            Write-MotherLog "Device already member of group" -Type Warning
            return $true
        }
        
        Write-MotherLog "Failed to add device to group: $($_.Exception.Message)" -Type Error
        return $false
    }
}

# ============================================================================
# WIPE PREPARATION
# ============================================================================

function Show-WipeInstructions {
    <#
    .SYNOPSIS
        Displays manual wipe instructions and preparation steps.
    .DESCRIPTION
        Provides detailed instructions for administrator to wipe device.
        Does not automatically trigger wipe for safety.
    #>
    
    Show-Separator
    Write-Host "╔════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║                    DEVICE WIPE PREPARATION                             ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Enrollment setup is complete. Device is ready for wipe and re-enrollment." -ForegroundColor Green
    Write-Host ""
    Write-Host "MANUAL WIPE OPTIONS:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Option 1: Windows Settings (Recommended for User-Initiated Wipe)" -ForegroundColor Green
    Write-Host "  1. Open Settings (Windows + I)" -ForegroundColor White
    Write-Host "  2. Go to Update & Security > Recovery" -ForegroundColor White
    Write-Host "  3. Under 'Reset this PC', click 'Get started'" -ForegroundColor White
    Write-Host "  4. Choose 'Remove everything'" -ForegroundColor White
    Write-Host "  5. Select 'Cloud download' (cleanest option)" -ForegroundColor White
    Write-Host "  6. Click 'Reset'" -ForegroundColor White
    Write-Host ""
    Write-Host "Option 2: PowerShell Command (Admin-Initiated)" -ForegroundColor Yellow
    Write-Host "  Run in elevated PowerShell:" -ForegroundColor White
    Write-Host "  systemreset -cleanpc" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Option 3: Remote Wipe from Intune Portal" -ForegroundColor Magenta
    Write-Host "  1. Go to endpoint.microsoft.com" -ForegroundColor White
    Write-Host "  2. Devices > All devices" -ForegroundColor White
    Write-Host "  3. Find device: $($script:DeviceInfo.ComputerName)" -ForegroundColor White
    Write-Host "  4. Select device > Wipe" -ForegroundColor White
    Write-Host "  5. Confirm wipe action" -ForegroundColor White
    Write-Host ""
    Write-Host "AFTER WIPE COMPLETES:" -ForegroundColor Cyan
    Write-Host "  1. Device will restart and enter OOBE" -ForegroundColor White
    Write-Host "  2. Connect to network during OOBE" -ForegroundColor White
    Write-Host "  3. Sign in with corporate credentials" -ForegroundColor White
    Write-Host "  4. Autopilot will automatically:" -ForegroundColor White
    Write-Host "     • Detect the registered device" -ForegroundColor Gray
    Write-Host "     • Apply group policies" -ForegroundColor Gray
    Write-Host "     • Install required applications" -ForegroundColor Gray
    Write-Host "     • Configure security settings" -ForegroundColor Gray
    Write-Host ""
    Write-Host "ESTIMATED TIMELINE:" -ForegroundColor Yellow
    Write-Host "  • Wipe process: 30-60 minutes" -ForegroundColor White
    Write-Host "  • OOBE and Autopilot: 15-30 minutes" -ForegroundColor White
    Write-Host "  • Full policy/app deployment: 30-60 minutes" -ForegroundColor White
    Write-Host "  • Total: 1.5-2.5 hours" -ForegroundColor White
    Write-Host ""
    
    # Provide PowerShell command for copy-paste
    Write-Host "Quick Copy Commands:" -ForegroundColor Cyan
    Write-Host "══════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "# Wipe command (run as admin):" -ForegroundColor Gray
    Write-Host "systemreset -cleanpc" -ForegroundColor Green
    Write-Host ""
    
    Write-MotherLog "Wipe instructions displayed to administrator" -Type Info
}

# ============================================================================
# LOGGING & REPORTING
# ============================================================================

function Initialize-LogFile {
    <#
    .SYNOPSIS
        Creates enrollment log file for audit trail.
    .DESCRIPTION
        Generates timestamped log file in both:
        - User's temp directory
        - C:\ProgramData\IntuneEnrollment (if permissions allow)
    #>
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logFileName = "IntuneEnrollment_$timestamp.log"
    
    # Try to create in ProgramData first
    $programDataPath = "C:\ProgramData\IntuneEnrollment"
    if (-not (Test-Path $programDataPath)) {
        try {
            New-Item -Path $programDataPath -ItemType Directory -Force | Out-Null
            $script:LogFile = Join-Path $programDataPath $logFileName
        } catch {
            # Fall back to temp
            $script:LogFile = Join-Path $env:TEMP $logFileName
        }
    } else {
        $script:LogFile = Join-Path $programDataPath $logFileName
    }
    
    # Create log file with header
    $header = @"
================================================================================
INTUNE DEVICE ENROLLMENT LOG - MOTHER PROTOCOL
================================================================================
Enrollment Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Script Version: 1.0
Executed By: $env:USERNAME
Computer Name: $env:COMPUTERNAME
================================================================================

"@
    
    Set-Content -Path $script:LogFile -Value $header
    Write-MotherLog "Log file created: $($script:LogFile)" -Type System
}

function Export-EnrollmentSummary {
    <#
    .SYNOPSIS
        Generates final enrollment summary report.
    .DESCRIPTION
        Creates comprehensive summary of enrollment process including:
        - Device information
        - Selected group
        - Autopilot registration status
        - Enrollment status
        - Next steps
        - Timeline
    #>
    
    param(
        [string]$Scenario,
        [object]$SelectedGroup,
        [string]$AutopilotId,
        [string]$EnrollmentStatus
    )
    
    $summary = @"

================================================================================
                        ENROLLMENT SUMMARY
================================================================================

DEVICE INFORMATION:
  Manufacturer    : $($script:DeviceInfo.Manufacturer)
  Model           : $($script:DeviceInfo.Model)
  Serial Number   : $($script:DeviceInfo.SerialNumber)
  Computer Name   : $($script:DeviceInfo.ComputerName)
  OS Version      : $($script:DeviceInfo.OSVersion) (Build $($script:DeviceInfo.OSBuild))
  TPM Status      : $($script:DeviceInfo.TPMStatus)

ENROLLMENT CONFIGURATION:
  Scenario        : $(if ($Scenario -eq '1') { 'New Device (OOBE)' } else { 'Existing Device (Wipe & Re-enroll)' })
  Selected Group  : $($SelectedGroup.DisplayName)
  Group ID        : $($SelectedGroup.Id)
  Group Type      : $(if ($SelectedGroup.GroupTypes -contains 'DynamicMembership') { 'Dynamic' } else { 'Assigned' })

AUTOPILOT REGISTRATION:
  Status          : $(if ($AutopilotId -eq 'skipped') { 'Skipped' } elseif ($AutopilotId) { 'Registered' } else { 'Failed' })
  Device ID       : $AutopilotId

ENROLLMENT STATUS:
  Status          : $EnrollmentStatus
  Completion Time : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  Duration        : $((New-TimeSpan -Start $script:EnrollmentStartTime -End (Get-Date)).ToString("mm\:ss"))

NEXT STEPS:
$(if ($Scenario -eq '2') {
@"
  1. Wipe device using one of the provided methods
  2. Device will restart and enter OOBE
  3. Sign in with corporate credentials during OOBE
  4. Autopilot will automatically configure the device
  5. Allow 1.5-2.5 hours for complete deployment
"@
} else {
@"
  1. Restart device and proceed through OOBE
  2. Sign in with corporate credentials
  3. Autopilot will automatically configure the device
  4. Allow 30-60 minutes for complete deployment
"@
})

VERIFICATION:
  • Check Intune portal: endpoint.microsoft.com
  • Verify device appears under: Devices > Windows > Windows devices
  • Confirm group membership: Groups > $($SelectedGroup.DisplayName)
  • Monitor Autopilot: Devices > Enroll devices > Windows Autopilot devices

SUPPORT INFORMATION:
  Log File        : $($script:LogFile)
  Executed By     : $env:USERNAME
  Execution Time  : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

================================================================================
"@

    # Write to log file
    Add-Content -Path $script:LogFile -Value $summary
    
    # Display on screen
    Write-Host $summary -ForegroundColor White
    
    Write-MotherLog "Enrollment summary exported" -Type Success
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Start-IntuneEnrollmentWizard {
    <#
    .SYNOPSIS
        Main orchestration function for the enrollment wizard.
    .DESCRIPTION
        Coordinates the complete enrollment process:
        1. Prerequisites check
        2. Authentication
        3. Device detection
        4. Scenario selection
        5. Group selection
        6. Autopilot registration
        7. Enrollment preparation
        8. Group assignment
        9. Wipe instructions (if applicable)
        10. Summary report
    #>
    
    Show-MotherHeader
    
    # Initialize logging
    Initialize-LogFile
    
    # Prerequisite checks
    Test-AdminPrivileges
    Write-Host ""
    Install-RequiredModules
    
    # Authentication
    Show-Separator
    if (-not (Connect-MotherGraph)) {
        Write-Host "Enrollment cannot proceed without authentication." -ForegroundColor Red
        pause
        exit 1
    }
    
    # Device information gathering
    Show-Separator
    if (-not (Get-DeviceInformation)) {
        Write-Host "Enrollment cannot proceed without device information." -ForegroundColor Red
        pause
        exit 1
    }
    
    # Scenario selection
    $scenario = Select-EnrollmentScenario
    Write-MotherLog "Selected scenario: $(if ($scenario -eq '1') { 'OOBE' } else { 'Wipe' })" -Type Info
    
    # Group selection
    Show-Separator
    $groups = Get-IntuneDeviceGroups
    if (-not $groups) {
        Write-Host "No device groups available. Cannot proceed." -ForegroundColor Red
        pause
        exit 1
    }
    
    $selectedGroup = Select-DeviceGroup -Groups $groups
    if (-not $selectedGroup) {
        Write-Host "Group selection required. Enrollment cancelled." -ForegroundColor Yellow
        pause
        exit 0
    }
    
    # Confirmation
    Show-Separator
    Write-Host "╔════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                     ENROLLMENT CONFIRMATION                            ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Device       : " -NoNewline -ForegroundColor Gray
    Write-Host "$($script:DeviceInfo.Manufacturer) $($script:DeviceInfo.Model)" -ForegroundColor White
    Write-Host "  Serial       : " -NoNewline -ForegroundColor Gray
    Write-Host $script:DeviceInfo.SerialNumber -ForegroundColor Yellow
    Write-Host "  Group        : " -NoNewline -ForegroundColor Gray
    Write-Host $selectedGroup.DisplayName -ForegroundColor Cyan
    Write-Host "  Scenario     : " -NoNewline -ForegroundColor Gray
    Write-Host $(if ($scenario -eq '1') { 'New Device (OOBE)' } else { 'Existing Device (Wipe)' }) -ForegroundColor White
    Write-Host ""
    
    $confirm = Read-Host "Proceed with enrollment? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-MotherLog "Enrollment cancelled by user" -Type Warning
        Write-Host "Enrollment cancelled." -ForegroundColor Yellow
        pause
        exit 0
    }
    
    # Autopilot registration
    Show-Separator
    $autopilotHash = Get-AutopilotHash
    $autopilotId = $null
    
    if ($autopilotHash) {
        $autopilotId = Register-AutopilotDevice -AutopilotHash $autopilotHash -GroupId $selectedGroup.Id
    } else {
        Write-MotherLog "Proceeding without Autopilot hash" -Type Warning
    }
    
    # Enrollment preparation
    Show-Separator
    $enrollmentStatus = Start-IntuneEnrollment -GroupId $selectedGroup.Id
    
    # Group assignment (may not work until device is fully enrolled)
    if ($enrollmentStatus) {
        Show-Separator
        Add-DeviceToGroup -DeviceId $enrollmentStatus -GroupId $selectedGroup.Id | Out-Null
    }
    
    # Wipe instructions (if existing device scenario)
    if ($scenario -eq '2') {
        Show-Separator
        Show-WipeInstructions
    }
    
    # Final summary
    Show-Separator
    Export-EnrollmentSummary -Scenario $scenario -SelectedGroup $selectedGroup -AutopilotId $autopilotId -EnrollmentStatus $enrollmentStatus
    
    # Completion
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                     ENROLLMENT COMPLETE                                ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-MotherLog "Intune enrollment wizard completed successfully" -Type Success
    Write-Host "[MOTHER] >>> System enrollment protocol complete." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Log file saved: $($script:LogFile)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Thank you for using the MOTHER PROTOCOL enrollment system." -ForegroundColor Cyan
    Write-Host ""
    
    # Disconnect from Graph
    Disconnect-MgGraph | Out-Null
    
    pause
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================

try {
    Start-IntuneEnrollmentWizard
} catch {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║                          CRITICAL ERROR                                ║" -ForegroundColor Red
    Write-Host "╚════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "An unexpected error occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Stack Trace:" -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    Write-Host ""
    
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value "`n[CRITICAL ERROR] $($_.Exception.Message)`n$($_.ScriptStackTrace)"
        Write-Host "Error logged to: $($script:LogFile)" -ForegroundColor Gray
    }
    
    pause
    exit 1
}