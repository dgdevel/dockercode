# dockercode: Windows console-mode support (plan)

Goal: same repo runs console-mode container (`dockercode-console` service) on
Windows (Docker Desktop, WSL2 backend) with fast homedir via named docker
volume. GUI mode stays Linux-only for now.

## Decisions

- Windows scripts are PowerShell (`bin/*.ps1`), Windows PowerShell 5.1
  compatible (no ternary, no `??`, no `-AsPlainText` assumptions).
- Bash scripts unchanged, still used on Linux.
- `homedir` source switchable via env `DOCKERCODE_HOME`:
  - Linux default: `./homedir` bind mount (unchanged behavior)
  - Windows: named volume `dockercode-home` (ext4 in Docker Desktop vhdx)
  - named volume declared in top-level `volumes:` (declaring unused volume is
    harmless on Linux)
- Windows scripts force `USER_UID=1000`, `USER_GID=1000`.
- Windows scripts never call systemctl; they ensure Docker is up by launching
  `"C:\Program Files\Docker\Docker\Docker Desktop.exe"` if `docker info`
  fails, then poll up to ~120s.
- `.gitattributes` pins LF for `*.sh`, `Dockerfile*`, `root/**`, `*.conf`
  (CRLF in entrypoint.sh breaks the container: `/usr/bin/env: 'bash\r'`).
  `*.ps1` get CRLF.
- vhdx compaction (bin/compact-vhdx.ps1):
  1. self-elevate admin
  2. quit Docker Desktop, `wsl --shutdown`
  3. locate vhdx: `%LOCALAPPDATA%\Docker\wsl\disk\docker_data.vhdx` (new
     layout) or `%LOCALAPPDATA%\Docker\wsl\data\ext4.vhdx` (old layout)
  4. `Optimize-VHD -Mode Full` if available, else diskpart
     (`select vdisk`/`attach vdisk readonly`/`compact vdisk`/`detach vdisk`)
  5. report size before/after; optionally restart Docker Desktop
- No export.ps1 yet (no xz on Windows by default). Future: `docker save -o
  dockercode.tar`.

## Task queue

1. [x] plan.md (this file)
2. [x] docker-compose.yml: `${DOCKERCODE_HOME:-./homedir}:/home/coder` in both
   services + top-level `volumes: dockercode-home:` declaration
3. [x] .gitattributes
4. [x] bin/build.ps1 (ensure docker up, USER_UID/GID=1000, generate Dockerfile
   from Dockerfile.template + optional Dockerfile.extension in PS, `docker
   compose build`)
5. [x] bin/start-console.ps1 (parity with start-console.sh: prune, refuse if
   GUI service up, restart on image change, compose run --rm -d, print IP;
   sets DOCKERCODE_HOME=dockercode-home)
6. [x] bin/shell.ps1 (label lookup GUI then console, docker exec -it bash,
   reuse the same inner bash bootstrap as bin/shell.sh)
7. [x] bin/stop.ps1 (label lookup, docker stop)
8. [x] bin/clean-image.ps1 (docker rmi + prune)
9. [x] bin/compact-vhdx.ps1 (see Decisions)
10. [x] README.md: Windows usage section (console only, volume, compact)
11. [x] validate: `docker compose config` parses; scripts pass `powershell
    -File` syntax check if PS available

## Test session fixes (Windows, 2026-10-17)

- bin/build.ps1: dropped Set-Content -NoNewline on header (glued comment onto FROM - build stage in current context')
- bin/stop.ps1: cids wrapped in @() around whole pipeline (single-container string was char-splatted into docker stop)
- .gitattributes: added 'root/** text eol=lf' (extension-less xdg-open matched no rule); worktree re-checked out LF for 12 polluted files

## Notes / gotchas

- compose volumes merge is per container-path: overriding `./homedir` with
  the same target via env var avoids needing a windows override file.
- named volume not browsable from Explorer (`\\wsl$`): use bin/shell.ps1 or
  docker cp. If Explorer access needed later: bind
  `\\wsl.localhost\<distro>\home\<user>\dockercode-home` instead (set
  DOCKERCODE_HOME).
- first boot on empty volume: entrypoint chowns /home/coder and copies skel.
- nested dockerd data lands in the volume (ext4): vfs driver now on fast fs.
