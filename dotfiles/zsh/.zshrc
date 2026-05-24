# ~/.zshrc

if [[ -o interactive ]]; then
  if [[ -z "${EDITOR:-}" ]]; then
    if command -v nvim >/dev/null 2>&1; then
      export EDITOR="nvim"
    else
      export EDITOR="nano"
    fi
  fi

  export PAGER="${PAGER:-less}"
  export LESS="${LESS:--FRX}"

  if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
  fi

  export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:---height=40% --layout=reverse --border}"

  if command -v starship >/dev/null 2>&1; then
    export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
    eval "$(starship init zsh)"
  fi

  if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh --cmd cd)"
  fi

  if [[ -r /usr/share/fzf/key-bindings.zsh ]]; then
    source /usr/share/fzf/key-bindings.zsh
  fi

  if [[ -r /usr/share/fzf/completion.zsh ]]; then
    source /usr/share/fzf/completion.zsh
  fi

  if command -v eza >/dev/null 2>&1; then
    alias ls='eza --group-directories-first --icons=auto'
    alias la='eza -a --group-directories-first --icons=auto'
    alias ll='eza -lah --group-directories-first --icons=auto --git'
    alias lt='eza --tree --level=2 --group-directories-first --icons=auto'
  fi

  if command -v bat >/dev/null 2>&1; then
    alias cat='bat --paging=never'
  fi

  if command -v rg >/dev/null 2>&1; then
    alias grep='rg'
  fi

  if command -v fd >/dev/null 2>&1; then
    alias find='fd'
  fi

  if command -v duf >/dev/null 2>&1; then
    alias df='duf'
  fi

  if command -v dust >/dev/null 2>&1; then
    alias du='dust'
  fi

  if command -v procs >/dev/null 2>&1; then
    alias ps='procs'
  fi

  if command -v yazi >/dev/null 2>&1; then
    alias y='yazi'
    alias fm='yazi'

    yy() {
      local tmp
      tmp="$(mktemp -t yazi-cwd.XXXXXX)"
      yazi "$@" --cwd-file="$tmp"

      if [[ -f "$tmp" ]]; then
        local cwd
        cwd="$(cat "$tmp")"
        rm -f "$tmp"

        if [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
          cd "$cwd"
        fi
      fi
    }
  fi

  if command -v tldr >/dev/null 2>&1; then
    alias helpme='tldr'
  fi
fi
