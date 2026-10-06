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
| browser | librewolf | - |
| launcher | fuzzel | - |
| wallpaper | awww | - |

## install

```sh
# arch: pacman -S chezmoi    macos: brew install chezmoi
git clone https://github.com/lluppi/dotfiles.git ~/clone/dotfiles
chezmoi init --source ~/clone/dotfiles   # writes ~/.config/chezmoi/chezmoi.toml pointing at the checkout
chezmoi diff                             # see what would change
chezmoi apply
```
## structure

```
home/
├── .chezmoiignore              # per-os gating
├── .chezmoi.toml.tmpl          # chezmoi config, keeps sourceDir on this checkout
├── dot_zshrc                   # shared shell config
├── dot_config/
│   ├── zsh/                    # darwin.zsh / linux.zsh
│   ├── ghostty/config.tmpl     # terminal, per-os bits templated
│   ├── nvim/                   # neovim
│   ├── lazygit/                # lazygit
│   ├── executable_starship.toml
│   ├── hypr/ quickshell/ fuzzel/ gtk-3.0/ gtk-4.0/ librewolf/   # linux only
├── dot_local/                  # linux only: bin/ scripts, gtk theme
├── dot_aerospace.toml          # macos only
├── dot_hammerspoon/            # macos only
└── private_Library/            # macos only: lazygit symlink
```
