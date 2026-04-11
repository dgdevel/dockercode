#!/usr/bin/env bash

exec docker save dockercode | xz -c > dockercode.tar.xz
