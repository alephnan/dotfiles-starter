# Dotfiles Starter

A shared **Catppuccin Mocha** terminal setup for **Bash, tmux, Starship, and
Neovim**, with optional Python/Rust development tools. Fork it and make it yours.

## Quick start

Supported: **Linux x86-64** running Arch, Ubuntu **24.04 / 26.04**, or Debian
**12 / 13**, including these distributions inside WSL. You need a normal user
account with `sudo`, Git, and an internet connection. macOS, native Windows,
and ARM are not supported by this installer.

Install Git and sudo first if necessary (`sudo apt-get install git sudo` on
Ubuntu/Debian, or `sudo pacman -Syu --needed git sudo` on Arch). If sudo is not
set up yet, ask your system administrator or use your distribution's setup guide.

```bash
git clone https://github.com/alephnan/dotfiles-starter.git
cd dotfiles-starter
./bootstrap.sh --dry-run   # optional preview; writes and downloads nothing
./bootstrap.sh
exec bash -l
```

Run the installer as your normal user. It invokes sudo for system packages.
Arch installation includes `pacman -Syu` (a full system upgrade); review the
package-manager confirmation. Ubuntu/Debian installation updates the package
index and installs dependencies, without a full distribution upgrade.

The repository can live anywhere, including a path with spaces. Keep it in
place after installation: your configuration files are symlinks into it.
Existing files, directories, and symlinks are preserved in unique
`~/.dotfiles-backup-*` directories. Repeated runs keep existing correct links
and preserve earlier backups.

### Optional Python and Rust tools

```bash
./bootstrap.sh --with-dev-tools
```

This adds Ruff and basedpyright in a dedicated Python virtual environment under
`~/.local/share/dotfiles-starter/python-tools`, plus Rust and rust-analyzer via
rustup. It reuses an existing rustup installation and its active toolchain.
Without this flag, the editor still has highlighting, completion, file search,
and a sidebar; language servers activate only when their executables are installed.

| Option | Behavior |
| --- | --- |
| `--dry-run` | Preview without file changes, sudo, or network access. |
| `--with-dev-tools` | Install optional Python/Rust tooling. |
| `--skip-packages` | Skip all dependency/toolchain installation; validate prerequisites, link configs, and restore plugins. Still needs network access. |
| `--yes` | Accept package-manager prompts for unattended installation. |
| `--help` | Print usage. |

## What's included

| Tool | Defaults |
| --- | --- |
| Bash | Color aliases, guarded Starship initialization, user-bin PATH entries without duplicates, WSL mount color fixes. |
| Starship | Compact directory, Git branch/status, and prompt character. |
| tmux | Mouse, vi copy mode, true color, Catppuccin status bar at the top. |
| Neovim | Catppuccin, relative line numbers, Telescope search, neo-tree sidebar, Blink completion, and syntax parsers. |

Neovim's leader is **Space**: `Space e` toggles the sidebar, `Space ff` searches
files, `Space fg` searches text, and `Space fb` lists buffers. `gd` goes to a
definition when a language server is attached. tmux keeps its default **Ctrl+b**
prefix; press **Ctrl+b, r** to reload its configuration.

### Versions and downloads

The editor requires Neovim **0.12+**, Tree-sitter CLI **0.26.1+**, and a C compiler.
Arch supplies these through pacman. Ubuntu/Debian use compatible existing tools
when available; otherwise the installer downloads official Neovim **0.12.2**,
Tree-sitter **0.26.3**, and Starship **1.26.0** releases. Downloads are checked
against SHA-256 hashes in `scripts/releases.sh`, then installed under
`~/.local/share/dotfiles-starter/tools` with links in `~/.local/bin`.

Debian 12's system library is too old for the official Tree-sitter binary.
On that version only, setup builds the same CLI release from its locked source
dependencies using a temporary Rust compiler. This first installation takes
several minutes and extra download/disk space; the temporary compiler is removed
when setup exits. It does not install a persistent Rust development toolchain.

Neovim plugin commits, including lazy.nvim, are recorded in `lazy-lock.json`;
tmux plugin commits are recorded in the installer. Parser installation finishes
before setup reports success. Blink uses its prebuilt matcher when available
and falls back to Lua, so completion needs no Rust compiler.
System packages and optional language tools follow their upstream releases;
this is not a fully locked operating-system image.

## Personal customization

Put private shell settings in `~/.bashrc.local` or `~/.bash_profile.local`.
These optional files are sourced after the shared settings and ignored by Git.
Keep credentials in their applications' credential stores. Git identity and
authentication are configured separately; this installer does not require a
GitHub account and does not change your Git configuration.

Edit the theme, keybindings, and plugin configuration in your fork. Installation
uses default configuration locations and refuses non-default `XDG_CONFIG_HOME`,
`STARSHIP_CONFIG`, or `NVIM_APPNAME` overrides before making changes.

## Fonts, clipboard, and Windows Terminal

Install a [Nerd Font](https://www.nerdfonts.com/font-downloads) and select it in
your terminal for icons. The configuration also works without it, but some
glyphs may appear as boxes.

Windows Terminal styling is an optional manual merge; follow
[the Windows instructions](windows/README.md). Retain your own profile identities
and existing keybindings. Linux installation never edits Windows settings or
`/etc/wsl.conf`.

Neovim requests the system clipboard through `unnamedplus`. Install `wl-clipboard`
on Wayland or `xclip` on X11 using your package manager. In WSL, configure a
Windows clipboard bridge supported by Neovim, such as `win32yank`, and ensure it
is on PATH. Clipboard support is optional; use `:checkhealth vim.provider` to
inspect detection. Terminal copy/paste remains available independently.

## Update and restore

To update an unmodified clone, run `git pull --ff-only`, then
`./bootstrap.sh --skip-packages`. If the update requires new dependencies, rerun
without `--skip-packages`. Local Git edits must be committed or stashed before
pulling. A changed lazy.nvim pin requires moving its old directory under
`~/.local/share/nvim/lazy/` aside before rerunning; the installer explains this.

Each backup preserves its original relative layout. To restore a file, first
move the installed link aside, then move the original back. For example, using
the actual backup directory printed by the installer:

```bash
backup="$HOME/.dotfiles-backup-REPLACE-WITH-YOUR-BACKUP"
mv "$HOME/.bashrc" "$HOME/.bashrc.before-restore"
mv "$backup/.bashrc" "$HOME/.bashrc"
```

Repeat for `.bash_profile`, `.tmux.conf`, `.config/starship.toml`, and
`.config/nvim` if present in that backup. If no original existed, remove only
the installed symlink. Backups also preserve any replaced `.local/bin` entries.
Restoring configs does not uninstall system packages, plugins, or toolchains.

## Troubleshooting and contributing

- **Download/build failure:** setup exits unsuccessfully and prints the backup
  location. Fix the reported issue and rerun; earlier backups remain intact.
- **Older Neovim still starts:** open a new shell, run `type -a nvim`, and check
  that `~/.local/bin` precedes the old installation.
- **Plugin has local changes:** move that plugin directory aside before rerunning;
  the installer does not discard your edits to pinned tmux plugins.
- **Missing editor features:** run `:checkhealth`, check installed tool versions,
  and use `--with-dev-tools` if language-server features are wanted.

Before contributing, use a GitHub noreply email for commits and review both the
diff and filenames for personal information. Run:

```bash
python3 -m unittest discover -s tests -v
shellcheck -x -s bash bootstrap.sh .bashrc .bash_profile scripts/*.sh tests/*.sh
python3 scripts/check-privacy.py
./scripts/check-secrets.sh
```

CI checks secrets and personal paths throughout reachable history, then tests
fresh and repeated installations on all five supported distribution versions.
`tests/container.sh` is exclusively for disposable containers: it installs
packages and creates a test account. Do not run it directly on your machine.
Automated scans supplement manual review; do not commit credentials, histories,
private directories, or real-machine screenshots.

## Credits and license

Configuration code is [MIT licensed](LICENSE). Themes come from
[Catppuccin](https://github.com/catppuccin/catppuccin); plugins and downloaded
tools retain their respective upstream licenses. The repository contains
configuration and installation instructions, not vendored plugin sources.
