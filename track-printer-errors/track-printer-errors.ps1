# 1 = yes, incl physical queues
$physicalOnly   = "1"
$deleteProblems = "0"
$smtpServer     = "mail.example.com"
$smtpPort       = "25"
$from           = "noreply@example.com"
$to             = "me@example.com"
$cc             = "helpdesk@example.com"
# netbios name or tld
$printServer    = "print"

# zendesk credentials
$useZendesk    = "1"
$zendeskUser   = "youragent@example.com/token" # user must be verified to use the zendesk api
$zendeskPass   = "bFDkj35897Fllk3j5lsdkgj0FSJK3250CLMs453a"
# zendesk author (numeric) for updates to existing tickets, ie: https://[example].zendesk.com/agent/#/users/000012345678
$zendeskAuthor = "000012345678"
$prtgName      = "PRTG"
$prtgEmail     = "prtg@example.com"
$zendeskURI    = "https://example.zendesk.com"
$debug         = 0 # set to 1 if you want to save a log file to the location referenced in $logPath
$logPath       = "C:\Users\youruser\Desktop\log.txt"


# call the zendesk api
function Call-ZenDesk($Api, $Method, $zendeskBody) {

  if ($useZendesk -eq 1) {
    # by default, powershell seems to want to use insecure/deprecated tls, the following fixes that
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-RestMethod -Method $Method -Uri "$($zendeskURI)$($Api)" -Headers $AuthHeader -Body $zendeskBody
  } else {
    Write-Warning "Set useZendesk variable to 1 in order to use the Zendesk option."
  }
}

# cli output
if ($physicalOnly -eq 0) {
    Write-Warning "You are returning searches for virtual queues only.  Standby.."
} else {
    Write-Warning "You are returning searches for both physical & virtual queues.  Standby.."
}


if ($physicalOnly -eq 1) {

    Write-Information "Searching through physical + virtual queues..."
    # only collect errors from physical queues
    $printerErr = Get-WMIObject win32_printer  -computername $printServer  | Select Name, PrinterState, PrinterStatus

} else {

    Write-Information "Searching through virtual queues only..."
    # collect errors from both virtual & physical queues
    $printerErr = Get-WMIObject win32_printer  -computername $printServer | Where-Object { $_.Name -notlike "*Physical" } | Select Name, PrinterState, PrinterStatus
    Write-Warning "Excluding Physical PLZ"
}

foreach ($printer in $printerErr) {

    $printerPrefix = $printer.Name
    Write-Host "Printer: $printerPrefix"

    # see if queue is offline
    if ($printerState -eq "128") {
      $subject               = "$printerPrefix is OFFLINE"
      $body                  = "$printerPrefix is returning Printer State: $printerState"
      Write-Warning $subject
      $sendOfflineQueueEmail = "1"
      # zendesk ticket body
      $zendeskTicketSubject = "$printerPrefix Printer Issue"
      $Message              = "$printerPrefix queues are in an offline/error state, please restart the printer."

      # if you want to log something other than the $Message var, simply replace the references in the conditional code block
      if ($debug -eq 1 -AND (Test-Path $logPath)) {

        Write-Output $Message | Out-File $logPath -Append

      } elseif ($debug -eq 1 -AND !(Test-Path $logPath)) {

        New-Item $logPath -ItemType file
        # redundant, but add-content was goobering up with unnecessary spaces between letters
        Write-Output $Message | Out-File $logPath -Append

      }
    }

    if ($physicalOnly -eq 1) {

      # physical printer searches only
      # isolate the problematic print on the printer with error status
      $jobErrors = Get-WMIObject -class Win32_PrintJob -computername $printServer | Where-Object { ($_.Status -eq "Error") -and ($_.Name -eq "$printerPrefix") }

    } else {

      # both physical & virtual queues
      $excludePhysical = $printerPrefix + '_Physical'

      # isolate the problematic print on the printer with error status
      # we wildcard the printer here, because the job id is affixed, otherwise
      $jobErrors = Get-WMIObject -class Win32_PrintJob -computername $printServer | Where-Object { ($_.Name -like "$printerPrefix*") }

    }


    # queue name
    $printerName   = $printer.Name
    $printerState  = $printer.PrinterState
    $printerStatus = $printer.PrinterStatus
    Write-Host "Queue Name: $printerName`nPrinter State: $printerState`nPrinter Status: $printerStatus `n`n"

    # nuke problematic prints
    foreach ($job in $jobErrors) {
      $sendNotification = "1"
      $jobDocument      = $job.Document
      # strip the job id from the printer id: , 00
      $jobPrinter       = $job.Name.Substring(0, $jobErrors.Name.IndexOf(','))
      # strip the ip: (00.00.00.00)
      $jobOwner         = $jobErrors.Owner.Substring(0, $jobErrors.Owner.IndexOf('('))
      $body             = "Document: $jobDocument`n Printer: $jobPrinter `n Print Owner: $jobOwner"

      # cli output
      Write-Host $body
      Write-Host "End $jobOwner's $jobDocument print job`n`n" -ForegroundColor DarkBlue -BackgroundColor white

      if ($deleteProblems -eq 1) {
        $job.Delete
        Write-Host "Deleted job; double-check to verify it's gone"
        $messageBody = "The following job was deleted and should be verified to ensure it's gone"
      } else {
        $messageBody = "The following job is in an error state and needs to be manually checked"
      }

      # email notification
      if ($sendNotifcation -eq 1) {
        $subject = "$jobDocument Printing Error by $jobOwner"
        Send-MailMessage -From $from -To $to -CC $cc -Subject $subject -Body "The following job is in an error state and needs to be manually checked:`n$body" -SmtpServer $smtpServer -port $smtpPort
        Write-Host "Email sent to $to and $cc"
      }
    }
}

if ($sendOfflineQueueEmail -eq 1) {

  Send-MailMessage -From $from -To $to -CC $cc -Subject $subject -Body "$body" -SmtpServer $smtpServer -port $smtpPort
  Write-Host "Email sent to $to and $cc"

  if ($useZendesk -eq 1) {
    # open a zendesk ticket for printers in offline state
    $AuthHeader = @{

      "Content-Type"  = "application/json";
      "Authorization" = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($zendeskUser):$($zendeskPass)"))

    }

    # find existing tickets, if any
    $Transaction = @{

      query = "subject:$printerPrefix offline<solved tags:printer-offline";

    }

    $SearchResults = Call-ZenDesk '/api/v2/search.json' Get $Transaction
    Write-Host "Search results count: $($SearchResults.count)"

    # Update existing ticket or create new
    if ($SearchResults.count -gt 0) {

      # there is at least one open ticket for this device tagged with PRTG
      $Ticket = $SearchResults.results.Item(0)
      Write-Host "Found a ticket! Updating ticket #$($Ticket.id)"

      $Transaction = @{
        ticket = @{
          comment = @{
            public    = $false;
            body      = $zendeskCommentBody;
            author_id = $zendeskAuthor;
          }
        }
      }

      $zendeskBody = ConvertTo-Json($Transaction)
      Call-ZenDesk "/api/v2/tickets/$($Ticket.id).json" Put $zendeskBody

  } elseif ($zendeskCommentBody -notlike '*OK*') {

    # no ticket found, create one; to add additional tags, separate by a comma
    $Tags        = "printer-offline,$zendeskTicketSubject"
    $zendeskCommentBody = "$Message"

    $Transaction = @{
      ticket = @{
      requester = @{
        name  = "$prtgName";
        email = "$prtgEmail"
      };
      subject  = "$zendeskTicketSubject";
      type     = "Incident";
      priority = "Normal";
      comment = @{
        public = $false;
        body   = "$zendeskCommentBody";
      };

      tags = "$Tags.Split(',')"
      }
    }

    $zendeskBody = ConvertTo-Json $Transaction

    Call-ZenDesk "/api/v2/tickets.json" Post $zendeskBody
    Write-Host "Opened a Zendesk ticket: $zendeskCommentBody"
    }
  }
}

exit 0
