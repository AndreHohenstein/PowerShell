#region

# Erstellt einen Alias für den FQDN "srv01.contoso.com", wird für die Speerprüfung miteels HTTP benötigt
Invoke-Command -ComputerName DC01 `
               -ScriptBlock {Add-DnsServerResourceRecordCName -ComputerName DC01 `
                                                              -Name "pki" `
                                                              -HostNameAlias "srv01.contoso.com" `
                                                              -ZoneName "contoso.com"}


#endregion

#region

# Zertifikat der Root-CA im AD veröffentlichen:
certutil.exe -f -dspublish "C:\cert\Root-CA.crt" RootCA

# Sperrliste der Root-CA im Ad veröffentlichen:
certutil.exe -f -dspublish "C:\Cert\Root-CA.crl" RootCA

gpupdate /force


# Ordner erstellen für Datenbank uind Logfiles:
$certlogpath = "C:\Certlog\"
if (!(test-path -path $certlogpath)) {new-item -path $certlogpath -itemtype directory}


# CAPolicy.inf erstellen und im Ordner c:\Windows ablegen

# Installation einer Windows Zertifizierungsstelle (CA):
$checkADCS = Get-WindowsFeature -Name 'ADCS-Cert-Authority','ADCS-Web-Enrollment'
if ($checkADCS.Installed -ne 'True') {
      #Install/Enable "ADCS-Cert-Authority"
      Install-WindowsFeature -Name $checkADCS.Name `
                             -IncludeManagementTools | Out-Null}


#Konfiguration der Sub-CA - 10 Jahre Gültigkeit mit jährlicher CRL überprüfung und Zertifikatsanforderung:
Install-AdcsCertificationAuthority -CAType EnterpriseSubordinateCA `
                                   -CACommonName "contoso-SubCA" `
                                   -CADistinguishedNameSuffix 'DC=CONTOSO,DC=COM' `
                                   -CryptoProviderName "ECDSA_P256#Microsoft Software Key Storage Provider" `
                                   -KeyLength 256 `
                                   -HashAlgorithmName SHA256 `
                                   -DatabaseDirectory C:\Certlog `
                                   -LogDirectory C:\Certlog `
                                   -AllowAdministratorInteraction `
                                   -OverwriteExistingKey `
                                   -OutputCertRequestFile C:\Cert\srv01.contoso.com.req `
                                   -Confirm:$false `
                                   -Force

#Web-Registrierungsstelle:
Install-AdcsWebEnrollment -Confirm:$false

#endregion

#region

# Zertifikatsanforderung-Datei zum Root-Ca kopieren und die Anforderung bestätigen srv1.contoso.com.req

###  Hier weitermachen nach die Zertifikatsdatei auf der Root-CA erstellt wurde. ###


# SubCA Zertifikat installieren (Warung darf ignoriert werden ;) 
Certutil -installCert "C:\cert\contoso-SubCA.crt"

# Dienst der CA starten ### Sollte es Probleme beim starten des Dienstes geben Workaround siehe unten
Start-Service CertSvc -Verbose -PassThru

#Configure the CDP Locations
# aktuelle Konfiguration Sperrlisten-Verteilungspunkt
Get-CACrlDistributionPoint | select uri

# Remove Existing CDP URIs
Get-CACrlDistributionPoint | ForEach-Object {Remove-CACrlDistributionPoint $_.uri -Force}

# Add New CDP URIs
Add-CACRLDistributionPoint -Uri "$($env:windir)\System32\CertSrv\CertEnroll\%3%8%9.crl" -PublishToServer -PublishDeltaToServer -Force
Add-CACRLDistributionPoint -Uri "ldap:///CN=%7%8,CN=%2,CN=CDP,CN=Public Key Services,CN=Services,%6%10" -AddToCertificateCdp -AddToFreshestCrl -AddToCrlCdp -PublishToServer -PublishDeltaToServer -Confirm:$false -Force
Add-CACRLDistributionPoint -Uri "http://pki.contoso.com/certenroll/%3%8%9.crl" -AddToCertificateCDP -AddToFreshestCrl -Force


#Configure the AIA Locations
# aktuelle Konfiguration Zugriff auf Stelleninformationen
Get-CAAuthorityInformationAccess

# Remove Existing AIA URIs
Get-CAAuthorityInformationAccess | ForEach-Object {Remove-CAAuthorityInformationAccess $_.uri -Force}

# Add New AIA URIs
Certutil -setreg CA\CACertPublicationURLs "1:C:\Windows\System32\CertSrv\CertEnroll\%3%4.crt"
Add-CAAuthorityInformationAccess -Uri "ldap:///CN=%7,CN=AIA,CN=Public Key Services,CN=Services,%6%11" -AddToCertificateAia -Confirm:$false -Force
Add-CAAuthorityInformationAccess -AddToCertificateAia -uri "http://pki.contoso.com/certenroll/%3%4.crt" -Force


# Maximale Gültigkeit für ausgestelle Zertifikate einstellen:
certutil -setreg ca\ValidityPeriodUnits 5
certutil -setreg ca\ValidityPeriod "Years"

# Definiert die Überlappungsperiode, die für die CRL Publikation gedacht ist. CRL Overlap:
Certutil -setreg CA\CRLOverlapPeriodUnits 12
Certutil -setreg CA\CRLOverlapPeriod "Hours"

# CA Überwachung aktivieren:
certutil -setreg CA\AuditFilter 127

Restart-Service certsvc -Verbose -PassThru


# Umbenennen der SUB-CA Zertifikats:
$DefaultCert = Get-ChildItem -Path $env:windir\System32\CertSrv\CertEnroll -Filter '*.crt'
$NewName = Join-Path $DefaultCert.PSParentPath ($DefaultCert.Name -replace '^[^_]*_', '')
Copy-Item -Path $DefaultCert.FullName -Destination $NewName
Remove-Item $DefaultCert.FullName

# Root-CA Stammzertifizierungsstellen-Zertifikat und Sperrliste in den richtigen Pfad
$CRT = "C:\cert\Root-CA.crt"
$CRL = "C:\Cert\Root-CA.crl"
Copy-Item $CRT C:\Windows\System32\certsrv\CertEnroll
Copy-Item $CRL C:\Windows\System32\certsrv\CertEnroll

# Neue Sperrliste veröffentlichen:
Certutil -crl

gpupdate /force

#endregion