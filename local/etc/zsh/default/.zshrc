#!/usr/bin/env zsh
# (C) 2020 - Roosembert Palacios <roosemberth@posteo.ch>
# Released under CC BY-NC-SA License: https://creativecommons.org/licenses/
# Based on my own previous zsh configuration, available on gitlab, under tag
# prereset-2020.

# -----------------------------------------------------------------------------
# Profiling. There's small related section at the end of this file. {{{
# See http://stackoverflow.com/a/4351664/2418854
if [ ! -z "$ZSH_PROFILING" ]; then
    # Set the trace prompt to include seconds, nanoseconds, script name and
    # line number. This is GNU date syntax; by default Macs ship with the BSD
    # date program, which is not compatible.
    PS4='+$(date "+%s:%N") %N:%i> '
    # Save stderr fd into fd 3 and redirect stderr (including trace output) to
    # a file with the script's PID as an extension.
    exec 3>&2 2>/tmp/zshprofiling.$$
    # Set options to turn on tracing and expansion of commands contained in the
    # prompt.
    setopt xtrace prompt_subst
fi
# }}}

export EDITOR="$(command -v vim)"
export VISUAL="$(command -v vim) -O"
export PAGER="$(command -v less) -j.3"

# Honor the XDG directory specification as best as possible. {{{
# https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share/:/usr/share/}"
export XDG_CONFIG_DIRS="${XDG_CONFIG_DIRS:-/etc/xdg}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
if [ -z "$XDG_RUNTIME_DIR" ]; then
    echo "Warning: XDG_RUNTIME_DIR is not set. Fallback to ~/.local/run" >&2
    export XDG_RUNTIME_DIR="~/.local/run"
    if [ ! -d "$XDG_RUNTIME_DIR" ]; then
        if mkdir -p "$XDG_RUNTIME_DIR"; then
            chmod 700 "$XDG_RUNTIME_DIR"
        else
            echo "Could not create fallback XDG_RUNTIME_DIR." >&2
            unset XDG_RUNTIME_DIR
        fi
    fi
fi
# }}}

# Make sure the zsh cache directory exists:
test -d "$XDG_CACHE_HOME/zsh" || mkdir -p "$XDG_CACHE_HOME/zsh"

# Nix and NixOS-specific configuration {{{
if [ -d /run/current-system/sw/share/zsh/site-functions ]; then
  fpath+=(/run/current-system/sw/share/zsh/site-functions)
fi
if [ -d ~/.nix-profile/share/zsh/site-functions ]; then
  fpath+=(~/.nix-profile/share/zsh/site-functions)
fi
if command -v fzf-share &> /dev/null; then
  source "$(fzf-share)/completion.zsh"
  source "$(fzf-share)/key-bindings.zsh"
fi
# }}}

autoload -Uz compinit
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"

# Print 'completing ...' when completing:
expand-or-complete-with-dots () {
    printf "$fg[blue] completing ...$reset_color\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
    zle expand-or-complete
    zle redisplay
}
zle -N expand-or-complete-with-dots
bindkey "^I" expand-or-complete-with-dots

# -----------------------------------------------------------------------------
# Profiling closure. See profiling section at the beginning of this file {{{
if [ ! -z "$ZSH_PROFILING" ]; then
    # turn off tracing
    unsetopt xtrace
    # restore stderr to the value saved in FD 3
    exec 2>&3 3>&-
fi
# }}}

# vim:expandtab:shiftwidth=4:tabstop=4:colorcolumn=80
