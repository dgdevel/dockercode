# clean-image.ps1 - Windows twin of bin/clean-image.sh: remove the built
# image and prune unused Docker data. Note: the dockercode-home volume holds
# the persistent homedir (including the nested dockerd data root); it is
# deliberately NOT removed here. To wipe it too: docker volume rm dockercode-home

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

docker rmi dockercode:latest
docker system prune -f
