#Requires -Version 3.0

[CmdletBinding()]

Param (
    [string]$SubjectName = $env:COMPUTERNAME,
    [int]$CertValidityDays = 1095,
    [switch]$SkipNetworkProfileCheck
    )

Function New-LegacySelfSignedCert
{
    Param (
        [string]$SubjectName,
        [int]$ValidDays = 1095
    )

    $hostnonFQDN = $env:computerName
    $hostFQDN = [System.Net.Dns]::GetHostByName(($env:computerName)).Hostname
    $SignatureAlgorithm = "SHA256"

    $name = New-Object -COM "X509Enrollment.CX500DistinguishedName.1"
    $name.Encode("CN=$SubjectName", 0)

    $key = New-Object -COM "X509Enrollment.CX509PrivateKey.1"
    $key.ProviderName = "Microsoft Enhanced RSA and AES Cryptographic Provider"
    $key.KeySpec = 1
    $key.Length = 4096
    $key.SecurityDescriptor = "D:PAI(A;;0xd01f01ff;;;SY)(A;;0xd01f01ff;;;BA)(A;;0x80120089;;;NS)"
    $key.MachineContext = 1
    $key.Create()

    $serverauthoid = New-Object -COM "X509Enrollment.CObjectId.1"
    $serverauthoid.InitializeFromValue("1.3.6.1.5.5.7.3.1")
    $ekuoids = New-Object -COM "X509Enrollment.CObjectIds.1"
    $ekuoids.Add($serverauthoid)
    $ekuext = New-Object -COM "X509Enrollment.CX509ExtensionEnhancedKeyUsage.1"
    $ekuext.InitializeEncode($ekuoids)

    $cert = New-Object -COM "X509Enrollment.CX509CertificateRequestCertificate.1"
    $cert.InitializeFromPrivateKey(2, $key, "")
    $cert.Subject = $name
    $cert.Issuer = $cert.Subject
    $cert.NotBefore = (Get-Date).AddDays(-1)
    $cert.NotAfter = $cert.NotBefore.AddDays($ValidDays)

    $SigOID = New-Object -ComObject X509Enrollment.CObjectId
    $SigOID.InitializeFromValue(([Security.Cryptography.Oid]$SignatureAlgorithm).Value)

    [string[]] $AlternativeName  += $hostnonFQDN
    $AlternativeName += $hostFQDN
    $IAlternativeNames = New-Object -ComObject X509Enrollment.CAlternativeNames

    foreach ($AN in $AlternativeName)
    {
        $AltName = New-Object -ComObject X509Enrollment.CAlternativeName
        $AltName.InitializeFromString(0x3,$AN)
        $IAlternativeNames.Add($AltName)
    }

    $SubjectAlternativeName = New-Object -ComObject X509Enrollment.CX509ExtensionAlternativeNames
    $SubjectAlternativeName.InitializeEncode($IAlternativeNames)

    [String[]]$KeyUsage = ("DigitalSignature", "KeyEncipherment")
    $KeyUsageObj = New-Object -ComObject X509Enrollment.CX509ExtensionKeyUsage
    $KeyUsageObj.InitializeEncode([int][Security.Cryptography.X509Certificates.X509KeyUsageFlags]($KeyUsage))
    $KeyUsageObj.Critical = $true

    $cert.X509Extensions.Add($KeyUsageObj)
    $cert.X509Extensions.Add($ekuext)
    $cert.SignatureInformation.HashAlgorithm = $SigOID
    $CERT.X509Extensions.Add($SubjectAlternativeName)
    $cert.Encode()

    $enrollment = New-Object -COM "X509Enrollment.CX509Enrollment.1"
    $enrollment.InitializeFromRequest($cert)
    $certdata = $enrollment.CreateRequest(0)
    $enrollment.InstallResponse(2, $certdata, 0, "")

    $parsed_cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $parsed_cert.Import([System.Text.Encoding]::UTF8.GetBytes($certdata))

    return $parsed_cert.Thumbprint
}

Trap
{
    $_
    Exit 1
}
$ErrorActionPreference = "Stop"

Set-Service -Name "WinRM" -StartupType Automatic
Start-Service -Name "WinRM" -ErrorAction Stop
Enable-PSRemoting -Force -ErrorAction Stop

$token_path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$token_prop_name = "LocalAccountTokenFilterPolicy"
$token_key = Get-Item -Path $token_path
$token_value = $token_key.GetValue($token_prop_name, $null)
if ($token_value -ne 1) {
    if ($null -ne $token_value) {
        Remove-ItemProperty -Path $token_path -Name $token_prop_name
    }
    New-ItemProperty -Path $token_path -Name $token_prop_name -Value 1 -PropertyType DWORD > $null
}

$thumbprint = New-LegacySelfSignedCert -SubjectName $SubjectName -ValidDays $CertValidityDays

$valueset = @{
    CertificateThumbprint = $thumbprint
    Hostname = $SubjectName
}

$selectorset = @{
    Address = "*"
    Transport = "HTTPS"
}
Remove-WSManInstance -ResourceURI 'winrm/config/Listener' -SelectorSet $selectorset

New-WSManInstance -ResourceURI 'winrm/config/Listener' -SelectorSet $selectorset -ValueSet $valueset

$basicAuthSetting = Get-ChildItem WSMan:\localhost\Service\Auth | Where-Object {$_.Name -eq "Basic"}


$fwtest1 = netsh advfirewall firewall show rule name="Allow WinRM HTTPS"
$fwtest2 = netsh advfirewall firewall show rule name="Allow WinRM HTTPS" profile=any
If ($fwtest1.count -lt 5)
{
    netsh advfirewall firewall add rule profile=any name="Allow WinRM HTTPS" dir=in localport=5986 protocol=TCP action=allow
}
ElseIf (($fwtest1.count -ge 5) -and ($fwtest2.count -lt 5))
{
    netsh advfirewall firewall set rule name="Allow WinRM HTTPS" new profile=any
}

$httpResult = Invoke-Command -ComputerName "localhost" -ScriptBlock {$env:COMPUTERNAME} -ErrorVariable httpError -ErrorAction SilentlyContinue
$httpsOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
$httpsResult = New-PSSession -UseSSL -ComputerName "localhost" -SessionOption $httpsOptions -ErrorVariable httpsError -ErrorAction SilentlyContinue

$disks = Get-Disk | Where partitionstyle -eq 'raw' | sort number
$letters = 70..89 | ForEach-Object { [char]$_ }
$count = 0
$labels = "data1","data2","data3"
foreach ($disk in $disks) {
    $driveLetter = $letters[$count].ToString()
    $disk | 
    Initialize-Disk -PartitionStyle MBR -PassThru |
    New-Partition -UseMaximumSize -DriveLetter $driveLetter |
    Format-Volume -FileSystem NTFS -NewFileSystemLabel $labels[$count] -Confirm:$false -Force
$count++
}

