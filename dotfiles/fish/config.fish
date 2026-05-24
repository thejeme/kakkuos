# ~/.config/fish/config.fish

# Disable default greeting
set fish_greeting ""

if status is-interactive
    if not set -q EDITOR
        if command -q nvim
            set -gx EDITOR nvim
        else if command -q nano
            set -gx EDITOR nano
        end
    end

    set -q PAGER; or set -gx PAGER less
    set -q LESS; or set -gx LESS -FRX
    set -q FZF_DEFAULT_OPTS; or set -gx FZF_DEFAULT_OPTS "--height=40% --layout=reverse --border"

    if command -q fd
        set -gx FZF_DEFAULT_COMMAND "fd --type f --hidden --follow --exclude .git"
        set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
        set -gx FZF_ALT_C_COMMAND "fd --type d --hidden --follow --exclude .git"
    end

    if command -q eza
        alias ls "eza --group-directories-first --icons=auto"
        alias la "eza -a --group-directories-first --icons=auto"
        alias ll "eza -lah --group-directories-first --icons=auto --git"
        alias lt "eza --tree --level=2 --group-directories-first --icons=auto"
    end

    if command -q bat
        alias cat "bat --paging=never"
    end

    if command -q rg
        alias grep rg
    end

    if command -q fd
        alias find fd
    end

    if command -q duf
        alias df duf
    end

    if command -q dust
        alias du dust
    end

    if command -q procs
        alias ps procs
    end

    if command -q yazi
        alias y yazi
        alias fm yazi

        function yy
            set -l tmp (mktemp -t yazi-cwd.XXXXXX)
            yazi $argv --cwd-file="$tmp"

            if test -f "$tmp"
                set -l cwd (cat "$tmp")
                rm -f "$tmp"

                if test -n "$cwd"; and test "$cwd" != "$PWD"
                    cd "$cwd"
                end
            end
        end
    end

    if command -q tldr
        alias helpme tldr
    end

    # Initialize prompts and integrations
    if command -q starship
        set -gx STARSHIP_CONFIG "$HOME/.config/starship/starship.toml"
        starship init fish | source
    end

    if command -q zoxide
        zoxide init fish --cmd cd | source
    end
    
    if command -q fzf
        fzf --fish | source 2>/dev/null || true
    end
end
