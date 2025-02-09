# Function: Process-STIGFiles


Function Process-STIGFiles {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Machines,
        [Parameter(Mandatory = $true)]
        [string]$ExecutionMode,
        [Parameter(Mandatory = $true)]
        [string]$SelectedMode,
        [Parameter(Mandatory = $false)]
        [array]$SelectedSTIG
    )
    $ParentPath = if ($PSScriptRoot) { Split-Path -Path "$PSScriptRoot" -Parent } else { Get-Location }
    Write-Log -Message "Parent path resolved: $ParentPath"

    $directoryPath = "$ParentPath\Data\stigs"
    Write-Log -Message "Resolved directory path: $directoryPath"

    if (-not (Test-Path $directoryPath)) {
        Write-Log -Message "Error: Directory $directoryPath does not exist." -IsError
        return
    }
    $Global:ManualRulesCount = 0
    $Global:RegistryRulesCount = 0
    $Global:DocumentRulesCount = 0

    foreach ($machine in $Machines) {
        Write-Log "Starting STIG processing for machine: $machine"

        # Handle selected STIGs
        $stigFiles = if ($SelectedSTIG) {
            # Ensure $SelectedSTIG is an array of selected file names with .xml appended
            $selectedFiles = $SelectedSTIG | ForEach-Object { "$_" + '.xml' }

            # Filter the directory for files matching any of the selected names
            Get-ChildItem "$directoryPath" -Filter "*.xml" | Where-Object {
                $selectedFiles -contains $_.Name
            }
        } else {
            # Default to all .xml files if no selection is made
            Get-ChildItem -Path $directoryPath -Filter "*.xml"
        }

        Write-Log "Selected STIG Files: $($stigFiles | ForEach-Object { $_.FullName })"

        foreach ($file in $stigFiles) {
            $filePath = $file.FullName
            Write-Log "Processing STIG file: $filePath for machine: $machine"

            try {
                $stigXml = [xml](Get-Content -Path $filePath -ErrorAction Stop)
                Write-Log -Message "Loaded XML structure for $filePath : $(${stigXml.DISASTIG | Out-String})"

                if ($stigXml.DISASTIG) {
                    Write-Log -Message "Found DISASTIG element in $filePath."

                    # Count manual rules
                    if ($stigXml.DISASTIG.ManualRule) {
                        $manualRules = @($stigXml.DISASTIG.ManualRule.Rule)
                        Write-Log -Message "ManualRule element exists. Found $($manualRules.Count) rules."
#                        foreach ($rule in $manualRules) {
#                            Write-Log -Message "Processing Manual Rule ID: $($rule.id)"
#                        }
                        $Global:ManualRulesCount += $manualRules.Count
                    } else {
                        Write-Log -Message "No ManualRule element found in $filePath."
                    }

                    # Count registry rules
                    if ($stigXml.DISASTIG.RegistryRule) {
                        $registryRules = @($stigXml.DISASTIG.RegistryRule.Rule)
                        Write-Log -Message "RegistryRule element exists. Found $($registryRules.Count) rules."
                        foreach ($rule in $registryRules) {
                           # Write-Log -Message "Processing Registry Rule ID: $($rule.id)"
                            Process-STIGRule -Rule $rule -ComputerName $machine -Mode $SelectedMode
                        }
                        $Global:RegistryRulesCount += $registryRules.Count
                    } else {
                        Write-Log -Message "No RegistryRule element found in $filePath."
                    }

                    # Count document rules
                    if ($stigXml.DISASTIG.DocumentRule) {
                        $documentRules = @($stigXml.DISASTIG.DocumentRule.Rule)
                        Write-Log -Message "DocumentRule element exists. Found $($documentRules.Count) rules."
                        foreach ($rule in $documentRules) {
                            Write-Log -Message "Processing Document Rule ID: $($rule.id)"
                        }
                        $Global:DocumentRulesCount += $documentRules.Count
                    } else {
                        Write-Log -Message "No DocumentRule element found in $filePath."
                    }
                } else {
                    Write-Log -Message "Debug: No DISASTIG element found in $filePath." -IsDebug
                }

            } catch {
                Write-Log "Error processing STIG file: $filePath - $_" -IsError
            }
        }

        # Log processing summary for this machine
        Write-Log -Message "Processing Summary for $machine : ${Global:ManualRulesCount} manual rules, ${Global:RegistryRulesCount} registry rules, and ${Global:DocumentRulesCount} document rules."
        Write-Host "Summary for $machine : ${Global:ManualRulesCount} manual rules, ${Global:RegistryRulesCount} registry rules, and ${Global:DocumentRulesCount} document rules." -ForegroundColor Cyan
    }
}