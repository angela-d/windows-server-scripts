# 1 = yes, incl physical queues
$physicalOnly = "1"
$deleteProblems = "0"
$smtpServer = "mail.example.com"
$smtpPort = "25"
$from = "noreply@example.com"
$to = "me@example.com"
$cc = "helpdesk@example.com"
# netbios name or tld
$printServer = "print"

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
      $jobDocument = $job.Document
      # strip the job id from the printer id: , 00
      $jobPrinter = $job.Name.Substring(0, $jobErrors.Name.IndexOf(','))
      # strip the ip: (00.00.00.00)
      $jobOwner = $jobErrors.Owner.Substring(0, $jobErrors.Owner.IndexOf('('))

      $body = "Document: $jobDocument`n Printer: $jobPrinter `n Print Owner: $jobOwner"

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
        Send-MailMessage -From $from -To $to -CC $cc -Subject $subject -Body "$messageBody:`n$body" -SmtpServer $smtpServer -port $smtpPort
        Write-Success "Email sent to $to"
      }
    }
}
