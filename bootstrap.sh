#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/releases.sh
source "$DOTFILES_DIR/scripts/releases.sh"
BACKUP_DIR=""
TEMP_DIR=""
SKIP_PACKAGES=0
WITH_DEV_TOOLS=0
DRY_RUN=0
ASSUME_YES=0
CONFIGS=(.bashrc .bash_profile .tmux.conf .config/starship.toml .config/nvim)
TPM_COMMIT=e261deb1b47614eed3400089ce7197dc68acc4eb
CATPPUCCIN_TMUX_COMMIT=d2d25bd3393fe43f19eb4fff6cdd2bdf5578e622

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'HELP'
Usage: ./bootstrap.sh [options]
  --with-dev-tools  Also install Ruff, basedpyright, Rust, and rust-analyzer.
  --skip-packages   Skip all dependency/toolchain installation; still install plugins.
  --dry-run         Show planned changes without writing or downloading anything.
  --yes            Accept package-manager prompts (for unattended setup).
  -h, --help       Show this help.

Run as your normal user. The package manager uses sudo when needed.
Existing configurations and replaced user-bin links are backed up automatically.
HELP
}

check_locations() {
  [[ "$HOME" == /* && "$HOME" != / && -d "$HOME" ]] || die 'HOME must be an existing absolute user directory.'
  [[ "${XDG_CONFIG_HOME:-$HOME/.config}" == "$HOME/.config" ]] || die 'Non-default XDG_CONFIG_HOME is unsupported.'
  [[ "${STARSHIP_CONFIG:-$HOME/.config/starship.toml}" == "$HOME/.config/starship.toml" ]] || die 'Non-default STARSHIP_CONFIG is unsupported.'
  [[ "${NVIM_APPNAME:-nvim}" == nvim ]] || die 'Non-default NVIM_APPNAME is unsupported.'
  local relative
  for relative in "${CONFIGS[@]}"; do
    [[ -e "$DOTFILES_DIR/$relative" ]] || die "Missing source configuration: $relative"
  done
}

check_platform() {
  [[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || die 'Supported platform: Linux x86-64, including WSL.'
  # shellcheck source=/dev/null
  source /etc/os-release
  DISTRO="$ID"
  case "$ID:${VERSION_ID:-}" in
    arch:*) ;;
    ubuntu:24.04|ubuntu:26.04|debian:12|debian:13) ;;
    *) die 'Supported distributions: Arch, Ubuntu 24.04/26.04, Debian 12/13.' ;;
  esac
}

prepend_bin() {
  local directory="$1"
  case ":$PATH:" in *":$directory:"*) ;; *) export PATH="$directory:$PATH" ;; esac
}

version_at_least() {
  [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n 1)" == "$2" ]]
}

command_version() {
  "$1" --version | sed -nE '1s/^[^0-9]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/p'
}

backup_target() {
  local relative="$1" target="$HOME/$1"
  [[ -e "$target" || -L "$target" ]] || return 0
  if [[ -z "$BACKUP_DIR" ]]; then
    BACKUP_DIR="$(mktemp -d "$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)-XXXXXX")"
  fi
  mkdir -p -- "$BACKUP_DIR/$(dirname -- "$relative")"
  # mv preserves the symlink itself, including broken links.
  mv -- "$target" "$BACKUP_DIR/$relative"
  printf 'Backed up %s to %s\n' "$relative" "$BACKUP_DIR/$relative"
}

link_file() {
  local source="$1" relative="$2" target="$HOME/$2"
  if [[ -L "$target" && "$(readlink -f -- "$target" || true)" == "$(readlink -f -- "$source")" ]]; then
    printf 'Already linked: %s\n' "$relative"
    return
  fi
  backup_target "$relative"
  mkdir -p -- "$(dirname -- "$target")"
  ln -s -- "$source" "$target"
  printf 'Linked: %s\n' "$relative"
}

download_verified() {
  local url="$1" checksum="$2" destination="$3"
  curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 \
    --max-time 300 --proto '=https' --tlsv1.2 "$url" -o "$destination"
  printf '%s  %s\n' "$checksum" "$destination" | sha256sum --check --status || die 'Download checksum mismatch; nothing from this download was installed.'
}

install_release() {
  local name="$1" version="$2" url="$3" checksum="$4" kind="$5"
  local destination="$HOME/.local/share/dotfiles-starter/tools/$name-$version"
  local unpack="$TEMP_DIR/$name" executable
  mkdir -p -- "$unpack"
  download_verified "$url" "$checksum" "$TEMP_DIR/$name.download"
  case "$kind" in
    nvim)
      tar -xzf "$TEMP_DIR/$name.download" -C "$unpack" --strip-components=1
      executable=bin/nvim ;;
    gzip)
      gzip -dc "$TEMP_DIR/$name.download" > "$unpack/$name"
      executable="$name" ;;
    tar)
      tar -xzf "$TEMP_DIR/$name.download" -C "$unpack"
      executable="$name" ;;
  esac
  chmod +x "$unpack/$executable"
  # A version directory is immutable once installed; do not overwrite it.
  if [[ ! -e "$destination" && ! -L "$destination" ]]; then
    mkdir -p -- "$(dirname -- "$destination")"
    mv -- "$unpack" "$destination"
  fi
  [[ -x "$destination/$executable" ]] || die "Incomplete installation at $destination; move it aside and rerun."
  link_file "$destination/$executable" ".local/bin/$name"
  hash -r
}

install_tree_sitter_from_source() {
  # Official binaries need glibc 2.39; Debian 12 has an older glibc. Use a
  # temporary compiler, retaining only the resulting CLI in the user's home.
  local destination="$HOME/.local/share/dotfiles-starter/tools/tree-sitter-$TREE_SITTER_VERSION"
  log 'Building Tree-sitter for this system (temporary Rust compiler; first install takes several minutes)'
  curl --fail --location --silent --show-error --retry 3 --proto '=https' --tlsv1.2 \
    https://sh.rustup.rs -o "$TEMP_DIR/build-rustup.sh"
  env RUSTUP_HOME="$TEMP_DIR/build-rustup" CARGO_HOME="$TEMP_DIR/build-cargo" \
    sh "$TEMP_DIR/build-rustup.sh" -y --no-modify-path --profile minimal --default-toolchain stable
  env RUSTUP_HOME="$TEMP_DIR/build-rustup" CARGO_HOME="$TEMP_DIR/build-cargo" \
    "$TEMP_DIR/build-cargo/bin/cargo" install tree-sitter-cli --version "$TREE_SITTER_VERSION" \
    --locked --root "$TEMP_DIR/tree-sitter-build"
  [[ ! -e "$destination" && ! -L "$destination" ]] || die "Move the incompatible installation at $destination aside, then rerun."
  mkdir -p -- "$destination"
  cp -- "$TEMP_DIR/tree-sitter-build/bin/tree-sitter" "$destination/tree-sitter"
  link_file "$destination/tree-sitter" .local/bin/tree-sitter
  hash -r
}

install_packages() {
  command -v sudo >/dev/null || die 'Install sudo first, then rerun as your normal user.'
  local -a options=() packages
  if [[ "$DISTRO" == arch ]]; then
    log 'Arch package installation includes a full system upgrade to avoid partial upgrades.'
    (( ASSUME_YES == 0 )) || options+=(--noconfirm)
    packages=(base-devel git curl ca-certificates tar gzip unzip neovim starship tmux ripgrep fd tree-sitter-cli)
    (( WITH_DEV_TOOLS == 0 )) || packages+=(python python-pip)
    sudo pacman -Syu --needed "${options[@]}" "${packages[@]}"
  else
    (( ASSUME_YES == 0 )) || options+=(-y)
    packages=(build-essential git curl ca-certificates tar gzip unzip tmux ripgrep fd-find)
    (( WITH_DEV_TOOLS == 0 )) || packages+=(python3 python3-venv)
    sudo apt-get update
    sudo apt-get install "${options[@]}" "${packages[@]}"
  fi

  if ! command -v nvim >/dev/null || ! version_at_least "$(command_version nvim)" 0.12.0; then
    install_release nvim "$NVIM_VERSION" "$NVIM_URL" "$NVIM_SHA256" nvim
  fi
  if ! command -v tree-sitter >/dev/null || ! version_at_least "$(command_version tree-sitter)" 0.26.1; then
    if [[ "$DISTRO" == debian && "$VERSION_ID" == 12 ]]; then
      install_tree_sitter_from_source
    else
      install_release tree-sitter "$TREE_SITTER_VERSION" "$TREE_SITTER_URL" "$TREE_SITTER_SHA256" gzip
    fi
  fi
  if ! command -v starship >/dev/null; then
    install_release starship "$STARSHIP_VERSION" "$STARSHIP_URL" "$STARSHIP_SHA256" tar
  fi
}

install_dev_tools() {
  local venv="$HOME/.local/share/dotfiles-starter/python-tools" executable
  if [[ ! -x "$venv/bin/python" ]]; then
    python3 -m venv "$venv"
  fi
  "$venv/bin/python" -m pip install --disable-pip-version-check ruff basedpyright
  for executable in ruff basedpyright basedpyright-langserver; do
    link_file "$venv/bin/$executable" ".local/bin/$executable"
  done
  if ! command -v rustup >/dev/null; then
    curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 \
      https://sh.rustup.rs -o "$TEMP_DIR/rustup-init.sh"
    sh "$TEMP_DIR/rustup-init.sh" -y --no-modify-path --profile minimal --default-toolchain stable
  fi
  prepend_bin "${CARGO_HOME:-$HOME/.cargo}/bin"
  if ! rustup show active-toolchain >/dev/null 2>&1; then
    rustup toolchain install stable --profile minimal
    rustup default stable
  fi
  rustup component add rust-analyzer
}

check_dependencies() {
  local executable
  for executable in git curl tar gzip unzip cc make nvim tree-sitter starship tmux rg; do
    command -v "$executable" >/dev/null || die "Missing $executable; rerun without --skip-packages."
  done
  command -v fd >/dev/null || command -v fdfind >/dev/null || die 'Missing fd/fdfind.'
  version_at_least "$(command_version nvim)" 0.12.0 || die 'Neovim 0.12+ is required.'
  version_at_least "$(command_version tree-sitter)" 0.26.1 || die 'Tree-sitter CLI 0.26.1+ is required.'
  if (( WITH_DEV_TOOLS )); then
    for executable in ruff basedpyright-langserver rustup cargo rust-analyzer; do
      command -v "$executable" >/dev/null || die "Missing optional tool $executable; rerun without --skip-packages."
    done
    rust-analyzer --version >/dev/null || die 'rust-analyzer is unavailable in the active Rust toolchain.'
  fi
}

clone_pinned() {
  local repository="$1" destination="$2" commit="$3" origin
  if [[ -d "$destination/.git" ]]; then
    origin="$(git -C "$destination" remote get-url origin)"
    [[ "${origin%.git}" == "${repository%.git}" ]] || die "Unexpected plugin repository at $destination."
    [[ -z "$(git -C "$destination" status --porcelain)" ]] || die "Plugin has local changes: $destination."
    [[ "$(git -C "$destination" rev-parse HEAD)" != "$commit" ]] || return 0
  else
    [[ ! -e "$destination" && ! -L "$destination" ]] || die "Plugin destination already exists: $destination."
    mkdir -p -- "$(dirname -- "$destination")"
    git clone --quiet --filter=blob:none --no-checkout "$repository" "$destination"
  fi
  git -C "$destination" cat-file -e "$commit^{commit}" 2>/dev/null || git -C "$destination" fetch --quiet origin "$commit"
  git -C "$destination" checkout --quiet --detach "$commit"
}

finish() {
  local status=$?
  [[ -z "$TEMP_DIR" ]] || rm -rf -- "$TEMP_DIR"
  if [[ -n "$BACKUP_DIR" ]]; then
    printf '\nBackups: %s\nRestore instructions: README.md\n' "$BACKUP_DIR"
  fi
  if (( status != 0 )); then
    printf '\nSetup stopped. Fix the reported problem and rerun; existing backups are preserved.\n' >&2
  fi
}

main() {
  local arg relative
  for arg in "$@"; do
    case "$arg" in
      --with-dev-tools) WITH_DEV_TOOLS=1 ;;
      --skip-packages) SKIP_PACKAGES=1 ;;
      --dry-run) DRY_RUN=1 ;;
      --yes) ASSUME_YES=1 ;;
      -h|--help) usage; return ;;
      *) die "Unknown argument: $arg (try --help)." ;;
    esac
  done
  check_locations
  check_platform
  if (( DRY_RUN )); then
    printf 'Distribution: %s\nSource: %s\n' "$DISTRO" "$DOTFILES_DIR"
    printf 'Dependency installation: %s (0 = enabled, 1 = skipped)\n' "$SKIP_PACKAGES"
    printf 'Optional Python/Rust tooling: %s (1 = enabled)\n' "$WITH_DEV_TOOLS"
    printf 'Back up conflicting paths, then link:\n'
    printf '  %s\n' "${CONFIGS[@]}"
    printf 'Install pinned tmux and Neovim plugins; compile syntax parsers.\n'
    return
  fi
  (( EUID != 0 )) || die 'Run as your normal user, not root or sudo ./bootstrap.sh.'
  TEMP_DIR="$(mktemp -d)"
  trap finish EXIT
  prepend_bin "${CARGO_HOME:-$HOME/.cargo}/bin"
  prepend_bin "$HOME/.local/bin"
  if (( SKIP_PACKAGES == 0 )); then
    install_packages
    (( WITH_DEV_TOOLS == 0 )) || install_dev_tools
  fi
  check_dependencies
  log 'Linking configuration (conflicting files and symlinks are backed up)'
  for relative in "${CONFIGS[@]}"; do link_file "$DOTFILES_DIR/$relative" "$relative"; done
  log 'Installing pinned tmux plugins'
  clone_pinned https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" "$TPM_COMMIT"
  clone_pinned https://github.com/catppuccin/tmux "$HOME/.tmux/plugins/tmux" "$CATPPUCCIN_TMUX_COMMIT"
  log 'Installing pinned Neovim plugins and syntax parsers'
  DOTFILES_NVIM_BOOTSTRAP="$DOTFILES_DIR/scripts/bootstrap-nvim.lua" \
    nvim --headless -u NONE -c 'lua dofile(vim.env.DOTFILES_NVIM_BOOTSTRAP)'
  log 'Setup complete. Open a new terminal or run: exec bash -l'
  printf 'Optional fonts, Windows Terminal styling, and clipboard setup: README.md\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
