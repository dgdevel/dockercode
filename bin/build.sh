#!/usr/bin/env bash

docker_active="$(systemctl is-active docker)"

if [ "$docker_active" = inactive ]; then
  sudo systemctl start docker
fi

docker system prune -f

cp Dockerfile.template Dockerfile
if [ -f Dockerfile.extension ]; then
  perl -i -pe 'BEGIN{local $/; $r=<STDIN>;} s/\QINCLUDED_EXTENSION\E/$r/g' Dockerfile < Dockerfile.extension
else
  sed -i 's/INCLUDED_EXTENSION//g' Dockerfile
fi

exec docker compose build

