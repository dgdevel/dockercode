# dockercode

A Docker container for running [opencode](https://opencode.ai) with a preconfigured Arch Linux development environment.

## What's included

- **Base:** Arch Linux
- **User:** `coder` user created at build time with passwordless sudo
- **Dev utilities:** vim, htop, tmux, curl, wget, git, unzip, gzip
- **Networking tools:** tcpdump, bind, iputils, net-tools
- **opencode dependencies:** Node.js, npm, Bun
- **Presets:** `opencode-ai` and `skills` packages are installed and updated automatically on startup
- **GUI:** opencode-desktop (`opencode-desktop-bin`, AUR) and support for various apps (provides FUSE, xdg-open wrapper, xdg-desktop-portal support - tested using z.ai zcode AppImage)
- **Docker-in-docker:** contained rootful `dockerd` started by the entrypoint, CLI (`docker`, `docker compose`, `docker buildx`) usable without sudo
- **Extension points:** via Dockerfile.extension and homedir/bin/entrypoint\_extension.sh to add and customize the container

## Usage

### Build the image

```sh
bin/build.sh
```

Starts Docker if needed, and builds the image.

### Run the container

```sh
bin/start-gui.sh
```

Starts Docker if needed, then starts the container in the background through
its entrypoint (opencode updates and the contained dbus session/portal
daemons run once at boot) and prints its address. It does not attach a
shell: use `bin/shell.sh` for that. The `homedir/` directory is mounted as
the container's `/home/coder` volume, so your work persists across runs.

Port `4096` is not published on the host: it is reachable only on the
container's own IP, which `bin/start-gui.sh` prints at launch (e.g.
`http://172.18.0.2:4096`).

The container keeps running in the background; run `bin/shell.sh` to get
into it, and `bin/stop.sh` to stop it. If the image was rebuilt meanwhile,
`bin/start-gui.sh` detects it and restarts the container on the new image.

### Run the text-console-only container

```sh
bin/start-console.sh        # Linux
bin\start-console.ps1       # Windows (Docker Desktop + WSL2, console mode only)
```

Same image, same `homedir/` volume, but started from the
`dockercode-console` compose service: no GUI wiring at all - no host
display/GPU/device mounts - and the entrypoint skips the contained dbus
session/portal (`DOCKERCODE_MODE=console`); it still runs privileged for
docker-in-docker. Use it when only terminal applications (opencode CLI,
tmux, etc.) are needed: no GUI wiring and no dependency on the host's
X/Wayland session. `bin/shell.sh` and `bin/stop.sh` work on it the same
way. The
GUI and console containers share `homedir/`, so `bin/start-console.sh`
refuses to run while the GUI one is up (their entrypoints would race on
the same bun packages); stop one before starting the other.

### Windows (console mode only)

On Windows the repo runs the text-console container through PowerShell twins
of the bash scripts, with these differences from Linux:

- GUI mode stays Linux-only for now (no host X/Wayland session to wire).
- `bin/build.ps1`, `bin/start-console.ps1`, `bin/shell.ps1`, `bin/stop.ps1`,
  `bin/clean-image.ps1` mirror the `.sh` counterparts; no `systemctl` - they
  start Docker Desktop themselves and wait for the engine.
- The homedir is NOT the `./homedir` bind: the scripts set
  `DOCKERCODE_HOME=dockercode-home`, so compose mounts the named ext4 volume
  `dockercode-home` at `/home/coder` instead (the compose switch
  `${DOCKERCODE_HOME:-./homedir}` keeps Linux behavior unchanged). A named
  volume is much faster than an NTFS bind for the nested dockerd writes,
  but it is not browsable in Explorer: access files only through
  `bin/shell.ps1` or `docker cp`. Wipe it with
  `docker volume rm dockercode-home`.
- `USER_UID`/`USER_GID` are forced to 1000 (the Git Bash `id -u` returns a
  Windows SID number, meaningless inside the container).
- If Docker Desktop was installed with the legacy vhdx layout, the disk
  image only ever grows. `bin/compact-vhdx.ps1` quits Docker Desktop, runs
  `wsl --shutdown`, and compacts the vhdx (Optimize-VHD on Pro, diskpart
  fallback on Home), then restarts Docker Desktop. Run `bin/stop.ps1`
  first: running containers are killed by the shutdown.

```powershell
bin\build.ps1
bin\start-console.ps1
bin\shell.ps1               # interactive bash inside
bin\stop.ps1
bin\compact-vhdx.ps1        # reclaim vhdx disk space
```


### Docker-in-docker

Both containers run privileged and their entrypoint boots a contained
`dockerd` (rootful) with its data root at `~/.local/share/docker` on the
`homedir/` volume: `docker`, `docker compose`, and `docker buildx` work
inside, nested containers are invisible to the host daemon, and nested
images/containers/volumes survive restarts and rebuilds. `coder` talks to
the daemon socket through its `docker` group membership - no sudo needed.

Notes:

- The vfs storage driver is used (overlay2 nested on the host overlay
  filesystem is unreliable); image pulls and builds inside are slower.
- The daemon lives only as long as the container: `bin/stop.sh` stops it
  and all nested containers with it (data persists, running state does not).
- Nested containers get their own network through the contained daemon;
  published ports live inside the dockercode container, not on the host.
- `privileged` makes the container host-root-equivalent, same as running
  dockerd anywhere without care: trust what you run inside.

### Choose the CLI or the desktop app

Both opencode clients are installed; start them from an attached shell:

```sh
bin/shell.sh                 # attach, then run what you need
opencode                     # opencode CLI
opencode-desktop             # opencode desktop (GUI)
```

### GPU

GUI apps render on the host GPU (AMD): the compose file mounts `/dev/dri`,
adds the host `video`/`render` group GIDs (exported by `bin/start-gui.sh`) to the
container user, and allows DRM devices (char major 226) in the device cgroup.
The image ships the full Mesa userspace stack: OpenGL (`radeonsi`), Vulkan
(`RADV`) and VA-API video decode.

Verify hardware acceleration inside the container with:

```sh
eglinfo -B -p surfaceless   # renderer should name the GPU, not llvmpipe
vulkaninfo --summary        # RADV should list the AMD GPU
glxinfo -B                  # with the GUI running (X11)
```

If the host has no `/dev/dri`, Docker mounts an empty directory and apps fall
back to software rendering. NVIDIA GPUs would need the nvidia-container-toolkit
on the host and `gpus: all` in `docker-compose.yml` instead.

### Shell into the running container

```sh
bin/shell.sh
```

Opens an interactive bash shell inside the running `dockercode` (or
`dockercode-console`) container, joined to the dbus session the entrypoint
started at boot (so GUI apps reach the contained portal, not the host one).
Fails with an error if no container is currently running.

### Stop the container

```sh
bin/stop.sh
```

Stops the background container started by `bin/start-gui.sh` or
`bin/start-console.sh`.

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

