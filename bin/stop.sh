#!/usr/bin/env bash

# Stop the background container started by bin/start-gui.sh or
# bin/start-console.sh; the --rm they were started with removes the
# container once it exits. Unquoted on purpose:
# docker stop accepts several ids if more than one is running.
cid="$(docker ps -q \
  --filter label=com.docker.compose.project=dockercode)"

if [ -z "$cid" ]; then
  echo "dockercode is not running"
  exit 0
fi

docker stop $cid
