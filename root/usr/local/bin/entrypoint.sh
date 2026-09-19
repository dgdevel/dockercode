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

# expose bun-installed binaries to non-interactive launches too
export PATH="$HOME/.bun/bin:$PATH"

# Contained desktop session
#
# GUI apps reach the *host* session bus through the mounted XDG_RUNTIME_DIR,
# so portal file pickers would be served by the host's xdg-desktop-portal:
# the host picker browses the host filesystem and hands host paths to the
# container app. Electron/Chromium dialogs are portal-only these days (not
# even GTK_USE_PORTAL=0 disables them), so the session gets its own bus and
# portal instead: their picker is a GTK dialog running inside the container,
# browsing only the container filesystem (i.e. /home/coder) and returning
# container paths to the app. Host-bus conveniences (notifications, theme
# following) are traded away; the host bus stays reachable at
# /run/user/<uid>/bus for opt-in use.
host_runtime_dir="$XDG_RUNTIME_DIR"
if command -v dbus-run-session >/dev/null 2>&1; then
  # private runtime dir keeps the contained bus socket and portal state out
  # of the mounted host dir; the compositor's Wayland socket stays reachable
  # through a symlink (X11, the supported path, does not use it)
  runtime=/tmp/dockercode-runtime
  rm -rf "$runtime"
  mkdir -m 700 "$runtime"
  if [ -n "$WAYLAND_DISPLAY" ] && [ -e "$host_runtime_dir/$WAYLAND_DISPLAY" ]; then
    ln -s "$host_runtime_dir/$WAYLAND_DISPLAY" "$runtime/$WAYLAND_DISPLAY"
  fi
  export XDG_RUNTIME_DIR="$runtime"
fi

if [ -f /home/coder/bin/entrypoint_extension.sh ] ; then
  /home/coder/bin/entrypoint_extension.sh
fi

# start the requested app (e.g. opencode or opencode-desktop), or a shell,
# on the contained session bus when one is available
if [ $# -eq 0 ]; then
  set -- bash
fi
if command -v dbus-run-session >/dev/null 2>&1; then
  exec dbus-run-session -- "$@"
fi
exec "$@"
