# Windows-side setup

`bootstrap.sh` only touches the Linux side. These two steps live on Windows and
have to be done by hand once per machine.

## 1. Install the Nerd Font

The prompt and status bars use powerline separators and devicon glyphs that a
normal font does not have. Without a Nerd Font they render as tofu boxes (`□`).

This setup uses **CaskaydiaCove Nerd Font** (the Nerd-Font patch of Cascadia
Code). Download it from <https://www.nerdfonts.com/font-downloads>, unzip, select
the `.ttf` files, right-click → **Install**.

A per-user font installation is stored in:

```
C:\Users\<you>\AppData\Local\Microsoft\Windows\Fonts
```

Installing "for all users" into `C:\Windows\Fonts` works equally well.

Verify: Windows Terminal → Settings → your WSL profile → Appearance → Font face.
`CaskaydiaCove Nerd Font` should be selectable. Restart Windows Terminal if it
was open while the font was installed.

## 2. Merge the terminal settings

Open Windows Terminal → Settings → **Open JSON file** (bottom left), or edit:

```
%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
```

Then follow the five numbered sections in [`windows-terminal.jsonc`](windows-terminal.jsonc).

Do **not** replace the whole file with the fragment. Profile `guid` and `source`
values are generated per machine — copying them from another computer would leave the new
install pointing at profiles that do not exist. Copy in the Catppuccin Mocha
scheme, the styling keys, and the keybindings; leave the local identity fields
alone.

## Why the theme is set in two places

The terminal owns the background colour and the 16 ANSI colours; Neovim,
tmux and starship pick their colours from that same Catppuccin Mocha palette.
If the terminal is left on the default scheme the Linux side still works, but
the shades will not match and translucency will be missing.
