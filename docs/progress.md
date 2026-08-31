# Progress

Phase checklist from `omarchy-nixos-plan.md`. Update this with the work, in the same commit.

Legend: `[x]` done and verified · `[~]` done, not yet verified on hardware · `[ ]` not started

## Phase 0 — scaffolding

- [x] flake with pinned inputs (nixpkgs, home-manager, disko, omarchy `flake = false`)
- [x] repo layout, `.gitignore`, MIT licence + `NOTICE` attributing upstream
- [x] GitHub Actions: `nix flake check`, `nix build .#omarchy`, format/lint, VM toplevel
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
- [x] NetworkManager, resolved, nftables firewall (22 + 53317 only), regdb
- [x] pipewire + wireplumber, bluez, A2DP autoconnect
- [x] cups, avahi, nss-mdns
- [~] verified: evaluates and builds; the firewall assertion is covered by `tests/session.nix`

## Phase 3 — session

- [x] Hyprland with UWSM, XWayland, uwsm `env.d` drop-in reaching the session
- [x] SDDM with the omarchy theme, optional autologin
- [x] XDG portals (hyprland + gtk), fcitx5, sleep hooks, mimeapps, xdg-terminal-exec
- [ ] **verified on hardware: boots to Hyprland** — see the checklist in `CLAUDE.md`

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
- [ ] **verified: a fresh user gets a working home**

## Phase 6 — packages

- [x] both `.packages` lists translated; 227 rows in `docs/omarchy-package-inventory.md`
- [x] every attribute resolves against the pinned nixpkgs
- [ ] the `unavailable` set (tensaku, ttfx, aether, omacalc, omacut, omawrite, …) — decide
      per package whether to write a derivation or accept the gap

## Phase 7 — theming

- [x] the vendored themes ship; `omarchy-theme-set` runs at first activation
- [ ] **verified: `omarchy theme set` propagates to terminal, shell, GTK and Qt**

## Phase 8 — disks and hardware

- [x] disko LUKS2 + btrfs subvolumes, argon2id, no key material in the repo
- [x] generic laptop host that refuses to install with the placeholder disk path
- [ ] **verified: installs and boots on real hardware**

## Phase 9 — tests

- [x] `tests/session.nix`: CLI router, FHS regression, stubs, replacements, firewall
- [x] `nix flake check` evaluates
- [ ] the VM test executed to completion
- [ ] the `CLAUDE.md` smoke-test checklist run once on hardware

## Known gaps

- Nothing has been run on hardware. Every `[~]` and unchecked box above is real.
- `docs/divergences.md` "Not available" is the user-visible cost of the port right now.
