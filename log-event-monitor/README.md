# Windows Server Event Monitor
Because it seems like nearly every update, Windows Server has a security patch you "should monitor event XX before setting this registry key for the patch to take full effect."

Let Windows monitor for this junk, instead.

## What Event Monitor Does
This super simple script allows you set (multiple) event IDs of interest, designate what logs to inspect and it will email you each time it finds an event that matches your criteria, along with a full copy of the event message.

- **Subject:** DC3 - 2 matches to Event Monitor
- **Message body:**

```text
Id TimeCreated           Message                                             
-- -----------           -------                                             
5827 9/10/2020 10:14:37 AM The Netlogon service denied a vulnerable Netlogon   
                         secure channel connection from a machine account.   

                          Machine SamAccountName: MAC-example                 
                          Domain: example.com.                                 
                          Account Type: Domain Member                       
                          Machine Operating System: OS X                     
                          Machine Operating System Build: 6.1:10.16         
                          Machine Operating System Service Pack: N/A         

                         For more information about why this was denied,     
                         please visit                                       
                         https://go.microsoft.com/fwlink/?linkid=2133485.   
5827 9/10/2020 10:14:37 AM The Netlogon service denied a vulnerable Netlogon   
                         secure channel connection from a machine account.   

                          Machine SamAccountName: MAC-example                 
                          Domain: example.com.                                 
                          Account Type: Domain Member                       
                          Machine Operating System: OS X                     
                          Machine Operating System Build: 6.1:10.16         
                          Machine Operating System Service Pack: N/A         

                         For more information about why this was denied,     
                         please visit                                       
                         https://go.microsoft.com/fwlink/?linkid=2133485.    
```
(example messages - event ID 5829 is what prompted this script to be assembled.)

## Setup
1. On the target machine, create `C:\Scripts` if it doesn't already exist
2. Place `event-monitor.ps1` into `C:\Scripts`
3. Open `event-monitor.ps1` and modify the variables inbetween `## CONFIG` and `## END CONFIG` to suit
4. Open Task Scheduler on the target machine and import `Event Monitor.xml` - adjust any options to suit (or, manually create the task) -- if this file opens jumbled, set your text editor to encoding `UTF-16 LE`
5. Test it

## Customizing
- Separate multiple event IDs of interest in the `$eventToCheck` variable *by comma, only*
- Separate the logs by single quotes and commas, only:
```powershell
$eventLog='System','Application' # if the appropriate log isn't listed here, but the ID is listed in $eventToCheck, it won't be seen!
```

- `$sendHourStart` & `$sendHourEnd` designate the time of day you'll receive these notifications (if matches are found).  By default, Saturday and Sunday are 'off days' - you can modify this by adjusting the following to suit:
```powershell
 -notmatch "Saturday|Sunday" # excludes sending on Saturdays OR Sundays
```
- If you prefer to set a limit on notification frequency (outside of the task scheduler default of 1 hour), you can specify a minute duration between each notification, in addition to the task scheduler frequency:
```powershell
$emailThreshold = "0" # change 0 to 5, for 5 mins
```

- By default, the script crawls back 61 minutes, if you want to extend or reduce it (though keep in mind what you set for the task schedule frequency), you can do so at:
```powershell
$date = (Get-Date).AddMinutes(-61)
```
