# Define the GitHub URL for the PowerSTIG processed data
$githubURL = "https://github.com/microsoft/PowerStig/tree/dev/source/StigData/Processed"

# Create a unique directory name based on the current date (e.g., YYYY-MM-DD)
$date = Get-Date -Format "yyyy-MM-dd"
$downloadFolder = "$PSScriptRoot\Data\STIGs_$date"
$dataStigsFolder = "$PSScriptRoot\Data\stigs"

# Ensure the download folder exists
try {
    if (-not (Test-Path -Path $downloadFolder)) {
        New-Item -ItemType Directory -Path $downloadFolder | Out-Null
    }
} catch {
    Write-Error "Failed to create required directories. Exiting."
    exit 1
}

# Fetch the GitHub repository page
Write-Host "Fetching the GitHub repository page..."
try {
    $webPageContent = Invoke-WebRequest -Uri $githubURL -UseBasicParsing
    Write-Host "GitHub repository page fetched successfully."
} catch {
    Write-Error "Failed to fetch the GitHub repository page. Exiting."
    exit 1
}

# Parse the HTML to find XML file links that do not end with "org.default.xml"
$xmlLinks = ($webPageContent.Links | Where-Object { 
    $_.href -match "\.xml$" -and $_.href -notmatch "org\.default\.xml$" 
}).href

if ($xmlLinks.Count -eq 0) {
    Write-Error "No matching XML files found in the repository. Exiting."
    exit 1
}

Write-Host "Found $($xmlLinks.Count) XML files to download."

# Download each XML file
foreach ($xmlLink in $xmlLinks) {
    # Convert relative links to absolute links if necessary
    if ($xmlLink -notmatch "^http") {
        $xmlLink = "https://raw.githubusercontent.com" + $xmlLink -replace "/blob/", "/"
    }

    $fileName = [System.IO.Path]::GetFileName($xmlLink)
    $filePath = Join-Path -Path $downloadFolder -ChildPath $fileName

    Write-Host "Downloading $fileName..."
    try {
        Invoke-WebRequest -Uri $xmlLink -OutFile $filePath
        Write-Host "$fileName downloaded successfully."
    } catch {
        Write-Warning "Failed to download $fileName. Skipping."
    }
}

# Delete all contents in $PSScriptRoot\Data\stigs
Write-Host "Cleaning up old files in $dataStigsFolder..."
if (Test-Path -Path $dataStigsFolder) {
    Get-ChildItem -Path $dataStigsFolder -Recurse | Remove-Item -Force -Recurse
    Write-Host "Old files removed from $dataStigsFolder."
} else {
    New-Item -ItemType Directory -Path $dataStigsFolder | Out-Null
    Write-Host "Created $dataStigsFolder."
}

# Copy the downloaded XML files to $PSScriptRoot\Data\stigs
Write-Host "Copying new XML files to $dataStigsFolder..."
Copy-Item -Path "$downloadFolder\*" -Destination $dataStigsFolder -Force
Write-Host "New XML files copied to $dataStigsFolder."

Write-Host "Process completed successfully. Files saved in $dataStigsFolder."
