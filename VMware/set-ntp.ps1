########################################################################################################
# Sets NTP servers so that your ESXi hosts use valid and redundant time sources
########################################################################################################

# Pull in vars
$vars = (Get-Item $PSScriptRoot).Parent.FullName + "\vars.ps1"
Invoke-Expression ($vars)

### Import modules
Add-PSSnapin -Name VMware.VimAutomation.Core

    # Ignore self-signed SSL certificates for vCenter Server (optional)
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -DisplayDeprecationWarnings:$false -Scope User -Confirm:$false

### Connect to vCenter
Connect-VIServer $global:vc
	
### Gather ESXi host data for future processing
$VMHosts = Get-VMHost

### Update NTP server info on the ESXi hosts in $vmhosts
$i = 1
foreach ($Server in $VMHosts)
	{
	# Everyone loves progress bars, so here is a progress bar
	Write-Progress -Activity "Configuring NTP Settings" -Status $Server -PercentComplete (($i / $VMHosts.Count) * 100)
		
	# Determine existing ntp config
	$NTPold = $Server | Get-VMHostNtpServer
		
	# Check to see if an NTP entry exists; if so, delete the value(s)
	If ($NTPold) {$Server | Remove-VMHostNtpServer -NtpServer $NTPold -Confirm:$false}
		
	# Add desired NTP value to the host
	Add-VmHostNtpServer -VMHost $Server -NtpServer $global:esxntp | Out-Null
		
	# Enable the NTP Client and restart the service
	$ntpclient = Get-VMHostService -VMHost $Server | where{$_.Key -match "ntpd"}
	Write-Host -BackgroundColor:Black -ForegroundColor:Yellow "Status: Configuring NTPd on $Server ..."
	$ntpclient | Set-VMHostService -Policy:On -Confirm:$false -ErrorAction:Stop | Out-Null
	Write-Host -BackgroundColor:Black -ForegroundColor:Yellow "Status: Restarting NTPd on $Server ..."
	$ntpclient | Restart-VMHostService -Confirm:$false -ErrorAction:Stop | Out-Null

	# Output to console (optional)
	Write-Host -BackgroundColor:Black -ForegroundColor:Green "Success: $Server is now using NTP server(s)" (Get-VMHostNtpServer -VMHost $server)

	$i++
	}

Disconnect-VIServer -Confirm:$false