<#
Coc Coc Browser Online Silent Installer
- Downloads & installs silently
- Downloads online tweaks from this fork
- Disables auto-update & crash reporter
- Creates clean shortcuts
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$OnlineInstallerUrl = "https://coccoc.33166099.xyz"
$RawBaseUrl = "https://raw.githubusercontent.com/dh6k/coccoc-debloat-personal/refs/heads/main"

function Resolve-CocCocBrowserPath {
    $candidates = @(
        "${env:ProgramFiles}\CocCoc\Browser\Application\browser.exe",
        "${env:ProgramFiles(x86)}\CocCoc\Browser\Application\browser.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $null
}

function Resolve-CocCocVersionDir([string]$browserPath) {
    if (-not $browserPath) {
        return $null
    }

    $applicationDir = Split-Path -Parent $browserPath
    if (-not (Test-Path -LiteralPath $applicationDir)) {
        return $null
    }

    Get-ChildItem -LiteralPath $applicationDir -Directory -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -match '^\d+\.\d+\.\d+\.\d+$' -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "browser.dll"))
        } |
        Sort-Object { [version]$_.Name } -Descending |
        Select-Object -First 1
}

function Invoke-CocCocMv2Patch([string]$browserPath) {
    if (-not $browserPath) {
        Write-Host "Skipping MV2 patch because installed browser.exe was not found." -ForegroundColor Yellow
        return
    }

    $versionDir = Resolve-CocCocVersionDir -browserPath $browserPath
    if (-not $versionDir) {
        Write-Host "Skipping MV2 patch because no Chromium version folder with browser.dll was found." -ForegroundColor Yellow
        return
    }

    Get-Process -Name "browser" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    $mv2Target = Join-Path $versionDir.FullName "mv2.ps1"
    $browserDll = Join-Path $versionDir.FullName "browser.dll"

    try {
        Invoke-WebRequest -Uri "$RawBaseUrl/mv2.ps1" -OutFile $mv2Target -UseBasicParsing -TimeoutSec 15
    }
    catch {
        Write-Host "Skipping MV2 patch because mv2.ps1 could not be downloaded." -ForegroundColor Yellow
        return
    }

    Write-Host "`nApplying Manifest V2 patch in $($versionDir.FullName)..." -ForegroundColor Cyan
    $mv2Process = Start-Process -FilePath "powershell.exe" -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-NonInteractive",
        "-File", "`"$mv2Target`"",
        "-dll", "`"$browserDll`"",
        "-NoPause"
    ) -WorkingDirectory $versionDir.FullName -Wait -PassThru -NoNewWindow

    if ($mv2Process.ExitCode -ne 0) {
        Write-Host "Manifest V2 patch failed with exit code $($mv2Process.ExitCode)." -ForegroundColor Red
        exit $mv2Process.ExitCode
    }
}

# Require Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-Command", "irm $OnlineInstallerUrl | iex"
    ) -Verb RunAs
    exit
}

Clear-Host
Write-Host "Coc Coc Browser Online Installer v1.2.4" -BackgroundColor DarkGreen
Write-Host "`nStarting download and installation..." -ForegroundColor Cyan

# Kill processes
@("browser", "CocCocUpdate", "CocCocCrashHandler*") | ForEach-Object {
    Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

# Clean old installation
@("${env:ProgramFiles}\CocCoc", "${env:ProgramFiles(x86)}\CocCoc") | ForEach-Object {
    if (Test-Path $_) {
        takeown /F $_ /R /A /D Y 2>&1 | Out-Null
        icacls $_ /grant:r "Administrators:F" /T /C 2>&1 | Out-Null
        Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Download & install
$installer = "$env:TEMP\coccoc.exe"
$urls = @(
    "https://files.coccoc.com/browser/x64/coccoc_standalone_en.exe",
    "https://files2.coccoc.com/browser/x64/coccoc_en_machine.exe"
)

foreach ($url in $urls) {
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing -TimeoutSec 30
        break
    }
    catch { continue }
}

Start-Process -FilePath $installer -ArgumentList "/silent /install" -Wait

$browserPath = Resolve-CocCocBrowserPath
Invoke-CocCocMv2Patch -browserPath $browserPath

# Disable updater & crash handler
Get-Item "${env:ProgramFiles}\CocCoc\Update\*\CocCocCrashHandler*.exe", "${env:ProgramFiles(x86)}\CocCoc\Update\*\CocCocCrashHandler*.exe", "${env:ProgramFiles}\CocCoc\Update\CocCocUpdate.exe", "${env:ProgramFiles(x86)}\CocCoc\Update\CocCocUpdate.exe" -ErrorAction SilentlyContinue | ForEach-Object {
    Get-Process -Name $_.BaseName -ErrorAction SilentlyContinue | Stop-Process -Force
    $disabled = $_.FullName + ".disabled"
    Rename-Item -Path $_.FullName -NewName $disabled -Force -ErrorAction SilentlyContinue
    New-Item -Path $_.FullName -ItemType File -Force | Out-Null
    (Get-Item $_.FullName -ErrorAction SilentlyContinue).Attributes = "ReadOnly, Hidden, System"
}

# Remove scheduled tasks
Get-ScheduledTask -TaskName "CocCoc*" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

# Apply registry tweaks
try {
    $reg = "$env:TEMP\debloat.reg"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/dh6k/coccoc-debloat-personal/refs/heads/main/coccoc-debloat.reg" -OutFile $reg -UseBasicParsing -TimeoutSec 15
    Start-Process "regedit.exe" -ArgumentList "/s `"$reg`"" -Wait -NoNewWindow
    Remove-Item $reg -ErrorAction SilentlyContinue
} catch {}

# Create shortcuts
$browserPath = Resolve-CocCocBrowserPath

if ($browserPath -and (Test-Path -LiteralPath $browserPath)) {
    # Remove old shortcuts from ALL locations
    @(
        [Environment]::GetFolderPath("Desktop"),
        [Environment]::GetFolderPath("CommonDesktopDirectory"),
        [Environment]::GetFolderPath("Programs"),
        [Environment]::GetFolderPath("CommonPrograms")
    ) | ForEach-Object {
        if (Test-Path $_) {
            Get-ChildItem "$_\Cốc Cốc.lnk" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
     #       Get-ChildItem "$_\*CocCoc*.lnk" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
     #       Get-ChildItem "$_\*Coc Coc*.lnk" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }

    # Create new shortcuts
    @([Environment]::GetFolderPath("Desktop"), [Environment]::GetFolderPath("CommonPrograms")) | ForEach-Object {
        $WshShell = New-Object -ComObject WScript.Shell
        $temp = "$_\temp.lnk"
        $final = "$_\Cốc Cốc.lnk"

        $shortcut = $WshShell.CreateShortcut($temp)
        $shortcut.TargetPath = $browserPath
        $shortcut.Arguments = "--no-first-run --no-default-browser-check --disable-features=CocCocSplitView,SidePanel --profile-directory=Default"
        $shortcut.IconLocation = "$browserPath,0"
        $shortcut.Save()
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WshShell) | Out-Null

        # Rename temp to final name and cleanup
        if (Test-Path $temp) {
            Rename-Item $temp $final -ErrorAction SilentlyContinue
        }
        # Remove temp file if rename failed
        Remove-Item $temp -ErrorAction SilentlyContinue
    }
}

# Cleanup
Remove-Item $installer -ErrorAction SilentlyContinue

Write-Host "`nCoc Coc installation completed!" -BackgroundColor DarkGreen

Write-Host "`nAutomatic updates are completely disabled." -ForegroundColor Yellow
Write-Host "Recommendation: Restart your computer to apply all changes." -ForegroundColor Yellow

Write-Host "`nNOTICE: To update Coc Coc when needed, please:" -ForegroundColor Cyan -BackgroundColor DarkGreen
Write-Host "1. Open PowerShell with Administrator privileges" -ForegroundColor White
Write-Host "2. Run the following command: irm https://coccoc.33166099.xyz | iex" -ForegroundColor Yellow
Write-Host "3. Wait for the installation process to complete" -ForegroundColor White
