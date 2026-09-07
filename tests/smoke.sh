#!/usr/bin/env bash
set -euo pipefail
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
test_directory="$(mktemp -d)"
tmux_socket="dotfiles-smoke-$$"
trap 'tmux -L "$tmux_socket" kill-server 2>/dev/null || true; rm -rf -- "$test_directory"' EXIT
export DOTFILES_SMOKE_LUA="$repo/tests/smoke.lua"
export DOTFILES_TEST_DEV="${1:-0}"

bash --noprofile --rcfile "$HOME/.bashrc" -ic 'command -v starship; command -v nvim'
bash --noprofile --norc -ic 'source "$HOME/.bash_profile"; source "$HOME/.bash_profile"; [[ "$PATH" != *"$HOME/.local/bin:$HOME/.local/bin"* ]]'
starship prompt >/dev/null
tmux -L "$tmux_socket" -f "$HOME/.tmux.conf" new-session -d -s smoke
[[ "$(tmux -L "$tmux_socket" show-option -gv status-position)" == top ]]
[[ "$(tmux -L "$tmux_socket" show-option -gv @catppuccin_flavor)" == mocha ]]

printf '[project]\nname = "smoke-example"\nversion = "0.0.0"\n' > "$test_directory/pyproject.toml"
printf 'value: int = 1\n' > "$test_directory/example.py"
nvim --headless "$test_directory/example.py" -c 'lua dofile(vim.env.DOTFILES_SMOKE_LUA)'
if [[ "$DOTFILES_TEST_DEV" == 1 ]]; then
  mkdir -p "$test_directory/src"
  printf '[package]\nname = "smoke-example"\nversion = "0.1.0"\nedition = "2021"\n' > "$test_directory/Cargo.toml"
  printf 'fn main() {}\n' > "$test_directory/src/main.rs"
  nvim --headless "$test_directory/src/main.rs" -c 'lua dofile(vim.env.DOTFILES_SMOKE_LUA)'
fi
git -C "$repo" diff --exit-code
[[ -z "$(git -C "$repo" status --porcelain)" ]]
printf 'Shell, tmux, Neovim, plugins, and language-server checks passed.\n'
