#!/bin/bash
# Sets up greetd + quickshell greeter + lock screen on a fresh Arch install.
# Run as your normal user (not root). Assumes dotfiles are at ~/dotfiles.

set -e

DOTFILES="$HOME/dotfiles"
QS_CONFIG="$HOME/.config/quickshell"

# ---- sanity checks ----

if [[ "$EUID" -eq 0 ]]; then
    echo "run as your normal user, not root" >&2
    exit 1
fi

if [[ ! -d "$QS_CONFIG" ]]; then
    echo "quickshell config not found at $QS_CONFIG — clone your dotfiles first" >&2
    exit 1
fi

# ---- packages ----

echo "==> installing packages..."
sudo pacman -S --needed --noconfirm greetd cage seatd

if ! pacman -Qi quickshell-git &>/dev/null; then
    if command -v yay &>/dev/null; then
        yay -S --needed --noconfirm quickshell-git
    else
        echo "quickshell-git not installed and yay not found — install it manually then re-run" >&2
        exit 1
    fi
fi

# ---- greeter user ----

echo "==> creating greeter user..."
if ! id greeter &>/dev/null; then
    sudo useradd -r -s /sbin/nologin -M -d /var/lib/greeter greeter
fi

sudo usermod -aG video greeter
sudo usermod -aG seat greeter

# ---- seatd ----

echo "==> enabling seatd..."
sudo systemctl enable --now seatd

# ---- PAM config ----

echo "==> writing /etc/pam.d/quickshell..."
sudo tee /etc/pam.d/quickshell > /dev/null << 'EOF'
#%PAM-1.0
auth     required    pam_unix.so nullok
account  required    pam_unix.so
EOF

# ---- greeter wrapper ----

echo "==> writing /usr/local/bin/greeter-wrapper.sh..."
sudo tee /usr/local/bin/greeter-wrapper.sh > /dev/null << 'EOF'
#!/bin/bash
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export QT_QPA_PLATFORM=wayland
printf '\033[2J\033[H\033[?25l'
setterm -background black -foreground black -clear all 2>/dev/null || true
exec cage -s -- qs -p /etc/quickshell/greeter.qml > /dev/null 2>&1
EOF
sudo chmod +x /usr/local/bin/greeter-wrapper.sh

# ---- greetd config ----

echo "==> writing /etc/greetd/config.toml..."
sudo tee /etc/greetd/config.toml > /dev/null << 'EOF'
[terminal]
vt = 1

[default_session]
command = "greeter-wrapper.sh"
user = "greeter"
EOF

# ---- /etc/quickshell symlinks ----

echo "==> setting up /etc/quickshell..."
sudo mkdir -p /etc/quickshell

for target in greeter.qml modules scripts; do
    sudo ln -sfn "$QS_CONFIG/$target" "/etc/quickshell/$target"
done

# ---- home dir traversal permissions ----
# greeter user needs o+x on each directory in the path to reach the symlink targets

echo "==> setting traversal permissions on home dirs..."
chmod o+x "$HOME"
chmod o+x "$HOME/.config"
chmod o+x "$QS_CONFIG"

# ---- enable greetd ----

echo "==> enabling greetd..."
# disable any other display managers that might conflict
for dm in sddm lightdm gdm lxdm; do
    if systemctl is-enabled "$dm" &>/dev/null; then
        echo "    disabling $dm..."
        sudo systemctl disable "$dm"
    fi
done

sudo systemctl enable greetd

echo ""
echo "done — reboot to start logging in through the greeter"
