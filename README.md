# dockercode

A Docker container for running [opencode](https://opencode.ai) with a preconfigured Arch Linux development environment.

## What's included

- **Base:** Arch Linux
- **Dev utilities:** vim, htop, tmux, curl, wget, git, unzip, gzip
- **Networking tools:** tcpdump, bind, iputils, net-tools
- **opencode dependencies:** Node.js, npm, Bun
- **Presets:** `opencode-ai` and `skills` packages are installed and updated automatically on startup

## Usage

### Build the image

```sh
bin/build.sh
```

Starts Docker if needed, prunes unused data, and builds the image via `docker compose build`.

### Run the container

```sh
bin/run.sh [command]
```

Starts Docker if needed, sets terminal dimensions, and opens an interactive shell (or runs an optional command) inside the container. The `homedir/` directory is mounted as the container's `/home/coder` volume, so your work persists across runs.

Port `4096` is forwarded to `localhost:4096`.

### Export the image

```sh
bin/export.sh
```

Exports the built image as a compressed `dockercode.tar.xz` archive in the current directory.

## Project layout

```
bin/          Helper scripts (build, run, export)
homedir/      Persistent home directory mounted at /home/coder
root/         Files copied into the image (entrypoint script)
Dockerfile    Image definition
docker-compose.yml
```
