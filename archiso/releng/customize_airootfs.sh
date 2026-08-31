#!/usr/bin/env bash
set -e -u

# oh-my-zsh and its custom plugins are git submodules, copied into place by
# scripts/build-local-repo.sh. If that script wasn't run first, mkarchiso
# would otherwise silently ship an empty .oh-my-zsh directory instead of
# failing the build.
omz_dir=/home/larch/.oh-my-zsh
if [[ ! -s "$omz_dir/oh-my-zsh.sh" ]]; then
    echo "error: $omz_dir looks empty (submodule not checked out)." >&2
    echo "Run scripts/build-local-repo.sh before mkarchiso." >&2
    exit 1
fi
for plugin in zsh-autosuggestions zsh-syntax-highlighting fzf-tab; do
    if [[ -z "$(ls -A "$omz_dir/custom/plugins/$plugin" 2>/dev/null)" ]]; then
        echo "error: $omz_dir/custom/plugins/$plugin is empty (plugin not copied in)." >&2
        echo "Run scripts/build-local-repo.sh before mkarchiso." >&2
        exit 1
    fi
done

gtk-update-icon-cache -f -t /usr/share/icons/hicolor

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
