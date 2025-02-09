###############################################
# DISA STIG Remediation Script
#-----------------------------------
# Version: 1.0.0 - initial creation
#-----------------------------------
# Author: TSgt Dillion Gasdia
#-----------------------------------
# Description: This script automates DISA STIG
# remediation tasks, with options for
# verification, test mode, and execution across
# multiple machines. For additional information
# please refer to the README file. 
###############################################


# Import Required Modules
# Logger: Handles logging of script execution details
# Preload-STIGOptions: Prepares and loads STIG options into the GUI dropdown
# Normalize-RegistryPath: Ensures registry paths are correctly formatted
# Process-STIGRules: Handles processing of individual STIG rules
# Prepare-MachineList: Prepares a list of machines for distributed execution
# Process-STIGFiles: Orchestrates the processing of selected STIG files
Import-Module "$PSScriptRoot\Modules\logger.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Preload-STIGOptions.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Normalize-RegistryPath.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Process-STIGRules.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Prepare-MachineList.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Process-STIGFiles.psm1" -Force


#Define Variables
#$logFilePath = "$PSScriptRoot\Logs"
# Initialize the report
$Global:ComplianceReport = @() # Initialize an empty array for compliance reporting

# Initialize counters for manual and skipped rules
$Global:ManualRulesCount = 0
$Global:SkippedRulesCount = 0


# Final summary log (outside the loop)
  Write-Log -Message "Final Processing Summary: ${Global:ManualRulesCount} manual rules, ${Global:RegistryRulesCount} registry rules, and ${Global:DocumentRulesCount} document rules across all machines."
  Write-Host "Final Summary: ${Global:ManualRulesCount} manual rules, ${Global:RegistryRulesCount} registry rules, and ${Global:DocumentRulesCount} document rules." -ForegroundColor Green

# Validate Required Directories
#$logDir = "$PSScriptRoot\Logs"
#if (-not (Test-Path -Path $LogsPath)) {
#    New-Item -ItemType Directory -Path $LogsPath -Force | Out-Null
#    Write-log "Logs directory created at $LogsPath"
#}

##################################################
#                                                #
# Main Script to Run GUI and Execute Functions   #
#                                                #
##################################################

# Start GUI and Process
Write-log "Starting STIG Remediation Tool..."

# Load Required Assemblies
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# Function to apply theme
Function Apply-Theme {
    param (
        [string]$Theme
    )

    switch ($Theme) {
        "Light" {
            $window.Background = [System.Windows.Media.Brushes]::White
            $window.Foreground = [System.Windows.Media.Brushes]::Black
            $window.FindName("ThemeToggleButton").Content = "Light Theme"
        }
        "Dark" {
            $window.Background = [System.Windows.Media.Brushes]::Black
            $window.Foreground = [System.Windows.Media.Brushes]::Gray
            $window.FindName("ThemeToggleButton").Content = "Dark Theme"
        }
    }
}

# STIG File Location
$stigFolderPath = "$PSScriptRoot\Data\stigs"

# Path to the XAML File
$xamlFilePath = "$PSScriptRoot\STIGRemediationGUI.xaml"

# Check if the XAML file exists
if (-not (Test-Path -Path $xamlFilePath)) {
    Write-log "Error: XAML file not found at $xamlFilePath" -IsError
    exit 1
}

# Load and Validate XAML Content
try {
    $xamlContent = Get-Content -Path $xamlFilePath -Raw
    Write-Log -Message "Raw XAML Content Loaded."

    $xmlDoc = New-Object System.Xml.XmlDocument
    $xmlDoc.LoadXml($xamlContent)
    Write-Log -Message "XAML successfully parsed as XML."
} catch {
    Write-Log -Message "Error loading or parsing XAML file: $_" -IsError
    exit 1
}

# Load WPF Window
try {
    $reader = New-Object System.Xml.XmlNodeReader($xmlDoc)
    $window = [Windows.Markup.XamlReader]::Load($reader)
    if (-not $window) {
        Write-Log -Message "Failed to load XAML into WPF Window. Please check the XAML structure." -IsError
        exit 1
    }
    Write-Log -Message "XAML successfully loaded into WPF Window."
} catch {
    Write-Log -Message "Error initializing WPF window from XAML: $_" -IsError
    exit 1
}

# Apply initial theme
Apply-Theme -Theme "Light"

# Theme Toggle Button Event Handler
$window.FindName("ThemeToggleButton").Add_Click({
    $currentTheme = $window.FindName("ThemeToggleButton").Content
    if ($currentTheme -eq "Light Theme") {
        Apply-Theme -Theme "Dark"
    } else {
        Apply-Theme -Theme "Light"
    }
})

#################################
#                               #
# Event Handlers                #
#                               #
#################################

# Help Button
$window.FindName("HelpButton").Add_Click({
    $helpMessage = @"
STIG Remediation Tool - User Guide
-----------------------------------

This tool is designed to automate DISA STIG remediation tasks with options for:
1. Selecting execution mode (Local or Distributed).
2. Running in Test, Run, or Verify modes.
3. Advanced options for selecting specific STIG rules or all available rules.
4. Generating compliance reports in CSV and PDF formats.
Modes:
------
1. **Test Mode**:
   - Simulates the changes that would be applied.
   - Logs the operations without making actual changes.
   - Use this mode to preview the impact of the script.

2. **Run Mode**:
   - Applies changes to the machine or machines in the selected mode.
   - Requires the user to acknowledge the risks before execution.
   - WARNING: This mode makes permanent changes.

3. **Verify Mode**:
   - Verifies the compliance of the system against the selected STIG rules.
   - Generates a detailed compliance report.
   - Does not apply any changes.

Using Advanced Options:
-----------------------
- Enable advanced options to select specific STIG rules for processing.
- Default behavior processes all available STIGs in the selected mode.
- Update the STIG files using the **Update STIGs** button to ensure the latest rules are applied.

Logs and Reports:
-----------------
- All operations are logged in the "Logs" directory under the script's location.
- Logs include execution details, errors, and compliance status.
- Reports (CSV) are generated for compliance checks in Verify Mode.

Steps to Use:
-------------
1. Select the desired execution mode (Local or Distributed).
2. Choose the operation mode: Test, Run, or Verify.
3. (Optional) Enable advanced options to select specific STIGs.
4. Click the **Run** button to execute the script.

Additional Information:
-----------------------
- Ensure you have sufficient privileges (e.g., Administrator) to apply changes in Run Mode.
- Review logs for detailed execution and compliance details.

For further assistance, refer to the README file or contact support.


"@
    [System.Windows.MessageBox]::Show($helpMessage, "Help - STIG Remediation Tool", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})

# Execution Mode Selection
$window.FindName("ExecutionModeSelector").Add_SelectionChanged({
    $executionMode = $window.FindName("ExecutionModeSelector").SelectedItem.Content
    if ($executionMode -eq "Distributed") {
        $window.FindName("BrowseButton").Visibility = "Visible"
        $window.FindName("ExecutionModeDescriptionTextBlock").Text = "Distributed: Executes on a list of remote machines."
    } else {
        $window.FindName("BrowseButton").Visibility = "Collapsed"
        $window.FindName("ExecutionModeDescriptionTextBlock").Text = "Local: Executes the script on this machine only."
    }
})

# Browse Button for Distributed Mode
$window.FindName("BrowseButton").Add_Click({
    # Load the Windows Forms assembly
    Add-Type -AssemblyName System.Windows.Forms

    $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $fileDialog.Filter = "Supported Files (*.csv;*.txt;*.json)|*.csv;*.txt;*.json|CSV Files (*.csv)|*.csv|Text Files (*.txt)|*.txt|JSON Files (*.json)|*.json"
    $fileDialog.Title = "Select Machine List"

    if ($fileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $selectedFile = $fileDialog.FileName
        $fileExtension = [System.IO.Path]::GetExtension($selectedFile).ToLower()

        # Validate file extension
        if ($fileExtension -notin @(".csv", ".txt", ".json")) {
            $window.FindName("StatusTextBlock").Text = "Error: Selected file type is not supported."
        } else {
            Write-Host "Selected Machine List: $selectedFile"
            $window.FindName("StatusTextBlock").Text = "Selected Machine List: $selectedFile"
            Set-Variable -Name machineListPath -Value $selectedFile -Scope Script
        }
    }
})

# Script Mode Selection
$window.FindName("ModeSelector").Add_SelectionChanged({
    $selectedMode = $window.FindName("ModeSelector").SelectedItem.Content
    switch ($selectedMode) {
        "Test Mode" {
            $window.FindName("ModeDescriptionTextBlock").Text = "Test Mode: Simulates changes without applying them."
            $window.FindName("WarningTextBlock").Visibility = "Collapsed"
            $window.FindName("AcceptRisksCheckbox").Visibility = "Collapsed"
        }
        "Run Mode" {
            $window.FindName("ModeDescriptionTextBlock").Text = "Run Mode: Applies changes to the machine."
            $window.FindName("WarningTextBlock").Text = "Warning: Run Mode will make permanent changes to the machine."
            $window.FindName("WarningTextBlock").Visibility = "Visible"
            $window.FindName("AcceptRisksCheckbox").Visibility = "Visible"
        }
        "Verify Mode" {
            $window.FindName("ModeDescriptionTextBlock").Text = "Verify Mode: Verifies compliance without making changes."
            $window.FindName("WarningTextBlock").Visibility = "Collapsed"
            $window.FindName("AcceptRisksCheckbox").Visibility = "Collapsed"
        }
    }
})
# Call the preload function during form initialization
Preload-STIGOptions

# Event handler for Advanced Options Toggle button
$window.FindName("AdvancedOptionsToggle").Add_Click({
    $advancedPanel = $window.FindName("AdvancedOptionsPanel")
    if ($advancedPanel.Visibility -eq "Visible") {
        $advancedPanel.Visibility = "Collapsed"
        $window.FindName("AdvancedOptionsToggle").Content = "Advanced Options"
    } else {
        $advancedPanel.Visibility = "Visible"
        $window.FindName("AdvancedOptionsToggle").Content = "Hide Advanced Options"
    }
})

# Event handler for Update STIGs button
$window.FindName("UpdateSTIGsButton").Add_Click({
    # Prompt for confirmation
    $confirmation = [System.Windows.MessageBox]::Show(
        "This will download and update the STIG files. Do you want to continue?",
        "Confirm Update",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )

    if ($confirmation -eq [System.Windows.MessageBoxResult]::Yes) {
        # Update status text
        $window.FindName("UpdateStatusTextBlock").Text = "Updating STIGs, please wait..."

        # Run the UpdateSTIGS.ps1 script
        try {
            $updateScriptPath = "$PSScriptRoot\Modules\UpdateSTIGS.ps1"
            if (Test-Path $updateScriptPath) {
                # Execute the script and capture output
                $output = & $updateScriptPath 2>&1
                $window.FindName("UpdateStatusTextBlock").Text = "STIGs updated successfully."

                # Log the output
                Write-Host "UpdateSTIGS Output:" -ForegroundColor Green
                Write-Host $output

                # Reload the dropdown with new STIGs
                Preload-STIGOptions 
            } else {
                $window.FindName("UpdateStatusTextBlock").Text = "Error: UpdateSTIGS.ps1 not found."
                Write-Host "Error: UpdateSTIGS.ps1 not found." -ForegroundColor Red
            }
        } catch {
            $window.FindName("UpdateStatusTextBlock").Text = "Error updating STIGs: $_"
            Write-Host "Error updating STIGs: $_" -ForegroundColor Red
        }
    } else {
        # User chose not to proceed
        $window.FindName("UpdateStatusTextBlock").Text = "Update canceled by user."
    }
})

# Cancel Button
$window.FindName("CancelButton").Add_Click({
    Write-Host "Script canceled by user."
    $window.Close()
    return
})

$window.FindName("RunButton").Add_Click({
    try {
        $executionMode = $window.FindName("ExecutionModeSelector").SelectedItem.Content
        $selectedMode = $window.FindName("ModeSelector").SelectedItem.Content
        $acceptRisks = $window.FindName("AcceptRisksCheckbox").IsChecked
        $currentUser = $env:USERNAME
        $logFileLink = $window.FindName("LogFileLink")

        # Log file path for the session
        $loggingPath = "$PSScriptRoot\Logs\STIG_Remediation.log"

        # Ensure the log directory exists
        if (-not (Test-Path -Path (Split-Path -Path $loggingPath))) {
            New-Item -ItemType Directory -Path (Split-Path -Path $loggingPath) -Force | Out-Null
        }

        Write-Log "Run button clicked. Selected Mode: $selectedMode, Execution Mode: $executionMode"

        # Validate and prepare machines list
        $machines = Prepare-MachineList -ExecutionMode $executionMode -MachineListPath $machineListPath
        Write-Log "Prepared machine list: $($machines -join ', ')"

        # Ensure risks are accepted in Run Mode
        if ($selectedMode -eq "Run Mode" -and -not $acceptRisks) {
            throw "You must accept the risks to proceed in Run Mode."
        }

        # Update GUI Status
        $window.FindName("StatusTextBlock").Text = "Script Running..."
        Write-Log "Script status updated to running."

        # Capture the selected STIG from the dropdown
        $selectedSTIG = @($window.FindName("STIGDropdown").SelectedItems | ForEach-Object { $_.ToString() })
        Write-Log "Processing Selected STIGs $selectedSTIG"

        # Ensure a default value if nothing is selected
        if (-not $selectedSTIG) {
            Write-Log "No STIG selected. Processing all STIGs."
        }

        # Call Process-STIGFiles with the selected STIG
        Process-STIGFiles -Machines $machines -ExecutionMode $executionMode -SelectedMode $selectedMode -SelectedSTIG $selectedSTIG

        # Generate Compliance Report in Verify Mode
        if ($selectedMode -eq "Verify Mode") {
            $reportPath = "$PSScriptRoot\Logs\ComplianceReport.csv"
            $Global:ComplianceReport | Select-Object MachineName, RuleID, Status, Expected, Actual, ValueName, KeyPath, Description | Export-Csv -Path $reportPath -NoTypeInformation -Force
            Write-Log -Message "Verification complete. Compliance report saved to $reportPath."
            Write-Host "Compliance report generated: $reportPath" -ForegroundColor Green
        }

        # Generate Test Report in Test Mode
        if ($selectedMode -eq "Test Mode") {
            $testReportPath = "$PSScriptRoot\Logs\TestReport.csv"
            $Global:ComplianceReport | Select-Object MachineName, RuleID, Status, Expected, Actual, ValueName, KeyPath, Description | Export-Csv -Path $testReportPath -NoTypeInformation -Force
            Write-Log -Message "Test complete. Test report saved to $testReportPath."
            Write-Host "Test report generated: $testReportPath" -ForegroundColor Green
        }

        # Generate Run Mode Report in Run Mode
        if ($selectedMode -eq "Run Mode") {
            $runModeReportPath = "$PSScriptRoot\Logs\RunModeReport.csv"
            $Global:ComplianceReport | Select-Object MachineName, RuleID, Status, Expected, Actual, ValueName, KeyPath, Description | Export-Csv -Path $runModeReportPath -NoTypeInformation -Force
            Write-Log -Message "Run Mode complete. Run Mode report saved to $runModeReportPath."
            Write-Host "Run Mode report generated: $runModeReportPath" -ForegroundColor Green
        }

        # Finalize
        $window.FindName("StatusTextBlock").Text = "Script Completed!"
        Write-Log "Script execution completed in $selectedMode mode."

        # Update Log File Link
        $window.FindName("LogFileLink").Tag = $loggingPath
        $window.FindName("LogFileLink").Text = "View Log File"
        $window.FindName("LogFileLink").Visibility = "Visible"
    } catch {
        $window.FindName("StatusTextBlock").Text = "Error: $_"
        Write-Log "Error: $_" -IsError
    }
})

# Log File Link Event Handler
$window.FindName("LogFileLink").Add_MouseLeftButtonUp({
    $loggingPath = $window.FindName("LogFileLink").Tag
    if (Test-Path $loggingPAth) {
        try {
            Start-Process -FilePath $loggingPath
        } catch {
            $window.FindName("StatusTextBlock").Text = "Error: Unable to open log file. $_"
            Write-Log "Error: Unable to open log file. $_" -IsError
        }
    } else {
        $window.FindName("StatusTextBlock").Text = "Error: Log file not found."
        Write-Log "Error: Log file not found at $logFilePath" -IsError
    }
})

# Set Log File Link After Processing
$window.FindName("LogFileLink").Dispatcher.BeginInvoke([action]{
    $window.FindName("LogFileLink").Tag = $loggingPath
    $window.FindName("LogFileLink").Text = "View Log File"
    $window.FindName("LogFileLink").Visibility = "Visible"
})


# Show the Window
try {
    $window.ShowDialog()
} catch {
    Write-Host "Error displaying the WPF window: $_" -ForegroundColor Red
    exit 1
}

Write-Log "All STIG Remediation Completed."
