<#
Purpose-
To monitor Process start time and to send email

Developer - K.Janarthanan
Date - 24/4/2021
#>

[CmdletBinding()]
param (
    [String]
    $ConfigFile="E:\Upwork\Upwork_Process_Monitor\Config.json"
)

$Global:LogFile = "$PSScriptRoot\Process_Monitor.log"

function Write-Log
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Validateset("INFO","ERR","WARN")]
        [string]$Type="INFO"
    )

    if(-not(Test-Path -path $LogFile.Replace($LogFile.split("\")[-1],"")))
    {
        New-Item -Path $LogFile.Replace($LogFile.split("\")[-1],"") -ItemType "directory" -Force
    }

    $DateTime = Get-Date -Format "MM-dd-yyyy HH:mm:ss"
    $FinalMessage = "[{0}]::[{1}]::[{2}]" -f $DateTime,$Type,$Message

    $FinalMessage | Out-File -FilePath $LogFile -Append
}

try 
{
    Write-Log "Script started"

    $Config = Get-Content -Path $ConfigFile -ErrorAction Stop | ConvertFrom-Json
    $EmailMessage = @()

    foreach($Process in $Config.Process)
    {
        try 
        {
            Write-Log "Working on process : $Process"

            $Check_Process = Get-Process -Name $Process -EA Stop

            if($Check_Process.StartTime.Count -gt 1)
            {
                Write-Log "More than 1 process is running for $Process"
                $Count= 0

                foreach($Entry in $Check_Process.StartTime)
                {
                    if($Entry.AddMinutes(($Config.Interval)) -lt (Get-Date))
                    {   $Count +=1
                        $Message = "Process $count of $Process is running more than $($Config.Interval) minutes"
                        Write-Log $Message

                        $EmailMessage+=$Message
                        $EmailMessage+="`n"
                    }
                }
            }
            elseif ($Check_Process.StartTime.Count -eq 0) 
            {
                throw "Unable to find the process start time for $Process"
            }
            else 
            {
                if((Get-Process -Name $Process).StartTime.AddMinutes(($Config.Interval)) -lt (Get-Date))
                {
                    $Message = "Process $Process is running more than $($Config.Interval) minutes"
                    Write-Log $Message

                    $EmailMessage+=$Message
                    $EmailMessage+="`n"
                }
            }         
        }
        catch 
        {
            Write-Log "Error while checking the process $Process - $_" -Type ERR
        }
    } 

    if($EmailMessage.Count -gt 0)
    {
        Write-Log "Going to send mail"
        Send-MailMessage -From $Config.Sender -To $Config.Recepients -Subject $Config.Subject -Body $EmailMessage -SmtpServer $Config.EmailServer -Port $Config.SmtpPort -EA Stop
        Write-Log "Mail send successfully"
    }
    
    Write-Log "Script completed"   
}
catch 
{
    Write-Log "$_" -Type ERR
}
