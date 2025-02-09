# Function: Process-STIGRule
Function Process-STIGRule {
    param (
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement]$Rule,
        [string]$ComputerName,
        [string]$Mode # 'Test', 'Verify', 'Apply'
    )

    $keyPath = Normalize-RegistryPath -Path $Rule.Key
    $valueName = $Rule.ValueName
    $expectedValue = $Rule.ValueData
    $valueType = $Rule.ValueType

    # Check if the rule is marked as manual or document
    if ($Rule.Type -eq "Manual" -or $Rule.Type -eq "Document") {
        $Global:ManualRulesCount++
        Write-Log -Message "Rule ID: $($Rule.id) is a $($Rule.Type) rule and requires manual implementation. Skipping." -ComputerName $ComputerName
        return
    }

    try {
        $keyExists = Test-Path "$keyPath"
        $actualValue = if ($keyExists) {
            Get-ItemProperty -Path "$keyPath" -Name $valueName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $valueName
        } else {
            $null
        }

        Write-Log -Message "Processing registry STIG: $keyPath -> $valueName (Value: $expectedValue, Type: $valueType)" -ComputerName $ComputerName

        switch ($Mode) {
            'Test Mode' {
                $description = $Rule.description -replace "<VulnDiscussion>", ""
                $reportEntry = @{
                    MachineName  = $ComputerName
                    RuleID       = $Rule.id
                    Status       = ''
                    Expected     = $expectedValue
                    Actual       = $actualValue
                    ValueName    = $valueName
                    KeyPath      = $keyPath
                    Description  = $description
                }

                if (-not $keyExists) {
                    Write-Log -Message "Test Mode: Missing registry key: $keyPath. Non-compliant." -ComputerName $ComputerName
                    $reportEntry.Status = "Missing Key"
                } elseif ($null -eq $actualValue) {
                    Write-Log -Message "Test Mode: Registry key exists but value '$valueName' is missing. Non-compliant." -ComputerName $ComputerName
                    $reportEntry.Status = "Missing Value"
                } elseif ($actualValue -ne $expectedValue) {
                    Write-Log -Message "Test Mode: Value mismatch for '$valueName': Expected '$expectedValue', Found '$actualValue'. Non-compliant." -ComputerName $ComputerName
                    $reportEntry.Status = "Value Mismatch"
                } else {
                    Write-Log -Message "Test Mode: $RuleID - '$valueName' is correctly set to '$expectedValue'. Compliant." -ComputerName $ComputerName
                    $reportEntry.Status = "Compliant"
                }

                # Debug logging for reportEntry
                Write-Log -Message "Debug: Report Entry - MachineName: $($reportEntry.MachineName), RuleID: $($reportEntry.RuleID), Status: $($reportEntry.Status), Expected: $($reportEntry.Expected), Actual: $($reportEntry.Actual), ValueName: $($reportEntry.ValueName), KeyPath: $($reportEntry.KeyPath), Description: $($reportEntry.Description)" -IsDebug
                Write-Host "Debug: Report Entry - MachineName: $($reportEntry.MachineName), RuleID: $($reportEntry.RuleID), Status: $($reportEntry.Status), Expected: $($reportEntry.Expected), Actual: $($reportEntry.Actual), ValueName: $($reportEntry.ValueName), KeyPath: $($reportEntry.KeyPath), Description: $($reportEntry.Description)" -ForegroundColor Yellow

                # Add to the compliance report
                $Global:ComplianceReport += [PSCustomObject]$reportEntry
            }
            'Verify Mode' {
                $description = $Rule.description -replace "<VulnDiscussion>", ""
                $reportEntry = @{
                    MachineName  = $ComputerName
                    RuleID       = $Rule.id
                    Status       = ''
                    Expected     = $expectedValue
                    Actual       = $actualValue
                    ValueName    = $valueName
                    KeyPath      = $keyPath
                    Description  = $description
                }

                if (-not $keyExists) {
                    $reportEntry.Status = "Missing Key"
                    Write-Log -Message "Verify Mode: Missing registry key: $keyPath. Non-compliant." -ComputerName $ComputerName
                } elseif ($null -eq $actualValue) {
                    $reportEntry.Status = "Missing Value"
                    Write-Log -Message "Verify Mode: Registry key exists but value '$valueName' is missing. Non-compliant." -ComputerName $ComputerName
                } elseif ($actualValue -ne $expectedValue) {
                    $reportEntry.Status = "Value Mismatch"
                    Write-Log -Message "Verify Mode: Value mismatch for '$valueName': Expected '$expectedValue', Found '$actualValue'. Non-compliant." -ComputerName $ComputerName
                } else {
                    $reportEntry.Status = "Compliant"
                    Write-Log -Message "Verify Mode: $RuleID - '$valueName' is correctly set to '$expectedValue'. Compliant." -ComputerName $ComputerName
                }

                # Debug logging for reportEntry
                Write-Log -Message "Debug: Report Entry - MachineName: $($reportEntry.MachineName), RuleID: $($reportEntry.RuleID), Status: $($reportEntry.Status), Expected: $($reportEntry.Expected), Actual: $($reportEntry.Actual), ValueName: $($reportEntry.ValueName), KeyPath: $($reportEntry.KeyPath), Description: $($reportEntry.Description)" -IsDebug
                Write-Host "Debug: Report Entry - MachineName: $($reportEntry.MachineName), RuleID: $($reportEntry.RuleID), Status: $($reportEntry.Status), Expected: $($reportEntry.Expected), Actual: $($reportEntry.Actual), ValueName: $($reportEntry.ValueName), KeyPath: $($reportEntry.KeyPath), Description: $($reportEntry.Description)" -ForegroundColor Yellow

                # Add to the compliance report
                $Global:ComplianceReport += [PSCustomObject]$reportEntry
            }

            'Run Mode' {
                $description = $Rule.description -replace "<VulnDiscussion>", ""
                $reportEntry = @{
                    MachineName  = $ComputerName
                    RuleID       = $Rule.id
                    Status       = ''
                    Expected     = $expectedValue
                    Actual       = $actualValue
                    ValueName    = $valueName
                    KeyPath      = $keyPath
                    Description  = $description
                }

                if (-not $keyExists) {
                    Write-Log -Message "Apply Mode: Creating registry key: $keyPath." -ComputerName $ComputerName
                    New-Item -Path "$keyPath" -Force | Out-Null
                    $reportEntry.Status = "Missing Key"
                }
                if ($null -eq $actualValue) {
                    Write-Log -Message "Apply Mode: Setting missing value '$valueName' to '$expectedValue'." -ComputerName $ComputerName
                    $reportEntry.Status = "Missing Value"
                } elseif ($actualValue -ne $expectedValue) {
                    Write-Log -Message "Apply Mode: Updating value '$valueName' from '$actualValue' to '$expectedValue'." -ComputerName $ComputerName
                    $reportEntry.Status = "Value Mismatch"
                } else {
                    Write-Log -Message "Apply Mode: '$valueName' is already correctly set to '$expectedValue'. No action required." -ComputerName $ComputerName
                    $reportEntry.Status = "Compliant"
                }

                # Debug logging for reportEntry
                Write-Log -Message "Debug: Report Entry - MachineName: $($reportEntry.MachineName), RuleID: $($reportEntry.RuleID), Status: $($reportEntry.Status), Expected: $($reportEntry.Expected), Actual: $($reportEntry.Actual), ValueName: $($reportEntry.ValueName), KeyPath: $($reportEntry.KeyPath), Description: $($reportEntry.Description)" -IsDebug
                Write-Host "Debug: Report Entry - MachineName: $($reportEntry.MachineName), RuleID: $($reportEntry.RuleID), Status: $($reportEntry.Status), Expected: $($reportEntry.Expected), Actual: $($reportEntry.Actual), ValueName: $($reportEntry.ValueName), KeyPath: $($reportEntry.KeyPath), Description: $($reportEntry.Description)" -ForegroundColor Yellow

                # Add to the compliance report
                $Global:ComplianceReport += [PSCustomObject]$reportEntry

                # Apply the value based on type
                if ($valueType -eq 'DWORD') {
                    if (-not (Test-Path "HKCU:\$keyPath")) {
                        New-Item -Path "HKCU:\$keyPath" -Force | Out-Null
                        Write-Log -Message "Apply Mode: Created registry key: $keyPath." -ComputerName $ComputerName
                    }
                    try {
                        $castValue = [int]$expectedValue
                        New-ItemProperty -Path "$keyPath" -Name $valueName -PropertyType DWord -Value $castValue -Force | Out-Null
                        Write-Log -Message "Apply Mode: Set DWORD value '$castValue' for '$valueName' in '$keyPath'." -ComputerName $ComputerName
                    } catch {
                        Write-Log -Message "Error setting DWORD value. Key: $keyPath, Name: $valueName, Value: $castValue - $_" -ComputerName $ComputerName -IsError
                    }
                } elseif ($valueType -eq 'String') {
                    if (-not (Test-Path "$keyPath")) {
                        New-Item -Path "$keyPath" -Force | Out-Null
                        Write-Log -Message "Apply Mode: Created registry key: $keyPath." -ComputerName $ComputerName
                    }
                    try {
                        $castValue = [string]$expectedValue
                        New-ItemProperty -Path "$keyPath" -Name $valueName -PropertyType String -Value $castValue -Force | Out-Null
                        Write-Log -Message "Apply Mode: Set String value '$castValue' for '$valueName' in '$keyPath'." -ComputerName $ComputerName
                    } catch {
                        Write-Log -Message "Error setting String value. Key: $keyPath, Name: $valueName, Value: $castValue - $_" -ComputerName $ComputerName -IsError
                    }
                } elseif ($valueType -eq 'MultiString') {
                    if (-not (Test-Path "$keyPath")) {
                        New-Item -Path "$keyPath" -Force | Out-Null
                        Write-Log -Message "Apply Mode: Created registry key: $keyPath." -ComputerName $ComputerName
                    }
                    try {
                        $castValue = ([string[]]$expectedValue -split ";")
                        New-ItemProperty -Path "$keyPath" -Name $valueName -PropertyType MultiString -Value $castValue -Force | Out-Null
                        Write-Log -Message "Apply Mode: Set MultiString value '$castValue' for '$valueName' in '$keyPath'." -ComputerName $ComputerName
                    } catch {
                        Write-Log -Message "Error setting MultiString value. Key: $keyPath, Name: $valueName, Value: $castValue - $_" -ComputerName $ComputerName -IsError
                    }
                } else {
                    Write-Log -Message "Apply Mode: Unsupported type '$valueType' for '$valueName'. Skipping application." -ComputerName $ComputerName
                }
            }
        }
    } catch {
        Write-Log -Message "Error processing Rule ID: $($Rule.id), Key: $keyPath - $_" -ComputerName $ComputerName -IsError
    }

}