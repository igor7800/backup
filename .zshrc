# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh
unsetopt correct_all


#theme 
ZSH_THEME="garyblessington"

[[ $- != *i* ]] && return

#alias
#alias reboot='sudo reboot'
alias poweroff='sudo poweroff'
alias lock='i3lock'
alias p='sudo pacman'
alias e='emacs -nw'
alias y='yaourt'
alias ls='ls --color=auto'
alias aauconnect='ssh isyryt11@skoda.es.aau.dk '
alias ll='ls -lh'
alias pico='nano'
alias p5='cd ~/svn/project5'
alias rep='cd ~/svn/project5/rep'
alias devices='sudo fdisk -l'
alias monitors='arandr'
alias matlab='cd ~/matlab/bin/ && ./matlab -nojvm'

PS1='[\u@\h \W]\$ '
plugins=(git archlinux)
source $ZSH/oh-my-zsh.sh
#PROMPT="[%~]$ %{$reset_color%}"
