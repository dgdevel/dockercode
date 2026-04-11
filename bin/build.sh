#!/usr/bin/env bash

docker_active="$(systemctl is-active docker)"

if [ "$docker_active" = inactive ]; then
  sudo systemctl start docker
fi

docker system prune -f

exec docker compose build

