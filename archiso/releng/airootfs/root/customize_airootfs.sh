#!/usr/bin/env bash
set -e -u

# oh-my-zsh and its custom plugins are git submodules, copied into place by
# scripts/prepare-iso.sh. If that script wasn't run first, mkarchiso
# would otherwise silently ship an empty .oh-my-zsh directory instead of
# failing the build.
omz_dir=/home/larch/.oh-my-zsh
if [[ ! -s "$omz_dir/oh-my-zsh.sh" ]]; then
    echo "error: $omz_dir looks empty (submodule not checked out)." >&2
    echo "Run: make prepare (scripts/prepare-iso.sh) before mkarchiso." >&2
    exit 1
fi
for plugin in zsh-autosuggestions zsh-syntax-highlighting fzf-tab; do
    if [[ -z "$(ls -A "$omz_dir/custom/plugins/$plugin" 2>/dev/null)" ]]; then
        echo "error: $omz_dir/custom/plugins/$plugin is empty (plugin not copied in)." >&2
        echo "Run: make prepare (scripts/prepare-iso.sh) before mkarchiso." >&2
        exit 1
    fi
done

# Chaotic-AUR: a prebuilt binary repo, used for a few packages neither the
# base Arch repos nor our own local build script (scripts/prepare-iso.sh)
# cover -- paru itself here (avoids the chicken-and-egg of building an AUR
# helper via makepkg -- chaotic only carries source-built "paru", not a
# "paru-bin", no functional difference since chaotic prebuilds it either
# way), and visual-studio-code-bin at install time only (see
# larch-calamares' netinstall/netinstall.conf; that one's never installed
# here, only made resolvable for later).
#
# Configured here, post-pacstrap, not as a static [chaotic-aur] entry in
# the profile's own pacman.conf: mkarchiso's pacstrap call passes -G (skip
# copying the host's already-trusted keyring), so this needs its own
# from-scratch keyring bootstrap rather than relying on anything the
# initial pacstrap set up.
#
# --init/--populate first: -G means the target never got the host's
# keyring, and nothing else in a bare pacstrap -G bootstrap runs this on
# its own -- confirmed the hard way ("You do not have sufficient
# permissions to read the pacman keyring", pacman-key's own generic error
# for an uninitialized target keyring, not an actual filesystem
# permissions bug despite the wording).
#
# Order matters for the rest: every pacman-suite tool parses the *entire*
# pacman.conf up front, Include= directives and all. Appending
# [chaotic-aur]'s Include= line before chaotic-mirrorlist is actually
# installed breaks every subsequent pacman call, including the very
# pacman -U call meant to install it (this one really did surface as
# "config file /etc/pacman.d/chaotic-mirrorlist could not be read" the
# first time). Key trust + the actual keyring/mirrorlist package installs
# must both happen *before* pacman.conf ever mentions chaotic-aur at all.
# pacman's CheckSpace pre-flight can't reliably determine the root
# mount point from inside arch-chroot (this isn't a real bind-mounted
# filesystem) and misreports "not enough free disk space" even with
# tens of GB actually free -- confirmed the hard way. Only an install
# operation triggers this check, which is why the earlier pacman -Rdd
# (remove) call above never hit it. A well-known false positive for
# pacman-in-a-chroot, not specific to Chaotic-AUR's packages.
sed -i '/^CheckSpace/d' /etc/pacman.conf
pacman-key --init
pacman-key --populate archlinux
pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
pacman-key --lsign-key 3056513887B78AEB
pacman -U --noconfirm \
    'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
    'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
cat >>/etc/pacman.conf <<'EOF'

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
pacman -Sy
pacman -S --noconfirm --needed paru

gtk-update-icon-cache -f -t /usr/share/icons/hicolor

# docker/docker-buildx land here as a transitive dependency of k3d-bin (k3d
# runs k3s inside Docker, so it's a hard `depends=`), not because we listed
# them -- pacstrap pulls in dependencies of anything in packages.x86_64
# whether we asked for them or not. Docker is meant to be strictly opt-in
# (the netinstall extras page already offers it, installed fresh with real
# network access at that point), so stripping it back out here keeps it out
# of both the live session and any install that doesn't explicitly pick it.
# -Rdd: skip dependency and file-conflict checks, since k3d-bin nominally
# still depends on it -- this leaves that dependency unsatisfied on purpose,
# the k3d binary itself is unaffected, it just needs Docker installed
# separately to actually run anything.
pacman -Rdd --noconfirm docker docker-buildx 2>/dev/null || true

# Overwritten here rather than shipped as a plain airootfs overlay file: the
# fontconfig package installs its own (empty) 51-local.conf at this same
# path, and _make_custom_airootfs runs before pacstrap, so an overlay copy
# would conflict with pacman's install instead of just overwriting it.
install -Dm644 /dev/stdin /usr/share/fontconfig/conf.default/51-local.conf <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>

  <!-- Default UI sans-serif -->
  <match target="pattern">
    <test qual="any" name="family"><string>sans-serif</string></test>
    <edit name="family" mode="prepend" binding="strong"><string>Adwaita Sans</string></edit>
  </match>

  <!-- Default serif -->
  <match target="pattern">
    <test qual="any" name="family"><string>serif</string></test>
    <edit name="family" mode="prepend" binding="strong"><string>Noto Serif</string></edit>
  </match>

  <!-- Default monospace -->
  <match target="pattern">
    <test qual="any" name="family"><string>monospace</string></test>
    <edit name="family" mode="prepend" binding="strong"><string>JetBrainsMono Nerd Font</string></edit>
  </match>

  <!-- Emoji -->
  <match target="pattern">
    <test qual="any" name="family"><string>emoji</string></test>
    <edit name="family" mode="prepend" binding="strong"><string>Noto Color Emoji</string></edit>
  </match>

  <!-- CJK fallback for sans-serif -->
  <match target="pattern">
    <test qual="any" name="family"><string>sans-serif</string></test>
    <edit name="family" mode="append" binding="weak"><string>Noto Sans CJK JP</string></edit>
  </match>

  <!-- system-ui alias, used by some GTK4/libadwaita apps -->
  <match target="pattern">
    <test qual="any" name="family"><string>system-ui</string></test>
    <edit name="family" mode="prepend" binding="strong"><string>Adwaita Sans</string></edit>
  </match>

</fontconfig>
EOF
