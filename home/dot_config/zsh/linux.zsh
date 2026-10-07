# sourced by ~/.zshrc on linux (arch)

# "did you mean to install X" for unknown commands (pacman -S pkgfile && pkgfile --update)
[[ -r /usr/share/doc/pkgfile/command-not-found.zsh ]] && source /usr/share/doc/pkgfile/command-not-found.zsh

path=(
	"$HOME/clone/go_projects/bin"
	$path
)
export BROWSER="librewolf"
export GOPATH="$HOME/clone/go_projects"
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)

export GTK_THEME=Kool
export QT_STYLE_OVERRIDE=adwaita-dark

alias pdf="sioyek"
alias sd="shutdown now"
alias rb="reboot"
alias gfx="lspci -nnk | grep -A2 VGA"
alias battery="upower -i /org/freedesktop/UPower/devices/battery_BAT0"
alias ff="librewolf &>/dev/null & disown"
alias discord="discord --no-sandbox &>/dev/null & disown"
alias fonts="fc-list"
alias zbr="zig build run"
alias c="claude"
