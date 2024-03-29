# Erstellt einen neuen lokalen Benutzer und fuegt ihn zur Gruppe der Administratoren hinzu.
# Alle weiteren Schritte bitte mit dem neuen Account durchfuehren.
$Password  = Read-Host -Prompt "Enter your Password" -AsSecureString
$UserName  = Read-Host -Prompt "Enter your Login Name"
$FullNmame = Read-Host -Prompt "Enter yout FullName"
New-LocalUser $UserName -Password $Password -FullName $FullNmame -Description "new loacal Admin" -PasswordNeverExpires
Add-LocalGroupMember -Group "Administratoren" -Member $UserName

Start-Sleep -Seconds 1

$NIC = (Get-NetAdapter | Where-Object {$_.Status -eq "Up"}).InterfaceAlias 
 New-NetIPAddress -InterfaceAlias $Nic `
                  -IPAddress 192.168.1.99 `
                  -PrefixLength 24 `
                  -DefaultGateway 192.168.1.1 | Out-Null
Set-DnsClientServerAddress -InterfaceAlias $Nic -ServerAddresses 192.168.1.101 | Out-Null
Rename-Computer -NewName RootCA -Restart
