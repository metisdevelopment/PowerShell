$registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" # Path for the registry key to be deployed
$Al = "TaskbarAl" # Align this name with your documentation for easy tracing
$value = "0" # Aligns the taskbar to the left in the DWORD registry key
New-ItemProperty -Path $registryPath -Name $Al -Value $value -PropertyType DWORD -Force -ErrorAction Ignore
