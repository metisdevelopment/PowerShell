
![Logo](https://metissolutions.co.uk/wp-content/uploads/2023/11/Metis-Logo-600-No-background-6x2-1.png)


# Windows DeBloat

In this article I will show you how to Debloat Windows 11 to Improve Performance, and deploy a DeBloat script via PowerShell. At the bottom, it also has a reference table with all of the applications you can add to the list to be removed when Windows OOBE has been initiated in Intune or the script has been run independently.

This is something I usually deploy via Intune for customers that are going through the OOBE. As soon as the device has been signed into for the first time, this script will run and delete everything that's listed in the table below. As the list grows, I just update my Script in Intune.




## Tutorial

Here is the link to tutorial on my Knowledgebase. If you have any recomendations/anyting you want to add, let me know and I'll update both this and the knowledgebase.

[Knowledgebase](https://metissolutions.co.uk/?post_type=knowledgebase&p=3517)


## Features

- Strip down unwanted applications including Manufacturer bloatware
- Decrease Cyber Attack vectors
- Remove unwanted Applications from a professional perspective

## Application List

| Application         | Application ID |
|--------------|--------------|
|Microsoft Get Started|Microsoft.Getstarted|
|Microsoft Get Help|Microsoft.GetHelp|
|Microsoft 3D viewer|Microsoft.Microsoft3DViewer|
|Microsoft Office Hub|Microsoft.MicrosoftOfficeHub|
|Microsoft Solitaire Collection|Microsoft.MicrosoftSolitaireCollection|
|Mixed Reality Portal|Microsoft.MixedReality.Portal|
|Office One Note|Microsoft.Office.OneNote|
|One Connect|Microsoft.OneConnect|
|Skype|Microsoft.SkypeApp|
|Feedback Hub|Microsoft.WindowsFeedbackHub|
|Xbox|Microsoft.Xbox.TCUI|
|Xbox|Microsoft.GamingApp_8wekyb3d8bbwe|
|Xbox App|HubMicrosoft.XboxApp|
|Xbox Game Overlay|Microsoft.XboxApp|
|Xbox Gaming Overlay|Microsoft.XboxGameOverlay|
|Xbox Identity Provider|Microsoft.XboxIdentityProvider|
|Xbox Speech to Text Overlay|Microsoft.XboxGamingOverlay|