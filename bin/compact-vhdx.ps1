# compact-vhdx.ps1 - reclaim disk space from the Docker Desktop WSL2 vhdx.
# Docker never shrinks the vhdx on its own: deleted files leave holes that
# keep the file at its high-water mark. This script:
#   1. self-elevates to administrator (required to compact a vhdx)
#   2. quits Docker Desktop and shuts down WSL (must be attached nowhere)
#   3. locates the Docker Desktop vhdx (new disk\docker_data.vhdx layout or
#      legacy data\ext4.vhdx)
#   4. compacts it: Optimize-VHD (Hyper-V, Win Pro) or diskpart fallback
#   5. reports size before/after
# Run bin/stop.ps1 first: running containers are killed by step 2.

param(
    # restart Docker Desktop after compacting (default: yes)
    [switch]$NoRestart
)

$ErrorActionPreference = 'Stop'

# --- 1. self-elevate ---------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $elevArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath)
    if ($NoRestart) { $elevArgs += '-NoRestart' }
    Start-Process powershell -Verb RunAs -Wait -ArgumentList $elevArgs
    exit 0
}

# --- 2. stop Docker Desktop + WSL -------------------------------------------
Write-Output "dockercode: quitting Docker Desktop..."
$ddProc = Get-Process 'Docker Desktop' -ErrorAction SilentlyContinue
if ($ddProc) {
    $ddProc | Stop-Process -Force
    Start-Sleep -Seconds 5
}
# com.docker.backend etc. also lock the vhdx
Get-Process 'com.docker.*' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Output "dockercode: shutting down WSL..."
wsl --shutdown
Start-Sleep -Seconds 5

# --- 3. locate the vhdx ------------------------------------------------------
$candidates = @(
    (Join-Path $env:LOCALAPPDATA 'Docker\wsl\disk\docker_data.vhdx'),  # new layout
    (Join-Path $env:LOCALAPPDATA 'Docker\wsl\data\ext4.vhdx')         # legacy layout
)
$vhdx = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $vhdx) {
    throw "no Docker Desktop vhdx found in $($env:LOCALAPPDATA)\Docker\wsl (disk\docker_data.vhdx or data\ext4.vhdx)"
}

$before = (Get-Item $vhdx).Length
Write-Output ("dockercode: compacting {0}" -f $vhdx)
Write-Output ("  size before: {0:N1} GB" -f ($before / 1GB))

# --- 4. compact --------------------------------------------------------------
if (Get-Command Optimize-VHD -ErrorAction SilentlyContinue) {
    # Hyper-V module (Pro/Enterprise): one call, no attach
    Optimize-VHD -Path $vhdx -Mode Full
}
else {
    # Home edition fallback: diskpart script file
    $script = Join-Path $env:TEMP 'dockercode-compact.txt'
    $lines = @(
        "select vdisk file=`"$vhdx`""
        "attach vdisk readonly"
        "compact vdisk"
        "detach vdisk"
    )
    Set-Content -Path $script -Value $lines -Encoding ascii
    diskpart /s $script
    if ($LASTEXITCODE -ne 0) { throw "diskpart compact failed (exit $LASTEXITCODE)" }
}

$after = (Get-Item $vhdx).Length
Write-Output ("  size after:  {0:N1} GB (freed {1:N1} GB)" -f ($after / 1GB), (($before - $after) / 1GB))

# --- 5. restart --------------------------------------------------------------
if (-not $NoRestart) {
    Write-Output "dockercode: starting Docker Desktop again..."
    $dd = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
    if (Test-Path $dd) { Start-Process $dd }
}
