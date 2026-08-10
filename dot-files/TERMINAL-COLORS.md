# Terminal Colors Across the Stack (WT / WSL / bash / Emacs)

Last updated: 2026-08-09. Applies to: Windows + Windows Terminal +
WSL2 Ubuntu-24.04 (narad) + bash + skewed-emacs.

## The four layers and who owns what

| Layer | Owns | Config file |
|-------|------|-------------|
| Windows Terminal | Background, foreground, the 16 ANSI palette colors, cursor, selection | `settings.json` (Settings → "Open JSON file"; on disk under `AppData/Local/Packages/Microsoft.WindowsTerminal_*/LocalState/`) |
| WSL/Ubuntu | Nothing color-specific | — |
| bash | `LS_COLORS` (ls), `PS1` (prompt), via the `theme` function — all **24-bit truecolor**, so they bypass the WT palette entirely | `~/.bash_profile` (symlink → `skewed-emacs/dot-files/bash_profile`), `~/.bashrc` |
| Emacs | Its own faces (modus-vivendi / modus-operandi); in GUI and truecolor terminals it ignores the WT palette too | `emacs.d` in skewed-emacs |

Key insight: the WT palette only matters for programs that use the
classic 16 ANSI colors — git, grep, man, htop, stock ls defaults. Our
bash theme and Emacs paint exact RGB. So a bad WT palette makes *other
tools* unreadable, and a bad WT *background* makes everything unreadable.

## What is configured now

- **WT schemes**: `Modus Vivendi` (black bg, palette taken from the
  Emacs modus-vivendi palette — every color ≥7:1 WCAG contrast on
  black) and `Modus Operandi` (white bg, from modus-operandi).
- **Ubuntu-24.04 profile**: `"colorScheme": {"dark": "Modus Vivendi",
  "light": "Modus Operandi"}` with app `"theme": "system"` — WT follows
  the Windows dark/light setting automatically.
- The old readability bug: the WSL fragment pinned the profile to the
  stock "Ubuntu" scheme (aubergine `#300A24` bg, `brightBlue #08458F`
  ≈ 1.9:1 contrast for bold-blue directories). The profile override in
  settings.json now wins over that fragment.
- **bash**: `theme dark|light|solarized|custom|auto`.
  - A manual pick is **sticky**: saved to `~/.config/skewed-theme`,
    picked up by every new tab/login.
  - `theme auto` deletes the sticky file and follows the Windows
    app light/dark mode (read via `reg.exe`; falls back to dark where
    there is no `/mnt/c`, e.g. inside containers).
  - Precedence at login: `$THEME` env → sticky file → Windows mode → dark.
  - `.bashrc`'s `dircolors -b` clobber is neutralized twice: bash_profile
    re-applies dircolors after sourcing .bashrc, and a tail hook in
    .bashrc re-applies the theme in *nested* interactive shells
    (functions are `export -f`'d so subshells have them).

## Checklist when colors look wrong

1. **Which layer?** Run `printf '\e[34mansi-blue\e[0m \e[38;2;47;175;255mrgb-blue\e[0m\n'`.
   If `ansi-blue` is unreadable but `rgb-blue` is fine → WT palette/scheme.
   If both are wrong-colored → background/scheme. If `ls` alone is dim →
   `LS_COLORS` got reset (check `echo $LS_COLORS | tr : '\n' | grep ^di=`;
   themed dark is `di=38;2;0;191;255`, stock clobber is `di=01;34`).
2. **WT scheme active?** WT Settings → Ubuntu-24.04 → Appearance, or
   check settings.json profile entry. Remember distro *fragments* can
   set a scheme invisibly; a profile-level `colorScheme` overrides them.
3. **bash theme state**: `echo $THEME`, `cat ~/.config/skewed-theme`.
   `theme dark` to force; `theme auto` to follow Windows.
4. **Emacs**: `M-x dark-theme` / `M-x light-theme` (modus-vivendi /
   modus-operandi) — pairs with the WT scheme of the same polarity.
5. WT hot-reloads settings.json on save — no restart needed. A backup
   of the pre-change file sits next to it as `settings.json.bak-2026-08-09`.

## Keeping it coherent

Dark everywhere = Windows dark mode + WT `Modus Vivendi` + `theme dark`
(or `auto`) + Emacs modus-vivendi. Light everywhere = flip Windows to
light; WT follows by itself, run `theme auto` (or `theme light`) in the
shell, `M-x light-theme` in Emacs. The WT palettes are generated from
the same modus palettes Emacs uses, so ANSI-colored tools and Emacs
agree by construction.
