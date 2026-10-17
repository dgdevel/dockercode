# stop.ps1 - Windows twin of bin/stop.sh: stop the background container
# started by bin/start-console.ps1 (or the GUI one if it is up); the --rm
# they were started with removes the container once it exits.

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

# force a real array even with a single container: a bare string would be
# char-splatted by `docker stop @cids` (each char its own argument)
$cids = @(
    docker ps -q `
        --filter label=com.docker.compose.project=dockercode |
    Where-Object { $_ }
)

if ($cids.Count -eq 0) {
    Write-Output "dockercode is not running"
    exit 0
}

docker stop @cids
exit $LASTEXITCODE
