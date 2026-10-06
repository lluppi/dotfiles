# sourced by ~/.zshrc on linux (arch)

export ZSH="$HOME/.config/oh-my-zsh"
export DISABLE_AUTO_UPDATE="true"
export DISABLE_UPDATE_PROMPT="true"

plugins=(
	git
    copybuffer
    command-not-found
    zsh-interactive-cd
)

source /usr/share/doc/pkgfile/command-not-found.zsh
source $ZSH/oh-my-zsh.sh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

path=(
	"$HOME/.config/ncmpcpp/ncmpcpp-ueberzug"
	"$HOME/clone/go_projects/bin"
	$path
)
export TERM="xterm-ghostty"
export BROWSER="librewolf"
export GOPATH="$HOME/clone/go_projects/"
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
export BUN_INSTALL="$HOME/.bun"

export GTK_THEME=Kool
# export GTK2_RC_FILES=/usr/share/themes/Adwaita-dark/gtk-2.0/gtkrc
export QT_STYLE_OVERRIDE=adwaita-dark

alias pdf="sioyek"
alias shutdown="shutdown now"
alias templs="templ generate --watch --proxy=\"http://localhost:8080\" --cmd=\"go run .\""
alias sd="shutdown now"
alias rb="reboot"
alias gfx="lspci -nnk | grep -A2 VGA"
# alias battery="cat /sys/class/power_supply/BAT0/capacity"
alias battery="upower -i /org/freedesktop/UPower/devices/battery_BAT0"
alias ff="librewolf > /dev/null 2>&1 &> /dev/null 2>&1 & disown"
alias discord="discord --no-sandbox > /dev/null 2>&1 &> /dev/null 2>&1 & disown"
alias fonts="fc-list"
alias sshmount="sshfs root@imre.al:/var/www ~/imre.al"
alias mail="mailsync > /dev/null 2>&1 &> /dev/null 2>&1 & bash -c neomutt"
alias music="ncmpcpp -q"
alias zbr="zig build run"
alias jz="~/clone/jetzig/cli/zig-out/bin/jetzig"
alias c="claude"
