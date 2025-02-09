# Function: Normalize-RegistryPath
Function Normalize-RegistryPath {
    param (
        [string]$Path
    )
    
    # Replace full names with their shortened versions for PowerShell operations
    $Path = $Path -replace '^HKEY_LOCAL_MACHINE', 'HKLM:'
    $Path = $Path -replace '^HKEY_CURRENT_USER', 'HKCU:'
    $Path = $Path -replace '^HKEY_CLASSES_ROOT', 'HKCR:'
    $Path = $Path -replace '^HKEY_USERS', 'HKU:'
    $Path = $Path -replace '^HKEY_CURRENT_CONFIG', 'HKCC:'
    return $Path
}