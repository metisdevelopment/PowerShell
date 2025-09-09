🖥️ PowerShell Commands for Endpoint Administration
🔧 System Information & Diagnostics



PowerShell
Get-ComputerInfo

Retrieves detailed information about the computer system including OS, BIOS, CPU, and more.




PowerShell
Get-EventLog -LogName System -Newest 50

Displays the 50 most recent entries from the System event log.




PowerShell
Get-Process

Lists all running processes on the local machine.




PowerShell
Get-Service

Lists all services and their statuses (Running, Stopped, etc.).




PowerShell
Test-Connection -ComputerName google.com -Count 4

Sends 4 ICMP echo requests to test network connectivity (like ping).

🧹 System Maintenance



PowerShell
Clear-RecycleBin -Force

Empties the recycle bin without prompting for confirmation.




PowerShell
Get-WinEvent -LogName Application | Where-Object {$_.LevelDisplayName -eq "Error"}

Filters application event logs to show only errors.




PowerShell
Restart-Computer -Force

Forces a restart of the local computer.

📁 File & Folder Management



PowerShell
Get-ChildItem -Path "C:\Users" -Recurse

Lists all files and folders under C:\Users, including subdirectories.




PowerShell
Copy-Item -Path "C:\source.txt" -Destination "D:\backup\source.txt"

Copies a file from one location to another.




PowerShell
Remove-Item -Path "C:\temp\oldfile.txt" -Force

Deletes a file or folder forcefully.

👥 User & Group Management



PowerShell
Get-LocalUser

Lists all local user accounts.




PowerShell
New-LocalUser -Name "TestUser" -Password (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force) -FullName "Test User" -Description "Temporary account"

Creates a new local user account.




PowerShell
Add-LocalGroupMember -Group "Administrators" -Member "TestUser"

Adds a user to the local Administrators group.

🔐 Security & Updates



PowerShell
Get-BitLockerVolume

Displays BitLocker encryption status for all drives.




PowerShell
Get-WindowsUpdate

(Requires PSWindowsUpdate module) Lists available Windows updates.




PowerShell
Install-WindowsUpdate -AcceptAll -AutoReboot

Installs all available updates and reboots automatically (requires PSWindowsUpdate).

🌐 Network Configuration



PowerShell
Get-NetIPAddress

Shows IP address configuration for all network adapters.




PowerShell
Get-NetAdapter

Lists all network adapters and their status.




PowerShell
Get-DnsClientServerAddress

Displays DNS server addresses for all interfaces.

📦 Software Management



PowerShell
Get-Package

Lists installed software packages.




PowerShell
Uninstall-Package -Name "AppName"

Uninstalls a specified application (requires provider support).




PowerShell
Get-AppxPackage | Select Name, PackageFullName

Lists installed Windows Store apps.

🧪 Useful One-Liners



PowerShell
Get-Process | Sort-Object CPU -Descending | Select-Object -First 5

Shows top 5 CPU-consuming processes.




PowerShell
Get-ChildItem -Path "C:\Logs" -Recurse | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-30)} | Remove-Item -Force

Deletes log files older than 30 days.

Would you like me to export this as a .md file for your GitHub repo? Or add more advanced commands like remote management, WMI queries, or registry edits?



You said:

Could you expand please. Queries for removing apps as well so I can just put in the app name
Copilot said:
Copilot
Great idea, Tom! Here's an expanded Markdown list including PowerShell commands for app management, especially for removing apps by name—ideal for endpoint cleanup and automation.

🧼 PowerShell App Management & Removal
🗂️ List Installed Applications



PowerShell
Get-WmiObject -Class Win32_Product | Select-Object Name, Version

Lists installed MSI-based applications. ⚠️ Note: This can trigger a consistency check and is slow.




PowerShell
Get-Package | Select-Object Name, Version

Lists installed packages via PowerShell package providers (e.g., MSI, Chocolatey, etc.).




PowerShell
Get-AppxPackage | Select Name, PackageFullName

Lists installed Microsoft Store apps for the current user.

❌ Remove Installed Applications
🔹 Remove MSI-Based Apps (Traditional Desktop Apps)



PowerShell
$AppName = "AppNameHere"
Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*$AppName*" } | ForEach-Object { $_.Uninstall() }

Uninstalls MSI-based apps matching the name. Replace "AppNameHere" with part or full name of the app.

🔹 Remove Microsoft Store Apps (Appx)



PowerShell
$AppName = "AppNameHere"
Get-AppxPackage -Name $AppName | Remove-AppxPackage

Removes a specific Microsoft Store app by its exact name.




PowerShell
Get-AppxPackage | Where-Object { $_.Name -like "*AppNameHere*" } | Remove-AppxPackage

Removes Store apps using partial name match.

🔹 Remove App for All Users



PowerShell
Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*AppNameHere*" } | Remove-AppxPackage

Removes the app for all users on the system.

🧪 Example: Remove Microsoft Teams



PowerShell
Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Teams*" } | ForEach-Object { $_.Uninstall() }

🧪 Example: Remove Xbox App (Store App)



PowerShell
Get-AppxPackage | Where-Object { $_.Name -like "*Xbox*" } | Remove-AppxPackage

🛡️ Optional: Check if App Exists Before Removing



PowerShell
$AppName = "AppNameHere"
$app = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*$AppName*" }
if ($app) {
    $app.Uninstall()
} else {
    Write-Host "App not found."
}

