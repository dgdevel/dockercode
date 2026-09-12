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
