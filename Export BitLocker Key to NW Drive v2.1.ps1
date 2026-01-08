# Export BitLocker recovery key using manage-bde
# Compatible with PDQ Deploy (runs as Deploy User or SYSTEM)
# Filename format: <HOSTNAME>, <GUI-Identifier>, <YYYY-MM-DD>.txt
# -----------------------------------------------------------

$MountPoint = "C:"                                    # Drive to export from
$ExportPath = "\\ntstore\Apps\Keys"                   # Where to save the recovery key file
$Version = "Save BitLocker Key to NTSTORE v2.1 PDQ"   # Name and version number of this script

Write-Host "Starting BitLocker recovery key export for $MountPoint..."

# Ensure export path exists
if (-not (Test-Path $ExportPath)) {
    Write-Error "The export path '$ExportPath' is not accessible. Exiting."
    exit 77
}

# Get BitLocker status
try {
    $BLV = Get-BitLockerVolume -MountPoint $MountPoint -ErrorAction Stop
} catch {
    Write-Error "Unable to retrieve BitLocker volume information: $($_.Exception.Message)"
    exit 99
}

if ($BLV.ProtectionStatus -ne 'On') {
    Write-Error "BitLocker is not enabled on $MountPoint. No recovery key to export."
    exit 88
}

# Run manage-bde to retrieve key info
Write-Host "Retrieving BitLocker protector information via manage-bde..."
try {
    $output = & manage-bde -protectors -get $MountPoint | Out-String
} catch {
    Write-Error "Failed to query manage-bde output: $($_.Exception.Message)"
    exit 66
}

# Extract the recovery password
$RecoveryPasswordMatch = $output | Select-String -Pattern "([0-9]{6}-){7}[0-9]{6}"
$RecoveryPassword = $RecoveryPasswordMatch.Matches.Value

# Extract the Protector GUID
$ProtectorGUIDMatch = $output | Select-String -Pattern "ID:\s*({[0-9A-Fa-f-]+})"
if ($ProtectorGUIDMatch) {
    $ProtectorGUID = $ProtectorGUIDMatch.Matches.Groups[1].Value
} else {
    $ProtectorGUID = "N/A"
}

# Extract the GUI-style Numerical Password ID
# We look specifically under "Numerical Password:" sections
$Lines = $output -split "`r?`n"
$Identifier = $null
for ($i=0; $i -lt $Lines.Count; $i++) {
    if ($Lines[$i] -match "Numerical Password") {
        # Look for the next line containing ID:
        for ($j = $i+1; $j -lt $Lines.Count; $j++) {
            if ($Lines[$j] -match "ID:\s*({[0-9A-Fa-f-]+})") {
                $Identifier = $Matches[1]
                $IdentifierSource = "GUI Identifier"
                break
            }
        }
        if ($Identifier) { break }
    }
}

# Fallback if GUI-style identifier not found
if (-not $Identifier) {
    $Identifier = $ProtectorGUID
    $IdentifierSource = "Fallback (Protector GUID)"
}

if (-not $RecoveryPassword -or -not $ProtectorGUID) {
    Write-Error "Could not parse recovery information from manage-bde output."
    exit 55
}

# Prepare filename: <HOSTNAME>, <GUI-Identifier>, <DATE>.txt
$ComputerName = $env:COMPUTERNAME
$Date = (Get-Date).ToString("yyyy-MM-dd")
$FileName = "$ComputerName, $Identifier, $Date.txt"
$TargetFile = Join-Path $ExportPath $FileName

# Write recovery details to file
try {
    $lines = @(
        "Computer Name: $ComputerName"
        "Drive: $MountPoint"
        "Protector ID: $ProtectorGUID"
        "Identifier: $Identifier ($IdentifierSource)"
        "Recovery Password: $RecoveryPassword"
        "Export Date: $Date"
        "Script that made this file: $Version"
    )
    $lines | Out-File -FilePath $TargetFile -Encoding ASCII
    Write-Host "Recovery key exported successfully to $TargetFile"
} catch {
    Write-Error "Failed to write recovery key file: $($_.Exception.Message)"
    exit 44
}

Write-Host "BitLocker recovery key export completed successfully for $ComputerName."
exit 0
