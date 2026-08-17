# Copyright © 2026 Gornskew Enterprises
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.  Distributed WITHOUT
# ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

# vhs tape: deterministic scenes of the skewed-emacs demo GIF
# Usage: vhs docs/demo.tape   (from repo root, on the host)
Output img/demo.gif
Set FontSize 16
Set Width 1000
Set Height 600
Set Theme "Monokai Vivid"
Set TypingSpeed 40ms

Type "./basilisk up"
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
