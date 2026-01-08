# Export BitLocker Recovery Key via manage-bde

A simple, automated PowerShell script to **export an existing BitLocker recovery key** from a Windows system using `manage-bde`. Designed for use with Ansible and PDQ deploy. 
This script saves the recovery key to a centralized network location using a consistent, human-readable filename format.

Please note: **this script does not enable BitLocker.** It assumes BitLocker is already enabled on the target drive, and extracts the recovery key.

## Overview

This script will:
- Verify **BitLocker is enabled** on a specified drive (default `C:`)
- Query BitLocker protector information using **manage-bde**
- Extract the **recovery password**
- Extract the **protector GUID**
- Extract the **GUI-visible Numerical Password identifier** (when available)
- Fall back to the protector GUID if the GUI identifier cannot be located
- Export the recovery key and metadata to a **network location**
- Name the output file in a standardized, human-readable format
- Return deterministic **exit codes** for automation tools such as **PDQ Deploy**

## Configuration

Drive to export recovery key from: $MountPoint = "C:"
Network path to store recovery key files: $ExportPath = "\\ntstore\Apps\Keys"
Script name and version (Written into the exported recovery file for logging): $Version = "Save BitLocker Key to NTSTORE v2.1 PDQ"

## Output Filename Format

Recovery files are output in this format:

    <HOSTNAME>, <GUI-Identifier>, <YYYY-MM-DD>.txt
For example:

    DESKTOP-1234, {A1B2C3D4-E5F6-7890-ABCD-1234567890AB}, 2026-01-08.txt

## Exit Codes

| Code | Description |
|-----:|-------------|
| 0 | Recovery key exported successfully |
| 44 | Failed to write recovery key file (permissions or network issue) |
| 55 | Could not parse recovery information from manage-bde output |
| 66 | Failed to query manage-bde output |
| 77 | Export path does not exist or is unreachable |
| 88 | BitLocker is not enabled on the target drive |
| 99 | Unable to retrieve BitLocker volume information |

## How It Works

    Start
     │
     │ Check if export path exists
     │       └─> Exit 77 if not reachable
     │
     │ Retrieve BitLocker volume information
     │       └─> Exit 99 if volume info cannot be retrieved
     │
     │ Verify BitLocker protection status
     │       └─> Exit 88 if BitLocker is not enabled
     │
     │ Query BitLocker protectors via manage-bde
     │       └─> Exit 66 on failure
     │
     │ Parse manage-bde output
     │       ├─> Extract recovery password
     │       ├─> Extract protector GUID
     │       └─> Extract GUI Numerical Password identifier
     │             └─> Fallback to protector GUID if GUI ID not found
     │             └─> Exit 55 if parsing fails
     │
     │ Build filename using hostname, identifier, and date
     │
     │ Write recovery details to file
     │       └─> Exit 44 on failure
     │
    End ──> Exit 0 (Success)
