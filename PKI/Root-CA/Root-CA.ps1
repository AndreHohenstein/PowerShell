#region
# BEGIN ROOT CA
# Ordner erstellen für Datenbank und Logfiles:
$certlogpath = "C:\Certlog\"
if (!(test-path -path $certlogpath)) {new-item -path $certlogpath -itemtype directory}

# CAPolicy.inf erstellen und im Ordner c:\Windows ablegen

# Installation einer Windows Zertifizierungsstelle (CA):
$checkADCS = Get-WindowsFeature -Name 'ADCS-Cert-Authority'
if ($checkADCS.Installed -ne 'True') {
      #Install/Enable "ADCS-Cert-Authority"
      Install-WindowsFeature -Name $checkADCS.Name `
                             -IncludeManagementTools | Out-Null}


#Konfiguration der Root-CA (15 Jahre Gültigkeit mit halbjährlicher CRL-Überprüfung:
Install-AdcsCertificationAuthority -CAType StandaloneRootCA `
                                   -CACommonName Root-CA `
                                   -CADistinguishedNameSuffix 'DC=CONTOSO,DC=COM' `
                                   -CryptoProviderName "ECDSA_P256#Microsoft Software Key Storage Provider" `
                                   -KeyLength 256 `
                                   -HashAlgorithmName SHA256 `
                                   -AllowAdministratorInteraction `
                                   -ValidityPeriod Years `
                                   -ValidityPeriodUnits 15 `
                                   -DatabaseDirectory C:\Certlog `
                                   -LogDirectory C:\Certlog `
                                   -Force


# Configure the CA
# Register Naming Context (Forestroot contoso.com)
Certutil -setreg CA\DSConfigDN 'CN=Configuration,DC=contoso,DC=com'

# Maximale Gültigkeit für ausgestelle Zertifikate einstellen:
#Configure Max Validity Period of Certificates Issued by this CA
Certutil -setreg ca\ValidityPeriodUnits '10'
Certutil -setreg ca\ValidityPeriod 'Years'

# The Following 2 Set the CRL Delta publication period. For offline Root CA's, this should be 0 to disable
Certutil -setreg CA\CRLDeltaPeriodUnits '0'
Certutil -setreg CA\CRLDeltaPeriod 'Hours'

# Zertifikatsperrlisten- und Deltazertifikatsperrlisten-Überschneidungszeitraum
Certutil -setreg CA\CRLOverlapPeriodUnits '12'
Certutil -setreg CA\CRLOverlapPeriod 'Hours'

# CA Überwachung aktivieren:
Certutil -setreg CA\AuditFilter '127'

# Review the CA Configuration
Certutil -CAInfo

# Displays the enrollment policy Certificate Authorities.
Certutil -getreg ca

# Review the Database and Log Locations
Certutil -getreg

#Configure the CDP Locations
# aktuelle Konfiguration Sperrlisten-Verteilungspunkt
Get-CACrlDistributionPoint | select uri

# Remove Existing CDP URIs
Get-CACrlDistributionPoint | ForEach-Object {Remove-CACrlDistributionPoint $_.uri -Force}

# Konfiguration Sperrlisten-Verteilungspunkt (CDP) anpassen
# Add New CDP URIs
Add-CACRLDistributionPoint -Uri "$($env:windir)\System32\CertSrv\CertEnroll\%3%8%9.crl" -PublishToServer -Force
Add-CACRLDistributionPoint -Uri "ldap:///CN=%7%8,CN=%2,CN=CDP,CN=Public Key Services,CN=Services,%6%10" -AddToCrlCdp -AddToCertificateCdp -Force
Add-CACRLDistributionPoint -Uri "http://pki.contoso.com/certenroll/%3%8%9.crl" -AddToCertificateCDP -AddToFreshestCrl -Force

### Hinweis: geht auch ohne Angaben von numerischen Variablen
# Add-CACRLDistributionPoint -Uri  "$env:SystemDrive\CRL\<CaName><CRLNameSuffix><DeltaCRLAllowed>.crl" -PublishToServer
# Add-CACRLDistributionPoint -Uri "ldap:///CN=<CATruncatedName><CRLNameSuffix>,CN=<ServerShortName>,CN=CDP,CN=Public Key Services,CN=Services,<ConfigurationContainer><CDPObjectClass>" -AddToCertificateCdp -AddToCrlCdp
# Add-CACRLDistributionPoint -Uri "http://pki.contoso.com/CRL/<CAName><CRLNameSuffix><DeltaCRLAllowed>.crl" -AddToCertificateCdp


#Configure the AIA Locations
# aktuelle Konfiguration Zugriff auf Stelleninformationen
Get-CAAuthorityInformationAccess | select uri

# Remove Existing AIA URIs
Get-CAAuthorityInformationAccess | ForEach-Object {Remove-CAAuthorityInformationAccess $_.uri -Force}

# Add New AIA URIs
Certutil -setreg CA\CACertPublicationURLs '1:C:\Windows\System32\CertSrv\CertEnroll\%3%4.crt'
Add-CAAuthorityInformationAccess -AddToCertificateAia -uri "http://pki.contoso.com/certenroll/%3%4.crt" -Force
Add-CAAuthorityInformationAccess -AddToCertificateAia -uri "ldap:///CN=%7,CN=AIA,CN=Public Key Services,CN=Services,%6%11" -Force

### Hinweis: geht auch ohne Angaben von numerischen Variablen
# Add-CAAuthorityInformationAccess -Uri "http://pki.contoso.com/certenroll/<ServerDNSName>_<CaName><CertificateName>.crt" -AddToCertificateAia


Restart-Service certsvc -Verbose -PassThru
Start-Sleep -Seconds 20

# Neue Sperrliste veröffentlichen:
Certutil -crl

#endregion

#region
# Ordner für Datenaustausch:
$ExportFolder = "C:\Cert\"
if (!(test-path -path $ExportFolder)) {new-item -path $ExportFolder -itemtype directory}


# Kopiert das Root-CA Zertifikat und Sperrliste in den Ordner "C:\Cert":
$DefaultCert = Get-ChildItem -Path $env:windir\System32\CertSrv\CertEnroll -Filter '*.crt'
$NewName = Join-Path $ExportFolder ($DefaultCert.Name -replace '^[^_]*_', '')

Copy-Item -Path $DefaultCert.FullName -Destination $NewName
Get-ChildItem -Path $env:windir\System32\CertSrv\CertEnroll -Filter '*.crl' | Copy-Item -Destination $ExportFolder
explorer.exe $ExportFolder

# END ROOT CA

# Den Ordner "c:\cert" zur Sub-CA kopieren.

#endregion


#region
### Hier erst weitermachen beim ausstellen der Zertifikatsanforderung ###

# Zertifikatsanforderung an die Root-CA:
certreq -submit "C:\cert\srv01.contoso.com.req"

# Zertifikat ausstellen
certutil -resubmit 2

# Zertifikatsdatei erstellen
certreq -Retrieve 2 "C:\cert\contoso-SubCA.crt"
#Zertifikatsdatei zur Sub-CA kopieren

#endregion