#!/usr/bin/env bash

# Stop the background container started by bin/run.sh; the --rm it was
# started with removes the container once it exits. Unquoted on purpose:
# docker stop accepts several ids if more than one is running.
cid="$(docker ps -q \
  --filter label=com.docker.compose.project=dockercode \
  --filter label=com.docker.compose.service=dockercode)"

if [ -z "$cid" ]; then
  echo "dockercode is not running"
  exit 0
fi

docker stop $cid
