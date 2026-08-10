# CI: Native Multi-Arch Image Builds

Automated builds of `gornskew/skewed-emacs` images via GitLab CI on
gitlab.genworks.com, replacing manual `docker/build --multi-arch` runs.

## Why native runners instead of buildx cross-builds

`docker/build --multi-arch` cross-builds arm64 on an amd64 host via
buildx + QEMU binfmt emulation.  On hosts without registered qemu
binfmt handlers (e.g. narad) arm64 RUN steps die with `exec format
error`, and even where emulation works it is ~10x slower and has shown
nondeterministic qemu-aarch64 SIGSEGVs (observed on the cl-docker-images
builds, 2026-07).  Native per-arch runners + a manifest stitch avoid all
of that.  (To fix narad cross-builds anyway:
`docker run --privileged --rm tonistiigi/binfmt --install arm64`.)

## Topology

| Leg | Runner | Tag |
|-----|--------|-----|
| amd64 | docker-capable runner on gitlab.genworks.com infra | `amd64` |
| arm64 | cl-arm64-build-1 (Mac mini M1 "sevam", 192.168.4.37) | `arm64` |
| manifest stitch | cl-arm64-build-1 | `arm64` |

Each build leg runs `docker/build --all --push` (native arch only,
pushes arch-suffixed tags); the stitch job runs `docker/build
--manifest-only` to merge `-amd64`/`-arm64` tags into the canonical
multi-arch tags.

## cl-arm64-build-1 (Mac mini M1, "sevam")

Already runs gitlab-runner 19.x (launchd service, user dcooper8,
config `~/.gitlab-runner/config.toml`) for
gitlab.common-lisp.net/cl-docker-images.  Docker comes from colima
(Ubuntu aarch64 VM, vz, socket
`unix:///Users/dcooper8/.colima/default/docker.sock`).

The existing cl.net registration uses the **docker executor**: jobs run
in a docker CLI image (alpine) with the VM docker socket mounted at
`/var/run/docker.sock`, driving the colima dockerd natively.  The
genworks registration mirrors it -- one more `[[runners]]` entry
serviced by the same launchd process:

```bash
# On the mini, as dcooper8:
/opt/homebrew/bin/gitlab-runner register --non-interactive \
  --url https://gitlab.genworks.com \
  --token glrt-XXXXXXXXXXXXXXXXXXXX \
  --executor docker \
  --docker-image docker:29.6.2 \
  --docker-host unix:///Users/dcooper8/.colima/default/docker.sock \
  --docker-volumes /var/run/docker.sock:/var/run/docker.sock \
  --docker-volumes /cache
```

No service restart needed -- the runner picks up config.toml changes on
its check interval; `brew services restart gitlab-runner` if in doubt.

With GitLab 16+ runner tokens (`glrt-`), the description, tags
(`arm64`), and "run untagged jobs" setting live on the GitLab side,
configured when the runner is created in the UI.

`concurrent = 1` in config.toml serializes genworks and cl.net jobs
(shared 6-CPU/6GB colima VM; also mind the disk situation -- see
projects.org "Runner disk hygiene on cl-arm64-build-1").  Bump to 2
only if overlap proves safe.

Note: macOS on the mini has no `timeout(1)`; irrelevant for CI jobs
(they run inside alpine containers) but relevant for ssh automation
against the host.

## Credentials

- Docker Hub push: CI variables `DOCKERHUB_USER` / `DOCKERHUB_TOKEN`
  (write scope on `gornskew/*`), set masked at project or group level.
  Used by the `docker login` in the CI default before_script.
- lisply-mcp revision lookup in docker/build curls api.github.com
  unauthenticated (60 req/hr/IP) -- fine at current build volume; pass a
  token if it ever starts rate-limiting.

## Runner disk maintenance (added 2026-08-10)

The 2026-08-10 arm64 build failure ("No space left on device,
/tmp/babel-" during the emacs-daemon settle step) was sevam's colima
VM at 89%: 45G of orphaned containerd data (namespace moby, content +
overlayfs snapshots) left behind by an earlier containerd-snapshotter
experiment.  That data is invisible to every `docker system df/prune`
-- if VM df and `docker system df` disagree wildly, look in
/var/lib/containerd (bind of /mnt/lima-colima/containerd).

Guards now in place:
- colima.yaml on sevam: `docker.builder.gc` enabled with
  defaultKeepStorage 25GB (build cache self-trims).
- .gitlab-ci.yml default after_script: `docker image prune -f`
  (dangling-only) -- tags move every build, so the previous build's
  ~4GB of layers go dangling each run.
- .gitlab-ci.yml default before_script prints `df -h` and
  `docker system df` so disk state heads every job log.

One-off cleanup recipe (services stopped, VM idle):
```bash
colima ssh -- sudo systemctl stop docker docker.socket containerd
colima ssh -- sudo rm -rf /var/lib/containerd/io.containerd.content.v1.content \
  /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs \
  /var/lib/containerd/io.containerd.metadata.v1.bolt
colima ssh -- sudo systemctl start containerd docker
```
Gotcha: `colima ssh` consumes stdin -- in scripts fed to a shell via
stdin, every command after the first `colima ssh` line silently
disappears.  Chain commands as ssh arguments instead.
