#!/usr/bin/env bash
# Prepares everything mkarchiso needs that isn't a plain pacman package:
#
# 1. Builds AUR-only packages the profile depends on and drops them into a
#    local pacman repo that archiso/releng/pacman.conf points at via its
#    [custom] repo.
# 2. Builds larch-calamares (our own Calamares fork -- branding, netinstall
#    extras, larch-postinstall module) from its own git repo the same way,
#    into the same local repo. Not an AUR package, so it's cloned from our
#    own remote instead of aur.archlinux.org.
# 3. Checks out the oh-my-zsh and zsh-plugin git submodules, then copies the
#    plugins into place under the oh-my-zsh submodule's (gitignored) custom/
#    plugins/ directory, since git won't let a submodule live inside another
#    submodule's own working tree.
# 4. Downloads the default wallpaper into a shared system location
#    (/usr/share/backgrounds/larch/), not any one user's home -- every
#    user's noctalia config (live "larch" and, via /etc/skel, every
#    installed user) references this same central path, so there's
#    nothing user-specific to get wrong or keep in sync. Fetched at
#    build time rather than committed to the repo, binary image assets
#    don't belong in git history.
# 5. Mirrors /home/larch (the live user's dotfiles: niri, noctalia, zsh,
#    etc.) into /etc/skel, so useradd -m during install seeds new users
#    with the same config instead of Arch's bare-bones default skel.
#    /home/larch stays the one canonical source; skel is derived, not
#    hand-maintained -- run last, after the plugin step above has
#    finished populating /home/larch.
#
# Run this once before mkarchiso, and again whenever the AUR packages or
# submodules need bumping.
#
# LOCAL_REPO and BUILD_DIR live under /tmp rather than inside the checkout:
# pacman.conf's Server= line has to be an absolute path, and a fixed /tmp
# path keeps that path (and the repo) identical no matter where or on which
# machine this checkout lives, instead of baking in one machine's checkout
# path.
set -euo pipefail

if [[ ${EUID} -eq 0 ]]; then
    echo "error: run this as a normal user, not root (makepkg refuses to build as root)" >&2
    exit 1
fi

for cmd in git makepkg repo-add rsync curl; do
    command -v "$cmd" >/dev/null || { echo "error: $cmd not found (install git, rsync, curl, and base-devel)" >&2; exit 1; }
done

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
PROFILE_DIR="$REPO_ROOT/archiso/releng"
OMZ_DIR="$PROFILE_DIR/airootfs/home/larch/.oh-my-zsh"
LOCAL_REPO="/tmp/larch-local-repo"
BUILD_DIR="/tmp/larch-aur-build-cache"

DEFAULT_WALLPAPER_URL="https://github.com/user-attachments/assets/bfae1bd8-1ce8-4534-b602-e6a1e39adaaa"
DEFAULT_WALLPAPER_DEST="$PROFILE_DIR/airootfs/usr/share/backgrounds/larch/default.png"

AUR_PACKAGES=(sddm-silent-theme redhat-fonts herdr-bin)
LARCH_CALAMARES_URL="https://github.com/larch-os/larch-calamares.git"
ZSH_PLUGINS=(zsh-autosuggestions zsh-syntax-highlighting fzf-tab)

git -C "$REPO_ROOT" submodule update --init --recursive

for plugin in "${ZSH_PLUGINS[@]}"; do
    rsync -a --delete --exclude='.git' "$REPO_ROOT/vendor/zsh-plugins/$plugin/" "$OMZ_DIR/custom/plugins/$plugin/"
done

mkdir -p "$LOCAL_REPO" "$BUILD_DIR"

for pkg in "${AUR_PACKAGES[@]}"; do
    pkg_dir="$BUILD_DIR/$pkg"
    if [[ -d "$pkg_dir" ]]; then
        git -C "$pkg_dir" pull --ff-only
    else
        git clone "https://aur.archlinux.org/$pkg.git" "$pkg_dir"
    fi

    (cd "$pkg_dir" && makepkg -sf --noconfirm --needed)

    cp -f "$pkg_dir"/*.pkg.tar.zst "$LOCAL_REPO/"
done

calamares_dir="$BUILD_DIR/larch-calamares"
if [[ -d "$calamares_dir" ]]; then
    git -C "$calamares_dir" pull --ff-only
else
    git clone "$LARCH_CALAMARES_URL" "$calamares_dir"
fi

(cd "$calamares_dir" && makepkg -sf --noconfirm --needed)

cp -f "$calamares_dir"/*.pkg.tar.zst "$LOCAL_REPO/"

repo-add "$LOCAL_REPO/custom.db.tar.gz" "$LOCAL_REPO"/*.pkg.tar.zst

sed -i "s#^Server = file://.*#Server = file://$LOCAL_REPO#" "$PROFILE_DIR/pacman.conf"

mkdir -p "$(dirname "$DEFAULT_WALLPAPER_DEST")"
curl -fsSL "$DEFAULT_WALLPAPER_URL" -o "$DEFAULT_WALLPAPER_DEST"

rsync -a --delete "$PROFILE_DIR/airootfs/home/larch/" "$PROFILE_DIR/airootfs/etc/skel/"

echo "Local repo ready at $LOCAL_REPO (incl. larch-calamares), pacman.conf updated, zsh plugins in place, default wallpaper fetched to a central location, /etc/skel synced from /home/larch."
