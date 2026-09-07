# Login shells use the shared interactive configuration and optional local hooks.
# shellcheck source=/dev/null
[[ ! -r "$HOME/.bashrc" ]] || . "$HOME/.bashrc"
# shellcheck source=/dev/null
[[ ! -r "$HOME/.bash_profile.local" ]] || . "$HOME/.bash_profile.local"
