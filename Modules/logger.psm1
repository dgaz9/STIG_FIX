# Logger.psm1

# Define the Write-Log function
Function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$ComputerName = $env:COMPUTERNAME,
        [switch]$IsError,
        [switch]$IsDebug,
        [switch]$IsVerify
    )

    # Define paths
    $logDirectoryPath = "$PSScriptRoot\Logs"
    $logFilePath = "$logDirectoryPath\STIG_Remediation.log"
    $verifyLogFilePath = "$logDirectoryPath\STIG_Verification.log"

    # Ensure the log directory exists
    if (-not (Test-Path $logDirectoryPath)) {
        try {
            New-Item -ItemType Directory -Path $logDirectoryPath -Force | Out-Null
        } catch {
            Write-Host "Failed to create log directory: $_" -ForegroundColor Red
            return
        }
    }

    # Construct the log message
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = if ($IsError) {
        "$timestamp [ERROR] [$ComputerName] $Message"
    } elseif ($IsDebug) {
        "$timestamp [DEBUG] [$ComputerName] $Message"
    } elseif ($IsVerify) {
        "$timestamp [VERIFICATION] [$ComputerName] $Message"
    } else {
        "$timestamp [INFO] [$ComputerName] $Message"
    }

    # Write to logs
    try {
        if ($IsVerify) {
            $logMessage | Out-File -FilePath $verifyLogFilePath -Append
        } else {
            $logMessage | Out-File -FilePath $logFilePath -Append
        }

        # Set console output color based on log level
        $color = if ($IsError) {
            "Red"
        } elseif ($IsDebug) {
            "Yellow"
        } else {
            "White"
        }

        Write-Host $logMessage -ForegroundColor $color
    } catch {
        Write-Host "Failed to write to log file. Error: $_" -ForegroundColor Red
    }
}
