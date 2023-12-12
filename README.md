Unfortunately there is no built in configuration policy to adjust the alignment of Windows 11 taskbar. So we need to use PowerShell for this adjustment. In the first step, we will create a PowerShell script using the Registry settings to change the Windows 11 taskbar to the left. In the second step, we will upload this file to Intune and configure the parameters. This allows us to achieve a smooth installation on the clients.

Step 1

How to align Windows 11 taskbar left with Microsoft Intune. First we need to create a PowerShell script. We are going to edit a Registry key. Just follow these steps:

Create a PowerShell script (below)

Save this PowerShell script. I named it TaskbarAllignLeft.ps1

Script;

  $registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
  
  $Al = "TaskbarAl" # Shift Start Menu Left
  
  $value = "0"
  
  New-ItemProperty -Path $registryPath -Name $Al -Value $value -PropertyType DWORD -Force -ErrorAction Ignore

This creates a registry key, specifying it as a DWORD. a binary won't work. 

The $registryPath is the location specifically within the registry. 

The $AL will determine the name of our new DWORD registry key.

And the $value will ensure it’s set to 0.

Everything afterwards in our script will determine the creation, file structure and the enforcement. 

Step 2

Importing the script via Intune via the following steps;

Go to endpoint.microsoft.com > Devices > Windows > Scripts > Platform Scripts (Top Bar) > Add 

Give your new policy a name - 'Align Taskbar Left' and fill your description for documentation, click next 



Script name and description for documentation

Upload your script and ensure the following are as below; 



Script settings for execution upon install

Run this script using the logged on credentials : Yes

Enforce script signature check : No

Run script in 64 bit PowerShell Host : Yes

Step 3



Assigning the script to a group

Pick your device groups, all users or all devices. Which ever you prefer. I set my policies to groupings which dynamically change. If you have this as a baseline, assign it to your over arching group such as %company_name%_Users_Windows. If it’s to be a user preference, create a specified group for people. 

Enforce your policy by syncing your devices. A shut down and startup of the device should also prompt the change (A restart doesn't always prompt the sync to take effect).
