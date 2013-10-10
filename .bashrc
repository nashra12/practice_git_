#!/bin/sh
# bash configuration file
# Written by ayekat on a rainy day in 2009.


# ------------------------------------------------------------------------------
# START {{{

# Check if this is an interactive session:
test -z "$PS1" && return

# }}}
# ------------------------------------------------------------------------------
# GENERAL (SHRC) {{{
# Load general configuration (bash and zsh).
# Contains:
# - SYSTEM
# - ALIASES
# - START-UP ACTIONS

. ~/.shrc

# }}}
# ------------------------------------------------------------------------------
# PROMPT {{{

# Vim statusline colours (fg):
#  22 normal prompt
# 208 visual prompt
#   7 normal filename
# 244 normal middle
#   8 insert prompt
#   7 insert filename
#  45 insert middle
#
# Vim statusline colours (bg):
# 148 normal prompt
#  52 visual prompt
#   8 normal filename
#   0 normal middle
#   7 insert prompt
#  31 insert filename
#  23 insert middle

# Create prompt:
ayeprompt_assemble() {
	git rev-parse 2> /dev/null && git_set=1
	PS1=""

	# Hostname (only if SSH):
	if [ -z "$SSH_TTY" ]; then
		if [ ! $git_set ]; then
			if [ $TERM = 'linux' ]; then
				PS1+="\[\033[1m\]"
				for c in 32 33 31 35 34 36; do
					PS1+="\[\033[${c}m\]:"
				done
			else
				for c in 10 11 9 13 12 14; do
					PS1+="\[\033[38;5;${c}m\]:"
				done
			fi
			PS1+="\[\033[0m\] "
		fi
	else
		PS1+="\[\033[35m\]\h "
	fi
	PS1+="\[\033[0m\]"

	# Git branch (only if in git repo):
	if [ $git_set ]; then
		git_diff=$(git diff --shortstat 2> /dev/null)
		git_branch=$(git branch | grep '*' | cut -c 3-)
		[ -z $git_branch ] && git_branch='empty'
		git_status=$(git status -s)
		git_ahead=$(git status -sb | grep ahead)
		if [ -z "$git_diff" ] && [ -z "$git_status" ]; then
			if [ -z "$git_ahead" ]; then git_colour=34; else git_colour=36; fi
		else
			git_colour=33
		fi
		PS1+="\[\033[${git_colour}m\][$git_branch]\[\033[0m\] "
		unset git_colour
	fi

	# Working directory
	PS1+="\[\033[32m\]\w\[\033[0m\] "

	# Clean variables:
	unset git_set
	unset git_status
	unset git_diff
	unset git_branch
}

# Print Prompt:
PROMPT_COMMAND='ayeprompt_assemble'

# }}}
# ------------------------------------------------------------------------------
# FEEL {{{

# Enable tab completion with sudo:
complete -cf sudo

# Enable Vi/ViM-like behaviour (default: emacs):
#set -o vi

# }}}
# ------------------------------------------------------------------------------
# HISTORY {{{

export HISTIGNORE='&:[bf]g:exit'
export HISTSIZE=100000

# }}}
# ------------------------------------------------------------------------------
# TIMESTAMP {{{
# Allows the usage of preexec() like in zsh.
. $HOME/.bash_preexec.sh

# Print timestamp after having typed command:
preexec() {
	printf "\033[1A\033[1024G\033[10D\033[34m[%s]\033[0m\n" $(date +%H:%M:%S)
}

# Initialise the whole stuff
preexec_install

# }}}

