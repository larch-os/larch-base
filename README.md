# Larch

Arch based linux distro for lazy yet power users.

Built almost entirely on stock Arch Linux repositories. Default desktop is [niri](https://github.com/YaLTeR/niri) (Wayland scrollable-tiling compositor) with [noctalia](https://github.com/noctalia-dev/noctalia-shell) (Quickshell-based shell). Installation uses a custom TUI installer instead of Calamares. See `docs/arch-niri-distro-context.md` for the design write-up.

The one exception: `noctalia-qs`, `noctalia-shell`, `sddm-silent-theme`, and `redhat-fonts` (a dependency of the SDDM theme) are AUR-only. `scripts/build-local-repo.sh` builds them and feeds them into a local pacman repo the profile points at, so `mkarchiso` still works offline of the AUR.

## Repo layout

```
archiso/releng/   archiso profile for the ISO, forked from the official releng profile
scripts/          build-time tooling (AUR-package local repo)
assets/           brand assets (logo, splash source)
docs/             design notes
```

## Building the ISO

Requires `archiso`, `git`, and `base-devel` installed on an Arch host (or run inside an Arch container).

```sh
./scripts/build-local-repo.sh          # once, and whenever the AUR packages need bumping
sudo mkarchiso -v -o out/ archiso/releng
```

Output lands in `out/larch-<date>-x86_64.iso`.

## Testing in a VM (libvirt/QEMU)

niri needs a real GPU render node. A default virt-install VM (plain `virtio-vga`/QXL, no 3D) boots fine but shows a black screen forever, because niri can never bring up an output. Three things need to be true on the VM, and any change to them requires a full power-off and start, not a guest reboot, since QEMU only re-reads video/graphics/memory config when the process itself restarts.

**Video device.** Needs virtio-gpu with 3D acceleration (virgl), not plain `virtio-vga`. In virt-manager, that's the video model's 3D acceleration checkbox. If it doesn't actually take, check `/var/log/libvirt/qemu/<vm>.log` for the real `-device` line: libvirt sometimes silently keeps the non-GL device even with `accel3d='yes'` set. Force it directly:

```xml
<video>
  <model type='none'/>
</video>
...
<qemu:commandline xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
  <qemu:arg value='-device'/>
  <qemu:arg value='virtio-vga-gl,id=video0,bus=pcie.0,addr=0x1'/>
</qemu:commandline>
```

**Graphics.** SPICE needs GL enabled with a local listener, not a TCP one:

```xml
<graphics type='spice'>
  <listen type='none'/>
  <gl enable='yes' rendernode='/dev/dri/renderD128'/>
</graphics>
```

**Memory backend.** virtio-gpu 3D needs shared memory:

```xml
<memoryBacking>
  <source type='memfd'/>
  <access mode='shared'/>
</memoryBacking>
```

Give the VM at least 4GB RAM and 4 vCPUs. Default templates hand out 1GB/2 vCPUs, which is too tight for a Qt6/QML shell.

A few VM-only quirks worth knowing, not bugs to fix:

- The virtual display shows up as `Virtual-1`, not `eDP-1`/`HDMI-A-1`, so niri's per-output config doesn't match it and it falls back to the GPU's default 1280x800. Reapply the real resolution by hand: `niri msg output Virtual-1 mode 1920x1080@60.000`.
- A VM has no Wi-Fi device by default. noctalia's network panel only shows its Wi-Fi/Ethernet toggle when both interface types exist, so on ethernet-only hardware it stays stuck on an empty Wi-Fi view even though the ethernet connection itself works. Real hardware with both interfaces doesn't hit this.
- The live root/user account has no password across reboots. The live ISO is stateless, so run `passwd` again each session if you need SSH access for debugging.

## Status

- [x] Branding: ISO metadata, boot menus (syslinux/systemd-boot/grub), splash image, `os-release`/`issue`, hostname, motd
- [x] Package list (niri, noctalia, install-time tooling)
- [x] Live-session config: niri/noctalia/theming configs replicated from a real working setup, `larch` live user with SDDM autologin into niri
- [ ] TUI installer
- [ ] Post-install provisioning (shell/desktop-shell choice, config copy)
