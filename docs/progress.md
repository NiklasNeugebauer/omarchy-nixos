# Progress

Phase checklist from `omarchy-nixos-plan.md`. Update this with the work, in the same commit.

Legend: `[x]` done and verified · `[~]` done, not yet verified on hardware · `[ ]` not started

## Phase 0 — scaffolding

- [x] flake with pinned inputs (nixpkgs, home-manager, disko, omarchy `flake = false`)
- [x] repo layout, `.gitignore`, MIT licence + `NOTICE` attributing upstream
- [x] GitHub Actions green — see `.github/workflows/ci.yml` for the jobs
- [x] docs: plan, porting steps, divergences, package inventory, sync procedure

## Phase 1 — the omarchy package

- [x] vendored tree at `$OMARCHY_PATH` (`$out/share/omarchy`)
- [x] shebang rewrite, all occurrences, self-verifying
- [x] `/usr/share/omarchy` → store path, self-verifying
- [x] `/usr/bin/` → system profile, self-verifying
- [x] Arch-machinery command stubs (`pkgs/omarchy/nixos-commands.nix`), build fails on drift
- [x] reimplemented commands (`pkgs/omarchy/commands/`), build fails on drift
- [x] `omarchy-*` on `PATH` as symlinks, so the router's sibling discovery still works
- [x] systemd user units, SDDM theme and Plymouth theme re-exported at NixOS paths
- [x] builds: `nix build .#omarchy`

## Phase 2 — base system

- [x] sysctl, logind, oomd + app.slice, systemd manager limits, zram, zswap off
- [x] faillock / `passwd_tries`, sudoers drop-ins, polkit, keyring, rtkit
- [x] systemd-boot with a generation limit, flake-ready `nix.settings`, weekly GC
- [x] docker via socket activation
- [x] NetworkManager, resolved, the nftables firewall, regdb
- [x] pipewire + wireplumber, bluez, A2DP autoconnect
- [x] cups, avahi, nss-mdns
- [x] the firewall policy is asserted by `tests/session.nix`

## Phase 3 — session

- [x] Hyprland with UWSM, XWayland, uwsm `env.d` drop-in reaching the session
- [x] SDDM with the omarchy theme, optional autologin
- [x] XDG portals (hyprland + gtk), fcitx5, sleep hooks, mimeapps, xdg-terminal-exec
- [x] verified in the VM: the greeter is wired into `graphical.target`, runs sddm with the
      omarchy theme, and the `hyprland-uwsm` session desktop file is installed
- [x] verified visually in a VM: `nix build .#greeter-screenshots` boots to
      `graphical.target` under llvmpipe and the omarchy greeter renders — branded logo,
      lock glyph, password field, theme colours
- [ ] **verified on hardware: logging in reaches a Hyprland session**

## Phase 4 — the shell

- [x] Quickshell + Qt runtime, shell's own units enabled as drop-ins
- [x] lock screen PAM services (`omarchy-lock-password`, `omarchy-lock-fingerprint`)
- [x] no competing notification daemon
- [ ] **verified on hardware: bar, menu, OSD, notifications, lock screen**

## Phase 5 — `$HOME`

- [x] shipped defaults as store symlinks; user-owned files seeded once
- [x] `~/.bashrc` composed with upstream's `default/bash/rc`
- [x] desktop entries, nautilus extensions, agent skills, XCompose, btop theme link
- [x] initial theme applied headlessly on first activation
- [x] verified in the VM: activation succeeds, a user-owned file is seeded, a shipped
      default resolves into the store, and the five per-application colour files are
      rendered — a theme name alone is what a switcher with a broken PATH leaves behind

## Phase 6 — packages

- [x] both `.packages` lists translated; every entry has a row in
      `docs/omarchy-package-inventory.md`
- [x] every attribute resolves against the pinned nixpkgs
- [ ] the `unavailable` set (tensaku, ttfx, aether, omacalc, omacut, omawrite, …) — decide
      per package whether to write a derivation or accept the gap

## Phase 7 — theming

- [x] the vendored themes ship; `omarchy-theme-set` runs at first activation
- [x] verified in the VM: the switcher runs headlessly and writes the theme state
- [ ] **verified on hardware: the switch propagates to terminal, shell, GTK and Qt**

## Phase 8 — disks and hardware

- [x] disko LUKS2 + btrfs subvolumes, argon2id, no key material in the repo
- [x] generic laptop host that refuses to install with the placeholder disk path
- [ ] **verified: installs and boots on real hardware**

## Phase 9 — tests

- [x] `tests/session.nix`: CLI router, FHS regression, stubs, replacements, firewall,
      rendered theme files
- [x] `nix flake check` passes, VM test included
- [x] the VM test executed to completion in a real qemu VM
- [ ] the checklist below run once on real hardware

## Verification checklist

Run once per release. The first list is covered by `nix build .#desktop-screenshots`, so a
regression there fails a build instead of waiting for someone to notice. The second needs a
person at a real machine, and nothing in CI can see any of it.

- [x] boots to Hyprland via UWSM autologin
- [x] Quickshell bar renders: workspaces, clock, tray, battery, volume
- [x] notifications appear
- [x] theme switch propagates to the background and the bar
- [x] the generated per-application theme files exist
- [x] no vendored command calls a tool that is not installed

Needs a person, on hardware:

- [ ] Super+Space unified menu opens and launches apps
- [ ] OSD on volume and brightness keys
- [ ] lock screen engages and unlocks
- [ ] polkit prompt appears (e.g. `systemctl restart` something)
- [ ] theme switch propagates to the terminal, GTK and Qt applications
- [ ] firewall: only 22 and 53317 open (asserted in `tests/session.nix`, worth confirming live)
- [ ] suspend and resume, with the session locked before it sleeps
- [ ] the LUKS passphrase prompt on the encrypted host

## Known gaps

- **Nothing has run on real hardware.** Every unchecked box above is real. The VM checks run
  under llvmpipe on emulated hardware, which is not the same as a GPU, a keyboard, a battery
  or a disk that has to be unlocked.
- The `unavailable` rows in `docs/omarchy-package-inventory.md` are the user-visible cost of
  the port as it stands.
