#!/usr/bin/env bash

# Shell into the background container started by bin/run.sh. One-off
# `docker compose run` containers are invisible to `docker compose ps`,
# so look them up by compose labels instead.
cid="$(docker ps -q \
  --filter label=com.docker.compose.project=dockercode \
  --filter label=com.docker.compose.service=dockercode | head -n1)"

if [ -z "$cid" ]; then
  echo "dockercode is not running (start it with bin/run.sh)"
  exit 1
fi

exec docker exec -it "$cid" /bin/bash
