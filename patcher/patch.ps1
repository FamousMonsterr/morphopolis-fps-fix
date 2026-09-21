# Morphopolis FPS Fix patcher
# Fixes stutter / FPS drops in Morphopolis (Steam, 2013, Marmalade engine) on Windows 10/11.
#
# What it does (both reversible):
#   1. app.icf: doubles Marmalade engine caches and memory heap
#      (MemSize 64->128 MB, DataCacheSize 8->16 MB, VertCacheSize 4096->8192)
#   2. HKCU compatibility flags for project.exe:
#      DISABLEDXMAXIMIZEDWINDOWEDMODE + HIGHDPIAWARE
#      (fixes DWM-induced stutter of legacy OpenGL games on Windows 10/11)
#
# No admin rights required (writes to HKCU only).

param(
    [ValidateSet('Patch', 'Undo', 'Status')]
    [string]$Mode = 'Patch',
    [string]$GamePath = ''
)

$ErrorActionPreference = 'Stop'
$exeName = 'project.exe'
$icfName = 'app.icf'
$layersKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
$compatFlags = '~ DISABLEDXMAXIMIZEDWINDOWEDMODE HIGHDPIAWARE'
$regBakName = 'fpsfix.registry.bak.txt'

# target values for app.icf
$icfTargets = @{
    'MemSize'       = '134217728'   # 64 MB  -> 128 MB
    'DataCacheSize' = '16777216'    # 8 MB   -> 16 MB
    'VertCacheSize' = '8192'        # 4096   -> 8192
}

function Write-Info($msg)  { Write-Host "[i] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "[+] $msg" -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err2($msg)  { Write-Host "[x] $msg" -ForegroundColor Red }

function Find-GameDir {
    param([string]$Hint)

    if ($Hint -and (Test-Path (Join-Path $Hint $exeName))) { return $Hint }

    $candidates = New-Object System.Collections.Generic.List[string]

    # Steam libraries (registry + libraryfolders.vdf)
    $steamRoots = @()
    foreach ($rk in @('HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam')) {
        $ip = (Get-ItemProperty $rk -ErrorAction SilentlyContinue).InstallPath
        if ($ip) { $steamRoots += $ip }
    }
    foreach ($root in $steamRoots) {
        $candidates.Add((Join-Path $root 'steamapps\common\Morphopolis'))
        $vdf = Join-Path $root 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) {
                $lib = $m.Groups[1].Value -replace '\\\\', '\'
                $candidates.Add((Join-Path $lib 'steamapps\common\Morphopolis'))
            }
        }
    }

    # common non-Steam locations
    foreach ($base in @('C:\Games', 'C:\GOG Galaxy Games', 'C:\GOG Games', 'C:\Program Files (x86)\Steam\steamapps\common')) {
        $candidates.Add((Join-Path $base 'Morphopolis'))
    }

    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c $exeName)) { return $c }
    }
    return $null
}

# ---- detect game -----------------------------------------------------------
$game = Find-GameDir -Hint $GamePath
Write-Host ''
Write-Host '=== Morphopolis FPS Fix ===' -ForegroundColor White
Write-Host ''

if (-not $game) {
    Write-Err2 "Morphopolis ($exeName) not found."
    Write-Info  "Pass the folder explicitly:  .\patch.ps1 -Mode Patch -GamePath 'D:\Games\Morphopolis'"
    exit 2
}
$exe  = Join-Path $game $exeName
$icf  = Join-Path $game $icfName
$bak  = "$icf.bak"
$regBak = Join-Path $game $regBakName
Write-Ok "Game found: $game"

# ---- helpers ---------------------------------------------------------------
function Get-IcfValue([string]$text, [string]$key) {
    $m = [regex]::Match($text, "(?m)^\s*$key\s*=\s*(\S+)")
    if ($m.Success) { $m.Groups[1].Value } else { $null }
}

function Test-IcfPatched([string]$text) {
    foreach ($k in $icfTargets.Keys) {
        if ((Get-IcfValue $text $k) -ne $icfTargets[$k]) { return $false }
    }
    return $true
}

function Get-CompatValue {
    if (-not (Test-Path $layersKey)) { return $null }
    $p = Get-ItemProperty $layersKey -Name $exe -ErrorAction SilentlyContinue
    if ($p) { $p.$exe } else { $null }
}

# ---- modes -----------------------------------------------------------------
switch ($Mode) {

    'Status' {
        Write-Host ''
        Write-Info "app.icf: $icf"
        if (Test-Path $icf) {
            $text = Get-Content $icf -Raw
            if (Test-IcfPatched $text) { Write-Ok '  engine config: PATCHED' }
            else {
                Write-Warn2 '  engine config: not patched'
                foreach ($k in $icfTargets.Keys) { Write-Host "      $k = $(Get-IcfValue $text $k)" }
            }
            if (Test-Path $bak) { Write-Info '  backup present: app.icf.bak' }
        } else { Write-Warn2 '  app.icf not found' }
        $regVal = Get-CompatValue
        if ($regVal -eq $compatFlags) { Write-Ok '  Windows compatibility flags: SET' }
        elseif ($regVal) { Write-Warn2 "  Windows compatibility flags: OTHER value: $regVal" }
        else { Write-Warn2 '  Windows compatibility flags: not set' }
    }

    'Patch' {
        # 1) app.icf
        Write-Host ''
        if (Test-Path $icf) {
            $text = Get-Content $icf -Raw
            if (Test-IcfPatched $text) {
                Write-Ok 'app.icf already patched (engine caches + heap).'
            } else {
                if (-not (Test-Path $bak)) { Copy-Item $icf $bak; Write-Info 'backup saved: app.icf.bak' }
                foreach ($k in $icfTargets.Keys) {
                    if (Get-IcfValue $text $k) {
                        $text = [regex]::Replace($text, "(?m)^(\s*$k\s*=\s*)\S+", "`${1}$($icfTargets[$k])")
                    }
                }
                Set-Content -Path $icf -Value $text -NoNewline
                Write-Ok 'app.icf patched: MemSize=128MB, DataCacheSize=16MB, VertCacheSize=8192.'
            }
        } else {
            Write-Warn2 "app.icf not found next to the exe - skipping engine config tweak."
        }

        # 2) HKCU compatibility flags
        if (-not (Test-Path $layersKey)) { New-Item $layersKey -Force | Out-Null }
        $prev = Get-CompatValue
        if ($prev -and ($prev -ne $compatFlags)) {
            Set-Content -Path $regBak -Value $prev -NoNewline
            Write-Info "previous compatibility flags saved to $regBakName"
        }
        New-ItemProperty -Path $layersKey -Name $exe -Value $compatFlags -PropertyType String -Force | Out-Null
        Write-Ok 'Windows compatibility flags set: fullscreen optimizations OFF, DPI awareness ON.'

        Write-Host ''
        Write-Ok 'Done! Launch Morphopolis and check the result.'
        Write-Info 'Extra (manual): in AMD Adrenalin set "Wait for vertical refresh = Off" for project.exe;'
        Write-Info 'in NVIDIA Control Panel set "Vertical sync = Off" for project.exe.'
    }

    'Undo' {
        Write-Host ''
        if (Test-Path $bak) {
            Copy-Item $bak $icf -Force
            Remove-Item $bak -Force
            Write-Ok 'app.icf restored from backup.'
        } else {
            Write-Warn2 'no app.icf.bak found - engine config left as is.'
        }
        if (Test-Path $regBak) {
            $old = (Get-Content $regBak -Raw).Trim()
            New-ItemProperty -Path $layersKey -Name $exe -Value $old -PropertyType String -Force | Out-Null
            Remove-Item $regBak -Force
            Write-Ok "compatibility flags restored to previous value: $old"
        } else {
            if (Test-Path $layersKey) {
                Remove-ItemProperty -Path $layersKey -Name $exe -ErrorAction SilentlyContinue
            }
            Write-Ok 'compatibility flags removed.'
        }
        Write-Host ''
        Write-Ok 'Undone. The game is back to its original state.'
    }
}
Write-Host ''
