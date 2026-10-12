#!/usr/bin/env bash

# Shell into the background container started by bin/start.sh, joining the
# dbus session the entrypoint started at boot. One-off `docker compose run`
# containers are invisible to `docker compose ps`, so look them up by
# compose labels instead.
cid="$(docker ps -q \
  --filter label=com.docker.compose.project=dockercode \
  --filter label=com.docker.compose.service=dockercode | head -n1)"

if [ -z "$cid" ]; then
  echo "dockercode is not running (start it with bin/start.sh)"
  exit 1
fi

exec docker exec -it "$cid" bash -c '
  env_file=/tmp/dockercode-session.env
  if [ ! -f "$env_file" ]; then
    # right after bin/start.sh the entrypoint may still be booting the
    # session (bun updates): give it a moment before falling back
    echo "dockercode: waiting for the boot session..."
    for _ in $(seq 1 30); do
      [ -f "$env_file" ] && break
      sleep 1
    done
  fi
  if [ -f "$env_file" ]; then
    . "$env_file"
  else
    echo "dockercode: boot session not up yet, GUI apps would reach the host bus; retry later" >&2
  fi
  exec bash -i
'
