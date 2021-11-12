# Import IIS Management PowerShell Module

$IISPath = "C:\inetpub\wwwroot\{{ProjectName}}"
if ((get-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole).state -eq "Enabled")
{
  iisreset /stop
  import-module webadministration

  if (get-iissite -name "Default Web Site")
    {
      Remove-iissite -Name "Default Web Site" -Confirm:$false 
    }

  if ((get-iissite -name "{{ProjectName}}") )
    {
      Remove-iissite -Name "{{ProjectName}}" -Confirm:$false
    }
}