#!/usr/bin/env bash

# Shell into the background container started by bin/start-gui.sh (GUI) or
# bin/start-console.sh (text console), joining the dbus session the entrypoint
# started at boot when in GUI mode. One-off `docker compose run`
# containers are invisible to `docker compose ps`, so look them up by
# compose labels instead.
cid="$(docker ps -q \
  --filter label=com.docker.compose.project=dockercode \
  --filter label=com.docker.compose.service=dockercode | head -n1)"
# fall back to the text-console container started by bin/start-console.sh;
# prefer the GUI one when both are somehow up (they normally exclude each other)
if [ -z "$cid" ]; then
  cid="$(docker ps -q \
    --filter label=com.docker.compose.project=dockercode \
    --filter label=com.docker.compose.service=dockercode-console | head -n1)"
fi

if [ -z "$cid" ]; then
  echo "dockercode is not running (start it with bin/start-gui.sh or bin/start-console.sh)"
  exit 1
fi

exec docker exec -it "$cid" bash -c '
  env_file=/tmp/dockercode-session.env
  if [ "${DOCKERCODE_MODE:-gui}" != console ] && [ ! -f "$env_file" ]; then
    # right after bin/start-gui.sh the entrypoint may still be booting the
    # session (bun updates): give it a moment before falling back
    echo "dockercode: waiting for the boot session..."
    for _ in $(seq 1 30); do
      [ -f "$env_file" ] && break
      sleep 1
    done
  fi
  if [ -f "$env_file" ]; then
    . "$env_file"
  elif [ "${DOCKERCODE_MODE:-gui}" != console ]; then
    echo "dockercode: boot session not up yet, GUI apps would reach the host bus; retry later" >&2
  fi
  exec bash -i
'
