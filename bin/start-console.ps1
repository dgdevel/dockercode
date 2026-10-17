# start-console.ps1 - Windows twin of bin/start-console.sh: start the
# text-console-only container in the background. Uses the named ext4 volume
# DOCKERCODE_HOME=dockercode-home instead of the ./homedir bind (NTFS bind
# would be slow, and the nested dockerd writes heavily to /home/coder).

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

function Ensure-Docker {
    # PS 5.1 wraps redirected native stderr into ErrorRecords: with
    # $ErrorActionPreference=Stop a failing `docker info` would throw before
    # $LASTEXITCODE is checked, so relax it around the daemon probes
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        docker info *> $null
        if ($LASTEXITCODE -eq 0) { return }
        Write-Output "dockercode: Docker daemon not reachable, starting Docker Desktop..."
        $dd = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
        if (-not (Test-Path $dd)) {
            throw "Docker Desktop not found at $dd - start Docker manually and retry"
        }
        Start-Process $dd | Out-Null
        $deadline = (Get-Date).AddSeconds(180)
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Seconds 5
            docker info *> $null
            if ($LASTEXITCODE -eq 0) { return }
            Write-Output "  waiting for the Docker engine..."
        }
        throw "Docker engine did not come up within 180s"
    }
    finally {
        $ErrorActionPreference = $prevEap
    }
}

Ensure-Docker

docker system prune -f

# Windows scripts always use the named volume (see header comment); forced
# USER_UID/GID=1000 to match the image's coder user
$env:DOCKERCODE_HOME = 'dockercode-home'
$env:USER_UID = '1000'
$env:USER_GID = '1000'
# no host X/Wayland session to inherit terminal geometry from
$env:TERM = if ($env:WT_SESSION) { 'xterm-256color' } else { 'xterm' }

# refuse to run alongside the GUI container: both entrypoints run `bun add`
# at boot and the shared homedir would have them race on the same
# package.json/lockfile
$guiCid = @(docker ps -q `
    --filter label=com.docker.compose.project=dockercode `
    --filter label=com.docker.compose.service=dockercode)
if ($guiCid.Count -gt 0 -and $guiCid[0]) {
    Write-Output "dockercode GUI container is running (bin/stop.sh or bin/stop.ps1 first: shared homedir makes concurrent boots race)"
    exit 1
}

# Find a console container left running by a previous launch; `docker
# compose ps` does not list one-off `compose run` containers, so look them up
# by compose labels instead
$cid = @(docker ps -q `
    --filter label=com.docker.compose.project=dockercode `
    --filter label=com.docker.compose.service=dockercode-console) |
    Where-Object { $_ } | Select-Object -First 1
if ($cid) {
    # a rebuilt image does not update an already running container: restart it
    # so the next launch runs on the current image, like the old per-launch flow
    $runningImage = docker inspect -f '{{.Image}}' $cid
    $latestImage = docker image inspect -f '{{.Id}}' dockercode:latest
    if ($runningImage -ne $latestImage) {
        Write-Output "dockercode: image changed since launch, restarting container"
        docker stop $cid | Out-Null
        $cid = $null
    }
}

if ($cid) {
    Write-Output "dockercode-console already running (shell in with bin/shell.ps1, stop with bin/stop.ps1)"
    exit 0
}

# Start the container in the background; the entrypoint idles as a keepalive
# (sleep infinity), with no session daemons in console mode
$cid = docker compose run --rm -d dockercode-console | Where-Object { $_ } | Select-Object -First 1
if (-not $cid) { throw "docker compose run failed (exit $LASTEXITCODE)" }

$ip = docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $cid
Write-Output "dockercode-console container started in background (shell in with bin/shell.ps1)"
Write-Output "dockercode-console container IP: $ip"
