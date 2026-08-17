# Windows Keybindings for Emacs Users

This directory contains configuration files to make Windows more Emacs-friendly by:
1. Remapping CapsLock to Control
2. Setting up Emacs-style navigation keys in various applications

## Files

- **sharpkeys-capslock-to-control.skl**: SharpKeys configuration to remap CapsLock to Control
- **autohotkey-config-for-emacs-like-bindings.ahk**: AutoHotkey script for Emacs-style navigation keys
- **autohotkey-config-for-emacs-in-ttyd.ahk**: the same idea for Emacs running in a ttyd browser terminal

Each of these is a small text configuration you feed to a tool you
install yourself. This directory deliberately ships no third-party
executables — see below.

## Sanskrit / IAST transliteration (KeySwap)

For typing IAST diacritics (ā ī ū ṛ ṝ ḷ ṭ ḍ ṇ ś ṣ ṃ ḥ …) on Windows,
**KeySwap** works well: hold a base letter's key and cycle through its
diacritic variants.

Get it from the author: <https://www.YesVedanta.com/keyswap>.

`keyswap.exe` used to be committed here. It was removed 2026-08-16: it
is someone else's compiled Windows binary, redistributed with no license
grant of any kind — no LICENSE file, no terms in its ReadMe, nothing
that says we may pass it on. A repo that ships its own license carefully
should not casually redistribute a binary it has no right to. Install it
from the source above instead.

Its `config.txt` maps each base letter to the variants it cycles
through; the shipped default already covers IAST, so there is usually
nothing to configure.

## Setup Instructions

### Remapping CapsLock to Control

1. Download and install [SharpKeys](https://github.com/randyrants/sharpkeys/releases)
2. Open SharpKeys and click "Import"
3. Select the `sharpkeys-capslock-to-control.skl` file
4. Click "Write to Registry"
5. Log out and log back in (or restart your computer) for changes to take effect

### Setting Up Emacs Navigation Keys

1. Download and install [AutoHotkey v2](https://www.autohotkey.com/)
2. Copy the `autohotkey-config-for-emacs-like-bindings.ahk` file to your preferred location
3. Double-click the file to run it
4. To make it start automatically with Windows:
   - Press `Win+R`, type `shell:startup` and press Enter
   - Create a shortcut to the .ahk file in this folder

## Available Keybindings

The AutoHotkey script provides the following Emacs-style keybindings in Microsoft Edge and Claude:

| Keybinding | Function |
|------------|----------|
| Ctrl+p | Up arrow |
| Ctrl+n | Down arrow |
| Ctrl+f | Right arrow |
| Ctrl+b | Left arrow |
| Ctrl+a | Home (beginning of line) |
| Ctrl+e | End (end of line) |
| Ctrl+d | Delete character |
| Ctrl+k | Kill to end of line |
| Ctrl+v | Page down |
| Alt+f | Move forward one word |
| Alt+b | Move backward one word |
| Alt+d | Delete word forward |
| Ctrl+Alt+f | Move forward one word (alternative) |
| Ctrl+Alt+b | Move backward one word (alternative) |

## Extending for Other Applications

To add Emacs keybindings to other applications, you can modify the AutoHotkey script:

1. Open the .ahk file in a text editor
2. Add a new section following the pattern of existing sections
3. Determine the executable name of your application (e.g., `notepad.exe`)
4. Add a new section like this:

```autohotkey
#HotIf WinActive("ahk_exe your_application.exe")
^p::Send "{Up}"
^n::Send "{Down}"
; Add more keybindings as needed
#HotIf
```

5. Save the file and reload the script by right-clicking the AutoHotkey icon in the system tray and selecting "Reload Script"