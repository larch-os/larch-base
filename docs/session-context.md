# Session handoff — where things stand

Read this first in a new session, alongside `README.md` and
`docs/arch-niri-distro-context.md` (the original design write-up for the
installer phase, still not started).

## What's built so far

A fork of archiso's `releng` profile (`archiso/releng/`) that produces a
branded, bootable live ISO which autologins into a real niri + noctalia
desktop — not a rescue TTY. The desktop config is a port of the user's own
daily-driver machine, not something designed from scratch.

- **Branding**: ISO metadata, boot menus (syslinux/systemd-boot/grub),
  splash image, `os-release`/`issue`, hostname, motd. Tagline: "Arch based
  Linux distro for developers and engineers."
- **Live user**: dedicated `larch` user (uid 1000), greetd autologin straight
  into a niri session, passwordless wheel sudo.
- **Desktop**: niri (Wayland compositor) + noctalia v5 (official `extra`
  package, TOML config — migrated off the old AUR v4/JSON setup). Display
  resolution auto-detects (no hardcoded output/connector names, which would
  only match specific real hardware).
- **Terminal/browser**: kitty (not konsole), firefox.
- **Network**: NetworkManager (not systemd-networkd/iwd — noctalia's
  network panel needs it).
- **Shell**: zsh + oh-my-zsh (robbyrussell theme) + `zsh-autosuggestions`,
  `zsh-syntax-highlighting`, `fzf-tab`, `eza`/`fzf`/`zoxide`. Nerd-fonts
  installed for `eza --icons`.
- **Theming**: dark GTK3/GTK4 + dark qt5ct/qt6ct + nwg-look + xsettingsd,
  replicated verbatim from the real machine's already-applied dark theme.
- **Login manager**: greetd + ReGreet (`greetd-regreet`, official `extra`,
  no AUR), replacing SDDM. ReGreet's config/CSS
  (`etc/greetd/regreet.{toml,css}`) is static, shared by live and installed
  alike via the squashfs; `etc/greetd/config.toml`'s autologin differs
  per-install (see `larch-calamares`'s `displaymanager`/`larch-preinstall`
  modules).

Everything above is committed and pushed to `origin/main`
(`git@github.com:larch-os/larch-base.git`). The most recent build,
`larch-2026.08.26-x86_64.iso`, was tested in a libvirt VM with GPU
passthrough and confirmed working.

## Key decisions worth knowing before touching this again

- **oh-my-zsh is a git submodule**, not vendored files. It and its 3
  plugins live at `archiso/releng/airootfs/home/larch/.oh-my-zsh` and
  `vendor/zsh-plugins/*`. `scripts/prepare-iso.sh` checks out the
  submodules and copies the plugins into place (git won't let a submodule
  live inside another submodule's own working tree, hence the copy step).
  Clone with `--recurse-submodules` or nothing works.
- **No `/etc/skel` design.** An alternative approach (install oh-my-zsh
  system-wide under `/usr/share/oh-my-zsh` + wire it via `/etc/skel` so
  every future user gets it automatically) was considered and explicitly
  rejected. The user wants oh-my-zsh scoped to the named `larch` live user
  only; when the installer exists, they'll wire it into the
  installer-created user by hand, deliberately, not via skel magic.
- **Git history was rewritten once** to remove an ~1093-file vendored
  oh-my-zsh commit that had already been pushed, replacing it with the
  submodule-based commits. Already force-pushed and done — not something
  to redo.
- **`grml-zsh-config` is deliberately absent** from `packages.x86_64`. It
  was in the stock `releng` package list and silently overwrote the
  oh-my-zsh prompt via a `precmd_functions` hook — root-caused and removed.
  Don't re-add it.
- **Chaotic-AUR is set up in `customize_airootfs.sh`, not as a static
  `[chaotic-aur]` entry in `pacman.conf`.** It has to run post-pacstrap:
  `mkarchiso` passes `-G` to `pacstrap` (skip copying the host's already-
  trusted keyring), so the *target's own* keyring only becomes usable
  partway through that initial bootstrap — too late to matter for a repo
  that isn't even configured yet, but exactly why the key-trust and repo
  setup work fine here, after pacstrap has already finished. `paru` itself
  is installed this way now (chaotic-aur only carries source-built
  "paru", no functional difference from a "paru-bin" since chaotic
  prebuilds it anyway) — replaced the old local `makepkg` build in
  `scripts/prepare-iso.sh`. `herdr-bin`/`k3d-bin` stay on the local build
  (not on chaotic-aur at all). `visual-studio-code-bin` is only made
  *resolvable* here, never installed on the live ISO — see
  `larch-calamares`'s `netinstall/netinstall.conf`.
- **Never rename the built ISO file.** If a VM needs pointing at a new
  build, repoint the VM's disk XML at the real dated filename
  (`out/larch-<date>-x86_64.iso`) instead.

## VM testing quirks (see README's "Testing in a VM" section for full XML)

niri needs a real GPU render node — plain `virtio-vga`/QXL shows a black
screen forever. Needs `virtio-vga-gl` forced via `qemu:commandline`, a
`<graphics type='egl-headless'><gl rendernode=.../></graphics>` element (a
raw commandline GL flag alone doesn't get libvirt to grant the cgroup
device access), `memfd` shared memory backing, and — since SPICE-over-network
combined with `gl=on` crashes on this host (spice built without a
GStreamer video encoder) — a separate `vnc` graphics element for actually
viewing the console. Any change to video/graphics/memory config needs a
full power-off + start, not a guest reboot (QEMU only re-reads that config
on process restart).

## How the user likes to work (see also the `feedback_commit_style` memory)

- Commits: author as the user only, no co-author trailer.
- Don't self-test the VM/UI — build it, tell the user, they test and
  report back.
- Prefers configs replicated verbatim from the real machine over
  invented/guessed defaults — when in doubt, diff against `~/.config/...`
  on the real machine rather than writing something plausible-looking.
- Wants a clean, readable git history — willing to rewrite history to
  remove accidental large/messy commits before they become "normal."

## Not started yet

- TUI installer (design sketch exists in
  `docs/arch-niri-distro-context.md`, no code).
- Post-install provisioning (shell/desktop-shell choice at install time,
  copying the live config into the installed system).
