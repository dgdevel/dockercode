#!/usr/bin/env bash

# Start the GUI container in the background through its entrypoint (opencode
# updates + contained dbus session/portal daemons) and exit; shells attach
# afterwards with bin/shell.sh.

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

# Find a container left running by a previous launch; `docker compose ps`
# does not list one-off `compose run` containers, so look them up by label
cid="$(docker ps -q \
  --filter label=com.docker.compose.project=dockercode \
  --filter label=com.docker.compose.service=dockercode | head -n1)"

if [ -n "$cid" ]; then
  # a rebuilt image does not update an already running container: restart it
  # so the next launch runs on the current image, like the old per-launch flow
  if [ "$(docker inspect -f '{{.Image}}' "$cid")" != "$(docker image inspect -f '{{.Id}}' dockercode:latest)" ]; then
    echo "dockercode: image changed since launch, restarting container"
    docker stop "$cid"
    cid=""
  fi
fi

if [ -n "$cid" ]; then
  echo "dockercode already running (shell in with bin/shell.sh, stop with bin/stop.sh)"
  exit 0
fi

# Start the container in the background; the entrypoint idles as a keepalive
# (sleep infinity) on its contained dbus session, so the session daemons
# (bus, portal) stay up for the whole container lifetime.
cid="$(docker compose run --rm -d dockercode)"

ip="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$cid")"
echo "dockercode container started in background (shell in with bin/shell.sh)"
echo "dockercode container IP: ${ip}"
