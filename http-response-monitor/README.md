# Response Monitor for Windows Server
If you have an http server running on Windows behaving erratically, digging through Windows logs can be tedious and tend to be quite time consuming.

Let the machine *report to you* when things get messy.

## This Script Does the Following
- Probes the specified URL for an http response, as frequently as you prefer via task scheduler
- When anything other than a 200/OK response is detected, (assuming this script is running locally, on the http-serving machine) it will collect the most recent logs; separate them in individual .txt files and email them to you, and any subordinates specified
- Logic to prevent boot loops if you have a re-occurring issue that isn't fixed after a preceding reboot
- Sends a message to all logged-in users the server is about to reboot (modify this by changing the following):
```powershell
msg * Server will be reboot momentarily
# delay between message being sent and the reboot occuring, in seconds
sleep 2
```

**Default Logs Collected**

- Event viewer logs: Application, Security, System (compiled to one .txt log)
- IIS logs (if you don't use, comment the line or remove it)
- Add any additional log paths you wish to monitor

Each log is tailed for the most current 10-30 lines, if you wish to extend or reduce, simply modify the `-Newest 10 ` and `-Tail 30` accordingly

### Setup
1. Put **response-monitor.ps1** in `C:\Scripts` - if it doesn't exist, create it
2. Open **response-monitor.ps1** and modify everything inbetween `## CONFIG` and `## END CONFIG`
3. Set up a task schedule

### Setting Up a Task Schedule
Using the Windows Task Scheduler GUI.

This script can be customized to run under a particular user, if you have your environment already set up with isolated permissions for executing these types of scripts; assign the launch user accordingly.  If you do *not* have such a user set up, run as `SYSTEM` (you should fully analyze and understand any code you allow to run with such high privileges!)

- On the target machine, open *Task Scheduler*
- Create a Task (right pane)


- **General tab:**
  - Name: `Response Monitor`
  - Description: `Monitor http response code and send logs as well as trigger a reboot for non-200 responses.`
  - When running the task, use the following user account: click **Change User or Group** > ensure **From this location:** is set to your local machine (not an AD domain) > type `SYSTEM` under the *Enter the object name to select* > click OK
  - [x] Run with highest privileges
  - Configure for: `Windows Server 2016`


- **Triggers tab:**
  - Click **New**
  - [x] Daily
  - Recur every `1` days
  - Repeat task every: `5 minutes` (or your preferred duration - don't do too frequent or Powershell information logs will bloat/write excessively)
  - for a duration of: `Indefinitely`
  - [x] Enabled


- **Actions tab:**
  - Click **New**
  - Program/script: `powershell`
  - Add arguments: `C:\Scripts\response-monitor.ps1` (adjust path accordingly, if you put it elsewhere)


- **Conditions tab:**
  - Uncheck all


- **Settings tab:**
  - Tick all & set preferred durations; leave *If the task is not scheduled to run again, delete it after* **blank/unchecked**

## Additional Customization
If you have other logs you want to collect, aside from defaults, simply add them under:
```powershell
# add any custom logs here
```

like so:
```powershell
  # last 30 of filemaker event log"
	Get-Content -Path "C:\Program Files\FileMaker\FileMaker Server\Logs\Event.log" -Tail 30 | Out-File -FilePath C:\Scripts\log-attachments\filemaker-event.txt
```

Customize path to suit & add as many as you find useful.

### Why Not Do a Service Restart?
Why restart the whole server?  You can go ahead, if you happen to know the cause of your particular bug.

This script was thrown together because it's an unknown to both the developer and sysadmin where the crash stems from.  At the time of writing, it does not self-heal and tends to require a number of service restarts, so (at the moment) it saves time doing a full system reboot.  

This script at least frees up some time from sifting through the horrific Windows logs on path to isolating the cause.
