# Interactive Bash configuration. Put private additions in ~/.bashrc.local.
[[ $- == *i* ]] || return 0

alias ls='ls --color=auto'
alias grep='grep --color=auto'

if command -v dircolors >/dev/null 2>&1; then
  eval "$(dircolors -b)"
  # Apply Windows filesystem workarounds only to an actual WSL mount.
  if [[ -r /proc/sys/kernel/osrelease ]] &&
     grep -qiE 'microsoft|wsl' /proc/sys/kernel/osrelease &&
     grep -q ' /mnt/c ' /proc/mounts; then
    LS_COLORS+=":ow=01;34:tw=01;34:st=01;34"
    grep -qE ' /mnt/c .*[, (]metadata([, )]|$)' /proc/mounts || LS_COLORS+=":ex=00"
  fi
  export LS_COLORS
fi

# Add each optional user bin directory once, including when this file is reloaded.
for dotfiles_bin in "$HOME/.cargo/bin" "$HOME/.local/bin"; do
  if [[ -d "$dotfiles_bin" ]]; then
    case ":$PATH:" in
      *":$dotfiles_bin:"*) ;;
      *) export PATH="$dotfiles_bin:$PATH" ;;
    esac
  fi
done
unset dotfiles_bin

PS1='[\W]\$ '
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi

# shellcheck source=/dev/null
[[ ! -r "$HOME/.bashrc.local" ]] || . "$HOME/.bashrc.local"
