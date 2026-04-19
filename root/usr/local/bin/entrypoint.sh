#!/usr/bin/env bash

# entrypoint.sh will run as coder user

# user setup
if [ ! -f /home/coder/.bashrc ] ; then
  sudo chown -R coder:coder /home/coder
  find /etc/skel/ -type f -exec cp '{}' /home/coder \;
  echo 'PATH=$PATH:$HOME/.bun/bin/' >> /home/coder/.bashrc
fi

cd /home/coder

# update opencode
bun add opencode-ai
bun add skills
bun add add-mcp

# launch user shell
bash $*
