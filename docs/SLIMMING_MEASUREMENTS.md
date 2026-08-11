# Image Slimming: Measurements (2026-08-11)

Data behind the slimming initiative (projects.org :must:).  All numbers
measured on narad against `gornskew/skewed-emacs:devo-full`
(977MB compressed download / 3.72GB on disk) plus fresh-closure
experiments on `debian:latest` containers.

## Where the 3.72GB lives (layer-attributed)

| Block | Size |
|---|---|
| GUI giga-layer (one RUN: emacs-gtk + chromium + fonts + gs/poppler) | 1.18GB |
| AUI homes: .claude 285 + .codex 301 + .gemini 122 + .grok 157 | 865MB |
| Node 24 (/usr/local copy) | 212MB |
| skewed-emacs repo copy (dot-files 77, docker/ 65 -- see dup below) | 147MB |
| common apt layer (git, curl, ssh, libvterm, gnupg, ...) | 134MB |
| Debian base | 87MB |
| copilot-language-server (/usr/local/bin) | 67MB |
| ttyd, nerd-fonts, config-gen, misc | ~25MB |

Inside the GUI giga-layer (dpkg attribution): chromium closure ~540MB
(chromium 309 + chromium-common 63 + libllvm19 124 + mesa-libgallium 41),
emacs-gtk stack ~225MB (emacs-common 79 + emacs-gtk 46 + emacs-el 19 +
libgccjit 37 + gtk3/adwaita ~45), fonts ~80MB, ghostscript/poppler ~40MB.

**Duplication bug found**: copilot-language-server ships TWICE -- 67MB at
/usr/local/bin AND ~65MB inside the repo copy's docker/ dir.  Excluding
docker/ from the runtime COPY reclaims ~65MB for free.

## Fresh dependency closures (debian:latest)

| Install | Download | Disk | Notes |
|---|---|---|---|
| chromium (Debian pkg) | 285MB | 1108MB | 345 packages; drags X/mesa/llvm even for headless use |
| emacs-nox | 122MB | 498MB | |
| chrome-headless-shell 151 (Chrome-for-Testing) | ~170MB zip | 262MB unpacked | Google's stripped headless build (what Puppeteer uses) |
| its lib deps (18 libs, apt closure) | 65MB | 282MB | no GTK, no mesa/llvm |
| deps + fontconfig/liberation/noto-core/emoji | 91MB | 347MB | |

**chrome-headless-shell verdict: works.**  With the 18-lib closure +
fonts it rendered a styled data: URL to a valid PNG
(`--headless --no-sandbox --disable-gpu --screenshot=...`).
Total snapshotting capability: ~610MB disk vs ~1.1GB for Debian
chromium -- and none of it overlaps the GUI stack.

**x3dom verdict: also works.**  WebGL comes up via SwiftShader
(software rendering) when launched with `--enable-unsafe-swiftshader`
(newer Chrome disables software WebGL without it -- webshot grows this
flag).  Verified against the real workload: screenshotted
/demo/naca-nurbs through dev cyclops with the right viewport in 3D
Interactive mode -- the x3dom airfoil renders.  Probe:
`canvas.getContext("webgl")` -> "WebKit WebGL" renderer.

## Implications for the variant tree (per Dave 2026-08-11 direction)

- Primary split: GUI vs non-GUI.  GUI branch (emacs-gtk = full X
  workstation) stays as a first-class, ready-to-spin-up graphical
  workstation image -- CI builds it every pipeline (which also proves
  the build and tracks the footprint), it's just no longer what the
  canonical tags point at.
- Snapshotting (webshot) outranks AUI TUIs in the default image;
  chrome-headless-shell gets it into the NON-GUI branch for ~610MB
  instead of pulling Debian chromium's 1.1GB closure.
- AUIs (claude/codex/gemini/grok TUIs, 865MB, all npm installs into
  home dirs) move to on-demand in-container install, elisp-first API
  (M-x skewed-install RET claude-code RET style; shell scripts baked
  into the image underneath).  Note: installs land in the container
  home, which is ephemeral BY DESIGN: the persistence story for
  someone who wants AUIs sticky is "switch to the -full image"
  (Dave, 2026-08-11).  No installer persistence machinery needed.
- copilot-language-server: also a candidate for on-demand (67MB), and
  fix the docker/ duplication regardless.
- Ballpark new default (non-GUI + emacs-nox + headless-shell + fonts):
  ~1.5GB disk / ~450-500MB download, vs 3.72GB / 977MB today.
  Overlapping closures make naive sums overestimate; exact numbers come
  from the first real build.

## Restructure result (2026-08-11, same day)

Implemented as the `runtime-default` stage (see docker/Dockerfile tree
and docker/BUILD.md).  First local amd64 build of `devo-default`:
**1.87GB on disk vs 3.72GB for devo-full -- exactly half.**  (Above
the 1.5GB ballpark mostly because the elpa-compiled emacs config in
dot-files is itself ~77MB source + native-comp artifacts.)  Verified
in the built image: emacs daemon + lisply HTTP up, webshot renders the
naca-nurbs x3dom viewport through cyclops via chrome-headless-shell,
`skewed-install claude-code` installs a working claude 2.1.227 and
removes cleanly.  Compressed download size: read off Docker Hub after
the first CI push.
- zstd layer compression (separate projects.org item) folds into the
  same build pass: pull time on small nodes is unpack-bound.
