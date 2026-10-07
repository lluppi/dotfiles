# dotfiles


| component | linux | macos |
|-----------|-------|-------|
| wm | hyprland | aerospace + hammerspoon |
| bar | quickshell | hammerspoon |
| terminal | ghostty | ghostty |
| editor | neovim | neovim |
| shell | zsh | zsh |
| prompt | starship | starship |
| git ui | lazygit | lazygit |
| multiplexer | tmux | tmux |
| files | yazi | yazi |
| history | atuin | atuin |
| pdf | sioyek | sioyek |
| music | ncmpcpp + drome-lord (navidrome) | ncmpcpp + drome-lord (navidrome) |
| browser | librewolf | - |
| launcher | fuzzel | - |
| wallpaper | awww | - |

## install

```sh
# arch:  pacman -S chezmoi fzf fnm starship eza bat zoxide git-delta tmux atuin yazi zsh-autosuggestions zsh-syntax-highlighting pkgfile mpv ncmpcpp
#        yay -S sioyek-git
# macos: brew install chezmoi fzf fnm starship eza bat zoxide git-delta tmux atuin yazi zsh-autosuggestions zsh-syntax-highlighting mpv ncmpcpp && brew install --cask sioyek
git clone https://github.com/lluppi/dotfiles.git ~/clone/dotfiles
chezmoi init --source ~/clone/dotfiles   # asks git name/email/signing key once, writes ~/.config/chezmoi/chezmoi.toml
chezmoi diff                             # see what would change
chezmoi apply                            # also clones fzf-tab + yazi flavor
atuin import zsh                         # pull existing zsh history into atuin
# music: build ~/clone/drome-lord with zig 0.17 (zig build -Doptimize=ReleaseSafe --prefix ~/.local), put the navidrome
#        login in ~/.config/drome-lord/credentials (username = / password =, chmod 600), chezmoi apply starts the service
```
## structure

```
home/
├── .chezmoiignore              # per-os gating
├── .chezmoi.toml.tmpl          # chezmoi config, keeps sourceDir on this checkout
├── .chezmoiexternal.toml       # fzf-tab, yazi kanagawa flavor
├── dot_zshrc                   # shared shell config
├── dot_gitconfig.tmpl          # git, identity from chezmoi.toml (not in this repo)
├── dot_config/
│   ├── zsh/                    # darwin.zsh / linux.zsh
│   ├── ghostty/config.tmpl     # terminal, per-os bits templated
│   ├── nvim/                   # neovim
│   ├── lazygit/                # lazygit
│   ├── tmux/ sioyek/ atuin/ yazi/ ncmpcpp/ drome-lord/
│   ├── systemd/user/drome-lord.service   # linux only
│   ├── executable_starship.toml
│   ├── hypr/ quickshell/ fuzzel/ gtk-3.0/ gtk-4.0/ librewolf/   # linux only
├── private_dot_local/          # linux only: bin/ scripts, gtk theme
├── run_after_librewolf-userchrome.sh.tmpl  # linux: links userChrome.css into every librewolf profile
├── dot_aerospace.toml          # macos only
├── dot_hammerspoon/            # macos only
├── run_onchange_after_drome-lord.sh.tmpl  # (re)starts the drome-lord service, systemd or launchd
└── private_Library/            # macos only: lazygit symlink, drome-lord launch agent
```
