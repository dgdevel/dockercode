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
#
# NOTE: the script is passed base64-encoded. Windows PowerShell 5.1 mangles
# multiline arguments given to native commands (it strips the embedded
# double quotes and squashes the newlines), so feeding $inner straight to
# `docker exec ... bash -c $inner` makes bash receive a truncated one-liner
# and die with "syntax error: unexpected end of file". base64 is immune to
# that, and `bash -c` on the decoder line takes over the exec'd TTY via the
# trailing `exec bash -i` inside $inner.
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

# decode-and-run via base64: see NOTE above. `base64 -d` (coreutils) exists
# in the image; [Convert]::ToBase64String emits one line, no embedded spaces.
# The script is fed through process substitution (<(...)), NOT a pipe: with
# `printf ... | base64 -d | bash` the last bash reads the script from stdin
# (the pipe), so the inner `exec bash -i` inherits that already-EOF pipe and
# dies at once, as if Ctrl+D was pressed
$payload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($inner))
docker exec -it $cid bash -c "exec bash <(printf %s $payload | base64 -d)"
exit $LASTEXITCODE
