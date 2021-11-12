# Import IIS Management PowerShell Module

$IISPath = "C:\inetpub\wwwroot\{{ProjectName}}"
try {
    if ((get-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole).state -eq "disabled")
    {
    # cd C:\Windows\system32
    # Install-WindowsFeature -name Web-Server -IncludeManagementTools
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-CommonHttpFeatures
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpErrors
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpRedirect
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ApplicationDevelopment
    Enable-WindowsOptionalFeature -online -FeatureName NetFx4Extended-ASPNET45
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-NetFxExtensibility45
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-HealthAndDiagnostics
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpLogging
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-LoggingLibraries
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-RequestMonitor
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpTracing
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-Security
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-RequestFiltering
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-Performance
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerManagementTools
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-IIS6ManagementCompatibility
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-Metabase
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ManagementConsole
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-BasicAuthentication
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WindowsAuthentication
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-StaticContent
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-DefaultDocument
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebSockets
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ApplicationInit
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ISAPIExtensions
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ISAPIFilter
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpCompressionStatic
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET45
    }
    import-module webadministration

}
catch {
    Write-Host $LASTEXITCODE
    exit $LASTEXITCODE
}
try {
    Write-Host "Check for existing sites"
    if (get-iissite -name "Default Web Site")
    {
    Stop-IISSite -Name "Default Web Site" -Confirm:$false
    ## Remove default website so that we don't have bind conflicts.
    Remove-iissite -Name "Default Web Site" -Confirm:$false 
    }

    if (-NOT (get-iissite -name "{{ProjectName}}") )
    {
    New-IISSite -Name "{{ProjectName}}" -BindingInformation "*:80:" -PhysicalPath "C:\inetpub\wwwroot\{{ProjectName}}" -Force
    New-IISSiteBinding -Name "{{ProjectName}}" -BindingInformation "*:443:" -CertificateThumbPrint $certThumbprint.Thumbprint -CertStoreLocation "Cert:\LocalMachine\My" -Protocol https
    New-WebBinding -Name {{ProjectName}} -IPAddress "*" -Protocol "http" -Port 80 -HostHeader $hostHeader
    get-iissite "{{ProjectName}}"
    }
}
catch {
    Write-Host $LASTEXITCODE
}
$Installerfile = "rewrite_amd64_en-US.msi"
$ssrspath = "C:\installers\"




if ( -not (Test-Path ($ssrspath + $Installerfile) -PathType Leaf))
{
    Write-Host "Installing rewrite modules"
    try {
        
        $S3InstallerFile = "windows/rewrite_amd64_en-US.msi"
        $Installer = Join-Path $ssrspath $Installerfile
        $installerbucket = "{{azdot-s3-installers-bucket}}" # to be dynamic in a CFT via parameter, this should be { "Ref": "pInstallationBucketName"},
        $s3ArgList = "-BucketName '$installerbucket' -key '$S3InstallerFile' -LocalFile '$Installer' -Region 'us-west-2' "
        powershell copy-s3object $s3ArgList
        Start-Process msiexec.exe -Wait -ArgumentList '/I C:\installers\rewrite_amd64_en-US.msi /quiet'
    }
    catch {
        Write-Host $LASTEXITCODE
        exit $LASTEXITCODE
    }
}
    # The name specified would be the name of the web site you’d like to add the binding to.  
    # The protocol and port are standard for SSL bindings. The host header is the URL you’d like the web site to respond to.  
    # Finally, SslFlags with a value of 1 enables SNI for this binding.
try {
    Write-Host "Downloading and installing certificates"
    $LocalFile = 'C:\programdata\amazon\{{ProjectName}}.pfx'
    #download certificate from s3 bucket
    $S3Bucket = "{{azdot-s3-cert-bucket}}"
    $ssmp = (Get-SSMParameter -Name "{{SSMCERTPARAM}}/password" -WithDecryption $True).Value 
    copy-s3object -BucketName $S3Bucket -Key $FileName -Region us-west-2 -LocalFile $LocalFile
    $Encrypted = ConvertTo-SecureString $ssmp -AsPlainText -Force
    Import-PfxCertificate -FilePath $LocalFile -CertStoreLocation Cert:\LocalMachine\My -Password $Encrypted
    $thumbprints = Get-ChildItem -path cert:\LocalMachine\My
    $certThumbprint = $thumbprints[0]

    ## If there is an existing folder move it to the backup folder
    Move-Item -Path $IISPath -Destination C:\inetpub\backup -Force
}
catch {
    Write-Host $LASTEXITCODE
    
}

try {
    Write-Host "Copying files and updating webconfig connection strings"
    $ssmp = (Get-SSMParameter -Name {{SSM_PASSWORD_KEY}} -WithDecryption $True).Value 
    $ssmu = (Get-SSMParameter -Name {{SSM_USERNAME_KEY}} -WithDecryption $True).Value 
    Write-Output $ssmu
    dir C:\inetpub\wwwroot
    Move-Item -Path C:\inetpub\temp\{{ProjectName}}\  -Destination $IISPath -Force


    $DBConnectionString = "Server={{SQL_SERVER}};Database={{DATABASE_NAME}};User Id=$ssmu;Password=$ssmp;"
    $f = "C:\inetpub\wwwroot\{{ProjectName}}\web.config"
    (Get-Content $f -Raw).Replace("{{'{{DATABASE_NAME}}'}}", $DBConnectionString) | Set-Content $f
    set-webconfiguration //WindowsAuthentication -metadata overrideMode -value Allow
    set-webconfiguration //AnonymousAuthentication -metadata overrideMode -value Allow
    Stop-IISSite -Name "{{ProjectName}}" -Confirm:$false
    Start-IISSite -Name "{{ProjectName}}"
    iisreset /restart
}
catch {
    Write-Host $LASTEXITCODE
    exit $LASTEXITCODE
}