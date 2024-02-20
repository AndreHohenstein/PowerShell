# Add Online Responder Services role and management snap-in
$checkADCSOnline = Get-WindowsFeature -Name 'ADCS-Online-Cert'
if ($checkADCSOnline.Installed -ne 'True') {
      #Install/Enable "ADCS-Cert-Authority"
      Install-WindowsFeature -Name $checkADCSOnline.Name `
                             -IncludeManagementTools | Out-Null}

# Install and configure the Online Responder Services role
Install-AdcsOnlineResponder -Confirm:$false -Force

# Configure the AIA Locations
# Configures the OCSP for a certification authority.
Add-CAAuthorityInformationAccess -Uri 'http://pki.contoso.com/ocsp' -AddToCertificateOcsp -Confirm:$false -Force

# Restart the certificate services so the changes can take affect
Restart-Service CertSvc -Verbose -PassThru