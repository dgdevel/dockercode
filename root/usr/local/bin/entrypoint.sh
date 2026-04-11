#!/usr/bin/env bash
# user setup
if ! id coder 2>/dev/null; then
  useradd -d /home/coder -M -s /usr/bin/bash coder
  echo 'coder ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers
  find /etc/skel/ -type f -exec cp '{}' /home/coder \;
  echo 'PATH=$PATH:$HOME/node_modules/.bin/' >> /home/coder/.bashrc
  chown -R coder:users /home/coder
fi

cd /home/coder

# update opencode
sudo -u coder bun add opencode-ai
sudo -u coder bun add skills

# launch user shell
sudo -u coder bash $*
