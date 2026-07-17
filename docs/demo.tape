# vhs tape: deterministic scenes of the skewed-emacs demo GIF
# Usage: vhs docs/demo.tape   (from repo root, on the host)
Output img/demo.gif
Set FontSize 16
Set Width 1000
Set Height 600
Set Theme "Monokai Vivid"
Set TypingSpeed 40ms

Type "./compose-dev up"
Enter
Sleep 8s
Type "eskew"
Enter
Sleep 4s
# Dashboard shows; pause on it
Sleep 3s
# Scene 3 (agent session) is interactive — record with asciinema
# per docs/DEMO_GIF.md and splice, or extend this tape once the
# claudly output is stable enough to script.
