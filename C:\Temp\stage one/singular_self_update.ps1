# Singular Windows Silent Self-Updater
$targetPid = 2240760
$appDir = "C:\Apps\singular app"
$srcDir = "C:\Temp\stage one"
$oldExeName = "singular.exe"

# 1. Wait for the old process to fully exit (max 6 seconds)
for ($i = 0; $i -lt 30; $i++) {
    $proc = Get-Process -Id $targetPid -ErrorAction SilentlyContinue
    if (-not $proc -or $proc.HasExited) { break }
    Start-Sleep -Milliseconds 200
}

# Force terminate any lingering instance of the target process
$proc = Get-Process -Id $targetPid -ErrorAction SilentlyContinue
if ($proc -and -not $proc.HasExited) {
    Stop-Process -Id $targetPid -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 300
}

# Ensure file handles are fully released
Start-Sleep -Milliseconds 400

# 2. Backup or rename old executable files if locked
$oldExePath = Join-Path $appDir $oldExeName
if (Test-Path $oldExePath) {
    try {
        Move-Item -Path $oldExePath -Destination "$oldExePath.old" -Force -ErrorAction SilentlyContinue
    } catch {}
}

# 3. Copy staged files into destination directory with retry loop
for ($attempt = 1; $attempt -le 5; $attempt++) {
    try {
        Copy-Item -Path (Join-Path $srcDir "*") -Destination $appDir -Recurse -Force -ErrorAction Stop
        break
    } catch {
        Start-Sleep -Milliseconds 600
    }
}

# Clean up legacy sb_ui.exe and old backup binaries
if (Test-Path (Join-Path $appDir "singular.exe")) {
    Remove-Item -Path (Join-Path $appDir "sb_ui.exe") -Force -ErrorAction SilentlyContinue
    Remove-Item -Path (Join-Path $appDir "sb_ui.exe.old") -Force -ErrorAction SilentlyContinue
    Remove-Item -Path (Join-Path $appDir "singular.exe.old") -Force -ErrorAction SilentlyContinue
}

# Remove updater script from destination if copied over
$copiedScript = Join-Path $appDir "singular_self_update.ps1"
if (Test-Path $copiedScript) {
    Remove-Item -Path $copiedScript -Force -ErrorAction SilentlyContinue
}

# 4. Resolve and launch the new executable
$launchTarget = Join-Path $appDir "singular.exe"
if (-not (Test-Path $launchTarget)) {
    $launchTarget = Join-Path $appDir $oldExeName
}

if (Test-Path $launchTarget) {
    Start-Process -FilePath $launchTarget -WorkingDirectory $appDir
}

# 5. Clean up temporary staging directory
Start-Sleep -Seconds 1
Remove-Item -Path $srcDir -Recurse -Force -ErrorAction SilentlyContinue
