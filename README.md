# dotfiles

one repo for arch (linux) and macos, managed with [chezmoi](https://chezmoi.io)

## details

| component | linux | macos |
|-----------|-------|-------|
| wm | hyprland | aerospace + hammerspoon |
| bar | quickshell | hammerspoon |
| terminal | ghostty | ghostty |
| editor | neovim | neovim |
| shell | zsh (oh-my-zsh) | zsh |
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

## day to day

- edit in the repo (`chezmoi cd` or `~/clone/dotfiles/home`), then `chezmoi apply`
- or edit a live file, then `chezmoi re-add` to pull it back into the repo (nvim's `lazy-lock.json` after `:Lazy update`)
- `chezmoi diff` before applying; commit and push from the repo like normal

## how os gating works

- `.chezmoiroot` points chezmoi at `home/`, which mirrors `$HOME` in chezmoi naming (`dot_config` = `.config`, `executable_` = +x, `private_` = 0700, `symlink_` = symlink, `.tmpl` = go template)
- `home/.chezmoiignore` skips linux-only files on macos (hypr, quickshell, fuzzel, gtk, librewolf, `.local/bin`, themes) and macos-only files on linux (aerospace, hammerspoon, `Library/`)
- small differences live in templates: `ghostty/config.tmpl` (`{{ if eq .chezmoi.os "darwin" }}`)
- big differences live in per-os files: `.zshrc` is shared and sources `~/.config/zsh/darwin.zsh` or `linux.zsh`
- lazygit's config is `~/.config/lazygit/config.yml` on both; on macos `~/Library/Application Support/lazygit/config.yml` is a symlink to it

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
