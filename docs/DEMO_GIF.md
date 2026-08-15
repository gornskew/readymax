# Recording the Demo GIF

Target: a ~30-second GIF for the README showing the arc:
`./basilisk up` → dashboard → an AI agent driving Gendl through MCP.

## Storyboard

1. (~5s) `./basilisk up` scrolling, ending on healthy services.
2. (~5s) `eskew` → the skewed-emacs dashboard (ASCII banner, backends green).
3. (~15s) `claudly` (or any agent CLI) prompted with:
   "Build me a staircase in Gendl — 3.1m rise, 3.9m run, 2x6 treads"
   — capture the tool-call spinner and the numeric answer coming back.
4. (~5s) Browser flash of geysr (http://localhost:9080/geysr) showing
   the staircase object. (Optional but strong.)

## Option A: asciinema + agg (interactive, recommended for scene 3)

On the host (not in-container):

```bash
sudo apt install asciinema   # or brew install asciinema
cargo install --git https://github.com/asciinema/agg  # or download release binary

asciinema rec demo.cast      # do the storyboard, Ctrl-D to stop
agg --theme monokai --font-size 16 --speed 1.4 demo.cast img/demo.gif
```

Keep the terminal at ~100x30 before recording; agg bakes the size in.

## Option B: vhs (scriptable, deterministic scenes only)

[vhs](https://github.com/charmbracelet/vhs) replays a .tape script —
good for scenes 1–2; scene 3's agent output isn't deterministic, so
record that with asciinema and splice, or accept variability.
A starter tape is in `docs/demo.tape`:

```bash
vhs docs/demo.tape   # writes img/demo.gif
```

## After recording

Place the GIF at `img/demo.gif` and it will show in the README
(placeholder link already present). Keep it under ~5MB for GitHub
rendering; `--speed` and `--font-size` in agg are the levers.
