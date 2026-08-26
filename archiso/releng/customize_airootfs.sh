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
