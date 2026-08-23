# Custom Arch-Based Linux Distro — Project Context

## Overview
Building a custom Linux distribution based on Arch Linux, featuring **niri** (Wayland scrollable-tiling compositor) and **noctalia** (Quickshell-based desktop shell) as the default experience. The distro will have its own name and logo, but will use the **standard Arch Linux repositories** (no custom package repo).

## Build Approach
- **archiso-based**: fork the official `releng` profile as the base for building the custom ISO.
- Stock Arch repos only — all customization happens through the ISO build config, installer, and post-install provisioning, not through custom packages.
- Rejected Calamares as the installer (too much overhead/maintenance) in favor of a custom TUI/script-based installer.

## Live ISO Behavior
- The ISO boots into a **full live desktop session** — niri + noctalia running by default (not a minimal TTY-only environment).
- This lets users preview the desktop and test hardware (wifi, GPU, trackpad/gestures) before committing to install.
- A tray icon (see below) or a terminal command launches the installer from within the live session.
- The live session's noctalia config can double as the "default" profile config copied into the installed system when the user picks noctalia — single source of truth, no duplicate maintenance.

## Installer Design
- **Not GUI-based (no Calamares)** — a custom TUI, likely built in Go (fits existing skillset) using something like `bubbletea` (Charm), or alternatively a Python `textual`/`questionary` app, or simpler `gum`/`whiptail` menus.
- Runs as root (via `pkexec`/`sudo`) since it performs disk operations.
- Offers **simple flexibility** during install: user picks between options (e.g., **fish vs zsh** shell, **noctalia vs dank material shell** desktop shell), and the installer places the matching configs/packages conditionally based on those choices.

### Installer Flow (step by step)
0. **Launch** — via tray icon or terminal command, runs the TUI fullscreen as root.
1. **Welcome screen** — logo, distro name, blurb, start/quit.
2. **Pre-flight checks** (automatic) — internet connectivity, UEFI vs BIOS detection; show status lines so failures aren't silent.
3. **Disk selection & partitioning** — pick target disk; Auto (erase disk, sane default layout) vs Manual (cfdisk/cgdisk or simple screen); explicit confirmation before destructive actions; optional filesystem choice (ext4 default, btrfs optional).
   - *Open question*: whether to support Manual partitioning in v1 or just ship Auto/erase-disk to start.
4. **System basics** — hostname, timezone (auto-detect + confirm), locale, keyboard layout, user account (username/password), root password or sudo-only.
5. **Custom choice pages** (distro-specific) — shell choice (fish/zsh), desktop shell choice (noctalia/dank material shell), and room for future toggles (extra app bundles, gpu drivers, laptop/desktop tuning). These just set variables; nothing installed yet at this step.
6. **Summary/confirm screen** — show all choices in one place, last chance to edit before committing.
7. **Install (automated, with progress shown)**:
   - Partition + format + mount.
   - `pacstrap` base system + kernel + always-installed core packages (niri, noctalia base, common utils).
   - Generate fstab.
   - `arch-chroot` in: set locale/hostname/timezone, create user, set passwords, set chosen shell (`chsh`), install bootloader (systemd-boot or GRUB depending on detected boot mode).
   - Install conditional package sets based on step 5 choices, and copy matching configs from the `profiles/` tree into the new user's home / `/etc/skel`.
   - Show live progress (step name + spinner/percentage).
8. **Done screen** — install complete, reboot or return to live session, optionally prompt to remove install media.

## Config/Profile Structure (proposed)
```
airootfs/etc/skel/          <- base configs, always applied
profiles/
  shell/fish/*
  shell/zsh/*
  wm-shell/noctalia/*
  wm-shell/dank/*
```
- Installer collects user choices (e.g., written to a temp answers file/env vars during the live session).
- A post-install provisioning script (run via `arch-chroot`) reads the choices and performs the actual package installs + config copy/symlink together, per choice (e.g., `SHELL_PKGS[fish]="fish"`, `WMSHELL_PKGS[noctalia]="noctalia-shell ..."`).

## Tray Icon → Fullscreen Terminal Installer Launch
Two separate mechanisms:

1. **Tray icon**: noctalia (Quickshell-based) likely renders any app that registers as a `StatusNotifierItem` (SNI) over DBus via a `StatusNotifierWatcher`. Build a minimal Go tray binary using `getlantern/systray` (or `fyne-io/systray` fork) that:
   - Sets the distro's icon/tooltip.
   - On click/menu-item, runs: `niri msg action spawn -- foot --title=distro-installer -e /usr/local/bin/distro-installer` (swap `foot` for whichever terminal is bundled).

2. **Fullscreen behavior in niri**: use a declarative **niri window rule** matching the terminal's title, rather than hardcoding fullscreen in the spawn command:
   ```kdl
   window-rule {
       match title="distro-installer"
       open-fullscreen true
   }
   ```

3. **Autostart the tray binary** at live-session boot via niri's `spawn-at-startup`:
   ```kdl
   spawn-at-startup "distro-tray-icon"
   ```

- *Open question*: whether noctalia exposes a way to pin a custom tray icon declaratively (some Quickshell shells allow config-based tray items) vs needing a full SNI passthrough binary — not yet confirmed.

## Open Decisions / Next Steps
- Manual vs Auto-only partitioning for v1.
- Confirm noctalia's tray/SNI capabilities.
- Sketch the archiso profile directory layout (what goes in `airootfs/`, where installer scripts live, autolaunch wiring).
- Build out the installer's actual choice-flow code/script logic.
- Decide bar/launcher/notification daemon stack alongside noctalia (equivalent of waybar/fuzzel/mako pieces) for the live/default config.
- Decide login/session flow specifics (greetd + niri session vs manual `niri-session` start) — noted early on, not yet resolved.
