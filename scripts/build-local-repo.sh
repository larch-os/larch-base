#!/usr/bin/env bash
# Builds AUR-only packages the profile depends on (not in the official repos)
# and drops them into a local pacman repo that archiso/releng/pacman.conf points
# at via its [custom] repo. Run this once before mkarchiso, and again whenever
# these packages need bumping.
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

for cmd in git makepkg repo-add; do
    command -v "$cmd" >/dev/null || { echo "error: $cmd not found (install git and base-devel)" >&2; exit 1; }
done

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
PROFILE_DIR="$REPO_ROOT/archiso/releng"
LOCAL_REPO="/tmp/larch-local-repo"
BUILD_DIR="/tmp/larch-aur-build-cache"

AUR_PACKAGES=(sddm-silent-theme redhat-fonts)

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

repo-add "$LOCAL_REPO/custom.db.tar.gz" "$LOCAL_REPO"/*.pkg.tar.zst

sed -i "s#^Server = file://.*#Server = file://$LOCAL_REPO#" "$PROFILE_DIR/pacman.conf"

echo "Local repo ready at $LOCAL_REPO, pacman.conf updated."
