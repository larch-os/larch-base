No os-release/issue overrides exist yet either — those currently fall through to the stock filesystem package defaults ("Arch Linux"), so they're a gap too. Here's the full branding checklist, grouped by area:

1. ISO metadata — profiledef.sh

- iso_name → larch (drives the output filename: larch-YYYY.MM.DD-x86_64.iso)
- iso*label → e.g. LARCH*$(date ...)
- iso_publisher → my name : Anish Araz + https://github.com/larch-os/larch
- iso_application → "Larch Live/Install Medium"
- install_dir → "larch" (optional; boot configs already reference it via %INSTALL_DIR% so this is a one-line, low-risk change)

2. Boot menu text (biggest chunk — all say "Arch Linux install medium")

- Syslinux (BIOS): archiso_head.cfg (MENU TITLE), archiso_sys-linux.cfg, archiso_pxe-linux.cfg — menu labels + help text
- systemd-boot (UEFI): efiboot/loader/entries/01-archiso-linux.conf, 02-archiso-speech-linux.conf — title lines
- GRUB: grub/grub.cfg, grub/loopback.cfg — menuentry titles (the --id/default=archlinux values can stay as internal IDs, or rename to larch for cleanliness)

3. Boot visuals

- syslinux/splash.png — currently the official Arch logo (640×480); needs a Larch splash graphic ( based on the idea generate a sample splash for now, i have a logo file that is present in assets folder.)
- GRUB has no background image configured today — optional to add a Larch-branded one alongside a boot theme

4. OS identity (currently missing → falls back to generic Arch)

- Add airootfs/etc/os-release override: NAME, PRETTY_NAME (e.g. "Larch Linux"), ID=larch, ID_LIKE=arch, HOME_URL, LOGO, ANSI_COLOR — this is what neofetch/fastfetch/GNOME-ish tools and hostnamectl display
- Add airootfs/etc/issue — pre-login TTY banner (currently unset)

5. Live-session text

- airootfs/etc/hostname → larch (currently archiso)
- airootfs/etc/motd → rewrite for Larch voice/tagline instead of the stock Arch wiki blurb (can still link the Arch install guide since it's Arch-based underneath)

6. Naming consistency check

- iso_publisher string and Installation_guide/choose-mirror scripts reference "Arch Linux" in a couple of comments/help strings — low priority, cosmetic only, since the underlying OS genuinely is Arch

---

Not included here (you said later): package list, niri/noctalia configs, installer branding/tray icon, wallpaper for the desktop session — those come with the packages/config step.

Want me to go ahead and implement items 1–5 now, or do you want to hand me the actual copy (tagline placement, splash art) first?
