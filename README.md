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
- **Extension points:** via Dockerfile.extension and homedir/bin/entrypoint\_extension.sh to add and customize the container

## Usage

### Build the image

```sh
bin/build.sh
```

Starts Docker if needed, and builds the image.

### Run the container

```sh
bin/start.sh
```

Starts Docker if needed, then starts the container in the background through
its entrypoint (opencode updates and the contained dbus session/portal
daemons run once at boot) and prints its address. It does not attach a
shell: use `bin/shell.sh` for that. The `homedir/` directory is mounted as
the container's `/home/coder` volume, so your work persists across runs.

Port `4096` is not published on the host: it is reachable only on the
container's own IP, which `bin/start.sh` prints at launch (e.g.
`http://172.18.0.2:4096`).

The container keeps running in the background; run `bin/shell.sh` to get
into it, and `bin/stop.sh` to stop it. If the image was rebuilt meanwhile,
`bin/start.sh` detects it and restarts the container on the new image.

### Choose the CLI or the desktop app

Both opencode clients are installed; start them from an attached shell:

```sh
bin/shell.sh                 # attach, then run what you need
opencode                     # opencode CLI
opencode-desktop             # opencode desktop (GUI)
```

### GPU

GUI apps render on the host GPU (AMD): the compose file mounts `/dev/dri`,
adds the host `video`/`render` group GIDs (exported by `bin/start.sh`) to the
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

Opens an interactive bash shell inside the running `dockercode` container,
joined to the dbus session the entrypoint started at boot (so GUI apps
reach the contained portal, not the host one). Fails with an error if the
container is not currently running.

### Stop the container

```sh
bin/stop.sh
```

Stops the background container started by `bin/start.sh`.

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

