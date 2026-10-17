# shell.ps1 - Windows twin of bin/shell.sh: shell into the background
# container started by bin/start-console.ps1 (console) or bin/start-gui.sh
# (GUI, from WSL/Linux). One-off `docker compose run` containers are
# invisible to `docker compose ps`, so look them up by compose labels.

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

# prefer the GUI one when both are somehow up (they normally exclude each
# other), fall back to the text-console container
$cid = @(docker ps -q `
    --filter label=com.docker.compose.project=dockercode `
    --filter label=com.docker.compose.service=dockercode) |
    Where-Object { $_ } | Select-Object -First 1
if (-not $cid) {
    $cid = @(docker ps -q `
        --filter label=com.docker.compose.project=dockercode `
        --filter label=com.docker.compose.service=dockercode-console) |
        Where-Object { $_ } | Select-Object -First 1
}

if (-not $cid) {
    Write-Output "dockercode is not running (start it with bin/start-gui.sh or bin/start-console.ps1)"
    exit 1
}

# same inner bootstrap as bin/shell.sh: wait for the boot session env in GUI
# mode, then drop into an interactive bash
$inner = @'
env_file=/tmp/dockercode-session.env
if [ "${DOCKERCODE_MODE:-gui}" != console ] && [ ! -f "$env_file" ]; then
  echo "dockercode: waiting for the boot session..."
  for _ in $(seq 1 30); do
    [ -f "$env_file" ] && break
    sleep 1
  done
fi
if [ -f "$env_file" ]; then
  . "$env_file"
elif [ "${DOCKERCODE_MODE:-gui}" != console ]; then
  echo "dockercode: boot session not up yet, GUI apps would reach the host bus; retry later" >&2
fi
exec bash -i
'@

docker exec -it $cid bash -c $inner
exit $LASTEXITCODE
