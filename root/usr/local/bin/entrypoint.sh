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
# oc2
bun add @opencode/cli
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
  # through a symlink (X11, the supported path, does not use it).
  # The entrypoint runs once per container (bin/start.sh starts it detached,
  # shells attach later with bin/shell.sh), so $$ (the container's PID 1)
  # just keeps boots distinct while rm -rf clears any stale previous boot.
  runtime="/tmp/dockercode-runtime.$$"
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

# run the requested app (e.g. opencode), or idle as a keepalive: bin/start.sh
# starts the container detached through this entrypoint, so with no args it
# must hold the container (and its daemons) up; shells attach afterwards
# with bin/shell.sh without re-running this script
if [ $# -eq 0 ]; then
  set -- sleep infinity
fi
if command -v dbus-run-session >/dev/null 2>&1; then
  # publish the contained session's addresses (private runtime dir, session
  # bus) so attached shells can join this session instead of the host bus
  exec dbus-run-session -- bash -c '
    { printf "export XDG_RUNTIME_DIR=%q\n" "$XDG_RUNTIME_DIR"
      printf "export DBUS_SESSION_BUS_ADDRESS=%q\n" "$DBUS_SESSION_BUS_ADDRESS"
    } > /tmp/dockercode-session.env
    exec "$@"
  ' entrypoint "$@"
fi
exec "$@"
