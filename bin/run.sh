#!/usr/bin/env bash

docker_active="$(systemctl is-active docker)"

if [ "$docker_active" = inactive ]; then
  sudo systemctl start docker
fi

docker system prune -f

export COLUMNS=$(tput cols)
export LINES=$(tput lines)

exec docker compose run --rm --service-ports dockercode $*

