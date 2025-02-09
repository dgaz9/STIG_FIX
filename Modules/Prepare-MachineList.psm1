# Function: Prepare-MachineList
Function Prepare-MachineList {
    param (
        [string]$ExecutionMode,
        [string]$MachineListPath
    )

    try {
        if ($ExecutionMode -eq "Distributed") {
            if (-not $MachineListPath -or -not (Test-Path -Path $MachineListPath)) {
                throw "Machine list file not provided or not found."
            }
            $machines = Get-Content -Path $MachineListPath

            # Check accessibility of each machine
            $accessibleMachines = @()
            foreach ($machine in $machines) {
                if (Test-Connection -ComputerName $machine -Count 1 -Quiet) {
                    $accessibleMachines += $machine
                } else {
                    Write-Log "Error: Machine $machine is not accessible." -IsError
                }
            }

            if ($accessibleMachines.Count -eq 0) {
                throw "No accessible machines found in the provided machine list."
            }
            $machines = $accessibleMachines
        } else {
            $machines = @($env:COMPUTERNAME)
        }

        Write-Log "Prepared machine list: $($machines -join ', ')"
        return $machines
    } catch {
        Write-Log "Error in Prepare-MachineList: $_" -IsError
        throw
    }
}