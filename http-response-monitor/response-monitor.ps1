# CONFIG
	# To should be a single address
	$To = "primary@example.com"
	# enter any additional recipients, separated by a comma
	$Bcc = "other@example.com,other2@example.com"
	$From = "noreply@example.com"
	$SMTPServer = "yourmail.example.com"
	$SMTPPort = "25"
	$authUser = "domain\user"
	# portion of the url after computername
	$tld = ".example.com"
	# anything after the https://example.com portion of the desired url
	$urlSuffix = "/page_to_monitor"
	# C:\Scripts must already exist; log-attachments gets created & removed from this script, as needed
	# DO NOT leave blank!
	$logsToAttach = "C:\Scripts\log-attachments\"
# END CONFIG

# for first run; create if doesn't exist.. powershell handles this backwards by default
# so it's easier to do this here
$LastReboot = "C:\Scripts\lastReboot.txt"
$FileExists = Test-Path $LastReboot
if ($FileExists -eq $False) {
  New-Item "C:\Scripts\lastReboot.txt" -ItemType File
}

# build the url
$url = 'https://'
$url += "$env:computername"
$url += $tld
$url += $urlSuffix

# powershell defaults to unsupported tls, so enforce tls1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# get the http response
# -UseBasicParsing is required for headless calls; w/out it, it uses IE's engine.. (?!)
$response = (Invoke-WebRequest -Uri $url -UseBasicParsing).statuscode

# return the http response to a cli run for debugging
Write-Host $response

# do a sanity check to ensure we didn't just reboot, already
$LastReboot = gci "C:\Scripts\lastReboot.txt"
$RebootTime = [DateTime] $LastReboot.LastWriteTime
$TimeNow = Get-Date
$TimeSinceLastReboot = ($TimeNow - $RebootTime).TotalMinutes


if ($response -ne '200') {
	# create the temp folder for the logs
	if (!(Test-Path $logsToAttach)) {
		New-Item $logsToAttach -ItemType Directory
	}

	# generate logs to attach
	# last 10 simultaneous log entries from application, security & system logs
	"Application","Security","System" | ForEach-Object {
	   Get-Eventlog -Newest 10 -LogName $_ | select -ExpandProperty message
	} | Out-File -FilePath C:\Scripts\log-attachments\eventviewer.txt

	# last 30 of http error log
	Get-Content -Path C:\Windows\System32\LogFiles\HTTPERR\httperr1.log -Tail 30 | Out-File -FilePath C:\Scripts\log-attachments\httperr.txt

	# add any custom logs here

  # let's make sure it hasn't 'been more than 59 minutes since the last reboot to avoid bootloops
  if ($TimeSinceLastReboot -gt '59') {
    Write-Host "Reboot requested"

    # keep record of this reboot by creating a log file and also using it as a threshold
    Write-Output $TimeNow "`r" | Out-File $LastReboot -Append string

    msg * Server will be reboot momentarily
		# delay between message being sent and the reboot occuring, in seconds
    sleep 2
    Restart-Computer -force

    Write-Host $RebootTime
    Write-Host "Non-200 response detected"

  	# email notification to multiple people, as specified in $Bcc var
  	forEach($sendTo in $Bcc) {
  		$logPath = (dir $logsToAttach*.txt).FullName
			$Subject = "$env:computername $response response"
			$Body = "Issues on $url detected with $response http response; a reboot was requested.  Find log excerpts attached."
  		Send-MailMessage -Attachments $logPath -From $From -To $To -Bcc ($Bcc -split ',') -Subject $Subject -Body $Body -SmtpServer $SMTPServer -port $SMTPPort -Credential $authUser -UseSsl
  	}

		# cleanup the logs that were attached to the email
		Remove-Item $logsToAttach -Recurse
	}
} else {
  Write-Host "Everything is good"
  Write-Host "Last reboot triggered by this script, was: $TimeSinceLastReboot mins ago"
}
