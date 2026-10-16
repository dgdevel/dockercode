#!/usr/bin/env bash

# Start the text-console-only container in the background: same image and
# homedir as bin/start-gui.sh, but the dockercode-console compose service has no
# GUI wiring (host display/GPU/device mounts, extra capabilities) and
# DOCKERCODE_MODE=console makes the entrypoint skip the contained dbus
# session/portal. Shells attach afterwards with bin/shell.sh.

docker_active="$(systemctl is-active docker)"

if [ "$docker_active" = inactive ]; then
  sudo systemctl start docker
fi

docker system prune -f

export COLUMNS=$(tput cols)
export LINES=$(tput lines)

# refuse to run alongside the GUI container: both entrypoints run `bun add`
# at boot and the shared homedir mount would have them race on the same
# package.json/lockfile
gui_cid="$(docker ps -q \
  --filter label=com.docker.compose.project=dockercode \
  --filter label=com.docker.compose.service=dockercode | head -n1)"
if [ -n "$gui_cid" ]; then
  echo "dockercode GUI container is running (bin/stop.sh first: shared homedir makes concurrent boots race)"
  exit 1
fi

# Find a console container left running by a previous launch; `docker compose
# ps` does not list one-off `compose run` containers, so look them up by label
cid="$(docker ps -q \
  --filter label=com.docker.compose.project=dockercode \
  --filter label=com.docker.compose.service=dockercode-console | head -n1)"

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
  echo "dockercode-console already running (shell in with bin/shell.sh, stop with bin/stop.sh)"
  exit 0
fi

# Start the container in the background; the entrypoint idles as a keepalive
# (sleep infinity), with no session daemons in console mode
cid="$(docker compose run --rm -d dockercode-console)"

ip="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$cid")"
echo "dockercode-console container started in background (shell in with bin/shell.sh)"
echo "dockercode-console container IP: ${ip}"
