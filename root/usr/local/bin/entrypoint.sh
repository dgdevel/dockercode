#!/usr/bin/env bash

# entrypoint.sh will run as coder user

sudo chown -R coder:users /home/coder
# user setup
if [ ! -f /home/coder/.bashrc ] ; then
  find /etc/skel/ -type f -exec cp '{}' /home/coder \;
  echo 'PATH=$PATH:$HOME/node_modules/.bin/' >> /home/coder/.bashrc
fi

cd /home/coder

# update opencode
bun add opencode-ai
bun add skills

# launch user shell
bash $*
