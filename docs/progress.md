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
- [x] verified in the VM: the greeter is wired into `graphical.target`, runs sddm with the
      omarchy theme, and the `hyprland-uwsm` session desktop file is installed
- [x] verified visually in a VM: `nix build .#greeter-screenshots` boots to
      `graphical.target` under llvmpipe and the omarchy greeter renders — branded logo,
      lock glyph, password field, theme colours
- [ ] **verified on hardware: logging in reaches a Hyprland session** — the checklist in
      `CLAUDE.md` starts after the greeter, and nothing past login has been seen

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
      default resolves into the store, and a theme name is written

## Phase 6 — packages

- [x] both `.packages` lists translated; 227 rows in `docs/omarchy-package-inventory.md`
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

- [x] `tests/session.nix`: CLI router, FHS regression, stubs, replacements, firewall
- [x] `nix flake check` passes, VM test included
- [x] the VM test executed to completion in a real qemu VM
- [ ] the `CLAUDE.md` smoke-test checklist run once on hardware

## Known gaps

- Nothing has been run on hardware, and nothing graphical has been seen. Every unchecked box
  above is real: the VM test asserts that the greeter is wired up, not that it draws.
- `docs/divergences.md` "Not available" is the user-visible cost of the port right now.

## Verified in this session

Run against the pinned inputs:

- `nix build .#omarchy` — the package builds; the porting-step checks pass
- `nix eval` on both hosts' `system.build.toplevel` — evaluates
- `nix build` of `omarchy-vm.config.system.build.toplevel` — the whole closure builds
- `nix fmt --fail-on-change`, `statix check`, `deadnix --fail`, `shellcheck` — clean
- the CLI router against the built tree: `omarchy --help` lists its groups,
  `omarchy commands --check` validates 438 commands' metadata, the stubs fail with a
  pointer, `omarchy-pkg-present` returns the right exit codes, `omarchy version` prints the
  upstream version, `omarchy theme list` reads the vendored themes
- `nix build .#checks.x86_64-linux.session` — the NixOS VM test boots a qemu VM and passes
- `nix build .#greeter-screenshots` — boots to `graphical.target` and the greeter renders
- `nix build .#desktop-screenshots` — autologs in, Hyprland and the Quickshell shell come up,
  the bar and the first-run notifications render, the five generated theme files exist, and
  nothing in the session reported a command it could not find
- `nix flake check` — green
- the porting-step drift guard, checked by building the package against a source tree with
  a stubbed command deleted: the build fails and names the file to edit

Bugs that only a running system exposed, all fixed:

- a shipped-default config directory linked as a store symlink breaks every application that
  rewrites its own config
- `services.displayManager.sddm.enable` does not wire `display-manager.service` into
  `graphical.target` on current nixpkgs, so the system booted to a text console
- the systemd user manager's PATH holds almost nothing on NixOS, so the shipped units'
  scripts could not find `dbus-monitor` and `omarchy-sleep-lock.service` restart-looped
- home-manager activation has its own PATH, so the initial theme switch wrote a theme name
  and a background and rendered none of the per-application colour files
- `XMODIFIERS=@im=fcitx` through `environment.sessionVariables` is parsed by pam_env, which
  reads the leading `@` as an expansion sigil and drops the variable
- `xkbcli` was missing, so the shell's keyboard-layout widget could not enumerate layouts

The last four are the class porting step 7 warns about, and `.#desktop-screenshots` now fails
on any of them: it asserts no command in a live session went unfound.
