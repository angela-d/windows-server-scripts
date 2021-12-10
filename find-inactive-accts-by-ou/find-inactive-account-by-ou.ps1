# CONFIG
  $targetOU   = "OU=Incoming,OU=Staff,OU=People,DC=example,DC=com"
	# To should be a single address
	$To         = "you@example.com"
	# enter any additional recipients, separated by a comma
	$From       = "noreply@example.com"
	$SMTPServer = "mail.example.com"
	$SMTPPort   = "25"
# END CONFIG


if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Write-Warning "The whenCreated attribute will be BLANK when running this script without administrator privileges."
  Write-Warning "Invoke Powershell as administrator and run again."
  exit
}

# pull accounts older than 120 days
$checkAccounts = (Get-ADUser -Filter * -Properties Name, EmailAddress, Description, whenCreated, lastLogon, lastLogonTimestamp -SearchBase $targetOU  |
	Where-Object { $_.whenCreated -lt (Get-Date).AddDays(-120) })

# get a count of records, so empty emails don't get sent
$totalAccounts = [int]$checkAccounts.Count
$subject = "$totalAccounts inactive accounts currently enabled"

# send an email if there's more than 1 record
if ($totalAccounts -gt 0) {
  # display for the terminal
  $Body = $checkAccounts | Format-List Name, UserPrincipalName, Description, DistinguishedName, @{Name="lastLogon";Expression={[datetime]::FromFileTime($_.'lastLogon')}}, @{Name="lastLogonTimestamp";Expression={[datetime]::FromFileTime($_.'lastLogonTimestamp')}}, whenCreated | Out-String
  Write-Host $Body

  # email notification
  $Subject = "$subject"
  Send-MailMessage -From $From -To $To -Subject $Subject -Body "The following accounts are more than 120 days old.`n$Body" -SmtpServer $SMTPServer -port $SMTPPort
  Write-Host "Email sent to $To"

  # additional logic here if you want to do something other than receive notifications
}
Write-Host $subject
exit
