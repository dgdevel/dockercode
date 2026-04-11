#!/usr/bin/env sh

image="dockercode:latest"
ID="$(docker ps --format json | jq "select(.Image=\"$image\") .ID" --raw-output)"

if [[ "$ID" = "" ]]; then
  echo "Image $image not running"
  exit 1
fi
docker exec -i -t "$ID" /bin/bash

