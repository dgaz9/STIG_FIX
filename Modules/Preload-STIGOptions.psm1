# Function: Preload-STIGOptions

$ParentPath = Split-Path -Path "$PSScriptRoot" -Parent

Function Preload-STIGOptions {
    $stigDropdown = $window.FindName("STIGDropdown")
    $stigDropdown.Items.Clear()

    try {
        $stigFiles = Get-ChildItem -Path "$ParentPath\Data\stigs" -Filter "*.xml"
        foreach ($file in $stigFiles) {
            $xml = [xml](Get-Content -Path $file.FullName)
            $stigid = $file.Name -replace '\.xml$', ''
            if ($stigid) {
                $stigDropdown.Items.Add($stigid)
            } else {
                $stigDropdown.Items.Add("Unknown STIG (File: $($file.Name))")
            }
        }
    } catch {
        $stigDropdown.Items.Add("Error loading STIG files.")
        Write-Host "Error loading STIG files: $_" -ForegroundColor Red
    }
}