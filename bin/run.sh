#!/usr/bin/env bash

docker_active="$(systemctl is-active docker)"

if [ "$docker_active" = inactive ]; then
  sudo systemctl start docker
fi

docker system prune -f

export COLUMNS=$(tput cols)
export LINES=$(tput lines)

# GUI wiring: match the host user and pass the host GPU group GIDs to compose
export USER_UID="${USER_UID:-$(id -u)}"
export USER_GID="${USER_GID:-$(id -g)}"
export VIDEO_GID="$(getent group video | cut -d: -f3)"
export RENDER_GID="$(getent group render | cut -d: -f3)"

exec docker compose run --rm --service-ports dockercode $*

