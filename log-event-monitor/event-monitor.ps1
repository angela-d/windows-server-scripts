## CONFIG
	$eventToCheck=5827,5828,5829,5830,5831,257,64
	$eventLog='System','Application'
	$from = "dc@example.com"
	$to = "you@example.com"
	$smtpServer = "yourserver.example.com"
	$smtpPort = "25"
	$authUser = "you@example.com"
	# filter to limit hours mailings are sent
	$sendHourStart = Get-Date '06:00'
	$sendHourEnd = Get-Date '13:00'
	# the following limits time between mailings in minutes; redundant if you have a decent schedule in task scheduler
	$emailThreshold = "0"
## END CONFIG

# for first run; create if doesn't exist.. powershell handles this backwards by default
# so it's easier to do this here
$lastCheck = "C:\Scripts\lastCheck.txt"
$fileExists = Test-Path $lastCheck
if ($fileExists -eq $False) {
  New-Item "C:\Scripts\lastCheck.txt" -ItemType File
}

# go back and search logs from 61 mins ago.. +1 just for weird offsets that may occur
$date = (Get-Date).AddMinutes(-61)

# get today's date to filter by weekday
$dayOfWeek = (Get-Date).DayOfWeek

# pull events i wish to be notified about
$Failure = Get-WinEvent -FilterHashTable @{
	LogName=$eventLog
		StartTime=$date;
		ID=$eventToCheck
} | select Id,TimeCreated,Message

# do a sanity check to ensure we didn't just get a notification, already
$lastCheck = gci "C:\Scripts\lastCheck.txt"
$lastNotification = [DateTime] $lastCheck.LastWriteTime
$timeNow = Get-Date
$timeSincelastCheck = ($timeNow - $lastNotification).TotalMinutes
$totalMatches = [int]$Failure.Count

# for cli debugging
Write-Host "$totalMatches matches"

# apply conditional filters
if ($totalMatches -And $dayOfWeek -notmatch "Saturday|Sunday" -And $timeNow -ge $sendHourStart -And $timeNow -le $sendHourEnd) {

  # if a threshold is set, obey it. this option is redundant if you use a decent schedule in task manager
  if ($timeSincelastCheck -gt $emailThreshold) {
    Write-Host "A match was found, an email will be sent"

    # keep record of this notification by creating a log file and also using it as a threshold
    Write-Output $timeNow "`r" | Out-File $lastCheck -Append string
    Write-Host "Last notification: $lastNotification"

	# email notification
	$Body = "Event $eventToCheck from $eventLog log has been spotted $lastNotification."
	Send-MailMessage -From $from -to $to -Subject "$env:computername - $totalMatches matches to Event Monitor" -Body ($Failure | Format-Table -auto -wrap | Out-String) -SmtpServer $smtpServer -port $smtpPort -Credential $authUser -UseSsl

  } else {
		Write-Host "A notification was sent recently, not sending another! Sent $timeSincelastCheck mins ago"
		Write-Host 'To adjust the threshold, modify the $emailThreshold variable.'
	}

} else {
	Write-Host "Everything is good"
	Write-Host "Last occurence: $timeSincelastCheck"
}
