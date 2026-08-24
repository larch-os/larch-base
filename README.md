# Larch

Arch based linux distro for lazy yet power users.

Built on stock Arch Linux repositories (no custom package repo). Default desktop is [niri](https://github.com/YaLTeR/niri) (Wayland scrollable-tiling compositor) with [noctalia](https://github.com/noctalia-dev/noctalia-shell) (Quickshell-based shell). Installation uses a custom TUI installer instead of Calamares. See `docs/arch-niri-distro-context.md` for the design write-up.

## Repo layout

```
archiso/releng/   archiso profile for the ISO, forked from the official releng profile
assets/           brand assets (logo, splash source)
docs/             design notes
```

## Building the ISO

Requires `archiso` installed on an Arch host (or run inside an Arch container).

```sh
sudo mkarchiso -v -o out/ archiso/releng
```

Output lands in `out/larch-<date>-x86_64.iso`.

## Status

- [x] Branding: ISO metadata, boot menus (syslinux/systemd-boot/grub), splash image, `os-release`/`issue`, hostname, motd
- [ ] Package list (niri, noctalia, install-time tooling)
- [ ] Live-session config (niri/noctalia defaults, autostart)
- [ ] TUI installer
- [ ] Post-install provisioning (shell/desktop-shell choice, config copy)
