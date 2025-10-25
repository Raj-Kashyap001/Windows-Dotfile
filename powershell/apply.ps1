# Replace Content in file of  Microsoft.PowerShell_profile.ps1 with main.ps1
Get-Content .\powershell\main.ps1 | Set-Content $PROFILE