# CI: Native Multi-Arch Image Builds

Automated builds of the `skewed-emacs` images via GitLab CI, replacing
manual `docker/build --multi-arch` runs.

## Why native runners instead of buildx cross-builds

`docker/build --multi-arch` cross-builds arm64 on an amd64 host via
buildx + QEMU binfmt emulation. On hosts without registered qemu binfmt
handlers, arm64 `RUN` steps die with `exec format error` — and even
where emulation works it is roughly 10x slower and has shown
nondeterministic `qemu-aarch64` SIGSEGVs. Native per-arch runners plus a
manifest stitch avoid all of that.

To install the binfmt handlers and make cross-builds work anyway:

```bash
docker run --privileged --rm tonistiigi/binfmt --install arm64
```

## Topology

| Leg | Runner | Tag |
|-----|--------|-----|
| amd64 | any docker-capable runner | `amd64` |
| arm64 | an arm64 host (e.g. an Apple silicon Mac running colima) | `arm64` |
| manifest stitch | the arm64 runner | `arm64` |

Each build leg runs `docker/build --all --push`, building the native
arch only and pushing arch-suffixed tags. The stitch job then runs
`docker/build --manifest-only` to merge the `-amd64` and `-arm64` tags
into the canonical multi-arch tags.

## Registering an arm64 runner on macOS + colima

Docker on an Apple silicon Mac can come from [colima](https://github.com/abiosoft/colima)
(a Linux VM with a native aarch64 dockerd). Use the **docker executor**:
jobs run in a docker CLI image and drive the VM's dockerd through its
mounted socket.

```bash
gitlab-runner register --non-interactive \
  --url https://<your-gitlab-instance> \
  --token <runner-token> \
  --executor docker \
  --docker-image docker:29.6.2 \
  --docker-host unix://<path-to>/.colima/default/docker.sock \
  --docker-volumes /var/run/docker.sock:/var/run/docker.sock \
  --docker-volumes /cache
```

One `gitlab-runner` process can service several `[[runners]]` entries,
so an existing runner host can take on another project without a second
service. No restart is needed — the runner picks up `config.toml`
changes on its check interval (`brew services restart gitlab-runner` if
in doubt).

With GitLab 16+ runner tokens (`glrt-`), the description, tags and
"run untagged jobs" setting live on the GitLab side and are configured
when the runner is created in the UI.

Set `concurrent = 1` in `config.toml` to serialize jobs when several
projects share one runner VM; raise it only once overlap proves safe on
that machine's CPU, memory and disk. Long-lived build hosts need a disk
hygiene story — image and cache accretion is what actually takes these
runners down.

Note: macOS has no `timeout(1)`. That is irrelevant for CI jobs, which
run inside Linux containers, but it matters for any ssh automation
driving the host directly.
