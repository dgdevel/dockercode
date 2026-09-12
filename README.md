# dockercode

A Docker container for running [opencode](https://opencode.ai) with a preconfigured Arch Linux development environment.

## What's included

- **Base:** Arch Linux
- **User:** `coder` user created at build time with passwordless sudo
- **Dev utilities:** vim, htop, tmux, curl, wget, git, unzip, gzip
- **Networking tools:** tcpdump, bind, iputils, net-tools
- **opencode dependencies:** Node.js, npm, Bun
- **Presets:** `opencode-ai` and `skills` packages are installed and updated automatically on startup
- **GUI:** opencode desktop (`opencode-desktop-bin`, AUR) plus Mesa/fonts, rendered on the host's Wayland session
- **File pickers:** a contained session bus with in-container `xdg-desktop-portal`/`-gtk`, so GUI apps' open/save dialogs browse the container filesystem only and return `/home/coder` paths (host paths are never revealed)
- **AppImages:** FUSE userland (`fuse2`/`fuse3`) + `squashfs-tools`; `/dev/fuse` is passed through when present, with `CAP_SYS_ADMIN` for the mount
- **URLs:** there is no browser in the container; `xdg-open` (and `$BROWSER`) print URLs to the terminal so they can be opened on the host — auth flows that poll for browser completion keep working

## Usage

### Build the image

```sh
bin/build.sh
```

Starts Docker if needed, and builds the image.

### Run the container

```sh
bin/run.sh [command]
```

Starts Docker if needed, and opens an interactive shell (or runs an optional command) inside the container.  
The `homedir/` directory is mounted as the container's `/home/coder` volume, so your work persists across runs.

Port `4096` is forwarded to `localhost:4096`.

### Choose the CLI or the desktop app

Both opencode clients are installed; which one starts is decided when you run the container:

```sh
bin/run.sh                   # interactive shell
bin/run.sh opencode          # opencode CLI
bin/run.sh opencode-desktop  # opencode desktop (GUI)
```

### Desktop apps and Wayland

There is no display server inside the container. Desktop apps are plain Wayland/X11 *clients* that render on your host compositor through the mounted session sockets, so windows appear as native windows in your running desktop session. Requirements and notes:

- Desktop apps run through the host's **XWayland** by default (`ELECTRON_OZONE_PLATFORM_HINT=x11`), using the session's `DISPLAY`/`XAUTHORITY`, which compose passes through — so start the container from an active desktop session.
- Native Wayland is currently broken for Electron apps in the container: the window is created hidden and Electron's `ready-to-show` never fires, so nothing is ever displayed (the GPU process also crash-loops on that path). Test it with `ELECTRON_OZONE_PLATFORM_HINT=wayland`, but expect no window.
- GPU access comes from the `/dev/dri` bind mount plus the host `video`/`render` group GIDs, which `bin/run.sh` passes automatically. Without a usable GPU, apps fall back to software rendering; if the GPU process proves unstable, append `--disable-gpu`.
- The container runs with `seccomp=unconfined` so Chromium/Electron apps can build their sandbox on user namespaces. If you prefer to keep Docker's default seccomp profile, launch desktop apps with `--no-sandbox` instead (e.g. `bin/run.sh opencode-desktop --no-sandbox`).
- Because container apps are real clients of your session compositor, only run trusted software this way — the session sockets are not isolated between clients.

### File pickers stay in the container

Electron/Chromium (including opencode-desktop) implement file dialogs **exclusively** through the XDG desktop portal — `GTK_USE_PORTAL=0` no longer disables them, which is why that experiment just made the dialog disappear. The portal lives on the session bus, and the host's bus is reachable here through the mounted `XDG_RUNTIME_DIR`: without countermeasures the *host's* portal would open the *host's* picker and hand host paths (e.g. `/home/milky/...`) straight to the container app.

To keep host paths out, `entrypoint.sh` gives every container session its own contained desktop session:

- a private session bus (`dbus-run-session`), which overrides `DBUS_SESSION_BUS_ADDRESS` for everything launched in the container,
- an in-container `xdg-desktop-portal` + `xdg-desktop-portal-gtk`, activated on demand over that bus and pinned via `/etc/xdg/xdg-desktop-portal/portals.conf`,
- a private `XDG_RUNTIME_DIR` (`/tmp/dockercode-runtime`), so the contained bus and portal never write into the mounted host runtime dir; the compositor's Wayland socket stays reachable through a symlink (X11 is unaffected).

The portal's file picker is therefore a GTK dialog *running inside the container*: it only sees the container filesystem, opens in `/home/coder`, and returns container paths (`/home/coder/...`) to the app — the host directory behind the `homedir/` bind mount is never revealed.

Trade-off: host session-bus services are no longer reachable, so desktop notifications and host theme following stop working for container apps. The host bus itself remains reachable at `/run/user/<uid>/bus` if you want to opt back in for a specific program.

### Shell into the running container

```sh
bin/shell.sh
```

Opens an interactive bash shell inside the running `dockercode` container.  
Fails with an error if the container is not currently running.

### Clean up

```sh
bin/clean.sh
```

Removes the `dockercode:latest` image and prunes unused Docker data.

### Export the image

```sh
bin/export.sh
```

Exports the built image as a compressed `dockercode.tar.xz` archive in the current directory.

## Project layout

```
bin/          Helper scripts (build, run, shell, clean, export)
homedir/      Persistent home directory mounted at /home/coder
root/         Files copied into the image (entrypoint script)
Dockerfile    Image definition
docker-compose.yml
```
