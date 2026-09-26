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

# Find a container left running by a previous launch; `docker compose ps`
# does not list one-off `compose run` containers, so look them up by label
cid="$(docker ps -q \
  --filter label=com.docker.compose.project=dockercode \
  --filter label=com.docker.compose.service=dockercode | head -n1)"

if [ -n "$cid" ]; then
  # a rebuilt image does not update an already running container: restart it
  # so the next shell runs on the current image, like the old per-launch flow
  if [ "$(docker inspect -f '{{.Image}}' "$cid")" != "$(docker image inspect -f '{{.Id}}' dockercode:latest)" ]; then
    echo "dockercode: image changed since launch, restarting container"
    docker stop "$cid"
    cid=""
  fi
fi

if [ -z "$cid" ]; then
  # Start the container in the background. `sleep infinity` is a bare
  # keepalive with the entrypoint bypassed, so the entrypoint side (opencode
  # updates, contained dbus session) runs exactly once, for the interactive
  # shell exec'd below, instead of twice.
  cid="$(docker compose run --rm -d --entrypoint sleep dockercode infinity)"
fi

ip="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$cid")"
echo "dockercode container IP: ${ip}"

# Open the interactive shell (or run the given command) through the
# entrypoint, which wraps it in the contained dbus session. docker exec
# allocates its own pty, so TUI apps work even though the background
# container was started detached (compose skips the service tty then).
exec docker exec -it "$cid" /usr/local/bin/entrypoint.sh "$@"
