# STIG_FIX

## Overview
STIG_FIX is an application designed to automate the process of applying Security Technical Implementation Guides (STIGs) to systems. It parses STIG XML files and applies the necessary configurations to ensure compliance with security standards.

## Features
- Parse and process STIG XML files
- Apply security configurations automatically
- Generate compliance reports
- Support for multiple operating systems
- Update new XML files on demand
- Select single or multiple STIGs to process
- Allow a local or distributed mode for processing (distributed mode supports, CSV, TXT, and JSON formats dynamically.)
- Run script in Test, Verify or Run mode.

## Usage
To use STIG_FIX, follow these steps:

1. Ensur your STIG XML files exist in the `Data\stigs` directory.
2. Run the PowerShell script:
    ```powershell
    .\stigscript.ps1
    ```
3. The application will process the STIG XML files and apply the necessary configurations.

## Modules
### Logger
Handles logging of script execution details.

### Preload-STIGOptions
Prepares and loads STIG options into the GUI dropdown.

### Normalize-RegistryPath
Ensures registry paths are correctly formatted.

### Process-STIGRules
Handles processing of individual STIG rules.

### Prepare-MachineList
Prepares a list of machines for distributed execution.

### Process-STIGFiles
Orchestrates the processing of selected STIG files.

### UpdateSTIGS
Updates the STIG files from the specified GitHub repository.

